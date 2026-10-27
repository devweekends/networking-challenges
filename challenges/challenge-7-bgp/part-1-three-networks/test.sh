#!/usr/bin/env bash
# Test for challenge 7, part 1. Run it in the lab AFTER you ran:  bash three-networks.sh
# When a check fails, the message says which step of three-networks.sh to look at.
# Must pass: three BIRD programs run; the three BGP sessions are up; r1 has 203.0.113.0/24
#   through r2 with the AS path 64497 64498; r3 has 198.51.100.0/24 with the AS path 64497 64496;
#   a ping from r1's block reaches r3's block.
# Must fail on purpose: a ping from r1's cable address gets no answer (nobody announces the cables).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

# ask_bird ROUTER COMMAND...: ask the BIRD program in ROUTER. Never stops the test.
ask_bird() { birdc -s "/tmp/bird-$1.ctl" "${@:2}" 2>&1 || true; }
# wait_until SECONDS COMMAND...: run COMMAND every half second until it works, or until SECONDS have passed.
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

# The three routers must exist.
if ns_exists r1 && ns_exists r2 && ns_exists r3; then
  t_pass "namespaces r1, r2 and r3 exist"
else
  t_fail "namespaces are missing. Run: bash three-networks.sh"
  t_done
fi

# Step 7: one BIRD program per router.
for r in r1 r2 r3; do
  if ask_bird "$r" show status | grep -q 'BIRD 2'; then
    t_pass "BIRD answers in $r"
  else
    t_fail "BIRD does not answer in $r. Look at step 7, and at the log: cat /tmp/networking-course-pids/bird-$r.log"
  fi
done

# Step 8: the three sessions are up.
for pair in "r1 to_r2" "r2 to_r1" "r2 to_r3" "r3 to_r2"; do
  set -- $pair
  if wait_until 20 established "$1" "$2"; then
    t_pass "the BGP session $2 in $1 is Established"
  else
    t_fail "the BGP session $2 in $1 is not Established. Look at step 6 (the neighbor address and AS number) and run: birdc -s /tmp/bird-$1.ctl show protocols"
  fi
done

# r1 learned r3's block, through r2, with the right AS path.
wait_until 15 has_route r1 203.0.113.0/24 || true
R1_ALL="$(ask_bird r1 show route all 203.0.113.0/24)"
if grep -q 'BGP.as_path: 64497 64498$' <<< "$R1_ALL" && grep -q 'via 10.0.12.2 on veth-to-r2' <<< "$R1_ALL"; then
  t_pass "r1's BIRD has 203.0.113.0/24 via 10.0.12.2 (r2), AS path 64497 64498"
else
  t_fail "r1's BIRD should have 203.0.113.0/24 via 10.0.12.2 with BGP.as_path: 64497 64498. It shows: $R1_ALL"
fi
R1_KERNEL="$(ip netns exec r1 ip route show 203.0.113.0/24 2>/dev/null || true)"
if grep -q 'via 10.0.12.2 dev veth-to-r2 proto bird' <<< "$R1_KERNEL"; then
  t_pass "Linux in r1 has the route: $R1_KERNEL"
else
  t_fail "Linux in r1 has no BIRD route to 203.0.113.0/24. Look at the kernel protocol in step 6. ip route says: '$R1_KERNEL'"
fi

# r3 learned r1's block the same way.
wait_until 15 has_route r3 198.51.100.0/24 || true
R3_ALL="$(ask_bird r3 show route all 198.51.100.0/24)"
if grep -q 'BGP.as_path: 64497 64496$' <<< "$R3_ALL"; then
  t_pass "r3's BIRD has 198.51.100.0/24 with AS path 64497 64496"
else
  t_fail "r3's BIRD should have 198.51.100.0/24 with BGP.as_path: 64497 64496. It shows: $R3_ALL"
fi

# Must pass: a ping from r1's block to r3's block.
RC=0
OUT="$(ip netns exec r1 ping -c2 -W1 -I 198.51.100.1 203.0.113.1 2>&1)" || RC=$?
if [ "$RC" -eq 0 ]; then
  t_pass "a ping from 198.51.100.1 (r1) reaches 203.0.113.1 (r3)"
else
  t_fail "a ping from 198.51.100.1 to 203.0.113.1 failed. Check forwarding in r2 (step 4) and the dummy addresses (step 5). Ping said: $OUT"
fi

# Must fail: from r1's cable address. r3 has no route back to 10.0.12.0/24, so the answer is lost.
RC=0
OUT="$(ip netns exec r1 ping -c1 -W1 -I 10.0.12.1 203.0.113.1 2>&1)" || RC=$?
if [ "$RC" -ne 0 ] && grep -q '0 received' <<< "$OUT"; then
  t_pass "a ping from the cable address 10.0.12.1 gets no answer (nobody announces 10.0.12.0/24)"
else
  t_fail "a ping from 10.0.12.1 should get no answer, because r3 has no way back to it. Did you announce more than dummy0? Ping said: $OUT"
fi

t_done
