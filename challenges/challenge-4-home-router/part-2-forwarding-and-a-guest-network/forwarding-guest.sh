#!/usr/bin/env bash
# Challenge 4, part 2: port forwarding and a guest network.
# Run it in the lab:  bash forwarding-guest.sh
# It starts by running YOUR part 1 script, so finish part 1 first (all its checks must pass).
# Safe to run again: part 1 deletes the old network first.
# Three things are missing on purpose. Each gap is marked TODO. Fill them in, then run:  bash test.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

PART1="$HERE/../part-1-masquerade/masquerade.sh"
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
# TODO 1: Open the front door: a request to the router's outside address 203.0.113.1, port 8080, must reach the laptop's web server (192.168.1.23, port 80).
#   Two lines, in the nat table you made in part 1:
#     a) a chain called prerouting: type nat, hook prerouting, priority -100. It runs BEFORE the router decides where to send the packet.
#     b) a rule in it: packets that arrive on "veth-rout" for tcp port 8080 get a new destination (dnat to ADDRESS:PORT)
#   Shapes: add chain ip nat NAME { type nat hook HOOK priority NUMBER ; }
#           add rule ip nat NAME iifname "INTERFACE" tcp dport PORT dnat to ADDRESS:PORT
RULES

# Step 5: keep the guest away from the home network. The forward hook sees packets that pass THROUGH the router.
in_ns router nft -f - <<'RULES'
add table ip filter
# TODO 2: Keep the guest away from the home network. Two lines, in a table called filter:
#     a) a chain called forward: type filter, hook forward, priority 0, policy accept. It sees packets that pass THROUGH the router.
#     b) a rule in it: packets from the guest network 192.168.50.0/24 to the home network 192.168.1.0/24 are dropped
#   Shapes: add chain ip filter NAME { type filter hook HOOK priority NUMBER ; policy accept ; }
#           add rule ip filter NAME ip saddr NETWORK ip daddr NETWORK drop
RULES

# Step 6: three tests from the outside. The server plays "a friend on the internet".
# run_check LABEL COMMAND...: run COMMAND, and write one line "LABEL: exit CODE" in outside-tests.txt
: > "$HERE/outside-tests.txt"
run_check() {
  local label="$1" code=0
  shift
  "$@" > /dev/null 2>&1 || code=$?
  echo "$label: exit $code" | tee -a "$HERE/outside-tests.txt"
}
echo "--- three tests from the server"
# TODO 3: Run three tests from the server computer with run_check. Use  curl -sS -m 3  (it gives up after 3 seconds).
#     forwarded:   the router's outside address, port 8080 (http://203.0.113.1:8080/). Should exit 0: the forwarding works.
#     unforwarded: the router's outside address, port 22 (http://203.0.113.1:22/). Should exit 7: refused at once, not a timeout.
#     direct:      the laptop's private address (http://192.168.1.23/). Should exit 7: the server has no route to a private address.
#   Shape: run_check LABEL in_ns NAMESPACE curl -sS -m 3 URL

# Step 7: the guest. It can reach the internet, and it must not reach the home network.
echo "--- the guest reaches the server, which sees the router's address:"
in_ns guest curl -sS -m 3 http://203.0.113.80:8080/cgi-bin/whoami || echo "(failed, exit $?)"
echo "--- the guest asks for the laptop's page (this must be blocked, so it times out):"
in_ns guest curl -sS -m 3 http://192.168.1.23/ || echo "(blocked or failed, exit $?)"
echo "--- the router's rules:"
in_ns router nft list ruleset
echo "Done. Next: bash test.sh"
