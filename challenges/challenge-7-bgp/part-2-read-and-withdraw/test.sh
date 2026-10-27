#!/usr/bin/env bash
# Test for challenge 7, part 2. Run it in the lab AFTER you ran:  bash withdraw.sh
# When a check fails, the message says which step of withdraw.sh to look at.
# Must pass: the three files the script saved show the route, the withdrawal and the return;
#   a live withdrawal removes the route from r2 and r1, and the ping fails; the route comes back.
# Must fail on purpose: with the route withdrawn, a ping from r1 to 203.0.113.1 gets no answer.
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
has_route() { ip netns exec "$1" ip route show "$2" 2>/dev/null | grep -q .; }
no_route() { ! has_route "$@"; }
ping_ok() { ip netns exec r1 ping -c1 -W1 -I 198.51.100.1 203.0.113.1; }

if ns_exists r1 && ns_exists r2 && ns_exists r3 && ask_bird r1 show status | grep -q 'BIRD 2'; then
  t_pass "the three networks of part 1 are running"
else
  t_fail "the three networks are not running. Run: bash withdraw.sh"
  t_done
fi

# Your files from the script.
if grep -q 'BGP.as_path: 64497 64498' "$HERE/route-all.txt" 2>/dev/null; then
  t_pass "route-all.txt shows the AS path 64497 64498 (step 2)"
else
  t_fail "route-all.txt is missing, or has no 'BGP.as_path: 64497 64498'. Run bash withdraw.sh again (step 2)"
fi
if grep -q 'Network not found' "$HERE/withdrawn.txt" 2>/dev/null && grep -q ' 0 received' "$HERE/withdrawn.txt" 2>/dev/null; then
  t_pass "withdrawn.txt shows 'Network not found' and a ping with no answer (step 5)"
else
  t_fail "withdrawn.txt should show 'Network not found' and '0 received'. Run bash withdraw.sh again (steps 4 and 5)"
fi
if grep -q '203.0.113.0/24 via 10.0.12.2' "$HERE/back.txt" 2>/dev/null && grep -q ' 0% packet loss' "$HERE/back.txt" 2>/dev/null; then
  t_pass "back.txt shows the route again and a ping with 0% packet loss (step 6)"
else
  t_fail "back.txt should show '203.0.113.0/24 via 10.0.12.2' and '0% packet loss'. Run bash withdraw.sh again (step 6)"
fi

# The route is there now, and the ping works.
wait_until 15 has_route r1 203.0.113.0/24 || true
if has_route r1 203.0.113.0/24 && wait_until 5 ping_ok; then
  t_pass "before the live test: r1 has 203.0.113.0/24 and the ping works"
else
  t_fail "r1 has no working route to 203.0.113.0/24. Did step 6 run? Try: birdc -s /tmp/bird-r3.ctl enable direct1"
fi

# Live test: r3 withdraws. The route must leave r2 and r1.
ask_bird r3 disable direct1 > /dev/null
if wait_until 15 no_route r1 203.0.113.0/24 && no_route r2 203.0.113.0/24; then
  t_pass "after r3 withdraws, r2 and r1 have no route to 203.0.113.0/24"
else
  t_fail "after 'disable direct1' in r3, r1 or r2 still has a route to 203.0.113.0/24"
fi
if ask_bird r1 show route 203.0.113.0/24 | grep -q 'Network not found'; then
  t_pass "r1's BIRD says: Network not found"
else
  t_fail "r1's BIRD should say 'Network not found' for 203.0.113.0/24"
fi

# Must fail: the ping, with the route gone.
RC=0
OUT="$(ip netns exec r1 ping -c1 -W1 -I 198.51.100.1 203.0.113.1 2>&1)" || RC=$?
if [ "$RC" -ne 0 ]; then
  t_pass "with the route withdrawn, the ping from r1 gets no answer"
else
  t_fail "the ping should fail while the route is withdrawn. Ping said: $OUT"
fi

# The withdrawal is counted on r1's session.
if ask_bird r1 show protocols all to_r2 | grep -Eq 'Import withdraws: +[1-9]'; then
  t_pass "r1's session to_r2 counted a withdrawal (Import withdraws)"
else
  t_fail "r1's session to_r2 shows no withdrawal. Run: birdc -s /tmp/bird-r1.ctl show protocols all to_r2"
fi

# r3 announces again. Everything comes back.
ask_bird r3 enable direct1 > /dev/null
if wait_until 15 has_route r1 203.0.113.0/24 && wait_until 5 ping_ok; then
  t_pass "after r3 announces again, r1 has the route and the ping works"
else
  t_fail "after 'enable direct1' in r3, r1 did not get the route back"
fi

t_done
