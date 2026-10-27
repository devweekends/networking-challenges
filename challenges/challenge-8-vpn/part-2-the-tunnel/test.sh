#!/usr/bin/env bash
# Test for challenge 8, part 2. Run it in the lab AFTER you ran:  bash tunnel.sh
# When a check fails, the message says which GAP in tunnel.sh to look at.
# Must pass: both ends listen on 51820 and know each other's public key; the laptop reaches 10.99.0.1
#   and 10.20.0.5 through the tunnel; a packet from a source outside AllowedIPs is dropped (an RX error).
# Must fail on purpose: with the laptop's wg0 down, 10.20.0.5 is out of reach again.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

KEYS=/tmp/networking-course-wg

# The part 1 network must exist.
if ns_exists laptop && ns_exists vpnbox && ns_exists officesrv && ns_exists officert; then
  t_pass "the part 1 namespaces exist"
else
  t_fail "the namespaces are missing. Run: bash tunnel.sh"
  t_done
fi

# Gap 1: the keys.
KEYS_OK=1
for f in vpnbox.key vpnbox.pub laptop.key laptop.pub; do
  [ -s "$KEYS/$f" ] || KEYS_OK=0
done
if [ "$KEYS_OK" -eq 1 ] && [ "$(wg pubkey < "$KEYS/laptop.key")" = "$(cat "$KEYS/laptop.pub")" ] \
   && [ "$(wg pubkey < "$KEYS/vpnbox.key")" = "$(cat "$KEYS/vpnbox.pub")" ]; then
  t_pass "GAP 1: two key pairs in $KEYS, and each public key belongs to its private key"
else
  t_fail "GAP 1: the four key files in $KEYS are missing, empty, or do not match. Shape: wg genkey | tee PRIVATE_FILE | wg pubkey > PUBLIC_FILE"
  t_done
fi
LAPTOP_PUB="$(cat "$KEYS/laptop.pub")"
VPNBOX_PUB="$(cat "$KEYS/vpnbox.pub")"

# The office end (given in the script).
VPN_DUMP="$(ip netns exec vpnbox wg show wg0 dump 2>/dev/null || true)"
if [ "$(sed -n 1p <<< "$VPN_DUMP" | cut -f3)" = "51820" ] && grep -q "^$LAPTOP_PUB" <<< "$VPN_DUMP"; then
  t_pass "the VPN box listens on 51820 and knows the laptop's public key"
else
  t_fail "the VPN box's wg0 is not set up (script step 4). Run: ip netns exec vpnbox wg show"
fi

# Gap 2: the laptop's end.
LAP_DUMP="$(ip netns exec laptop wg show wg0 dump 2>/dev/null || true)"
LAP_PEER="$(sed -n 2p <<< "$LAP_DUMP")"
LAP_PORT="$(sed -n 1p <<< "$LAP_DUMP" | cut -f3)"
LAP_PRIV="$(sed -n 1p <<< "$LAP_DUMP" | cut -f1)"
if [ -z "$LAP_DUMP" ]; then
  t_fail "GAP 2: the laptop has no wg0. Run: ip netns exec laptop wg show"
else
  if [ "$LAP_PRIV" = "$(cat "$KEYS/laptop.key")" ] && [ "$LAP_PORT" = "51820" ]; then
    t_pass "GAP 2: the laptop uses its own private key and listens on 51820"
  else
    t_fail "GAP 2: the laptop's wg0 should use $KEYS/laptop.key and listen-port 51820. Run: ip netns exec laptop wg show"
  fi
  if [ "$(cut -f1 <<< "$LAP_PEER")" = "$VPNBOX_PUB" ] && [ "$(cut -f3 <<< "$LAP_PEER")" = "203.0.113.2:51820" ]; then
    t_pass "GAP 2: the laptop's peer is the VPN box's public key, at endpoint 203.0.113.2:51820"
  else
    t_fail "GAP 2: the laptop's peer should be the VPN box's PUBLIC key with endpoint 203.0.113.2:51820. The peer line is: '$LAP_PEER'"
  fi
  ALLOWED="$(cut -f4 <<< "$LAP_PEER")"
  if grep -q '10\.20\.0\.0/24' <<< "$ALLOWED" && grep -q '10\.99\.0\.1/32' <<< "$ALLOWED"; then
    t_pass "GAP 2: the laptop's allowed-ips are $ALLOWED"
  else
    t_fail "GAP 2: the laptop's allowed-ips should be 10.20.0.0/24,10.99.0.1/32. They are: '$ALLOWED'"
  fi
fi

# The handshake works: the VPN box's tunnel address answers.
try_ping laptop 10.99.0.1 2
if [ "$RC" -eq 0 ]; then
  t_pass "mid-point: the laptop reaches 10.99.0.1, the VPN box, through the tunnel"
else
  t_fail "mid-point: the laptop cannot reach 10.99.0.1. The tunnel is not up. Check GAP 1 and GAP 2. Ping said: $OUT"
fi

# Gap 3: the route into the tunnel.
ROUTE_GET="$(ip netns exec laptop ip route get 10.20.0.5 2>/dev/null || true)"
if grep -q 'dev wg0' <<< "$ROUTE_GET"; then
  t_pass "GAP 3: the laptop sends 10.20.0.5 into wg0"
else
  t_fail "GAP 3: the laptop sends 10.20.0.5 somewhere else: '$ROUTE_GET'. AllowedIPs does not add a route. Add one for 10.20.0.0/24 dev wg0"
fi

# Gap 4: the return route on the office server.
BACK="$(ip netns exec officesrv ip route get 10.99.0.2 2>/dev/null || true)"
if grep -q 'via 10\.20\.0\.2' <<< "$BACK"; then
  t_pass "GAP 4: the office server sends 10.99.0.2 back via the VPN box, 10.20.0.2"
else
  t_fail "GAP 4: the office server sends answers for 10.99.0.2 the wrong way: '$BACK'. It needs a route to 10.99.0.0/24 via 10.20.0.2"
fi

# Must pass: the office server through the tunnel.
try_ping laptop 10.20.0.5 2
if [ "$RC" -eq 0 ]; then
  t_pass "the laptop reaches 10.20.0.5 through the tunnel"
else
  t_fail "the laptop cannot reach 10.20.0.5. If 10.99.0.1 works, look at GAP 3 and GAP 4. Ping said: $OUT"
fi
try_curl laptop http://10.20.0.5/
if [ "$RC" -eq 0 ] && grep -q 'office test server' <<< "$OUT"; then
  t_pass "the laptop gets the office test page through the tunnel"
else
  t_fail "the laptop cannot get http://10.20.0.5/ (curl exit $RC). Check GAP 3 and GAP 4"
fi

# Must fail: with the laptop's end of the tunnel down, the office is out of reach.
# Taking wg0 down also deletes its routes, so the test puts back what was there.
SAVED_ROUTE="$(ip netns exec laptop ip route show 10.20.0.0/24 2>/dev/null || true)"
ip netns exec laptop ip link set wg0 down 2>/dev/null || true
try_ping laptop 10.20.0.5 1
DOWN_RC=$RC
DOWN_OUT="$OUT"
ip netns exec laptop ip link set wg0 up 2>/dev/null || true
if [ -n "$SAVED_ROUTE" ]; then
  ip netns exec laptop ip route replace $SAVED_ROUTE 2>/dev/null || true
fi
if [ "$DOWN_RC" -ne 0 ]; then
  t_pass "with the laptop's wg0 down, 10.20.0.5 is out of reach (as expected)"
else
  t_fail "with wg0 down the laptop should NOT reach 10.20.0.5. Ping said: $DOWN_OUT"
fi

# Must pass: a source outside AllowedIPs is dropped at the VPN box. It shows as a receive error on wg0.
rx_errors() {
  ip netns exec vpnbox ip -s link show wg0 | awk '/RX:/ { getline; print $3; exit }'
}
E1="$(rx_errors)"
ip netns exec laptop ip addr add 10.99.0.77/32 dev wg0 2>/dev/null || true
ip netns exec laptop ping -c1 -W1 -I 10.99.0.77 10.20.0.5 > /dev/null 2>&1 || true
ip netns exec laptop ip addr del 10.99.0.77/32 dev wg0 2>/dev/null || true
E2="$(rx_errors)"
if [ -n "$E1" ] && [ -n "$E2" ] && [ "$E2" -gt "$E1" ]; then
  t_pass "a packet from 10.99.0.77 (not in the laptop's allowed-ips on the VPN box) was dropped: RX errors $E1 to $E2"
else
  t_fail "a packet from 10.99.0.77 should add an RX error on the VPN box's wg0. Errors before: '$E1', after: '$E2'"
fi

# Your evidence files.
if grep -q '1 received' "$HERE/with-tunnel.txt" 2>/dev/null || grep -q '2 received' "$HERE/with-tunnel.txt" 2>/dev/null; then
  t_pass "with-tunnel.txt shows answers from 10.20.0.5"
else
  t_fail "with-tunnel.txt is missing or shows no answer. Fill in the gaps, then run bash tunnel.sh again"
fi
if grep -q ' 0 received' "$HERE/before-tunnel.txt" 2>/dev/null; then
  t_pass "before-tunnel.txt shows no answer from 10.20.0.5"
else
  t_fail "before-tunnel.txt is missing or shows an answer. Run bash tunnel.sh again"
fi
if [ -s "$HERE/spoof.txt" ] && grep -q 'receive errors: before' "$HERE/spoof.txt"; then
  t_pass "spoof.txt is there"
else
  t_fail "spoof.txt is missing. Run: bash tunnel.sh (without build-only)"
fi

t_done
