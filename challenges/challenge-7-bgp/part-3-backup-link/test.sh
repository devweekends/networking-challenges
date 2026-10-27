#!/usr/bin/env bash
# Test for challenge 7, part 3. Run it in the lab AFTER you ran:  bash backup-link.sh
# When a check fails, the message says which GAP in backup-link.sh to look at.
# Must pass: the direct link r1 -- r3 carries a BGP session; before the preference it won on path length;
#   now r1 and r3 both use r2, and the direct routes have local preference 50;
#   when r2's session to r1 is cut, both move to the direct link and the ping still works;
#   when it comes back, both move back to r2.
# The test cuts and restores the main link itself, so it does not trust your files alone.
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
uses() { ip netns exec "$1" ip route show "$2" 2>/dev/null | grep -q "via $3 "; }
ping_ok() { ip netns exec r1 ping -c1 -W1 -I 198.51.100.1 203.0.113.1; }
# best_via ROUTER BLOCK: the next hop of the route BIRD chose (the one marked *)
best_via() { ask_bird "$1" show route "$2" primary | grep -o 'via [0-9.]*' | head -n 1 | cut -d' ' -f2; }
# pref_from ROUTER BLOCK SESSION: the local preference of the route learned on SESSION
pref_from() { ask_bird "$1" show route all "$2" protocol "$3" | sed -n 's/.*BGP.local_pref: *\([0-9]*\).*/\1/p' | head -n 1; }

if ns_exists r1 && ns_exists r2 && ns_exists r3 && ip netns exec r1 ip link show veth-to-r3 > /dev/null 2>&1; then
  t_pass "namespaces r1, r2 and r3 exist, with the direct link r1 -- r3"
else
  t_fail "the triangle is missing. Run: bash backup-link.sh"
  t_done
fi
for r in r1 r2 r3; do
  if ask_bird "$r" show status | grep -q 'BIRD 2'; then
    t_pass "BIRD answers in $r"
  else
    t_fail "BIRD does not answer in $r. Is the file valid? Run: bird -p -c $HERE/$r.conf"
  fi
done

# Gap 1: the session over the direct link.
if ask_bird r3 show protocols to_r1 | grep -q 'BGP'; then
  t_pass "GAP 1: r3 has a session called to_r1"
else
  t_fail "GAP 1: r3 has no session called to_r1. Add the protocol bgp to_r1 block in write_r3_conf"
fi
if wait_until 20 established r1 to_r3 && established r3 to_r1; then
  t_pass "GAP 1: the session over the direct link is Established (r1 to_r3, r3 to_r1)"
else
  t_fail "GAP 1: the session over the direct link is not Established. In r3's to_r1 block, check: local as 64498; neighbor 10.0.13.1 as 64496. Run: birdc -s /tmp/bird-r3.ctl show protocols"
fi
if [ ! -s "$HERE/before-preference.txt" ]; then
  t_fail "GAP 1: before-preference.txt is missing. Run bash backup-link.sh again"
elif grep -A1 ' \* ' "$HERE/before-preference.txt" | grep -q 'via 10.0.13.3'; then
  t_pass "GAP 1: before the preference, the direct link won on path length (before-preference.txt)"
else
  t_fail "GAP 1: before-preference.txt should show the best route (marked *) via 10.0.13.3, the direct link. Is r3's session to r1 up?"
fi

# Gap 4 first: the main link must be on, or nothing below can work.
if wait_until 30 established r2 to_r1; then
  t_pass "GAP 4: r2's session to r1 is on again"
else
  t_fail "GAP 4: r2's session to r1 is still off (or not Established). Did you switch it on again? The test switches it on now, to check the other gaps"
  ask_bird r2 enable to_r1 > /dev/null
  wait_until 30 established r2 to_r1 || true
fi

# Gap 2: the preference on both ends of the direct link.
wait_until 15 uses r1 203.0.113.0/24 10.0.12.2 || true
R1_PREF="$(pref_from r1 203.0.113.0/24 to_r3)"
R1_BEST="$(best_via r1 203.0.113.0/24)"
if [ -z "$R1_PREF" ]; then
  t_fail "GAP 2: r1 has no route from the direct link, so its preference cannot be checked. Fix GAP 1 first"
elif [ "$R1_PREF" = "50" ] && [ "$R1_BEST" = "10.0.12.2" ]; then
  t_pass "GAP 2: in r1 the direct route has local preference 50, and the best route goes via r2 (10.0.12.2)"
else
  t_fail "GAP 2: in r1 the direct route should have BGP.local_pref 50 and the best route should go via 10.0.12.2. Now: local_pref '${R1_PREF:-none}', best via '${R1_BEST:-none}'. Check R1_FROM_R3"
fi
wait_until 15 uses r3 198.51.100.0/24 10.0.23.2 || true
R3_PREF="$(pref_from r3 198.51.100.0/24 to_r1)"
R3_BEST="$(best_via r3 198.51.100.0/24)"
if [ -z "$R3_PREF" ]; then
  t_fail "GAP 2: r3 has no route from the direct link, so its preference cannot be checked. Fix GAP 1 first"
elif [ "$R3_PREF" = "50" ] && [ "$R3_BEST" = "10.0.23.2" ]; then
  t_pass "GAP 2: in r3 the direct route has local preference 50, and the best route goes via r2 (10.0.23.2)"
else
  t_fail "GAP 2: in r3 the direct route should have BGP.local_pref 50 and the best route should go via 10.0.23.2. Now: local_pref '${R3_PREF:-none}', best via '${R3_BEST:-none}'. Check R3_FROM_R1. Without it, r3's answers take the direct link"
fi

# Live test: cut the main link, then put it back.
ask_bird r2 disable to_r1 > /dev/null
if wait_until 15 uses r1 203.0.113.0/24 10.0.13.3 && wait_until 15 uses r3 198.51.100.0/24 10.0.13.1; then
  t_pass "live: with r2's session to r1 cut, r1 and r3 both use the direct link"
else
  t_fail "live: with r2's session to r1 cut, r1 should use 10.0.13.3 and r3 should use 10.0.13.1. r1 has: '$(ip netns exec r1 ip route show 203.0.113.0/24)'. Check GAP 1"
fi
if wait_until 5 ping_ok; then
  t_pass "live: with the main link cut, the ping from r1 to r3 still works"
else
  t_fail "live: with the main link cut, the ping from 198.51.100.1 to 203.0.113.1 fails. The direct link must carry it. Check GAP 1"
fi
ask_bird r2 enable to_r1 > /dev/null
if wait_until 30 uses r1 203.0.113.0/24 10.0.12.2 && wait_until 15 uses r3 198.51.100.0/24 10.0.23.2 && wait_until 5 ping_ok; then
  t_pass "live: with the main link back, r1 and r3 use r2 again, and the ping works"
else
  t_fail "live: with the main link back, r1 should use 10.0.12.2 again. r1: '$(ip netns exec r1 ip route show 203.0.113.0/24)'. Check GAP 2"
fi

# Your files from Gap 3 and Gap 4.
if grep -q '203.0.113.0/24 via 10.0.13.3' "$HERE/failover.txt" 2>/dev/null && grep -q ' 0% packet loss' "$HERE/failover.txt"; then
  t_pass "GAP 3: failover.txt shows r1 on the direct link, and a ping with 0% packet loss"
else
  t_fail "GAP 3: failover.txt should show '203.0.113.0/24 via 10.0.13.3' and '0% packet loss'. Did you disable r2's session to_r1? Then run bash backup-link.sh again"
fi
if grep -q '203.0.113.0/24 via 10.0.12.2' "$HERE/restored.txt" 2>/dev/null && grep -q ' 0% packet loss' "$HERE/restored.txt"; then
  t_pass "GAP 4: restored.txt shows r1 back on r2 (via 10.0.12.2)"
else
  t_fail "GAP 4: restored.txt should show '203.0.113.0/24 via 10.0.12.2' and '0% packet loss'. Did you enable r2's session to_r1 again? (If GAP 2 failed, fix it first.)"
fi

t_done
