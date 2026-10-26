#!/usr/bin/env bash
# Test for challenge 4, part 1. Run it in the lab AFTER you ran:  bash masquerade.sh
# When a check fails, the message says which GAP in masquerade.sh to look at.
# Must pass: each device reaches the server and the server sees 203.0.113.1, never 192.168.1.x;
#   with the same source port on both devices, the two ports the server reports differ,
#   and the second one matches the router's NAT table.
# Must fail on purpose: from the server, 192.168.1.23 is not reachable (the server has no route to it).
# The test never checks a fixed port number. It only compares.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

WHOAMI=http://203.0.113.80:8080/cgi-bin/whoami
SLOW=http://203.0.113.80:8080/cgi-bin/slow

# port_in TEXT: print the port from "the server sees you as ADDRESS:PORT"
port_in() {
  sed -n 's/.*sees you as [0-9.]*:\([0-9]*\).*/\1/p' <<< "$1" | head -n 1
}

# The four computers must exist.
if ns_exists laptop && ns_exists phone && ns_exists router && ns_exists server; then
  t_pass "namespaces laptop, phone, router and server exist"
else
  t_fail "namespaces are missing. Run: bash masquerade.sh"
  t_done
fi

# The mid-point: each home device reaches the router, and the router reaches the server.
try_ping laptop 192.168.1.1 1
LAPTOP_ROUTER_RC=$RC
try_ping phone 192.168.1.1 1
if [ "$LAPTOP_ROUTER_RC" -eq 0 ] && [ "$RC" -eq 0 ]; then
  t_pass "mid-point: laptop and phone reach the router, 192.168.1.1"
else
  t_fail "mid-point: laptop or phone cannot reach 192.168.1.1. Check the home side (script step 3)"
fi
try_ping router 203.0.113.80 1
if [ "$RC" -eq 0 ]; then
  t_pass "mid-point: the router reaches the server, 203.0.113.80"
else
  t_fail "mid-point: the router cannot reach 203.0.113.80. Check the outside cable and addresses (script step 4). Ping said: $OUT"
fi

# Gap 1: forwarding and default routes.
FORWARDING="$(ip netns exec router sysctl -n net.ipv4.ip_forward 2>/dev/null || echo unknown)"
if [ "$FORWARDING" = "1" ]; then
  t_pass "GAP 1: forwarding is on in the router"
else
  t_fail "GAP 1: forwarding is off in the router (net.ipv4.ip_forward is $FORWARDING)"
fi
LAPTOP_DEFAULT="$(ip netns exec laptop ip route show default 2>/dev/null || true)"
PHONE_DEFAULT="$(ip netns exec phone ip route show default 2>/dev/null || true)"
if grep -q 'default via 192.168.1.1' <<< "$LAPTOP_DEFAULT" && grep -q 'default via 192.168.1.1' <<< "$PHONE_DEFAULT"; then
  t_pass "GAP 1: laptop and phone both have a default route via 192.168.1.1"
else
  t_fail "GAP 1: laptop or phone has no default route via 192.168.1.1. Run: ip netns exec laptop ip route"
fi

# Gap 2: masquerade.
RULESET="$(ip netns exec router nft list ruleset 2>/dev/null || true)"
if grep -q 'masquerade' <<< "$RULESET"; then
  t_pass "GAP 2: the router has a masquerade rule"
else
  t_fail "GAP 2: no masquerade rule in the router. Run: ip netns exec router nft list ruleset"
fi

# Must pass: each device reaches the server, and the server sees the router's outside address.
for device in laptop phone; do
  try_curl "$device" "$WHOAMI"
  if [ "$RC" -eq 0 ] && grep -q 'sees you as 203\.0\.113\.1:' <<< "$OUT"; then
    t_pass "$device reaches the server, and the server sees 203.0.113.1"
  elif [ "$RC" -eq 0 ] && grep -q 'sees you as 192\.168\.1\.' <<< "$OUT"; then
    t_fail "$device reaches the server, but the server sees a private address. The source was not rewritten. Check GAP 2. The server said: $OUT"
  else
    t_fail "$device cannot get the page from $WHOAMI (curl exit $RC). Check GAP 1 and GAP 2. Curl said: $OUT"
  fi
done

# Must fail: the server cannot reach a private address. It has no route to it, so curl fails at once.
try_curl server -o /dev/null http://192.168.1.23/
if [ "$RC" -eq 7 ] && [ "$ELAPSED" -lt 3 ]; then
  t_pass "from the server, 192.168.1.23 is not reachable (curl exit 7, at once)"
else
  t_fail "from the server, curl to 192.168.1.23 should fail at once with exit 7. It exited $RC after $ELAPSED seconds. Curl said: $OUT"
fi

# Gap 3 and 4: the same source port from both devices. Live test with a port the test picks.
PORT=$((42000 + RANDOM % 1000))
ip netns exec laptop curl -sS -m 8 --local-port "$PORT" "$SLOW" > "$TMP/laptop.txt" 2>&1 &
LAPTOP_PID=$!
sleep 1
try_curl phone --local-port "$PORT" "$WHOAMI"
PHONE_OUT="$OUT"
wait "$LAPTOP_PID" || true
LAPTOP_OUT="$(cat "$TMP/laptop.txt")"
LAPTOP_SEEN="$(port_in "$LAPTOP_OUT")"
PHONE_SEEN="$(port_in "$PHONE_OUT")"
if [ -n "$LAPTOP_SEEN" ] && [ -n "$PHONE_SEEN" ] && [ "$LAPTOP_SEEN" != "$PHONE_SEEN" ]; then
  t_pass "both devices sent from the same source port, and the server saw two different ports ($LAPTOP_SEEN and $PHONE_SEEN)"
else
  t_fail "the server should report two different ports. Laptop: '$LAPTOP_OUT' Phone: '$PHONE_OUT'"
fi

# The new port is in the router's NAT table.
TABLE="$(ip netns exec router conntrack -L 2>/dev/null || true)"
PHONE_LINE="$(grep "src=192.168.1.24 " <<< "$TABLE" | grep "sport=$PORT " | head -n 1 || true)"
TABLE_PORT="$(grep -o 'dport=[0-9]*' <<< "$PHONE_LINE" | tail -n 1 | cut -d= -f2 || true)"
if [ -n "$TABLE_PORT" ] && [ "$TABLE_PORT" = "$PHONE_SEEN" ]; then
  t_pass "conntrack -L shows the phone's flow with the new port the server saw ($TABLE_PORT)"
else
  t_fail "conntrack -L should list the phone's flow (sport=$PORT) and its reply with dport=$PHONE_SEEN. The line was: '$PHONE_LINE'"
fi

# Your evidence files from the script (Gap 3 and Gap 4).
if [ ! -s "$HERE/same-port-laptop.txt" ] || [ ! -s "$HERE/same-port-phone.txt" ]; then
  t_fail "GAP 3: same-port-laptop.txt or same-port-phone.txt is missing or empty. Fill in the gap, then run bash masquerade.sh again"
else
  FILE_LAPTOP="$(port_in "$(cat "$HERE/same-port-laptop.txt")")"
  FILE_PHONE="$(port_in "$(cat "$HERE/same-port-phone.txt")")"
  if [ -n "$FILE_LAPTOP" ] && [ -n "$FILE_PHONE" ] && [ "$FILE_LAPTOP" != "$FILE_PHONE" ]; then
    t_pass "GAP 3: your two files show two different ports ($FILE_LAPTOP and $FILE_PHONE)"
  else
    t_fail "GAP 3: your two files should show two different ports. Laptop: '$(cat "$HERE/same-port-laptop.txt")' Phone: '$(cat "$HERE/same-port-phone.txt")'. Is the laptop's curl in the background (&), and do both use --local-port 41000?"
  fi
fi
if [ ! -s "$HERE/conntrack.txt" ]; then
  t_fail "GAP 4: conntrack.txt is missing or empty. Fill in the gap, then run bash masquerade.sh again"
elif [ "$(grep -c 'sport=41000 ' "$HERE/conntrack.txt" || true)" -ge 2 ]; then
  t_pass "GAP 4: conntrack.txt lists two flows that both left from sport=41000"
else
  t_fail "GAP 4: conntrack.txt should have two lines with sport=41000 (one per device). It has: $(cat "$HERE/conntrack.txt")"
fi

t_done
