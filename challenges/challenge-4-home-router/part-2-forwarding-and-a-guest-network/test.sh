#!/usr/bin/env bash
# Test for challenge 4, part 2. Run it in the lab AFTER you ran:  bash forwarding-guest.sh
# When a check fails, the message says which GAP in forwarding-guest.sh to look at.
# Must pass: from the server, 203.0.113.1:8080 returns the laptop's page (port forwarding);
#   the guest reaches the server and the server sees 203.0.113.1.
# Must fail on purpose: the guest cannot reach the laptop (the drop rule makes it time out);
#   the server cannot reach 192.168.1.23 directly (no route, fails at once);
#   an unforwarded port, 203.0.113.1:22, is refused at once (exit 7), not a timeout.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

# The five computers must exist.
if ns_exists laptop && ns_exists phone && ns_exists router && ns_exists server && ns_exists guest; then
  t_pass "namespaces laptop, phone, router, server and guest exist"
else
  t_fail "namespaces are missing. Run: bash forwarding-guest.sh (and make part 1 pass first)"
  t_done
fi

# Part 1 must still work: a device reaches the server and the server sees 203.0.113.1.
try_curl laptop http://203.0.113.80:8080/cgi-bin/whoami
if [ "$RC" -eq 0 ] && grep -q 'sees you as 203\.0\.113\.1:' <<< "$OUT"; then
  t_pass "part 1 still works: the laptop reaches the server, which sees 203.0.113.1"
else
  t_fail "part 1 is broken. Run: bash ../part-1-masquerade/test.sh. Curl said: $OUT"
fi

# The mid-point: the laptop's web page works on its own network, and the guest reaches its router.
try_curl router -o - http://192.168.1.23/
if [ "$RC" -eq 0 ] && grep -q 'home web server' <<< "$OUT"; then
  t_pass "mid-point: the router can read the laptop's web page at 192.168.1.23:80"
else
  t_fail "mid-point: the router cannot read http://192.168.1.23/. Is the web server on the laptop running? Run: ip netns exec laptop ss -tlnp. Curl said: $OUT"
fi
try_ping guest 192.168.50.1 1
if [ "$RC" -eq 0 ]; then
  t_pass "mid-point: the guest reaches the router, 192.168.50.1"
else
  t_fail "mid-point: the guest cannot reach 192.168.50.1. Check the guest cable and addresses (script step 2). Ping said: $OUT"
fi

# Gap 1: port forwarding. From the server, the router's outside address and port 8080 return the laptop's page.
try_curl server http://203.0.113.1:8080/
if [ "$RC" -eq 0 ] && grep -q 'home web server' <<< "$OUT"; then
  t_pass "GAP 1: from the server, http://203.0.113.1:8080/ returns the laptop's page"
else
  RULESET="$(ip netns exec router nft list ruleset 2>/dev/null || true)"
  if grep -q 'dnat' <<< "$RULESET"; then
    t_fail "GAP 1: there is a dnat rule, but http://203.0.113.1:8080/ did not return the laptop's page (curl exit $RC). Check the port numbers and the address in the rule. Curl said: $OUT"
  else
    t_fail "GAP 1: the router has no dnat rule. Run: ip netns exec router nft list ruleset"
  fi
fi

# Required observation: a port that is not forwarded is refused at once.
try_curl server -v -o /dev/null http://203.0.113.1:22/
if [ "$RC" -eq 7 ] && [ "$ELAPSED" -lt 3 ] && grep -q 'Connection refused' <<< "$OUT"; then
  t_pass "an unforwarded port, 203.0.113.1:22, is refused at once (exit 7, Connection refused)"
else
  t_fail "203.0.113.1:22 should be refused at once (exit 7, 'Connection refused'). It exited $RC after $ELAPSED seconds. Curl said: $OUT"
fi

# Must fail: the server cannot reach a private address directly.
try_curl server -o /dev/null http://192.168.1.23/
if [ "$RC" -eq 7 ] && [ "$ELAPSED" -lt 3 ]; then
  t_pass "from the server, 192.168.1.23 is not reachable (curl exit 7, at once)"
else
  t_fail "from the server, curl to 192.168.1.23 should fail at once with exit 7. It exited $RC after $ELAPSED seconds. Curl said: $OUT"
fi

# The guest reaches the server, and the server sees the router's outside address.
try_curl guest http://203.0.113.80:8080/cgi-bin/whoami
if [ "$RC" -eq 0 ] && grep -q 'sees you as 203\.0\.113\.1:' <<< "$OUT"; then
  t_pass "the guest reaches the server, which sees 203.0.113.1"
else
  t_fail "the guest cannot reach the server (curl exit $RC). Does the guest have a default route? Is masquerade on? Curl said: $OUT"
fi

# Gap 2: the guest cannot reach the home network. A drop rule is silent, so the request times out.
try_curl guest -o /dev/null http://192.168.1.23/
if [ "$RC" -eq 28 ]; then
  t_pass "GAP 2: the guest cannot reach the laptop (curl timed out, exit 28)"
elif [ "$RC" -eq 0 ]; then
  t_fail "GAP 2: the guest reached the laptop's page. The isolation rule is missing or wrong. Run: ip netns exec router nft list ruleset"
else
  t_fail "GAP 2: the guest failed with exit $RC, but a drop rule should make it time out (exit 28). Another problem may be hiding. Curl said: $OUT"
fi

# The home network still works inside itself.
try_curl phone -o - http://192.168.1.23/
if [ "$RC" -eq 0 ] && grep -q 'home web server' <<< "$OUT"; then
  t_pass "the phone still reaches the laptop's page (the rule only blocks the guest)"
else
  t_fail "the phone cannot reach the laptop's page. Curl said: $OUT"
fi

# Gap 3: your three outside tests, saved by the script.
if [ ! -s "$HERE/outside-tests.txt" ]; then
  t_fail "GAP 3: outside-tests.txt is missing or empty. Fill in the gap, then run bash forwarding-guest.sh again"
else
  FILE="$(cat "$HERE/outside-tests.txt")"
  if grep -qx 'forwarded: exit 0' <<< "$FILE" && grep -qx 'unforwarded: exit 7' <<< "$FILE" && grep -qx 'direct: exit 7' <<< "$FILE"; then
    t_pass "GAP 3: outside-tests.txt has forwarded 0, unforwarded 7 and direct 7"
  else
    t_fail "GAP 3: outside-tests.txt should say 'forwarded: exit 0', 'unforwarded: exit 7' and 'direct: exit 7'. It says: $FILE"
  fi
fi

t_done
