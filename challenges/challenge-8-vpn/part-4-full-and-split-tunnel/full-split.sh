#!/usr/bin/env bash
# Challenge 8, part 4: a full tunnel, then a split tunnel.
# Run it in the lab:  bash full-split.sh
# It starts by running YOUR part 2 script, so part 2's test must pass first.
# Safe to run again: part 2 rebuilds everything.
# Five things are missing on purpose. Each gap is marked TODO. Fill them in, then run:  bash test.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

PART2="$HERE/../part-2-the-tunnel/tunnel.sh"
KEYS=/tmp/networking-course-wg
WHOAMI=http://192.0.2.80/cgi-bin/whoami

# Step 1: rebuild parts 1 and 2: the office, the cafe, and the tunnel (split, as part 2 left it).
[ -f "$PART2" ] || die "part 2 is missing: $PART2"
echo "--- building parts 1 and 2"
if ! bash "$PART2" build-only > /tmp/networking-course-part2.log 2>&1; then
  cat /tmp/networking-course-part2.log
  die "your part 2 script failed. Make bash ../part-2-the-tunnel/test.sh pass first."
fi
VPNBOX_PUB="$(cat "$KEYS/vpnbox.pub")"
rm -f "$HERE"/website-*.txt "$HERE"/dns-*.txt "$HERE"/cafe-outside-*.txt "$HERE"/routes-*.txt

# Step 2: a name server on each side. Both files are given: cafe-dns.conf and office-dns.conf.
bg_start cafe-dns caferouter dnsmasq --keep-in-foreground --conf-file="$HERE/cafe-dns.conf"
bg_start office-dns officert dnsmasq --keep-in-foreground --conf-file="$HERE/office-dns.conf"
sleep 2
for name in cafe-dns office-dns; do
  if ! kill -0 "$(cat "$NET_PID_DIR/$name.pid")" 2>/dev/null; then
    cat "$NET_PID_DIR/$name.log"
    die "dnsmasq ($name) stopped at once. Its message is above."
  fi
done
# The laptop got its name server from the cafe, as a real cafe's DHCP would give it.
mkdir -p /etc/netns/laptop
echo "nameserver 192.168.50.1" > /etc/netns/laptop/resolv.conf

# capture NS IFACE SECONDS FILTER FILE: run tcpdump in the background. Its process id goes in CAP_PID.
capture() {
  timeout "$3" ip netns exec "$1" tcpdump -n -l -i "$2" $4 > "$5" 2>&1 &
  CAP_PID=$!
  sleep 1
}

# Step 3: before. The website sees the cafe.
echo "--- before: the laptop visits the website"
in_ns laptop curl -sS -m 3 "$WHOAMI" 2>&1 | tee "$HERE/website-before.txt" || true

# Step 4: the full tunnel. Everything the laptop sends goes into wg0.
# TODO 1: First, keep the tunnel's own packets OUT of the tunnel. The outer packets go to the office router,
#   203.0.113.2. Give that one address (a /32) a route through the cafe router, 192.168.50.1.
#   Why: a default route into wg0 would also catch the outer packets. WireGuard would try to send the tunnel
#   through itself, and drop them. A /32 is more exact than the default, so it wins. wg-quick does this for you.
#   Shape: ip route add ADDRESS/32 via ADDRESS      (inside the laptop)

# TODO 2: Now send everything into the tunnel. Two lines, inside the laptop:
#     a) the VPN box may now get packets for ANY address: allowed-ips 0.0.0.0/0 for the peer "$VPNBOX_PUB"
#     b) the default route goes into wg0 (replace the old one, which went to the cafe router)
#   Shapes: wg set wg0 peer PUBLIC_KEY allowed-ips NETWORK       and       ip route replace default dev INTERFACE

# TODO 3: The way back. The website's answer comes back to the office router, which un-NATs it to 10.99.0.2.
#   The office router must know that 10.99.0.0/24 is behind the VPN box, 10.20.0.2.
#   Why: without it, the office router sends the answer to its own default route, out to the internet.
#   (Another way: masquerade on the VPN box, so the office sees only 10.20.0.2. We use the route.)
#   Shape: ip route add NETWORK via ADDRESS      (inside the office router)

{
  echo "=== laptop: ip route"
  in_ns laptop ip route
  echo "=== laptop: wg show wg0 allowed-ips"
  in_ns laptop wg show wg0 allowed-ips
} > "$HERE/routes-full.txt" 2>&1
cat "$HERE/routes-full.txt"

echo "--- full tunnel: the laptop visits the website, while the cafe's outside plug is captured"
capture caferouter veth-cafe-out 5 ip "$HERE/cafe-outside-full.txt"
in_ns laptop curl -sS -m 3 "$WHOAMI" 2>&1 | tee "$HERE/website-full.txt" || true
wait "$CAP_PID" || true
grep -E '^[0-9]{2}:' "$HERE/cafe-outside-full.txt" || true

# Step 5: DNS in a full tunnel. The laptop still asks the cafe's name server, 192.168.50.1.
# That address is on the laptop's own cable, so its route is more exact than the default. The question leaves in the clear.
echo "--- full tunnel: the laptop looks up web.test. The capture is on the cafe router's inside plug"
capture caferouter veth-cafe-in 4 "udp port 53" "$HERE/dns-cafe.txt"
in_ns laptop dig +short +time=2 +tries=1 web.test || true
wait "$CAP_PID" || true
grep -E '^[0-9]{2}:' "$HERE/dns-cafe.txt" || true

# TODO 4: Point the laptop's name server through the tunnel: the office's, 10.20.0.1.
#   Why: then the question travels inside wg0, and the cafe sees only UDP 51820.
#   The laptop reads its name server from /etc/netns/laptop/resolv.conf. Write one line there.
#   Shape: echo "nameserver ADDRESS" > /etc/netns/laptop/resolv.conf

echo "--- DNS through the tunnel: captures on the cafe router's inside plug and on the VPN box's wg0"
capture caferouter veth-cafe-in 5 "udp port 53" "$HERE/dns-cafe-after.txt"
CAFE_CAP=$CAP_PID
capture vpnbox wg0 4 "udp port 53" "$HERE/dns-tunnel.txt"
in_ns laptop dig +short +time=2 +tries=1 web.test || true
in_ns laptop dig +short +time=2 +tries=1 intranet.test || true
wait "$CAFE_CAP" "$CAP_PID" || true
echo "cafe inside plug:"
grep -E '^[0-9]{2}:' "$HERE/dns-cafe-after.txt" || echo "(no DNS packets)"
echo "VPN box wg0:"
grep -E '^[0-9]{2}:' "$HERE/dns-tunnel.txt" || echo "(no DNS packets)"

# Step 6: the split tunnel. Only the office goes into the tunnel. The rest goes out through the cafe.
# TODO 5: Undo the full tunnel. Two lines, inside the laptop:
#     a) the VPN box gets only the office again: allowed-ips 10.20.0.0/24,10.99.0.1/32 for the peer "$VPNBOX_PUB"
#     b) the default route goes back to the cafe router, 192.168.50.1
#   The route 10.20.0.0/24 dev wg0 from part 2 is still there, so office traffic still goes into the tunnel.
#   Shapes: wg set wg0 peer PUBLIC_KEY allowed-ips NET1,NET2       and       ip route replace default via ADDRESS
# The /32 from Gap 1 is not needed any more.
in_ns laptop ip route del 203.0.113.2/32 2> /dev/null || true

{
  echo "=== laptop: ip route"
  in_ns laptop ip route
  echo "=== laptop: wg show wg0 allowed-ips"
  in_ns laptop wg show wg0 allowed-ips
} > "$HERE/routes-split.txt" 2>&1
cat "$HERE/routes-split.txt"

echo "--- split tunnel: the laptop visits the website and pings the office, while the cafe's outside plug is captured"
capture caferouter veth-cafe-out 5 ip "$HERE/cafe-outside-split.txt"
in_ns laptop curl -sS -m 3 "$WHOAMI" 2>&1 | tee "$HERE/website-split.txt" || true
in_ns laptop ping -c1 -W2 10.20.0.5 > /dev/null || echo "(the office did not answer)"
wait "$CAP_PID" || true
grep -E '^[0-9]{2}:' "$HERE/cafe-outside-split.txt" || true

echo "Done. Next: bash test.sh"
