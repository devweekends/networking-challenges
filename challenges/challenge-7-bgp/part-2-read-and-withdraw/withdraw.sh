#!/usr/bin/env bash
# Challenge 7, part 2: read a BGP route, then withdraw it and bring it back.
# Run it in the lab:  bash withdraw.sh
# Safe to run again: it builds part 1 again from nothing first.
# It saves three files here: route-all.txt, withdrawn.txt and back.txt.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

wait_until() {
  local end=$((SECONDS + $1))
  shift
  until "$@" > /dev/null 2>&1; do
    [ "$SECONDS" -lt "$end" ] || return 1
    sleep 0.5
  done
}
has_route() { ip netns exec "$1" ip route show "$2" | grep -q .; }
no_route() { ! has_route "$@"; }

# Step 1: build the three networks of part 1 again (r1 -- r2 -- r3, BIRD in each).
echo "--- building part 1 again"
bash "$HERE/../part-1-three-networks/three-networks.sh" > /dev/null
wait_until 15 has_route r1 203.0.113.0/24 || echo "(r1 has no route to 203.0.113.0/24. Run part 1 and its test first)"

# Step 2: read the whole route r1 has for r3's block. Save it in route-all.txt.
echo "--- r1: show route all 203.0.113.0/24"
birdc -s /tmp/bird-r1.ctl show route all 203.0.113.0/24 | tee "$HERE/route-all.txt"

# Step 3: the same block, seen from r2. r2 is next to r3, so its path is one network long.
echo "--- r2: show route all 203.0.113.0/24"
birdc -s /tmp/bird-r2.ctl show route all 203.0.113.0/24

# Step 4: r3 withdraws its block. We tell r3's BIRD to stop announcing its own addresses.
# The address 203.0.113.1 stays on r3. Only the announcement goes.
echo "--- r3 withdraws 203.0.113.0/24"
birdc -s /tmp/bird-r3.ctl disable direct1
wait_until 15 no_route r1 203.0.113.0/24 || echo "(r1 still has the route)"

# Step 5: look at r1 now. Save what you see in withdrawn.txt.
# birdc ends with an error code when it finds no route, so "|| true" lets the script go on.
{
  echo "### birdc -s /tmp/bird-r1.ctl show route all 203.0.113.0/24"
  birdc -s /tmp/bird-r1.ctl show route all 203.0.113.0/24 || true
  echo "### ip netns exec r1 ip route"
  in_ns r1 ip route
  echo "### ip netns exec r1 ping -c2 -W1 -I 198.51.100.1 203.0.113.1"
  in_ns r1 ping -c2 -W1 -I 198.51.100.1 203.0.113.1 2>&1 || true
  echo "### the withdrawal r1 received (birdc -s /tmp/bird-r1.ctl show protocols all to_r2)"
  birdc -s /tmp/bird-r1.ctl show protocols all to_r2 | grep -E 'Routes:|Route change stats|Import updates|Import withdraws' || true
} > "$HERE/withdrawn.txt" 2>&1
cat "$HERE/withdrawn.txt"

# Step 6: r3 announces its block again. Save what you see in back.txt.
echo "--- r3 announces 203.0.113.0/24 again"
birdc -s /tmp/bird-r3.ctl enable direct1
wait_until 15 has_route r1 203.0.113.0/24 || echo "(r1 has no route yet)"
{
  echo "### ip netns exec r1 ip route"
  in_ns r1 ip route
  echo "### ip netns exec r1 ping -c2 -W1 -I 198.51.100.1 203.0.113.1"
  in_ns r1 ping -c2 -W1 -I 198.51.100.1 203.0.113.1 2>&1 || true
} > "$HERE/back.txt" 2>&1
cat "$HERE/back.txt"
echo "Done. Next: bash test.sh"
