#!/usr/bin/env bash
# Test for challenge 9, part 5. Run it in the lab AFTER you filled in results.md and Fault 3 in faults.md.
# Must pass: the consent line is in results.md, above your first scan; your scans show the three states
#   (open, closed, filtered) and the app's port of YOUR seed as filtered; after the fix the port is open;
#   Fault 3 in faults.md has the filtered line; and the app answers again.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
source "$HERE/../part-0-the-broken-network/seed.sh"
require_root

RESULTS="$HERE/results.md"
CONSENT="I scan only computers that I own or that I have written permission to scan. In this challenge I scan only the lab network."

SEED="$(ch9_seed)"
if [ -z "$SEED" ]; then
  t_fail "there is no seed. Run: bash ../part-0-the-broken-network/faults.sh --seed YOUR_NAME"
  t_done
fi
ch9_values "$SEED" 1

# The consent line: typed by you, on one line, above the first scan.
norm() { tr -s '[:space:]' ' ' | tr '[:upper:]' '[:lower:]' | sed 's/^ //; s/ $//'; }
WANT="$(norm <<< "$CONSENT")"
CONSENT_AT="$(awk -v w="$WANT" '{ l = tolower($0); gsub(/[[:space:]]+/, " ", l); sub(/^ /, "", l); sub(/ $/, "", l) } l == w { print NR; exit }' "$RESULTS")"
FIRST_SCAN_AT="$(grep -n 'Nmap scan report' "$RESULTS" | head -n 1 | cut -d: -f1 || true)"
if [ -z "$CONSENT_AT" ]; then
  t_fail "results.md: type the consent line, word for word, on its own line under 'Consent' before you scan anything: $CONSENT"
elif [ -n "$FIRST_SCAN_AT" ] && [ "$FIRST_SCAN_AT" -lt "$CONSENT_AT" ]; then
  t_fail "results.md: the consent line must come before your first scan"
else
  t_pass "results.md: the consent line is there, above your scans"
fi

WIDE="$(md_section "$RESULTS" "A wider scan")"
if grep -Eq "^$V_PORT/tcp[[:space:]]+filtered" <<< "$WIDE"; then
  t_pass "results.md, A wider scan: port $V_PORT is filtered"
else
  t_fail "results.md, A wider scan: paste the output of nmap -n -p 1-10000 203.0.113.80. The app's port, $V_PORT, should show as filtered"
fi

THREE="$(md_section "$RESULTS" "Three states")"
if grep -Eq '^[0-9]+/tcp[[:space:]]+open[[:space:]]' <<< "$THREE" \
  && grep -Eq '^[0-9]+/tcp[[:space:]]+closed[[:space:]]' <<< "$THREE" \
  && grep -Eq "^$V_PORT/tcp[[:space:]]+filtered" <<< "$THREE"; then
  t_pass "results.md, Three states: one port open, one closed, and $V_PORT filtered"
else
  t_fail "results.md, Three states: paste the output of nmap -n -p 80,81,$V_PORT 203.0.113.80. It should have an open, a closed and a filtered line"
fi

AFTER="$(md_section "$RESULTS" "After the fix")"
if grep -Eq "^$V_PORT/tcp[[:space:]]+open" <<< "$AFTER"; then
  t_pass "results.md, After the fix: port $V_PORT is open"
else
  t_fail "results.md, After the fix: paste a scan of port $V_PORT after you removed the rule. It should say open"
fi

check_fault_entry 3

if [ "$(ch9_current_round)" = "1" ]; then
  try_curl laptop "http://203.0.113.80:$V_PORT/"
  if [ "$RC" -eq 0 ] && grep -q 'the app' <<< "$OUT"; then
    t_pass "fault 3 is cleared: the app on port $V_PORT answers the laptop"
  else
    t_fail "fault 3 is still there: the laptop cannot reach http://203.0.113.80:$V_PORT/ (curl exit $RC). Look for the rule with: ip netns exec r2 nft list ruleset"
  fi
else
  echo "NOTE round 1 is not in the network now ($(ch9_current_round)), so the live check is skipped"
fi

t_done
