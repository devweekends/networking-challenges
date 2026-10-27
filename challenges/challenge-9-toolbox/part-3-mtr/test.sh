#!/usr/bin/env bash
# Test for challenge 9, part 3. Run it in the lab AFTER you filled in results.md and Fault 1 in faults.md.
# Must pass: your report with the fault shows loss that starts at one hop and goes on to the last hop;
#   your "router limiting itself" report shows loss at hop 1 only; your report after the fix is clean;
#   Fault 1 in faults.md has an mtr line that proves the loss; the loss is gone from the network.
# The test checks patterns (where the loss is), never an exact percentage.
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

# loss_at ROWS HOST: the loss of HOST in the mtr rows (empty if the host is not there)
loss_at() {
  awk -v h="$2" '$2 == h { print $3; exit }' <<< "$1"
}

# 1. The report with the fault.
ROWS="$(mtr_rows "$(md_section "$RESULTS" "Fault 1: a report with the loss")")"
L1="$(loss_at "$ROWS" 192.0.2.1)"
L2="$(loss_at "$ROWS" 198.51.100.2)"
L3="$(loss_at "$ROWS" 203.0.113.80)"
if [ -z "$L1" ] || [ -z "$L2" ] || [ -z "$L3" ]; then
  t_fail "results.md, Fault 1: paste a whole mtr report from the laptop to 203.0.113.80 (three hops: 192.0.2.1, 198.51.100.2, 203.0.113.80)"
elif num_gt "$L3" 0 && num_gt "$L2" 0 && ! num_gt "$L1" 0; then
  t_pass "results.md, Fault 1: no loss at hop 1, and loss from hop 2 to the last hop ($L2% and $L3%)"
elif ! num_gt "$L3" 0; then
  t_fail "results.md, Fault 1: the last hop shows 0% loss. Real loss goes on to the last hop. Run mtr while fault 1 is planted, with -c 50 -i 0.2"
else
  t_fail "results.md, Fault 1: the report should show 0% at hop 1 and loss at hops 2 and 3. It shows $L1%, $L2% and $L3%. Was r1 limiting its replies when you ran it?"
fi

# 2. A router limiting itself: loss at hop 1 only.
ROWS="$(mtr_rows "$(md_section "$RESULTS" "A router limiting itself")")"
L1="$(loss_at "$ROWS" 192.0.2.1)"
L3="$(loss_at "$ROWS" 203.0.113.80)"
if [ -z "$L1" ] || [ -z "$L3" ]; then
  t_fail "results.md, A router limiting itself: paste the whole mtr report you ran with r1's icmp_ratelimit at 1000"
elif num_gt "$L1" 0 && ! num_gt "$L3" 0; then
  t_pass "results.md, A router limiting itself: loss at hop 1 ($L1%), and none at the last hop"
else
  t_fail "results.md, A router limiting itself: hop 1 should show loss and the last hop 0%. It shows $L1% and $L3%. Fix fault 1 first, then switch r1's limit on, and use -i 0.2"
fi

# 3. After the fix: a clean report.
ROWS="$(mtr_rows "$(md_section "$RESULTS" "After the fix")")"
if [ "$(wc -l <<< "$ROWS" | tr -d ' ')" -ge 3 ] && ! awk '$3 + 0 > 0 { bad = 1 } END { exit !bad }' <<< "$ROWS"; then
  t_pass "results.md, After the fix: a clean report, 0% loss at every hop"
else
  t_fail "results.md, After the fix: paste a report with 0% loss at every hop. Switch r1's limit off again first: ip netns exec r1 sysctl -w net.ipv4.icmp_ratelimit=0"
fi

# 4. Which link.
LINK="$(md_section "$RESULTS" "The lossy link")"
if grep -q '198\.51\.100\.2' <<< "$LINK" && grep -Eq '192\.0\.2\.1([^0-9]|$)|198\.51\.100\.1([^0-9]|$)|r1' <<< "$LINK" && ! grep -q '<.*>' <<< "$LINK"; then
  t_pass "results.md, The lossy link: you named the cable between r1 and r2"
else
  t_fail "results.md, The lossy link: name the two ends of the lossy cable. The loss starts at hop 2. Which cable leads to hop 2?"
fi

# 5. faults.md, Fault 1.
check_fault_entry 1

# 6. The loss is gone from the network (only while round 1 is in the network).
if [ "$(ch9_current_round)" = "1" ]; then
  QDISC="$(ip netns exec r1 tc qdisc show dev veth-r1wan 2>/dev/null || true)"
  if grep -q 'loss' <<< "$QDISC"; then
    t_fail "fault 1 is still in the network. Find it with: ip netns exec r1 tc qdisc show. Then remove it"
  else
    t_pass "fault 1 is cleared: no loss on r1's cable to r2"
  fi
else
  echo "NOTE round 1 is not in the network now ($(ch9_current_round)), so the live check is skipped"
fi

t_done
