#!/usr/bin/env bash
# Test for challenge 9, part 2. Run it in the lab AFTER you made the three capture files and filled in results.md.
# Must pass: each file can be read with tcpdump -r, holds between 1 and the -c count of packets,
#   and holds ONLY packets that match its capture filter (dns-only.pcap holds only DNS).
# The test does not need the lab network. It only reads your files.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
source "$HERE/../part-0-the-broken-network/seed.sh"

RESULTS="$HERE/results.md"

# check_file FILE FILTER MAX HINT: one PASS or FAIL line for a capture file
check_file() {
  local file="$HERE/$1" filter="$2" max="$3" hint="$4" total other
  if [ ! -s "$file" ]; then
    t_fail "$1 is missing or empty. $hint"
    return
  fi
  if ! tcpdump -nn -r "$file" -c 1 > /dev/null 2>&1; then
    t_fail "$1 cannot be read with tcpdump -r. Did tcpdump stop cleanly (with -c, or with Ctrl-C)? $hint"
    return
  fi
  total="$({ tcpdump -nn -r "$file" 2>/dev/null || true; } | wc -l | tr -d ' ')"
  other="$({ tcpdump -nn -r "$file" "not ($filter)" 2>/dev/null || true; } | wc -l | tr -d ' ')"
  if [ "$total" -lt 1 ]; then
    t_fail "$1 holds no packets. Was traffic.sh running? $hint"
  elif [ "$other" -gt 0 ]; then
    t_fail "$1 holds $other packet(s) that do not match '$filter'. Put the capture filter at the end of the tcpdump command. $hint"
  elif [ "$total" -gt "$max" ]; then
    t_fail "$1 holds $total packets. Stop after $max with -c $max. $hint"
  else
    t_pass "$1 holds $total packet(s), and every one matches '$filter'"
  fi
}

check_file dns-only.pcap "port 53" 10 \
  "Run: ip netns exec laptop tcpdump -nn -i veth-laptop -c 10 -w dns-only.pcap port 53"
if [ -s "$HERE/dns-only.pcap" ] && tcpdump -nn -r "$HERE/dns-only.pcap" 2>/dev/null | grep -q ' A? '; then
  t_pass "dns-only.pcap holds at least one DNS question (A?)"
else
  t_fail "dns-only.pcap should hold DNS questions (lines with A?). Is traffic.sh running while you capture?"
fi
check_file server-only.pcap "host 203.0.113.80" 10 \
  "Capture on the laptop with the filter host 203.0.113.80"
check_file public-net.pcap "net 203.0.113.0/24" 20 \
  "Capture in r1 on veth-r1wan with the filter net 203.0.113.0/24"

# results.md: reading part 1's capture with a filter.
READ="$(md_section "$RESULTS" "Reading a file with a filter")"
if grep -q '\.53: ' <<< "$READ" && grep -q ' A? ' <<< "$READ"; then
  t_pass "results.md: you read the DNS packets of your part 1 capture"
else
  t_fail "results.md, Reading a file with a filter: paste the output of tcpdump -nn -r ../part-1-wireshark/capture.pcap port 53"
fi
QUESTIONS="$(md_section "$RESULTS" "Questions")"
if grep -q '<.*>' <<< "$QUESTIONS" || ! grep -q '[A-Za-z]' <<< "$QUESTIONS"; then
  t_fail "results.md, Questions: answer every question in your own words"
else
  t_pass "results.md: you answered the questions"
fi

t_done
