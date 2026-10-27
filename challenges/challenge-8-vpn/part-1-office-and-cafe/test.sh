#!/usr/bin/env bash
# Test for challenge 8, part 1. Run it in the lab AFTER you ran:  bash office-cafe.sh
# When a check fails, the message says which step of office-cafe.sh to look at.
# Must pass: the lab website sees the cafe's address (198.51.100.2) for the laptop and the office's
#   address (203.0.113.2) for the office server; a UDP packet to 203.0.113.2 port 51820 reaches the VPN box;
#   forward-test.txt shows the break-and-mend experiment.
# Must fail on purpose: the laptop cannot reach 10.20.0.5. The internet has no route to a private address.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

WHOAMI=http://192.0.2.80/cgi-bin/whoami

# The seven computers must exist.
MISSING=""
for ns in internet website officert vpnbox officesrv caferouter laptop; do
  ns_exists "$ns" || MISSING="$MISSING $ns"
done
if [ -z "$MISSING" ]; then
  t_pass "the seven namespaces exist"
else
  t_fail "namespaces missing:$MISSING. Run: bash office-cafe.sh"
  t_done
fi

# Mid-points: each computer reaches its own router.
for pair in "laptop 192.168.50.1" "caferouter 198.51.100.1" "officert 203.0.113.1" "vpnbox 10.20.0.1" "officesrv 10.20.0.1" "website 192.0.2.1"; do
  set -- $pair
  try_ping "$1" "$2" 1
  if [ "$RC" -eq 0 ]; then
    t_pass "mid-point: $1 reaches $2"
  else
    t_fail "mid-point: $1 cannot reach $2. Check steps 3 to 5 (cables and addresses). Ping said: $OUT"
  fi
done

# Must pass: the website sees each network's public address.
try_curl laptop "$WHOAMI"
if [ "$RC" -eq 0 ] && grep -q 'sees you as 198\.51\.100\.2:' <<< "$OUT"; then
  t_pass "the laptop reaches the website, and the website sees the cafe, 198.51.100.2"
else
  t_fail "the website should see the laptop as 198.51.100.2. Check the cafe NAT (step 7). Curl exit $RC: $OUT"
fi
try_curl officesrv "$WHOAMI"
if [ "$RC" -eq 0 ] && grep -q 'sees you as 203\.0\.113\.2:' <<< "$OUT"; then
  t_pass "the office server reaches the website, and the website sees the office, 203.0.113.2"
else
  t_fail "the website should see the office server as 203.0.113.2. Check the office NAT (step 7). Curl exit $RC: $OUT"
fi

# Must fail: no tunnel yet, so the laptop cannot reach the office server.
try_ping laptop 10.20.0.5 1
if [ "$RC" -ne 0 ]; then
  t_pass "the laptop cannot reach 10.20.0.5 (no tunnel yet, as expected)"
else
  t_fail "the laptop should NOT reach 10.20.0.5 before the tunnel. Did something add a route? Ping said: $OUT"
fi

# The port forward rule is in the office router.
RULESET="$(ip netns exec officert nft list ruleset 2>/dev/null || true)"
if grep -q 'udp dport 51820 dnat to 10.20.0.2:51820' <<< "$RULESET"; then
  t_pass "the office router forwards UDP 51820 to 10.20.0.2"
else
  t_fail "no port forward for UDP 51820 in the office router (step 7, or step 10 did not put it back). Run: ip netns exec officert nft list ruleset"
fi

# Live: one UDP packet from a fresh port, so no old NAT state can help it.
PORT=$((43000 + RANDOM % 1000))
timeout 3 ip netns exec vpnbox tcpdump -n -l -i veth-vpnbox -c 1 udp port 51820 > "/tmp/networking-course-t8p1.txt" 2>/dev/null &
WATCH_PID=$!
sleep 1
echo test | ip netns exec laptop nc -u -w1 -p "$PORT" 203.0.113.2 51820 > /dev/null 2>&1 || true
wait "$WATCH_PID" || true
SEEN="$(grep ' UDP' /tmp/networking-course-t8p1.txt || true)"
if grep -q "198\.51\.100\.2\.[0-9]* > 10\.20\.0\.2\.51820" <<< "$SEEN"; then
  t_pass "a packet from the laptop to 203.0.113.2:51820 reaches the VPN box, from 198.51.100.2"
else
  t_fail "a UDP packet to 203.0.113.2:51820 did not reach the VPN box. Check the port forward (step 7). The VPN box saw: '$SEEN'"
fi

# The experiment file from step 10.
if [ ! -s "$HERE/forward-test.txt" ]; then
  t_fail "forward-test.txt is missing. Run: bash office-cafe.sh (without build-only)"
else
  EXPECT="1:arrived 2:arrived 3:nothing 4:nothing 5:arrived"
  GOT=""
  for n in 1 2 3 4 5; do
    if grep -q "^$n .*: arrived" "$HERE/forward-test.txt"; then
      GOT="$GOT $n:arrived"
    elif grep -q "^$n .*: nothing arrived" "$HERE/forward-test.txt"; then
      GOT="$GOT $n:nothing"
    else
      GOT="$GOT $n:missing"
    fi
  done
  if [ "${GOT# }" = "$EXPECT" ]; then
    t_pass "forward-test.txt: arrived, arrived (old state), nothing (flushed), nothing (old state), arrived (flushed)"
  else
    t_fail "forward-test.txt should read $EXPECT. It reads${GOT}. Look at step 10"
  fi
fi

t_done
