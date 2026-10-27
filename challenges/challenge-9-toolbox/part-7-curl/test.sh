#!/usr/bin/env bash
# Test for challenge 9, part 7. Run it in the lab AFTER you filled in results.md.
# Must pass: your curl -v output shows the request and the answer; each -w line has the four timing
#   fields, and they make sense: lookup <= connect <= first byte <= total; the slow page waits about
#   4 seconds before its first byte, and the fast page does not.
# The test only reads results.md. Your numbers will differ from anyone else's.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
source "$HERE/../part-0-the-broken-network/seed.sh"

RESULTS="$HERE/results.md"

VERBOSE="$(md_section "$RESULTS" "curl -v")"
if grep -q '^> GET / HTTP/1\.1' <<< "$VERBOSE" && grep -q '^< HTTP/1\.[01] 200' <<< "$VERBOSE"; then
  t_pass "results.md, curl -v: the request (> GET) and the answer (< HTTP 200) are there"
else
  t_fail "results.md, curl -v: paste the whole output of curl -v http://www.lab.test/ from the laptop. It has lines that start with > and <"
fi

# timing SECTION: check one -w line. Sets T_FIRST and T_TOTAL.
timing() {
  local text field v prev=0 ok=1
  text="$(md_section "$RESULTS" "$1" | grep 'time_total=' | tail -n 1)"
  T_FIRST=""
  T_TOTAL=""
  if [ -z "$text" ]; then
    t_fail "results.md, $1: paste the line that curl -w printed, with time_namelookup, time_connect, time_starttransfer and time_total"
    return 1
  fi
  for field in time_namelookup time_connect time_starttransfer time_total; do
    v="$(sed -n -E "s/.*$field=([0-9.]+).*/\1/p" <<< "$text")"
    if [ -z "$v" ]; then
      t_fail "results.md, $1: the field $field is missing. Use the -w text from the README"
      return 1
    fi
    num_ge "$v" "$prev" || ok=0
    prev="$v"
    [ "$field" = time_starttransfer ] && T_FIRST="$v"
    [ "$field" = time_total ] && T_TOTAL="$v"
  done
  if [ "$ok" -eq 0 ]; then
    t_fail "results.md, $1: the four times should grow from left to right (each one counts from the start). Line: $text"
    return 1
  fi
  if ! num_gt "$(sed -n -E 's/.*time_namelookup=([0-9.]+).*/\1/p' <<< "$text")" 0; then
    t_fail "results.md, $1: time_namelookup is 0. Use the name www.lab.test, not the address"
    return 1
  fi
  t_pass "results.md, $1: the four timing fields are there, and they grow from left to right"
}

if timing "The fast page"; then
  if num_gt 2 "$T_TOTAL"; then
    t_pass "results.md, The fast page: it took $T_TOTAL seconds in all"
  else
    t_fail "results.md, The fast page: $T_TOTAL seconds is slow for this page. Were faults still in the network?"
  fi
fi
if timing "The slow page"; then
  if num_ge "$T_FIRST" 3.5 && num_gt 30 "$T_TOTAL"; then
    t_pass "results.md, The slow page: the first byte came after $T_FIRST seconds. The server made you wait"
  else
    t_fail "results.md, The slow page: the first byte should come after about 4 seconds (it came after $T_FIRST). Did you ask for /cgi-bin/slow?"
  fi
fi

QUESTIONS="$(md_section "$RESULTS" "Questions")"
if grep -q '<.*>' <<< "$QUESTIONS" || ! grep -q '[A-Za-z]' <<< "$QUESTIONS"; then
  t_fail "results.md, Questions: answer every question in your own words"
else
  t_pass "results.md: you answered the questions"
fi

t_done
