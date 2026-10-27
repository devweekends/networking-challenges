#!/usr/bin/env bash
# Restore: the network from the end of challenge 4, part 1 (a home router with masquerade).
# This is the course's reference build, the answer. Use it only after you have tried the part yourself.
# If you use it, say so in your capstone demo.
# Run it with:  bash /work/toolkit/restore.sh 4.1
# It is a copy of the reference masquerade.sh. Like it, it takes one word:
#   bash 4.1.sh               build everything, then run the same-port experiment
#   bash 4.1.sh build-only    build everything and stop (challenge 4 part 2 uses this)
# The experiment's files go to /tmp/networking-restore/, not into your repository.
# Your own part 2 can use it as its part 1:  PART1=/work/toolkit/restore/4.1.sh bash forwarding-guest.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../lib.sh"
require_root

# The reference writes its result files next to itself. Here they go to /tmp instead, so nothing lands in your repository.
OUT=/tmp/networking-restore
mkdir -p "$OUT"

MODE="${1:-full}"
WWW=/tmp/networking-course-www-server

# Step 1: delete anything this course built before.
teardown_all

# Step 2: four computers. The two home devices sit behind the router. The server is "the internet".
ns_add laptop
ns_add phone
ns_add router
ns_add server

# Step 3: the home side. A bridge inside the router works like a small switch:
# laptop and phone plug into it, and the router's inside address lives on the bridge.
in_ns router ip link add br-home type bridge
in_ns router ip link set br-home up
cable_if laptop veth-laptop router veth-rlaptop
cable_if phone veth-phone router veth-rphone
in_ns router ip link set veth-rlaptop master br-home
in_ns router ip link set veth-rphone master br-home
in_ns router ip addr add 192.168.1.1/24 dev br-home
in_ns laptop ip addr add 192.168.1.23/24 dev veth-laptop
in_ns phone ip addr add 192.168.1.24/24 dev veth-phone

# Step 4: the outside. One more cable, from the router's outside plug to the server.
cable_if router veth-rout server veth-server
in_ns router ip addr add 203.0.113.1/24 dev veth-rout
in_ns server ip addr add 203.0.113.80/24 dev veth-server

# Step 5: the server runs a tiny web server on port 8080. Its page /cgi-bin/whoami
# answers with the address and port the visitor appears to have.
www_make "$WWW" "public web server"
bg_start server-web server busybox httpd -f -p 0.0.0.0:8080 -h "$WWW"
sleep 1

# Step 6: make the router route. You did this in challenge 2.
# Gap 1: Three things from challenge 2 are missing:
#     a) switch forwarding on in the router (the setting net.ipv4.ip_forward)
#     b) a default route in the laptop, through the router's inside address 192.168.1.1
#     c) a default route in the phone, through the same address
#   Why: without a), the router throws away packets that are not for itself. Without b) and c), the devices do not know the way out.
#   Shapes: sysctl -w SETTING=VALUE    and    ip route add default via ROUTER_ADDRESS    (run each one inside the right computer, with in_ns)
in_ns router sysctl -w net.ipv4.ip_forward=1
in_ns laptop ip route add default via 192.168.1.1
in_ns phone ip route add default via 192.168.1.1

# With forwarding on, the packet crosses the router. But its source address is still 192.168.1.23,
# and the server has no way to reach that private address. So the ping gets no answer. Masquerade fixes this.
echo "--- before masquerade: the laptop pings the server"
in_ns laptop ping -c1 -W1 203.0.113.80 || echo "(no answer, as expected: the server has no way back to 192.168.1.23)"

# Step 7: masquerade. Every packet that leaves by the outside plug gets the router's outside address as its source.
# The router writes the original into its NAT table (the conntrack table) so it can send the answer back.
# nft wants one setting per line, so we send the rules as a small file with line breaks.
in_ns router nft -f - <<'RULES'
table ip nat {
  chain postrouting {
    type nat hook postrouting priority 100 ; policy accept ;
# Gap 2: Add ONE rule here. Packets that leave through the outside plug, "veth-rout", must be masqueraded.
#   Why: the interface name is the match, and masquerade is the action. In nft, an interface name with a hyphen needs double quotes.
#   Shape of the rule: oifname "INTERFACE" masquerade
    oifname "veth-rout" masquerade
  }
}
RULES

# The mid-point check: a device reaches the server.
echo "--- mid-point: the laptop and the phone ask the server who they are"
in_ns laptop curl -sS -m 3 http://203.0.113.80:8080/cgi-bin/whoami || echo "(failed. Check Gap 1 and Gap 2)"
in_ns phone curl -sS -m 3 http://203.0.113.80:8080/cgi-bin/whoami || echo "(failed. Check Gap 1 and Gap 2)"

if [ "$MODE" = "build-only" ]; then
  echo "Done (build only)."
  exit 0
fi

# Step 8: the same-port experiment. Both devices send from source port 41000 to the same server.
# The laptop uses the slow page, so its conversation stays open for 4 seconds while the phone asks.
echo "--- both devices use source port 41000"
FAST=http://203.0.113.80:8080/cgi-bin/whoami
SLOW=http://203.0.113.80:8080/cgi-bin/slow
# Gap 3: Make the laptop and the phone both connect from source port 41000. curl has an option for the local port: --local-port.
#     1) The laptop asks for $SLOW. Put it in the background with & so it stays open while the phone asks.
#        Save its output in $OUT/same-port-laptop.txt (use > FILE 2>&1)
#     2) After sleep 1, the phone asks for $FAST. Save its output in $OUT/same-port-phone.txt
#   Shape: in_ns NAMESPACE curl -sS --local-port PORT URL > FILE 2>&1
in_ns laptop curl -sS -m 8 --local-port 41000 "$SLOW" > "$OUT/same-port-laptop.txt" 2>&1 &
sleep 1
in_ns phone curl -sS -m 8 --local-port 41000 "$FAST" > "$OUT/same-port-phone.txt" 2>&1
sleep 4

# Gap 4: Read the router's NAT table with conntrack, and keep only the lines for port 8080 (use grep 'dport=8080').
#   Save them in $OUT/conntrack.txt. Hide conntrack's own note with 2>/dev/null.
#   Shape: in_ns NAMESPACE conntrack -L 2>/dev/null | grep 'dport=8080' > FILE
in_ns router conntrack -L 2>/dev/null | grep 'dport=8080' > "$OUT/conntrack.txt" || true

echo "laptop sent from 41000. The server says: $(cat "$OUT/same-port-laptop.txt" 2>/dev/null || echo '(missing. Fill in Gap 3.)')"
echo "phone sent from 41000. The server says:  $(cat "$OUT/same-port-phone.txt" 2>/dev/null || echo '(missing. Fill in Gap 3.)')"
echo "The router's NAT table:"
cat "$OUT/conntrack.txt" 2>/dev/null || echo "(missing. Fill in Gap 4.)"
echo "Done. Next: bash test.sh"
