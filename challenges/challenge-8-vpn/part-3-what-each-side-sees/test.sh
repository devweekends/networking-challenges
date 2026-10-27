#!/usr/bin/env bash
# Test for challenge 8, part 3. Run it in the lab AFTER you ran:  bash captures.sh
# When a check fails, the message says which GAP in captures.sh to look at.
# Must pass: at the cafe's outside plug there is only UDP on port 51820, both ways, and no ICMP or TCP;
#   on the VPN box's wg0 there is the inner ping from 10.99.0.2 to 10.20.0.5;
#   an 84-byte ping travels in a 156-byte outer packet.
# Must fail on purpose: the inner address 10.20.0.5 never shows at the cafe's outside plug.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# packet_lines FILE: the lines of a tcpdump file that are packets (they start with a time)
packet_lines() {
  grep -E '^[0-9]{2}:[0-9]{2}:[0-9]{2}\.' "$1" 2>/dev/null || true
}

# The network from parts 1 and 2 must exist, with the tunnel up.
if ns_exists laptop && ns_exists caferouter && ns_exists vpnbox; then
  t_pass "the namespaces exist"
else
  t_fail "the namespaces are missing. Run: bash captures.sh"
  t_done
fi
try_ping laptop 10.20.0.5 2
if [ "$RC" -eq 0 ]; then
  t_pass "mid-point: the tunnel works (the laptop reaches 10.20.0.5)"
else
  t_fail "mid-point: the laptop cannot reach 10.20.0.5. Make part 2's test pass first"
  t_done
fi

# Live: the test's own capture at the cafe's outside plug, during a ping and a page fetch.
timeout 6 ip netns exec caferouter tcpdump -n -l -i veth-cafe-out ip > "$TMP/out.txt" 2>&1 &
P=$!
sleep 1
ip netns exec laptop ping -c3 -W2 10.20.0.5 > /dev/null 2>&1 || true
ip netns exec laptop curl -sS -m 3 -o /dev/null http://10.20.0.5/ 2>/dev/null || true
wait "$P" || true
LIVE="$(packet_lines "$TMP/out.txt")"
OUTWARD="$(grep -c '198\.51\.100\.2\.51820 > 203\.0\.113\.2\.51820: UDP' <<< "$LIVE" || true)"
INWARD="$(grep -c '203\.0\.113\.2\.51820 > 198\.51\.100\.2\.51820: UDP' <<< "$LIVE" || true)"
OTHER="$(grep -v '\.51820 > [0-9.]*\.51820: UDP' <<< "$LIVE" | grep -c . || true)"
if [ "$OUTWARD" -ge 4 ] && [ "$INWARD" -ge 4 ] && [ "$OTHER" -eq 0 ]; then
  t_pass "live: the cafe's outside plug carries only UDP 51820 ($OUTWARD out, $INWARD in, nothing else)"
else
  t_fail "live: the cafe's outside plug should carry only UDP 51820 both ways. Out $OUTWARD, in $INWARD, other lines $OTHER"
fi
if grep -q '10\.20\.0\.5' <<< "$LIVE"; then
  t_fail "live: the inner address 10.20.0.5 showed at the cafe's outside plug. It should be hidden inside the tunnel"
else
  t_pass "live: the inner address 10.20.0.5 never shows at the cafe's outside plug"
fi

# Gap 1: your capture file.
CAFE="$HERE/cafe-outside.txt"
if [ ! -s "$CAFE" ]; then
  t_fail "GAP 1: cafe-outside.txt is missing or empty. Fill in the gap, then run bash captures.sh again"
else
  LINES="$(packet_lines "$CAFE")"
  N_UDP="$(grep -c '\.51820 > [0-9.]*\.51820: UDP' <<< "$LINES" || true)"
  N_ALL="$(grep -c . <<< "$LINES" || true)"
  if grep -qE 'ICMP|Flags \[' <<< "$LINES"; then
    t_fail "GAP 1: cafe-outside.txt shows ICMP or TCP. Those are inner packets. Capture in the caferouter namespace, on veth-cafe-out"
  elif grep -q '192\.168\.50\.23' <<< "$LINES"; then
    t_fail "GAP 1: cafe-outside.txt shows 192.168.50.23, the laptop's own address. That is the cafe's INSIDE plug, before NAT. Capture on veth-cafe-out"
  elif ! grep -q '198\.51\.100\.2\.51820 > 203\.0\.113\.2\.51820' <<< "$LINES" || ! grep -q '203\.0\.113\.2\.51820 > 198\.51\.100\.2\.51820' <<< "$LINES"; then
    t_fail "GAP 1: cafe-outside.txt should have UDP 51820 both ways, 198.51.100.2 to 203.0.113.2 and back. It has $N_ALL packet lines"
  elif [ "$N_UDP" -ne "$N_ALL" ]; then
    t_fail "GAP 1: cafe-outside.txt has lines that are not UDP 51820. Use the filter ip, on veth-cafe-out"
  else
    t_pass "GAP 1: cafe-outside.txt has $N_UDP lines, all UDP 51820, both ways, and no ICMP or TCP"
  fi
fi

# Gap 2: the inner ping on wg0.
WG="$HERE/wg0.txt"
if [ ! -s "$WG" ]; then
  t_fail "GAP 2: wg0.txt is missing or empty. Fill in the gap, then run bash captures.sh again"
elif grep -q '10\.99\.0\.2 > 10\.20\.0\.5: ICMP echo request' "$WG" && grep -q '10\.20\.0\.5 > 10\.99\.0\.2: ICMP echo reply' "$WG"; then
  t_pass "GAP 2: wg0.txt shows the inner ping, 10.99.0.2 to 10.20.0.5 and the reply"
else
  t_fail "GAP 2: wg0.txt should show 'IP 10.99.0.2 > 10.20.0.5: ICMP echo request' and the reply. Capture on wg0 in vpnbox, with the filter icmp"
fi

# Gap 3: the sum.
if grep -q 'outer 156$' "$HERE/size.txt" 2>/dev/null; then
  t_pass "GAP 3: size.txt says the outer packet is 156 bytes"
else
  t_fail "GAP 3: size.txt should end with 'outer 156'. It says: '$(cat "$HERE/size.txt" 2>/dev/null)'. Round 84 up to a multiple of 16, then add 32, 8 and 20"
fi

# Live: one outer packet, with -v, really is 156 bytes long.
timeout 5 ip netns exec caferouter tcpdump -n -l -v -i veth-cafe-out -c 1 udp port 51820 > "$TMP/size.txt" 2>&1 &
P=$!
sleep 1
ip netns exec laptop ping -c1 -W2 10.20.0.5 > /dev/null 2>&1 || true
wait "$P" || true
if grep -q 'proto UDP (17), length 156)' "$TMP/size.txt"; then
  t_pass "live: an 84-byte ping leaves the cafe in a 156-byte outer packet"
else
  t_fail "live: the outer packet for one ping should be 156 bytes. tcpdump said: $(tr '\n' ' ' < "$TMP/size.txt")"
fi

t_done
