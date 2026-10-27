#!/usr/bin/env bash
# Test for challenge 9, part 4. Run it in the lab AFTER you filled in results.md and Fault 2 in faults.md.
# Must pass: your two dig answers for the broken name disagree, the campus one with the wrong address of
#   YOUR seed and the public one with 203.0.113.80; you followed a +trace from the root; Fault 2 in
#   faults.md has the wrong answer; and the laptop now gets the right address.
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
NAME_RE="${V_NAME//./\\.}\\."

# answer_line TEXT ADDRESS: true if TEXT has an answer line "NAME. TTL IN A ADDRESS"
answer_line() {
  grep -Eq "^${NAME_RE}[[:space:]]+[0-9]+[[:space:]]+IN[[:space:]]+A[[:space:]]+${2//./\\.}([^0-9]|$)" <<< "$1"
}

TWO="$(md_section "$RESULTS" "Two resolvers")"
if grep -q 'SERVER: 192\.0\.2\.1#53' <<< "$TWO" && answer_line "$TWO" "$V_WRONG"; then
  t_pass "results.md, Two resolvers: the campus resolver (192.0.2.1) answers $V_NAME with $V_WRONG"
else
  t_fail "results.md, Two resolvers: paste the whole output of dig @192.0.2.1 $V_NAME, with its ANSWER SECTION and its SERVER line"
fi
if grep -q 'SERVER: 203\.0\.113\.53#53' <<< "$TWO" && answer_line "$TWO" 203.0.113.80; then
  t_pass "results.md, Two resolvers: the public resolver (203.0.113.53) answers $V_NAME with 203.0.113.80"
else
  t_fail "results.md, Two resolvers: paste the whole output of dig @203.0.113.53 $V_NAME, with its ANSWER SECTION and its SERVER line"
fi

TRACE="$(md_section "$RESULTS" "Following a name from the root")"
if grep -q 'root-servers\.net' <<< "$TRACE" && grep -q 'Received' <<< "$TRACE"; then
  t_pass "results.md, Following a name from the root: your +trace starts at the root servers"
elif grep -qi 'blocked' <<< "$TRACE"; then
  echo "NOTE results.md says +trace was blocked on your network. A mentor will read why"
else
  t_fail "results.md, Following a name from the root: paste the output of dig +trace @1.1.1.1 example.com (run it in the lab, not in the laptop). If your network blocks it, write the word blocked and the error"
fi

AFTER="$(md_section "$RESULTS" "After the fix")"
if grep -Eq '^[[:space:]]*203\.0\.113\.80[[:space:]]*$' <<< "$AFTER" && grep -q 'lab web server' <<< "$AFTER"; then
  t_pass "results.md, After the fix: dig +short gives 203.0.113.80 and curl gets the page"
else
  t_fail "results.md, After the fix: paste the output of dig +short $V_NAME and of curl http://$V_NAME/ from the laptop"
fi

check_fault_entry 2

if [ "$(ch9_current_round)" = "1" ]; then
  NOW="$(ip netns exec laptop dig +short +time=2 +tries=1 "$V_NAME" 2>/dev/null | head -n 1 || true)"
  if [ "$NOW" = "203.0.113.80" ]; then
    t_pass "fault 2 is cleared: the laptop's resolver now answers $V_NAME with 203.0.113.80"
  else
    t_fail "fault 2 is still there: from the laptop, dig +short $V_NAME says '$NOW', not 203.0.113.80. Read step 6 of the README"
  fi
else
  echo "NOTE round 1 is not in the network now ($(ch9_current_round)), so the live check is skipped"
fi

t_done
