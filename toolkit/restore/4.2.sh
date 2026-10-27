#!/usr/bin/env bash
# Restore: the network from the end of challenge 4, part 2 (port forwarding and a guest network).
# This is the course's reference build, the answer. Use it only after you have tried the part yourself.
# If you use it, say so in your capstone demo.
# Run it with:  bash /work/toolkit/restore.sh 4.2
# It is a copy of the reference forwarding-guest.sh. It builds part 1 with 4.1.sh, next to it, not with your part 1.
# outside-tests.txt goes to /tmp/networking-restore/, not into your repository.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../lib.sh"
require_root

# The reference writes its result files next to itself. Here they go to /tmp instead, so nothing lands in your repository.
OUT=/tmp/networking-restore
mkdir -p "$OUT"

PART1="$HERE/4.1.sh"
HOMEWWW=/tmp/networking-course-www-home

# Step 1: rebuild the network from part 1 (laptop, phone, router, server, masquerade).
[ -f "$PART1" ] || die "part 1 is missing: $PART1"
echo "--- building the part 1 network"
if ! bash "$PART1" build-only > /tmp/networking-course-part1.log 2>&1; then
  cat /tmp/networking-course-part1.log
  die "your part 1 script failed. Make bash ../part-1-masquerade/test.sh pass first."
fi

# Step 2: a guest computer on its own cable and its own subnet, 192.168.50.0/24.
# The router gets a third plug for it. The guest uses the router as its way out.
ns_add guest
cable_if guest veth-guest router veth-rguest
in_ns router ip addr add 192.168.50.1/24 dev veth-rguest
in_ns guest ip addr add 192.168.50.10/24 dev veth-guest
in_ns guest ip route add default via 192.168.50.1

# Step 3: a web server on the laptop, port 80. This is the page we want friends to reach.
www_make "$HOMEWWW" "home web server"
bg_start home-web laptop busybox httpd -f -p 0.0.0.0:80 -h "$HOMEWWW"
sleep 1

# Step 4: port forwarding. A request to the router's outside address, 203.0.113.1, port 8080,
# is sent on to the laptop's web server, 192.168.1.23 port 80.
# The chain must run BEFORE the router decides where to send the packet. That is the prerouting hook.
in_ns router nft -f - <<'RULES'
add table ip nat
# Gap 1: Open the front door: a request to the router's outside address 203.0.113.1, port 8080, must reach the laptop's web server (192.168.1.23, port 80).
#   Two lines, in the nat table you made in part 1:
#     a) a chain called prerouting: type nat, hook prerouting, priority -100. It runs BEFORE the router decides where to send the packet.
#     b) a rule in it: packets that arrive on "veth-rout" for tcp port 8080 get a new destination (dnat to ADDRESS:PORT)
#   Shapes: add chain ip nat NAME { type nat hook HOOK priority NUMBER ; }
#           add rule ip nat NAME iifname "INTERFACE" tcp dport PORT dnat to ADDRESS:PORT
add chain ip nat prerouting { type nat hook prerouting priority -100 ; }
add rule ip nat prerouting iifname "veth-rout" tcp dport 8080 dnat to 192.168.1.23:80
RULES

# Step 5: keep the guest away from the home network. The forward hook sees packets that pass THROUGH the router.
in_ns router nft -f - <<'RULES'
add table ip filter
# Gap 2: Keep the guest away from the home network. Two lines, in a table called filter:
#     a) a chain called forward: type filter, hook forward, priority 0, policy accept. It sees packets that pass THROUGH the router.
#     b) a rule in it: packets from the guest network 192.168.50.0/24 to the home network 192.168.1.0/24 are dropped
#   Shapes: add chain ip filter NAME { type filter hook HOOK priority NUMBER ; policy accept ; }
#           add rule ip filter NAME ip saddr NETWORK ip daddr NETWORK drop
add chain ip filter forward { type filter hook forward priority 0 ; policy accept ; }
add rule ip filter forward ip saddr 192.168.50.0/24 ip daddr 192.168.1.0/24 drop
RULES

# Step 6: three tests from the outside. The server plays "a friend on the internet".
# run_check LABEL COMMAND...: run COMMAND, and write one line "LABEL: exit CODE" in outside-tests.txt
: > "$OUT/outside-tests.txt"
run_check() {
  local label="$1" code=0
  shift
  "$@" > /dev/null 2>&1 || code=$?
  echo "$label: exit $code" | tee -a "$OUT/outside-tests.txt"
}
echo "--- three tests from the server"
# Gap 3: Run three tests from the server computer with run_check. Use  curl -sS -m 3  (it gives up after 3 seconds).
#     forwarded:   the router's outside address, port 8080 (http://203.0.113.1:8080/). Should exit 0: the forwarding works.
#     unforwarded: the router's outside address, port 22 (http://203.0.113.1:22/). Should exit 7: refused at once, not a timeout.
#     direct:      the laptop's private address (http://192.168.1.23/). Should exit 7: the server has no route to a private address.
#   Shape: run_check LABEL in_ns NAMESPACE curl -sS -m 3 URL
run_check forwarded in_ns server curl -sS -m 3 http://203.0.113.1:8080/
run_check unforwarded in_ns server curl -sS -m 3 http://203.0.113.1:22/
run_check direct in_ns server curl -sS -m 3 http://192.168.1.23/

# Step 7: the guest. It can reach the internet, and it must not reach the home network.
echo "--- the guest reaches the server, which sees the router's address:"
in_ns guest curl -sS -m 3 http://203.0.113.80:8080/cgi-bin/whoami || echo "(failed, exit $?)"
echo "--- the guest asks for the laptop's page (this must be blocked, so it times out):"
in_ns guest curl -sS -m 3 http://192.168.1.23/ || echo "(blocked or failed, exit $?)"
echo "--- the router's rules:"
in_ns router nft list ruleset
echo "Done. Next: bash test.sh"
