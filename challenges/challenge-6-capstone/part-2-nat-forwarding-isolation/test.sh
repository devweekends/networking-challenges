#!/usr/bin/env bash
# Test for challenge 6, part 2. Run it in the lab AFTER you ran your  bash nat-forwarding-isolation.sh
# Must pass: home1 and guest1 reach the public server and it sees only 198.51.100.2;
#   the server reaches the home web server through the forwarded port, across the provider router;
#   the router's NAT table lists the connection.
# Must fail on purpose: guest1 cannot reach the home web server (the request times out);
#   the server cannot reach 192.168.1.20 directly (no route, fails at once);
#   an unforwarded port, 198.51.100.2:22, is refused at once.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

WHOAMI=http://203.0.113.80:8080/cgi-bin/whoami

# All seven computers must exist.
MISSING=""
for ns in home1 home2 homeweb guest1 hrouter prouter server; do
  ns_exists "$ns" || MISSING="$MISSING $ns"
done
if [ -z "$MISSING" ]; then
  t_pass "all seven namespaces exist"
else
  t_fail "these namespaces are missing:$MISSING. Run your nat-forwarding-isolation.sh"
  t_done
fi

# The rules are there.
RULESET="$(ip netns exec hrouter nft list ruleset 2>/dev/null || true)"
if grep -q 'masquerade' <<< "$RULESET"; then
  t_pass "hrouter has a masquerade rule"
else
  t_fail "hrouter has no masquerade rule. Run: ip netns exec hrouter nft list ruleset"
fi
if grep -q 'dnat to 192.168.1.20' <<< "$RULESET"; then
  t_pass "hrouter has a rule that forwards a port to 192.168.1.20"
else
  t_fail "hrouter has no 'dnat to 192.168.1.20...' rule. Run: ip netns exec hrouter nft list ruleset"
fi

# Must pass: home1 and guest1 reach the public server, which sees only the router's outside address.
for device in home1 guest1; do
  try_curl "$device" "$WHOAMI"
  if [ "$RC" -eq 0 ] && grep -q 'sees you as 198\.51\.100\.2:' <<< "$OUT"; then
    t_pass "$device reaches the public server, which sees 198.51.100.2"
  elif [ "$RC" -eq 0 ]; then
    t_fail "$device reaches the public server, but it sees the wrong address. The server said: $OUT"
  else
    t_fail "$device cannot get the page from $WHOAMI (curl exit $RC). Is forwarding on? Is there a masquerade rule on the outside interface? Curl said: $OUT"
  fi
done

# The NAT table lists the connection.
TABLE="$(ip netns exec hrouter conntrack -L 2>/dev/null || true)"
if grep -q 'dst=203.0.113.80 .*dport=8080' <<< "$TABLE"; then
  t_pass "conntrack -L in hrouter lists a connection to 203.0.113.80:8080"
else
  t_fail "conntrack -L in hrouter has no line with dst=203.0.113.80 and dport=8080. The table has: $TABLE"
fi

# Must pass: the server reaches the home web server through the forwarded port, across the provider router.
try_curl server http://198.51.100.2:8080/
if [ "$RC" -eq 0 ] && grep -q 'home web server' <<< "$OUT"; then
  t_pass "the server reaches the home web server through 198.51.100.2:8080"
else
  t_fail "http://198.51.100.2:8080/ did not return the home web server's page (curl exit $RC). Check the dnat rule, the home web server, and the route back. Curl said: $OUT"
fi

# Must fail: the guest cannot reach the home web server. A drop is silent, so the request times out.
try_curl guest1 -o /dev/null http://192.168.1.20/
if [ "$RC" -eq 28 ]; then
  t_pass "guest1 cannot reach the home web server (curl timed out, exit 28)"
elif [ "$RC" -eq 0 ]; then
  t_fail "guest1 reached the home web server. The isolation rule is missing or wrong. Run: ip netns exec hrouter nft list ruleset"
else
  t_fail "guest1 failed with exit $RC, but a drop rule should make it time out (exit 28). Another problem may be hiding. Curl said: $OUT"
fi

# Must fail: the server has no way to a private address, and fails at once.
try_curl server -o /dev/null http://192.168.1.20/
if [ "$RC" -eq 7 ] && [ "$ELAPSED" -lt 3 ]; then
  t_pass "the server cannot reach 192.168.1.20 directly (curl exit 7, at once)"
else
  t_fail "the server's curl to 192.168.1.20 should fail at once with exit 7. It exited $RC after $ELAPSED seconds. Curl said: $OUT"
fi

# Must fail: an unforwarded port is refused at once, not a timeout.
try_curl server -v -o /dev/null http://198.51.100.2:22/
if [ "$RC" -eq 7 ] && [ "$ELAPSED" -lt 3 ] && grep -q 'Connection refused' <<< "$OUT"; then
  t_pass "an unforwarded port, 198.51.100.2:22, is refused at once (exit 7, Connection refused)"
else
  t_fail "198.51.100.2:22 should be refused at once (exit 7, 'Connection refused'). It exited $RC after $ELAPSED seconds. Curl said: $OUT"
fi

t_done
