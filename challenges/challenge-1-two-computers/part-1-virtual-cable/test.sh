#!/usr/bin/env bash
# Test for challenge 1, part 1. Run it in the lab AFTER you ran:  bash cable.sh
# Must pass: laptop reaches phone (192.168.1.20).
# Must fail on purpose: nobody owns 192.168.1.99, so that ping gets no answer at all.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

# ping_from NAMESPACE ADDRESS: sets OUT and RC without stopping the test when ping fails
ping_from() {
  RC=0
  OUT="$(ip netns exec "$1" ping -c2 -W1 "$2" 2>&1)" || RC=$?
}

# The two computers must exist.
NS_LIST="$(ip netns list)"
if grep -qw laptop <<< "$NS_LIST" && grep -qw phone <<< "$NS_LIST"; then
  t_pass "namespaces laptop and phone exist"
else
  t_fail "namespaces laptop and phone are missing. Run: bash cable.sh"
  t_done
fi

# Each end must have the right address.
LAPTOP_ADDR="$(ip netns exec laptop ip -4 -o addr show dev veth-laptop 2>/dev/null || true)"
PHONE_ADDR="$(ip netns exec phone ip -4 -o addr show dev veth-phone 2>/dev/null || true)"
if grep -q '192.168.1.10/24' <<< "$LAPTOP_ADDR"; then
  t_pass "laptop has 192.168.1.10/24 on veth-laptop"
else
  t_fail "laptop does not have 192.168.1.10/24 on veth-laptop. Run: ip netns exec laptop ip addr"
fi
if grep -q '192.168.1.20/24' <<< "$PHONE_ADDR"; then
  t_pass "phone has 192.168.1.20/24 on veth-phone"
else
  t_fail "phone does not have 192.168.1.20/24 on veth-phone. Run: ip netns exec phone ip addr"
fi

# Must pass: ping the phone from the laptop.
ping_from laptop 192.168.1.20
if [ "$RC" -eq 0 ] && grep -q ' 0% packet loss' <<< "$OUT"; then
  t_pass "laptop pings 192.168.1.20 with 0% loss"
else
  t_fail "laptop could not ping 192.168.1.20. Are both ends up? Run: ip netns exec phone ip link. Ping said: $OUT"
fi

# Must pass: and back again.
ping_from phone 192.168.1.10
if [ "$RC" -eq 0 ] && grep -q ' 0% packet loss' <<< "$OUT"; then
  t_pass "phone pings 192.168.1.10 with 0% loss"
else
  t_fail "phone could not ping 192.168.1.10. Ping said: $OUT"
fi

# Must fail: an address nobody owns gives silent loss. Two sent, none received.
ping_from laptop 192.168.1.99
if [ "$RC" -ne 0 ] && grep -q '2 packets transmitted, 0 received' <<< "$OUT"; then
  t_pass "192.168.1.99 gets no answer (2 sent, 0 received), as it should"
else
  t_fail "192.168.1.99 should get no answer at all. Does something own it? Ping said: $OUT"
fi

# Your evidence. This is a note, not a failure: the capture is a step in the README.
if [ -f "$HERE/capture.txt" ]; then
  if grep -q 'ARP' "$HERE/capture.txt" && grep -q 'ICMP echo request' "$HERE/capture.txt"; then
    t_pass "capture.txt has the ARP lines and the ping lines"
  else
    t_fail "capture.txt exists but has no ARP line or no 'ICMP echo request' line. Do the capture step again."
  fi
else
  echo "NOTE capture.txt not found yet. Do the capture step in the README, then run this test again."
fi

t_done
