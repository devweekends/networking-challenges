#!/usr/bin/env bash
# Test for challenge 6, part 1. Run it in the lab AFTER you ran your  bash addresses-and-routes.sh
# Must pass: every device reaches its own router; the home router reaches the public server through the
#   provider router, and the server sees 198.51.100.2; the routes pick the gateway; traceroute shows two hops.
# Must fail on purpose (only while there is no NAT yet): home1 pings the public server and gets no reply,
#   and a capture on the home router's outside link shows the private source address leaving.
# After part 2 has added NAT, the "no NAT" checks are skipped, so this test also passes on the full network.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# has_addr NAMESPACE ADDRESS/PREFIX: true if any interface in the namespace has this address
has_addr() {
  local out
  out="$(ip netns exec "$1" ip -4 -o addr show 2>/dev/null || true)"
  grep -qF " $2 " <<< "$out"
}

# ping_ok NAMESPACE ADDRESS LABEL: one PASS or FAIL line
ping_ok() {
  try_ping "$1" "$2" 1
  if [ "$RC" -eq 0 ]; then
    t_pass "$3"
  else
    t_fail "$3 FAILED. Ping said: $OUT"
  fi
}

# All seven computers must exist.
MISSING=""
for ns in home1 home2 homeweb guest1 hrouter prouter server; do
  ns_exists "$ns" || MISSING="$MISSING $ns"
done
if [ -z "$MISSING" ]; then
  t_pass "all seven namespaces exist"
else
  t_fail "these namespaces are missing:$MISSING. Run your addresses-and-routes.sh"
  t_done
fi

# The address plan.
if has_addr hrouter 192.168.1.1/24 && has_addr hrouter 192.168.50.1/24 && has_addr hrouter 198.51.100.2/30; then
  t_pass "hrouter has 192.168.1.1/24, 192.168.50.1/24 and 198.51.100.2/30"
else
  t_fail "hrouter should have 192.168.1.1/24, 192.168.50.1/24 and 198.51.100.2/30. Run: ip netns exec hrouter ip addr"
fi
if has_addr prouter 198.51.100.1/30 && has_addr prouter 203.0.113.1/24 && has_addr server 203.0.113.80/24; then
  t_pass "prouter has 198.51.100.1/30 and 203.0.113.1/24, and the server has 203.0.113.80/24"
else
  t_fail "prouter should have 198.51.100.1/30 and 203.0.113.1/24, and the server 203.0.113.80/24"
fi
if has_addr homeweb 192.168.1.20/24; then
  t_pass "homeweb has 192.168.1.20/24"
else
  t_fail "homeweb should have 192.168.1.20/24. Run: ip netns exec homeweb ip addr  (is the mask right?)"
fi
HOME1_ADDR="$(ip netns exec home1 ip -4 -o addr show 2>/dev/null | awk '$2 != "lo" && !done { sub(/\/.*/, "", $4); print $4; done = 1 }' || true)"
HOME2_ADDR="$(ip netns exec home2 ip -4 -o addr show 2>/dev/null | awk '$2 != "lo" && !done { sub(/\/.*/, "", $4); print $4; done = 1 }' || true)"
GUEST1_ADDR="$(ip netns exec guest1 ip -4 -o addr show 2>/dev/null | awk '$2 != "lo" && !done { sub(/\/.*/, "", $4); print $4; done = 1 }' || true)"
case "$HOME1_ADDR" in 192.168.1.*) ok1=1 ;; *) ok1=0 ;; esac
case "$HOME2_ADDR" in 192.168.1.*) ok2=1 ;; *) ok2=0 ;; esac
case "$GUEST1_ADDR" in 192.168.50.*) ok3=1 ;; *) ok3=0 ;; esac
if [ "$ok1" -eq 1 ] && [ "$ok2" -eq 1 ] && [ "$ok3" -eq 1 ]; then
  t_pass "home1 ($HOME1_ADDR) and home2 ($HOME2_ADDR) are on 192.168.1.0/24, guest1 ($GUEST1_ADDR) is on 192.168.50.0/24"
else
  t_fail "home1 and home2 need an address on 192.168.1.0/24 and guest1 one on 192.168.50.0/24. They have: '$HOME1_ADDR' '$HOME2_ADDR' '$GUEST1_ADDR'"
fi

# Forwarding is on in both routers.
HR_FWD="$(ip netns exec hrouter sysctl -n net.ipv4.ip_forward 2>/dev/null || echo unknown)"
PR_FWD="$(ip netns exec prouter sysctl -n net.ipv4.ip_forward 2>/dev/null || echo unknown)"
if [ "$HR_FWD" = "1" ] && [ "$PR_FWD" = "1" ]; then
  t_pass "forwarding is on in hrouter and prouter"
else
  t_fail "forwarding must be on in both routers. hrouter: $HR_FWD, prouter: $PR_FWD. Run: ip netns exec hrouter sysctl net.ipv4.ip_forward"
fi

# Every device reaches its own router.
ping_ok home1 192.168.1.1 "home1 reaches its router, 192.168.1.1"
ping_ok home2 192.168.1.1 "home2 reaches its router, 192.168.1.1"
ping_ok homeweb 192.168.1.1 "homeweb reaches its router, 192.168.1.1"
ping_ok guest1 192.168.50.1 "guest1 reaches its router, 192.168.50.1"

# The routers reach the devices and each other.
ping_ok hrouter 192.168.1.20 "hrouter reaches homeweb, 192.168.1.20"
ping_ok hrouter 198.51.100.1 "hrouter reaches prouter, 198.51.100.1"
ping_ok prouter 203.0.113.80 "prouter reaches the public server, 203.0.113.80"

# The home router reaches the public server through the provider router, and the server sees 198.51.100.2.
ping_ok hrouter 203.0.113.80 "hrouter reaches the public server, 203.0.113.80, through prouter"
try_curl hrouter http://203.0.113.80:8080/cgi-bin/whoami
if [ "$RC" -eq 0 ] && grep -q 'sees you as 198\.51\.100\.2:' <<< "$OUT"; then
  t_pass "the public server sees hrouter as 198.51.100.2"
else
  t_fail "the public server's page did not say 198.51.100.2 (curl exit $RC). Is the server's web server running? Curl said: $OUT"
fi
try_curl hrouter http://192.168.1.20/
if [ "$RC" -eq 0 ] && grep -q 'home web server' <<< "$OUT"; then
  t_pass "hrouter can read the home web server's page at 192.168.1.20:80"
else
  t_fail "hrouter cannot read http://192.168.1.20/ (curl exit $RC). Is the home web server running on port 80? Curl said: $OUT"
fi

# The routes pick the gateway.
ROUTE_HOME1="$(ip netns exec home1 ip route get 203.0.113.80 2>&1 || true)"
ROUTE_HROUTER="$(ip netns exec hrouter ip route get 203.0.113.80 2>&1 || true)"
if grep -q 'via 192\.168\.1\.1 ' <<< "$ROUTE_HOME1"; then
  t_pass "home1: the route to 203.0.113.80 goes via 192.168.1.1"
else
  t_fail "home1: ip route get 203.0.113.80 should say 'via 192.168.1.1'. It said: $ROUTE_HOME1"
fi
if grep -q 'via 198\.51\.100\.1 ' <<< "$ROUTE_HROUTER"; then
  t_pass "hrouter: the route to 203.0.113.80 goes via 198.51.100.1"
else
  t_fail "hrouter: ip route get 203.0.113.80 should say 'via 198.51.100.1'. It said: $ROUTE_HROUTER"
fi

# traceroute from the home router: the provider router, then the server.
TRACE="$(ip netns exec hrouter traceroute -n -w 1 -q 1 -m 5 203.0.113.80 2>&1 || true)"
HOP1="$(awk '$1 == 1 { print $2 }' <<< "$TRACE")"
HOP2="$(awk '$1 == 2 { print $2 }' <<< "$TRACE")"
if [ "$HOP1" = "198.51.100.1" ] && [ "$HOP2" = "203.0.113.80" ]; then
  t_pass "traceroute from hrouter shows 198.51.100.1, then 203.0.113.80"
else
  t_fail "traceroute from hrouter should show 198.51.100.1 then 203.0.113.80. It showed: $TRACE"
fi

# Must fail while there is no NAT: a private source address cannot get an answer from the public server.
RULESET="$(ip netns exec hrouter nft list ruleset 2>/dev/null || true)"
if grep -q 'masquerade' <<< "$RULESET"; then
  echo "NOTE hrouter already has a masquerade rule (part 2). The no-NAT checks are skipped."
else
  OUTSIDE_IF="$(if_with_addr hrouter 198.51.100.2)"
  if [ -n "$OUTSIDE_IF" ]; then
    timeout 8 ip netns exec hrouter tcpdump -n -U -i "$OUTSIDE_IF" -c 1 icmp > "$TMP/outside.txt" 2>&1 &
    CAPTURE_PID=$!
    sleep 1
    try_ping home1 203.0.113.80 2
    wait "$CAPTURE_PID" || true
    if [ "$RC" -ne 0 ] && grep -q ' 100% packet loss' <<< "$OUT"; then
      t_pass "no NAT yet: home1 gets no reply from 203.0.113.80 (100% loss), as it should"
    else
      t_fail "home1 should get no reply from 203.0.113.80 before NAT exists. Ping said: $OUT"
    fi
    if grep -qF "$HOME1_ADDR > 203.0.113.80: ICMP echo request" "$TMP/outside.txt"; then
      t_pass "the capture on $OUTSIDE_IF shows the private source $HOME1_ADDR leaving the home router"
    else
      t_fail "expected '$HOME1_ADDR > 203.0.113.80: ICMP echo request' on $OUTSIDE_IF. Capture was: $(cat "$TMP/outside.txt")"
    fi
  else
    t_fail "hrouter has no interface with 198.51.100.2, so the capture was skipped"
  fi
fi

t_done
