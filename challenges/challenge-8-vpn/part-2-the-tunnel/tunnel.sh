#!/usr/bin/env bash
# Challenge 8, part 2: a WireGuard tunnel from the cafe laptop to the office VPN box.
# Run it in the lab:
#   bash tunnel.sh               build part 1, bring up the tunnel, then send one packet with a false source
#   bash tunnel.sh build-only    build part 1 and the tunnel, and stop (parts 3 and 4 use this)
# It starts by running YOUR part 1 script, so part 1's test must pass first.
# Safe to run again: part 1 deletes the old network, and new keys are made each time.
# Four things are missing on purpose. Each gap is marked TODO. Fill them in, then run:  bash test.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

MODE="${1:-full}"
PART1="$HERE/../part-1-office-and-cafe/office-cafe.sh"
KEYS=/tmp/networking-course-wg

# Step 1: rebuild the office, the cafe and the internet from part 1.
[ -f "$PART1" ] || die "part 1 is missing: $PART1"
echo "--- building the part 1 network"
if ! bash "$PART1" build-only > /tmp/networking-course-part1.log 2>&1; then
  cat /tmp/networking-course-part1.log
  die "your part 1 script failed. Make bash ../part-1-office-and-cafe/test.sh pass first."
fi

# Step 2: before the tunnel. The laptop cannot reach the office server.
echo "--- before the tunnel: the laptop pings 10.20.0.5"
in_ns laptop ping -c1 -W1 10.20.0.5 > "$HERE/before-tunnel.txt" 2>&1 || true
cat "$HERE/before-tunnel.txt"

# Step 3: keys. Each side makes a private key and works out its public key from it.
# The private key never leaves its computer. The public key is what you give to the other side.
# The keys live in /tmp, outside your repository. Never commit a private key.
rm -rf "$KEYS"
mkdir -p "$KEYS"
umask 077
# TODO 1: Make two key pairs: one for the VPN box, one for the laptop.
#   wg genkey prints a new private key. wg pubkey reads a private key and prints its public key.
#   tee saves the private key in a file and also passes it on to wg pubkey.
#   Files: $KEYS/vpnbox.key and $KEYS/vpnbox.pub, then $KEYS/laptop.key and $KEYS/laptop.pub
#   Shape: wg genkey | tee PRIVATE_FILE | wg pubkey > PUBLIC_FILE      (one line for each side)
umask 022
for f in vpnbox.key vpnbox.pub laptop.key laptop.pub; do
  [ -s "$KEYS/$f" ] || die "Gap 1: $KEYS/$f is missing or empty. Make the keys first."
done

# Step 4: the office end of the tunnel, on the VPN box. This one is given. Read it: Gap 2 is its mirror.
#   listen-port 51820   the port the office router forwards to this box (part 1)
#   peer ... allowed-ips 10.99.0.2/32   the laptop may send from 10.99.0.2 only, and packets to 10.99.0.2 go to the laptop
in_ns vpnbox ip link add wg0 type wireguard
in_ns vpnbox wg set wg0 private-key "$KEYS/vpnbox.key" listen-port 51820 \
  peer "$(cat "$KEYS/laptop.pub")" allowed-ips 10.99.0.2/32
in_ns vpnbox ip addr add 10.99.0.1/24 dev wg0
in_ns vpnbox ip link set wg0 up
# The VPN box passes packets between the tunnel and the office network, so it must forward.
in_ns vpnbox sysctl -qw net.ipv4.ip_forward=1

# Step 5: the cafe end of the tunnel, on the laptop.
in_ns laptop ip link add wg0 type wireguard
# TODO 2: Set up the laptop's end with one wg set line. It needs:
#     private-key   the laptop's private key file
#     listen-port   51820, the same port as the office end
#     peer          the VPN box's PUBLIC key, "$(cat "$KEYS/vpnbox.pub")"
#     endpoint      where to send the outer packets: the office router's outside address and the forwarded port, 203.0.113.2:51820
#     allowed-ips   which inner addresses go to this peer: the office network 10.20.0.0/24 and the VPN box's tunnel address 10.99.0.1/32 (comma between them, no space)
#   Shape: in_ns laptop wg set wg0 private-key FILE listen-port PORT peer PUBLIC_KEY endpoint ADDRESS:PORT allowed-ips NET1,NET2
in_ns laptop ip addr add 10.99.0.2/24 dev wg0
in_ns laptop ip link set wg0 up

# Step 6: routes. AllowedIPs picks the peer once a packet is IN wg0. It does not put packets into wg0.
# The routing table does that. wg-quick would add this route for you. Here you add it by hand.
# TODO 3: On the laptop, send the office network 10.20.0.0/24 into the tunnel.
#   Why: without it, the laptop sends 10.20.0.5 to its default route, the cafe router, and the internet drops it.
#   Shape: ip route add NETWORK dev INTERFACE      (inside the laptop)

# TODO 4: On the office server, the way back to the tunnel network 10.99.0.0/24 is through the VPN box, 10.20.0.2.
#   Why: the ping arrives at the server from 10.99.0.2. Without this route, the server sends its answer
#   to its default route, the office router, which sends it out to the internet. The laptop never gets it.
#   Shape: ip route add NETWORK via ADDRESS      (inside the office server)

# Step 7: with the tunnel. The first packet starts the handshake, so give it 2 seconds.
echo "--- with the tunnel: the laptop pings the VPN box's tunnel address, then the office server"
in_ns laptop ping -c1 -W2 10.99.0.1 || echo "(no answer. Check Gap 1 and Gap 2)"
in_ns laptop ping -c2 -W2 10.20.0.5 > "$HERE/with-tunnel.txt" 2>&1 || true
cat "$HERE/with-tunnel.txt"
echo "--- the office test page, through the tunnel"
in_ns laptop curl -sS -m 3 http://10.20.0.5/ || echo "(failed. Check Gap 3 and Gap 4)"

# Step 8: what each end knows about the other. Save it for your results.
{
  echo "=== laptop"
  in_ns laptop wg show wg0
  echo
  echo "=== vpnbox"
  in_ns vpnbox wg show wg0
} > "$HERE/wg-show.txt" 2>&1
cat "$HERE/wg-show.txt"

if [ "$MODE" = "build-only" ]; then
  echo "Done (build only)."
  exit 0
fi

# Step 9: a packet with a false source. The laptop gets a second tunnel address, 10.99.0.66, and pings from it.
# The VPN box only accepts 10.99.0.2 from this peer (its allowed-ips). Watch its wg0 receive errors.
rx_errors() {
  in_ns vpnbox ip -s link show wg0 | awk '/RX:/ { getline; print $3; exit }'
}
echo "--- one packet from 10.99.0.66, a source the VPN box does not allow"
BEFORE="$(rx_errors)"
in_ns laptop ip addr add 10.99.0.66/32 dev wg0
# The VPN box listens on its wg0 while the laptop sends. A dropped packet never reaches wg0, so tcpdump sees nothing.
timeout 3 ip netns exec vpnbox tcpdump -n -l -i wg0 icmp > "$HERE/spoof-capture.txt" 2>&1 &
WATCH=$!
sleep 1
in_ns laptop ping -c1 -W1 -I 10.99.0.66 10.20.0.5 || echo "(no answer)"
wait "$WATCH" || true
in_ns laptop ip addr del 10.99.0.66/32 dev wg0
AFTER="$(rx_errors)"
echo "VPN box wg0 receive errors: before $BEFORE, after $AFTER" | tee "$HERE/spoof.txt"
in_ns vpnbox ip -s link show wg0 | tee -a "$HERE/spoof.txt"
echo "--- what tcpdump saw on the VPN box's wg0 during that ping:"
cat "$HERE/spoof-capture.txt"

echo "Done. Next: bash test.sh"
