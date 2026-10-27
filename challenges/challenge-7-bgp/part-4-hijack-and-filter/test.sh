#!/usr/bin/env bash
# Test for challenge 7, part 4. Run it in the lab AFTER you ran:  bash hijack.sh
# When a check fails, the message says which GAP in hijack.sh to look at.
# Must pass: r2 announces 198.51.100.128/25 (r1 still learns it); hijack.txt shows the /25 won in r3
#   and r2 answered for 198.51.100.130; now r3 uses owner_only on both sessions, has the real /24
#   from AS64496, keeps the /25 only as filtered, and r1 answers for 198.51.100.130 again.
# Must fail on purpose: a /24 announced by the wrong network (AS64497) is filtered by r3.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

ask_bird() { birdc -s "/tmp/bird-$1.ctl" "${@:2}" 2>&1 || true; }
wait_until() {
  local end=$((SECONDS + $1))
  shift
  until "$@" > /dev/null 2>&1; do
    [ "$SECONDS" -lt "$end" ] || return 1
    sleep 0.5
  done
}
established() { ask_bird "$1" show protocols "$2" | grep -q Established; }
has_route() { ip netns exec "$1" ip route show "$2" 2>/dev/null | grep -q .; }
no_route() { ! has_route "$@"; }
visit() { ip netns exec r3 curl -sS -m 3 --interface 203.0.113.1 "http://$1:8080/" 2>&1 || true; }
in_filtered() { ask_bird r3 show route filtered all "$1" | grep -q "BGP.as_path: $2\$"; }

if ns_exists r1 && ns_exists r2 && ns_exists r3 && ip netns exec r1 ip link show veth-to-r3 > /dev/null 2>&1; then
  t_pass "namespaces r1, r2 and r3 exist, with the direct link r1 -- r3"
else
  t_fail "the triangle is missing. Run: bash hijack.sh"
  t_done
fi
for r in r1 r2 r3; do
  if ask_bird "$r" show status | grep -q 'BIRD 2'; then
    t_pass "BIRD answers in $r"
  else
    t_fail "BIRD does not answer in $r. Is the file valid? Run: bird -p -c $HERE/$r.conf"
  fi
done
ALL_UP=yes
for pair in "r1 to_r2" "r1 to_r3" "r2 to_r1" "r2 to_r3" "r3 to_r2" "r3 to_r1"; do
  set -- $pair
  wait_until 20 established "$1" "$2" || ALL_UP="no ($1 $2)"
done
if [ "$ALL_UP" = yes ]; then
  t_pass "all six BGP sessions are Established"
else
  t_fail "a BGP session is not Established: $ALL_UP. Run: birdc -s /tmp/bird-r3.ctl show protocols"
fi

# Gap 1: the hijack.
if ip netns exec r2 ip -4 addr show dev dummy0 2>/dev/null | grep -q 'inet 198.51.100.130/25 '; then
  t_pass "GAP 1: r2's dummy0 has 198.51.100.130/25"
else
  t_fail "GAP 1: r2's dummy0 has no 198.51.100.130/25. Run: ip netns exec r2 ip addr show dev dummy0"
fi
if ask_bird r1 show route all 198.51.100.128/25 | grep -q 'BGP.as_path: 64497$'; then
  t_pass "GAP 1: r2 announces 198.51.100.128/25 (r1 learns it with AS path 64497)"
else
  t_fail "GAP 1: r1 does not learn 198.51.100.128/25 from r2. r2 is not announcing it"
fi
if grep -q 'r2 (AS64497)' "$HERE/hijack.txt" 2>/dev/null && grep -q '198.51.100.128/25' "$HERE/hijack.txt"; then
  t_pass "GAP 1: hijack.txt shows the /25 in r3, and r2 answered for 198.51.100.130"
else
  t_fail "GAP 1: hijack.txt should show 198.51.100.128/25 and the page 'r2 (AS64497), the wrong network'. Fill in Gap 1, then run bash hijack.sh again"
fi
if grep -A1 '### r3 visits 198.51.100.1$' "$HERE/hijack.txt" 2>/dev/null | grep -q 'r1 (AS64496)'; then
  t_pass "hijack.txt shows the split: 198.51.100.1 still went to r1"
else
  t_fail "hijack.txt should show r1 answering for 198.51.100.1 during the hijack. Run bash hijack.sh again"
fi

# Gap 3: the filter is used on both of r3's sessions.
F3=0
for s in to_r2 to_r1; do
  if ask_bird r3 show protocols all "$s" | grep -q 'Input filter: *owner_only'; then
    F3=$((F3 + 1))
  fi
done
if [ "$F3" -eq 2 ]; then
  t_pass "GAP 3: r3 uses owner_only on both sessions (Input filter: owner_only)"
else
  t_fail "GAP 3: r3 should show 'Input filter: owner_only' on to_r2 and to_r1. Set R3_IMPORT. Run: birdc -s /tmp/bird-r3.ctl show protocols all to_r2"
fi

# Gap 2: the line that accepts the real owner.
wait_until 15 has_route r3 198.51.100.0/24 || true
if ask_bird r3 show route all 198.51.100.0/24 primary | grep -q 'BGP.as_path: 64496$'; then
  t_pass "GAP 2: r3 accepts 198.51.100.0/24 from AS64496 (its best route has AS path 64496)"
elif [ "$F3" -eq 2 ]; then
  t_fail "GAP 2: r3 has no route for 198.51.100.0/24 from AS64496. Your filter rejects everything. Add the accept line in owner_only"
else
  t_fail "GAP 2: r3 should have 198.51.100.0/24 with AS path 64496"
fi

# The result: the /25 is gone from r3, but BIRD keeps it as filtered, and r1 answers again.
wait_until 15 no_route r3 198.51.100.128/25 || true
if no_route r3 198.51.100.128/25 && in_filtered 198.51.100.128/25 64497; then
  t_pass "r3 has no route for the /25. BIRD lists it under 'show route filtered'"
elif has_route r3 198.51.100.128/25; then
  t_fail "r3 still uses 198.51.100.128/25, the stolen block. Check GAP 3 (is the filter used?) and GAP 2"
else
  t_fail "r3 has no /25 to filter, because nobody announces one. Fill in GAP 1 first"
fi
PAGE="$(visit 198.51.100.130)"
if grep -q 'r1 (AS64496)' <<< "$PAGE"; then
  t_pass "r3 reaches the real owner again: $PAGE"
else
  t_fail "r3 should reach r1 at 198.51.100.130. The page said: $PAGE. Check GAP 2 and GAP 3"
fi
if grep -q 'r1 (AS64496)' "$HERE/after-filter.txt" 2>/dev/null && ! grep -q 'r2 (AS64497)' "$HERE/after-filter.txt"; then
  t_pass "after-filter.txt shows r1 answering for both addresses"
else
  t_fail "after-filter.txt should show only r1 answering. Run bash hijack.sh again"
fi

# Must fail on purpose: the wrong network announces the whole /24. r3 must filter it.
ip netns exec r2 ip addr add 198.51.100.200/24 dev dummy0 2>/dev/null || true
if wait_until 15 in_filtered 198.51.100.0/24 64497; then
  t_pass "a /24 announced by AS64497 (the wrong origin) is filtered by r3"
elif [ "$F3" -ne 2 ]; then
  t_fail "GAP 3: r3 accepted 198.51.100.0/24 from AS64497, because it uses no filter. Set R3_IMPORT"
elif ask_bird r3 show route all 198.51.100.0/24 protocol to_r2 | grep -q 'BGP.as_path: 64497$'; then
  t_fail "GAP 2: r3 accepted 198.51.100.0/24 from AS64497. The filter must check the origin too: bgp_path.last = 64496"
else
  t_fail "r3 did not receive 198.51.100.0/24 from AS64497 at all. Check GAP 3 (import keep filtered on must stay)"
fi
ip netns exec r2 ip addr del 198.51.100.200/24 dev dummy0 2>/dev/null || true

t_done
