#!/usr/bin/env bash
# Test for challenge 1, part 2. Run it in the lab:  bash test.sh
# The test builds the cable itself, twice: first with masks that disagree, then with the fix.
# It deletes and rebuilds your two computers, so save any capture you want first.
# Must fail on purpose (with /24 and /28):
#   phone to 192.168.1.10 says "Network is unreachable"
#   laptop to 192.168.1.20 gets no answer (2 sent, 0 received)
#   laptop to 192.168.1.99 gets no answer, and nobody answers its ARP request
# Must pass (both /24): ping works both ways with 0% loss.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ping_from() {
  RC=0
  OUT="$(ip netns exec "$1" ping -c2 -W1 "$2" 2>&1)" || RC=$?
}

echo "--- masks disagree: laptop /24, phone /28"
bash "$HERE/wrong-mask.sh" 28 > /dev/null

# laptop to phone: no answer.
ping_from laptop 192.168.1.20
if [ "$RC" -ne 0 ] && grep -q '2 packets transmitted, 0 received' <<< "$OUT"; then
  t_pass "laptop to 192.168.1.20: silent loss (2 sent, 0 received)"
else
  t_fail "laptop to 192.168.1.20 should get no answer. Ping said: $OUT"
fi

# phone to laptop: no route, so ping stops at once.
ping_from phone 192.168.1.10
if [ "$RC" -ne 0 ] && grep -q 'Network is unreachable' <<< "$OUT"; then
  t_pass "phone to 192.168.1.10: Network is unreachable"
else
  t_fail "phone to 192.168.1.10 should say Network is unreachable and exit non-zero. Ping said: $OUT"
fi

# laptop to an address nobody owns: watch the ARP on the phone's side of the cable.
ip netns exec phone timeout 6 tcpdump -n -U -i veth-phone arp > "$TMP/arp.txt" 2>&1 &
CAPTURE_PID=$!
sleep 1
ping_from laptop 192.168.1.99
wait "$CAPTURE_PID" || true
if [ "$RC" -ne 0 ] && grep -q '2 packets transmitted, 0 received' <<< "$OUT"; then
  t_pass "laptop to 192.168.1.99: silent loss (2 sent, 0 received)"
else
  t_fail "laptop to 192.168.1.99 should get no answer. Ping said: $OUT"
fi
if grep -q 'who-has 192.168.1.99' "$TMP/arp.txt" && ! grep -q 'Reply 192.168.1.99' "$TMP/arp.txt"; then
  t_pass "the ARP request for 192.168.1.99 goes unanswered"
else
  t_fail "expected an ARP request for 192.168.1.99 and no reply. Capture was: $(cat "$TMP/arp.txt")"
fi

echo "--- the fix: both /24"
bash "$HERE/wrong-mask.sh" 24 > /dev/null

ping_from laptop 192.168.1.20
if [ "$RC" -eq 0 ] && grep -q ' 0% packet loss' <<< "$OUT"; then
  t_pass "laptop to 192.168.1.20: 0% loss"
else
  t_fail "with both /24, laptop to 192.168.1.20 should work. Ping said: $OUT"
fi
ping_from phone 192.168.1.10
if [ "$RC" -eq 0 ] && grep -q ' 0% packet loss' <<< "$OUT"; then
  t_pass "phone to 192.168.1.10: 0% loss"
else
  t_fail "with both /24, phone to 192.168.1.10 should work. Ping said: $OUT"
fi

t_done
