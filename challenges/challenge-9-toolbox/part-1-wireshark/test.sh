#!/usr/bin/env bash
# Test for challenge 9, part 1. Run it in the lab AFTER you ran  bash make-capture.sh  and filled in results.md.
# Must pass: capture.pcap was made from your seed, and your three answers in results.md are the values
#   that tcpdump -r reads from that same file: a source port, a TTL and a packet count.
# The test does not need the lab network. It only reads capture.pcap and results.md.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
source "$HERE/../part-0-the-broken-network/seed.sh"

PCAP="$HERE/capture.pcap"
RESULTS="$HERE/results.md"

# answer ROW: the last cell of the results.md table row whose first cell starts with ROW
answer() {
  awk -F'|' -v r="$1" 'index($2, " " r) == 1 { v = $(NF - 1); gsub(/[ `]/, "", v); print v; exit }' "$RESULTS"
}

# filter_cell ROW: the middle cell (the display filter you used)
filter_cell() {
  awk -F'|' -v r="$1" 'index($2, " " r) == 1 { v = $3; gsub(/^[ `]+|[ `]+$/, "", v); print v; exit }' "$RESULTS"
}

SEED="$(ch9_seed)"
if [ -z "$SEED" ]; then
  t_fail "there is no seed. Run: bash ../part-0-the-broken-network/faults.sh --seed YOUR_NAME"
  t_done
fi
ch9_capture_values "$SEED"

if [ ! -s "$PCAP" ]; then
  t_fail "capture.pcap is missing. Run: bash make-capture.sh"
  t_done
fi

# What the file really holds, read with tcpdump -r.
FIRST_SYN="$(tcpdump -nn -r "$PCAP" -c 1 'src host 192.0.2.10 and dst port 80 and tcp[tcpflags] & tcp-syn != 0' 2>/dev/null || true)"
REAL_PORT="$(sed -n -E 's/.* 192\.0\.2\.10\.([0-9]+) > 203\.0\.113\.80\.80:.*/\1/p' <<< "$FIRST_SYN")"
SERVER_PKT="$(tcpdump -nn -v -r "$PCAP" -c 1 'src host 203.0.113.80' 2>/dev/null || true)"
REAL_TTL="$(sed -n -E 's/.*[(, ]ttl ([0-9]+),.*/\1/p' <<< "$SERVER_PKT" | head -n 1)"
REAL_COUNT="$({ tcpdump -nn -r "$PCAP" 'dst host 203.0.113.80' 2>/dev/null || true; } | wc -l | tr -d ' ')"

if [ "$REAL_PORT" = "$C_PORT" ] && [ "$REAL_TTL" = "$((C_TTL - 2))" ]; then
  t_pass "capture.pcap was made from your seed '$SEED'"
else
  t_fail "capture.pcap was not made from your seed '$SEED'. Run: bash make-capture.sh (a capture from another learner has other numbers)"
fi

# Your three answers.
check_answer() {
  local row="$1" real="$2" label="$3" mine
  mine="$(answer "$row")"
  if is_unfilled "$mine" || [ -z "$mine" ]; then
    t_fail "results.md: fill in the row '$row' with the number you read in Wireshark"
  elif [ "$mine" = "$real" ]; then
    t_pass "results.md: $label is $mine, the same as tcpdump -r reads from the file"
  else
    t_fail "results.md: $label. You wrote $mine, but the file holds another value. Look again in Wireshark. $4"
  fi
}
check_answer "Source port" "$REAL_PORT" "the source port of the laptop's first web connection" \
  "Find the first packet with the SYN flag from 192.0.2.10. Its source port is in the TCP layer"
check_answer "TTL" "$REAL_TTL" "the TTL of the server's packets as they reach the laptop" \
  "Pick a packet from 203.0.113.80 and open the Internet Protocol layer"
check_answer "Packets to" "$REAL_COUNT" "the number of packets sent to 203.0.113.80" \
  "Use a display filter that keeps only packets whose destination is 203.0.113.80, and read the count at the bottom"

# Display filters are Wireshark's own language (ip.src == ...). Capture filters (host, port) are tcpdump's.
for row in "Source port" "TTL" "Packets to"; do
  F="$(filter_cell "$row")"
  if is_unfilled "$F" || [ -z "$F" ]; then
    t_fail "results.md: write the display filter you used for the row '$row'"
  elif grep -Eq '(ip|tcp|udp|frame)\.[a-z]' <<< "$F"; then
    t_pass "results.md: the row '$row' has a display filter ($F)"
  else
    t_fail "results.md: '$F' is not a Wireshark display filter. Display filters name a field, for example ip.dst == 203.0.113.80. Words like 'host' and 'port' belong to capture filters"
  fi
done

STREAM="$(md_section "$RESULTS" "Follow the TCP stream")"
if grep -q 'GET / HTTP/1\.1' <<< "$STREAM"; then
  t_pass "results.md: your followed stream shows the laptop's request, GET / HTTP/1.1"
else
  t_fail "results.md, Follow the TCP stream: paste the first lines the laptop sent. They start with GET / HTTP/1.1"
fi

t_done
