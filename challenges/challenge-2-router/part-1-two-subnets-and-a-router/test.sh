#!/usr/bin/env bash
# Test for challenge 2, part 1. Run it in the lab AFTER you ran:  bash router.sh
# When a check fails, the message says which GAP in router.sh to look at.
# Must pass: the mid-point (each side reaches its own router), then laptop and server reach each other
#   through the router, traceroute shows two hops, and the capture shows the MAC change.
# Must fail on purpose: 198.51.100.7 is an address the router has no route for. The router answers
#   "Destination Net Unreachable". That is a router saying "I got it, but I do not know where to send it".
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# has_addr NAMESPACE INTERFACE ADDRESS/PREFIX
has_addr() {
  local out
  out="$(ip netns exec "$1" ip -4 -o addr show dev "$2" 2>/dev/null || true)"
  grep -q "$3" <<< "$out"
}

# The three computers must exist.
if ns_exists laptop && ns_exists router && ns_exists server; then
  t_pass "namespaces laptop, router and server exist"
else
  t_fail "namespaces laptop, router and server are missing. Run: bash router.sh"
  t_done
fi

# Every plug has its address.
if has_addr laptop veth-laptop 192.168.1.23/24 && has_addr router veth-rin 192.168.1.1/24 \
   && has_addr router veth-rout 203.0.113.1/24 && has_addr server veth-server 203.0.113.80/24; then
  t_pass "all four plugs have their addresses"
else
  t_fail "an address is missing. Compare 'ip addr' in each computer with the table in the README"
fi

# The mid-point check. These need none of the gaps.
try_ping laptop 192.168.1.1
if [ "$RC" -eq 0 ] && grep -q ' 0% packet loss' <<< "$OUT"; then
  t_pass "mid-point: laptop reaches its own router, 192.168.1.1"
else
  t_fail "mid-point: laptop cannot reach 192.168.1.1. Check the cables and addresses (steps 3 and 4). Ping said: $OUT"
fi
try_ping server 203.0.113.1
if [ "$RC" -eq 0 ] && grep -q ' 0% packet loss' <<< "$OUT"; then
  t_pass "mid-point: server reaches its own router, 203.0.113.1"
else
  t_fail "mid-point: server cannot reach 203.0.113.1. Check the cables and addresses (steps 3 and 4). Ping said: $OUT"
fi

# Gap 1: the laptop's default route.
LAPTOP_DEFAULT="$(ip netns exec laptop ip route show default 2>/dev/null || true)"
if grep -q 'default via 192.168.1.1' <<< "$LAPTOP_DEFAULT"; then
  t_pass "GAP 1: the laptop has a default route via 192.168.1.1"
else
  t_fail "GAP 1: the laptop has no default route via 192.168.1.1. Run: ip netns exec laptop ip route"
fi

# Gap 2: forwarding in the router.
FORWARDING="$(ip netns exec router sysctl -n net.ipv4.ip_forward 2>/dev/null || echo unknown)"
if [ "$FORWARDING" = "1" ]; then
  t_pass "GAP 2: forwarding is on in the router"
else
  t_fail "GAP 2: forwarding is off in the router (net.ipv4.ip_forward is $FORWARDING). Run: ip netns exec router sysctl net.ipv4.ip_forward"
fi

# Gap 3: the server's way back.
SERVER_ROUTES="$(ip netns exec server ip route show 2>/dev/null || true)"
if grep -q '192.168.1.0/24 via 203.0.113.1' <<< "$SERVER_ROUTES"; then
  t_pass "GAP 3: the server has a route to 192.168.1.0/24 via 203.0.113.1"
else
  t_fail "GAP 3: the server has no route to 192.168.1.0/24 via 203.0.113.1. Run: ip netns exec server ip route"
fi

# Must pass: across the router, both ways.
try_ping laptop 203.0.113.80
if [ "$RC" -eq 0 ] && grep -q ' 0% packet loss' <<< "$OUT"; then
  t_pass "laptop pings the server, 203.0.113.80, with 0% loss"
  ACROSS=1
else
  t_fail "laptop cannot ping 203.0.113.80. Fix the failing GAP above first. Ping said: $OUT"
  ACROSS=0
fi
try_ping server 192.168.1.23
if [ "$RC" -eq 0 ] && grep -q ' 0% packet loss' <<< "$OUT"; then
  t_pass "server pings the laptop, 192.168.1.23, with 0% loss"
else
  t_fail "server cannot ping 192.168.1.23. Ping said: $OUT"
fi

# Must pass: traceroute shows the router, then the server.
TRACE="$(ip netns exec laptop traceroute -n -w 1 -q 1 -m 5 203.0.113.80 2>&1 || true)"
HOP1="$(awk '$1 == 1 { print $2 }' <<< "$TRACE")"
HOP2="$(awk '$1 == 2 { print $2 }' <<< "$TRACE")"
if [ "$HOP1" = "192.168.1.1" ] && [ "$HOP2" = "203.0.113.80" ]; then
  t_pass "traceroute shows two hops: 192.168.1.1, then 203.0.113.80"
else
  t_fail "traceroute should show 192.168.1.1 then 203.0.113.80. It showed: $TRACE"
fi

# Must fail: the router has no route for 198.51.100.7, and it says so.
try_ping laptop 198.51.100.7 1
if [ "$RC" -ne 0 ] && grep -q 'From 192.168.1.1 .*Destination Net Unreachable' <<< "$OUT"; then
  t_pass "198.51.100.7: the router, 192.168.1.1, answers Destination Net Unreachable, as it should"
else
  t_fail "expected 'Destination Net Unreachable' from 192.168.1.1. If there was no answer at all, forwarding may be off (GAP 2). Ping said: $OUT"
fi

# The MAC change. Capture one ping on both sides of the router.
if [ "$ACROSS" -eq 1 ]; then
  LAPTOP_MAC="$(mac_of laptop veth-laptop)"
  RIN_MAC="$(mac_of router veth-rin)"
  ROUT_MAC="$(mac_of router veth-rout)"
  SERVER_MAC="$(mac_of server veth-server)"
  timeout 8 ip netns exec router tcpdump -n -e -v -U -i veth-rin -c 2 icmp > "$TMP/inside.txt" 2>&1 &
  INSIDE_PID=$!
  timeout 8 ip netns exec router tcpdump -n -e -v -U -i veth-rout -c 2 icmp > "$TMP/outside.txt" 2>&1 &
  OUTSIDE_PID=$!
  sleep 1
  try_ping laptop 203.0.113.80 1
  wait "$INSIDE_PID" || true
  wait "$OUTSIDE_PID" || true

  INSIDE_REQUEST="$(grep -m1 "$LAPTOP_MAC > $RIN_MAC" "$TMP/inside.txt" || true)"
  OUTSIDE_REQUEST="$(grep -m1 "$ROUT_MAC > $SERVER_MAC" "$TMP/outside.txt" || true)"
  if [ -n "$INSIDE_REQUEST" ] && grep -q 'ttl 64' <<< "$INSIDE_REQUEST"; then
    t_pass "inside link: the echo goes from the laptop's MAC to the router's inside MAC, ttl 64"
  else
    t_fail "inside link: expected a line '$LAPTOP_MAC > $RIN_MAC' with 'ttl 64'. Capture was: $(cat "$TMP/inside.txt")"
  fi
  if [ -n "$OUTSIDE_REQUEST" ] && grep -q 'ttl 63' <<< "$OUTSIDE_REQUEST"; then
    t_pass "outside link: the same echo goes from the router's outside MAC to the server's MAC, ttl 63"
  else
    t_fail "outside link: expected a line '$ROUT_MAC > $SERVER_MAC' with 'ttl 63'. Capture was: $(cat "$TMP/outside.txt")"
  fi
  if grep -q '192.168.1.23 > 203.0.113.80: ICMP echo request' "$TMP/inside.txt" \
     && grep -q '192.168.1.23 > 203.0.113.80: ICMP echo request' "$TMP/outside.txt"; then
    t_pass "the IP addresses are the same on both sides: 192.168.1.23 > 203.0.113.80"
  else
    t_fail "the IP addresses should not change at a router. Inside: $(cat "$TMP/inside.txt") Outside: $(cat "$TMP/outside.txt")"
  fi
else
  echo "NOTE the MAC-change checks need the ping across the router to work. Fix the gaps first."
fi

t_done
