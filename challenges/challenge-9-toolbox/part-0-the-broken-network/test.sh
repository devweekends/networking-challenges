#!/usr/bin/env bash
# Test for challenge 9, setup. Run it in the lab AFTER you ran:  bash faults.sh
#   bash test.sh              checks the setup: the network, your seed, your best guesses and results.md
#   bash test.sh --round 2    the gate: checks all of faults.md, round 1 and the blind round
# The test never runs a tool for you and never needs a fixed number. It compares your lines with the
# numbers of YOUR seed (see seed.sh).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
source "$HERE/seed.sh"
require_root

GATE=0
if [ "${1:-}" = "--round" ] && [ "${2:-}" = "2" ]; then
  GATE=1
fi

FAULTS_MD="$HERE/faults.md"
RESULTS="$HERE/results.md"

SEED="$(ch9_seed)"
if [ -n "$SEED" ]; then
  t_pass "your seed is '$SEED' (in fault-seed.txt)"
else
  t_fail "fault-seed.txt is missing. Run: bash faults.sh --seed YOUR_NAME"
  t_done
fi

SEED_LINE="$(sed -n 's/^Seed:[[:space:]]*//p' "$FAULTS_MD" | head -n 1 | tr -d '\r')"
if [ "$SEED_LINE" = "$SEED" ]; then
  t_pass "faults.md has your seed"
else
  t_fail "faults.md should start with the line 'Seed: $SEED'. It has: 'Seed: $SEED_LINE'"
fi

if [ "$GATE" -eq 0 ]; then
  # The lab network must exist.
  MISSING=""
  for ns in laptop r1 r2 server dns; do
    ns_exists "$ns" || MISSING="$MISSING $ns"
  done
  if [ -z "$MISSING" ]; then
    t_pass "the lab network exists (laptop, r1, r2, server, dns)"
  else
    t_fail "these computers are missing:$MISSING. Run: bash faults.sh"
  fi

  # Best guesses, written before part 1.
  for c in A B C; do
    GUESS="$(md_field "$(md_section "$FAULTS_MD" "Complaint $c")" "Best guess")"
    if is_unfilled "$GUESS"; then
      t_fail "faults.md, Complaint $c: write your best guess (one sentence)"
    else
      t_pass "faults.md, Complaint $c: you wrote a best guess"
    fi
  done

  # results.md: what ping and traceroute could show.
  PING="$(md_section "$RESULTS" "Ping")"
  LOSS="$(sed -n -E 's/.* ([0-9.]+)% packet loss.*/\1/p' <<< "$PING" | head -n 1)"
  if [ -z "$LOSS" ]; then
    t_fail "results.md, Ping: paste the output of the ping command, with its last two lines (the one with 'packet loss')"
  elif num_gt "$LOSS" 0; then
    t_pass "results.md, Ping: your ping shows $LOSS% packet loss"
  else
    t_fail "results.md, Ping: your ping shows 0% loss. Run it while the faults are planted (bash faults.sh), with -c 50 -i 0.2"
  fi
  TRACE="$(md_section "$RESULTS" "Traceroute")"
  if grep -q '192\.0\.2\.1 ' <<< "$TRACE" && grep -q '198\.51\.100\.2 ' <<< "$TRACE" && grep -q '203\.0\.113\.80 ' <<< "$TRACE"; then
    t_pass "results.md, Traceroute: three hops, 192.0.2.1, 198.51.100.2 and 203.0.113.80"
  else
    t_fail "results.md, Traceroute: paste the output of traceroute -n 203.0.113.80 from the laptop. It should show 192.0.2.1, 198.51.100.2 and 203.0.113.80"
  fi
  ANSWER="$(md_section "$RESULTS" "What ping and traceroute cannot tell")"
  if grep -q '[A-Za-z]' <<< "$ANSWER" && ! grep -q '<.*>' <<< "$ANSWER"; then
    t_pass "results.md: you wrote what ping and traceroute cannot tell"
  else
    t_fail "results.md, What ping and traceroute cannot tell: answer the question in your own words"
  fi
  t_done
fi

# ---- the gate: all of faults.md ----

ch9_values "$SEED" 1
for n in 1 2 3 4; do
  check_fault_entry "$n"
done

# The blind round. The test knows which two faults your seed planted in round 2, and their new numbers.
ch9_values "$SEED" 2
PICKS="$(ch9_round2_picks "$SEED")"
FOUND=""
for f in A B; do
  ENTRY="$(md_section "$FAULTS_MD" "Finding $f")"
  WHAT="$(md_field "$ENTRY" "What it is")"
  CMD="$(md_field "$ENTRY" Command)"
  LINE="$(md_field "$ENTRY" "Output line")"
  if is_unfilled "$WHAT" || is_unfilled "$CMD" || is_unfilled "$LINE"; then
    t_fail "faults.md, Finding $f: fill in What it is, Tool, Command and Output line. Run bash faults.sh --round 2 first"
    continue
  fi
  MATCH=""
  for n in $PICKS; do
    if grep -q "$(fault_tool "$n")" <<< "$CMD" && fault_matches "$n" "$LINE"; then
      MATCH="$n"
    fi
  done
  if [ -z "$MATCH" ]; then
    t_fail "faults.md, Finding $f: the command and the output line do not prove a fault that round 2 planted. Read the line again: is it from a tool run after bash faults.sh --round 2? Line: '$LINE'"
  elif [[ " $FOUND " == *" $MATCH "* ]]; then
    t_fail "faults.md, Finding $f: it proves the same fault as the other finding. Two different faults are planted"
  else
    FOUND="$FOUND $MATCH"
    t_pass "faults.md, Finding $f: the output line proves a fault that round 2 planted"
  fi
done

t_done
