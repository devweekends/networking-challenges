#!/usr/bin/env bash
# Test for challenge 9, part 6. Run it in the lab AFTER you filled in results.md and Fault 4 in faults.md.
# Must pass: the slow direction runs near the speed limit of YOUR seed, with few retransmits;
#   the other direction (-R) is many times faster; UDP below the limit loses nothing; after the fix the
#   slow direction is fast too; Fault 4 in faults.md has the receiver line; the limit is gone.
# The test compares speeds (a ratio). It never needs one exact speed.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
source "$HERE/../part-0-the-broken-network/seed.sh"
require_root

RESULTS="$HERE/results.md"

SEED="$(ch9_seed)"
if [ -z "$SEED" ]; then
  t_fail "there is no seed. Run: bash ../part-0-the-broken-network/faults.sh --seed YOUR_NAME"
  t_done
fi
ch9_values "$SEED" 1

# receiver TEXT: the speed (Mbit/s) in the receiver line.  retr TEXT: the Retr number in the sender line
# (Both print nothing, and do not stop the test, when the line is missing.)
receiver() { to_mbits "$(grep 'receiver' <<< "$1" | tail -n 1 || true)"; }
retr() {
  { grep 'sender' <<< "$1" || true; } | tail -n 1 | sed -n -E 's/.*bits\/sec[[:space:]]+([0-9]+)[[:space:]]+sender.*/\1/p'
}

SLOW_TEXT="$(md_section "$RESULTS" "The slow direction")"
SLOW="$(receiver "$SLOW_TEXT")"
SLOW_RETR="$(retr "$SLOW_TEXT")"
if [ -z "$SLOW" ]; then
  t_fail "results.md, The slow direction: paste the whole output of iperf3 -c 203.0.113.80 -t 5 from the laptop, with its sender and receiver lines"
elif num_ge "$SLOW" "$(awk -v r="$V_RATE" 'BEGIN { print r * 0.5 }')" && num_ge "$(awk -v r="$V_RATE" 'BEGIN { print r * 1.1 }')" "$SLOW"; then
  t_pass "results.md, The slow direction: the receiver got $SLOW Mbit/s, near the speed limit"
else
  t_fail "results.md, The slow direction: the receiver line says $SLOW Mbit/s. Run it while fault 4 is planted. Read the receiver line, not the sender line"
fi
if [ -z "$SLOW_RETR" ]; then
  t_fail "results.md, The slow direction: the sender line with its Retr number is missing (TCP, not UDP)"
elif [ "$SLOW_RETR" -lt 100 ]; then
  t_pass "results.md, The slow direction: only $SLOW_RETR retransmits. The link is slow, but it loses nothing"
else
  t_fail "results.md, The slow direction: $SLOW_RETR retransmits. That is loss, not a speed limit. Did you clear fault 1 in part 3 first?"
fi

FAST="$(receiver "$(md_section "$RESULTS" "The other direction")")"
if [ -z "$FAST" ] || [ -z "$SLOW" ]; then
  t_fail "results.md, The other direction: paste the whole output of iperf3 -c 203.0.113.80 -t 5 -R"
elif num_ge "$FAST" "$(awk -v s="$SLOW" 'BEGIN { print s * 5 }')"; then
  t_pass "results.md, The other direction: -R got $FAST Mbit/s, more than 5 times the slow direction"
else
  t_fail "results.md, The other direction: -R got $FAST Mbit/s and the slow direction $SLOW. With fault 4, -R should be many times faster"
fi

UDP="$(md_section "$RESULTS" "UDP")"
UDP_LOSS="$({ grep 'receiver' <<< "$UDP" || true; } | tail -n 1 | sed -n -E 's/.*\(([0-9.]+)%\).*/\1/p')"
if [ -z "$UDP_LOSS" ]; then
  t_fail "results.md, UDP: paste the whole output of iperf3 -c 203.0.113.80 -t 5 -u -b 2M, with the receiver line"
elif ! num_gt "$UDP_LOSS" 1; then
  t_pass "results.md, UDP: $UDP_LOSS% lost below the limit. A speed limit makes packets wait, it does not drop them"
else
  t_fail "results.md, UDP: $UDP_LOSS% lost. Below the limit (-b 2M) nothing should be lost. Is fault 1 cleared?"
fi

AFTER="$(receiver "$(md_section "$RESULTS" "After the fix")")"
if [ -n "$AFTER" ] && num_ge "$AFTER" "$(awk -v r="$V_RATE" 'BEGIN { print r * 10 }')"; then
  t_pass "results.md, After the fix: the slow direction now gets $AFTER Mbit/s"
else
  t_fail "results.md, After the fix: paste iperf3 -c 203.0.113.80 -t 5 again, after you removed the limit. It should be many times faster than ${V_RATE} Mbit/s"
fi

check_fault_entry 4

if [ "$(ch9_current_round)" = "1" ]; then
  QDISC="$(ip netns exec r2 tc qdisc show dev veth-r2srv 2>/dev/null || true)"
  if grep -q 'rate' <<< "$QDISC"; then
    t_fail "fault 4 is still in the network. Find it with: ip netns exec r2 tc qdisc show. Then remove it"
  else
    t_pass "fault 4 is cleared: no speed limit on r2's cable to the server"
  fi
else
  echo "NOTE round 1 is not in the network now ($(ch9_current_round)), so the live check is skipped"
fi

t_done
