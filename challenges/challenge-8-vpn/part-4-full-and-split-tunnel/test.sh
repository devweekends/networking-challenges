#!/usr/bin/env bash
# Test for challenge 8, part 4. Run it in the lab AFTER you ran:  bash full-split.sh
# When a check fails, the message says which GAP in full-split.sh to look at.
# Must pass: with the full tunnel the website sees the office (203.0.113.2) and the cafe's outside plug
#   carries only UDP 51820; DNS goes to the cafe in the clear until it is pointed at 10.20.0.1, and then
#   it travels inside wg0; with the split tunnel the website sees the cafe again and the office is still reachable.
# Must fail on purpose: in the split tunnel, the website must NOT see the office address.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

WHOAMI=http://192.0.2.80/cgi-bin/whoami

packet_lines() {
  grep -E '^[0-9]{2}:[0-9]{2}:[0-9]{2}\.' "$1" 2>/dev/null || true
}

# The network from parts 1 and 2, with the tunnel up.
if ns_exists laptop && ns_exists caferouter && ns_exists vpnbox && ns_exists officert; then
  t_pass "the namespaces exist"
else
  t_fail "the namespaces are missing. Run: bash full-split.sh"
  t_done
fi
try_ping laptop 10.20.0.5 2
if [ "$RC" -eq 0 ]; then
  t_pass "mid-point: the tunnel works (the laptop reaches 10.20.0.5)"
else
  t_fail "mid-point: the laptop cannot reach 10.20.0.5. Check GAP 5 (the split tunnel), or make part 2's test pass first. Ping said: $OUT"
fi

# The two name servers (given).
CAFE_ANS="$(ip netns exec laptop dig +short +time=2 +tries=1 @192.168.50.1 web.test 2>/dev/null || true)"
OFFICE_ANS="$(ip netns exec vpnbox dig +short +time=2 +tries=1 @10.20.0.1 intranet.test 2>/dev/null || true)"
if [ "$CAFE_ANS" = "192.0.2.80" ] && [ "$OFFICE_ANS" = "10.20.0.5" ]; then
  t_pass "the cafe's name server (192.168.50.1) and the office's (10.20.0.1) both answer"
else
  t_fail "a name server does not answer. Cafe said '$CAFE_ANS', office said '$OFFICE_ANS'. Look at the dnsmasq logs in $NET_PID_DIR"
fi

# Before the full tunnel.
if grep -q 'sees you as 198\.51\.100\.2:' "$HERE/website-before.txt" 2>/dev/null; then
  t_pass "website-before.txt: before the full tunnel, the website sees the cafe, 198.51.100.2"
else
  t_fail "website-before.txt should say the website sees 198.51.100.2. Run bash full-split.sh again"
fi

# Gap 1: the endpoint stays outside the tunnel.
if grep -q '^203\.0\.113\.2 via 192\.168\.50\.1' "$HERE/routes-full.txt" 2>/dev/null; then
  t_pass "GAP 1: in the full tunnel, 203.0.113.2/32 goes via the cafe router, outside the tunnel"
else
  t_fail "GAP 1: routes-full.txt has no route '203.0.113.2 via 192.168.50.1'. Without it, the tunnel's own packets go into the tunnel"
fi

# Gap 2: everything into the tunnel.
if grep -q '^default dev wg0' "$HERE/routes-full.txt" 2>/dev/null && grep -q '0\.0\.0\.0/0' "$HERE/routes-full.txt" 2>/dev/null; then
  t_pass "GAP 2: in the full tunnel, the default route is wg0 and allowed-ips is 0.0.0.0/0"
else
  t_fail "GAP 2: routes-full.txt should show 'default dev wg0' and allowed-ips 0.0.0.0/0. It shows: '$(grep '^default' "$HERE/routes-full.txt" 2>/dev/null | head -n 1)' and '$(tail -n 1 "$HERE/routes-full.txt" 2>/dev/null | cut -f2)'"
fi

# Gap 3: the way back, on the office router.
BACK="$(ip netns exec officert ip route get 10.99.0.2 2>/dev/null || true)"
if grep -q 'via 10\.20\.0\.2' <<< "$BACK"; then
  t_pass "GAP 3: the office router sends 10.99.0.2 back via the VPN box, 10.20.0.2"
else
  t_fail "GAP 3: the office router sends 10.99.0.2 the wrong way: '$BACK'. It needs a route to 10.99.0.0/24 via 10.20.0.2"
fi

# Must pass: the website sees the office in the full tunnel.
FULL_OK=0
if grep -q 'sees you as 203\.0\.113\.2:' "$HERE/website-full.txt" 2>/dev/null; then
  FULL_OK=1
  t_pass "website-full.txt: with the full tunnel, the website sees the office, 203.0.113.2"
elif grep -q 'sees you as 198\.51\.100\.2:' "$HERE/website-full.txt" 2>/dev/null; then
  t_fail "website-full.txt: the website still sees the cafe, 198.51.100.2. The traffic did not go into the tunnel. Check GAP 2"
else
  t_fail "website-full.txt: the laptop got no page in the full tunnel: '$(cat "$HERE/website-full.txt" 2>/dev/null)'. Check GAP 1 and GAP 3"
fi
if [ "$FULL_OK" -eq 1 ]; then
  LINES="$(packet_lines "$HERE/cafe-outside-full.txt")"
  if [ -n "$LINES" ] && ! grep -v '\.51820 > [0-9.]*\.51820: UDP' <<< "$LINES" | grep -q .; then
    t_pass "cafe-outside-full.txt: in the full tunnel, the cafe sees only UDP 51820, even for the website"
  else
    t_fail "cafe-outside-full.txt should hold only UDP 51820 lines. It has: $(grep -v '\.51820 > [0-9.]*\.51820: UDP' <<< "$LINES" | head -n 2 | tr '\n' ' ')"
  fi
fi

# DNS in the full tunnel: still to the cafe, in the clear.
if packet_lines "$HERE/dns-cafe.txt" | grep -q '192\.168\.50\.23\.[0-9]* > 192\.168\.50\.1\.53: .* A? web\.test'; then
  t_pass "dns-cafe.txt: in the full tunnel the question for web.test still went to the cafe, in the clear"
else
  t_fail "dns-cafe.txt should show the laptop asking 192.168.50.1 for web.test. Run bash full-split.sh again. It has: $(packet_lines "$HERE/dns-cafe.txt" | head -n 2 | tr '\n' ' ')"
fi

# Gap 4: DNS through the tunnel.
RESOLV="$(cat /etc/netns/laptop/resolv.conf 2>/dev/null || true)"
if grep -q '^nameserver 10\.20\.0\.1' <<< "$RESOLV"; then
  t_pass "GAP 4: the laptop's name server is 10.20.0.1, through the tunnel"
else
  t_fail "GAP 4: /etc/netns/laptop/resolv.conf should say 'nameserver 10.20.0.1'. It says: '$RESOLV'"
fi
if packet_lines "$HERE/dns-tunnel.txt" | grep -q '10\.99\.0\.2\.[0-9]* > 10\.20\.0\.1\.53: .* A? web\.test'; then
  t_pass "GAP 4: dns-tunnel.txt shows the question for web.test inside wg0, from 10.99.0.2 to 10.20.0.1"
else
  t_fail "GAP 4: dns-tunnel.txt should show '10.99.0.2.PORT > 10.20.0.1.53: ... A? web.test'. Check GAP 4 and GAP 3"
fi
if [ -f "$HERE/dns-cafe-after.txt" ] && ! packet_lines "$HERE/dns-cafe-after.txt" | grep -q '\.53: '; then
  t_pass "GAP 4: dns-cafe-after.txt: after the change, the cafe's inside plug carries no DNS"
else
  t_fail "GAP 4: dns-cafe-after.txt should have no DNS lines. The laptop still asks the cafe. Check GAP 4"
fi

# Gap 5: the split tunnel, live.
if [ "$FULL_OK" -ne 1 ]; then
  t_fail "GAP 5: make the full tunnel work first (GAP 1 to GAP 3). Then split it"
else
  ALLOWED="$(ip netns exec laptop wg show wg0 allowed-ips 2>/dev/null | cut -f2)"
  DEFAULT="$(ip netns exec laptop ip route show default 2>/dev/null || true)"
  if ! grep -q '0\.0\.0\.0/0' <<< "$ALLOWED" && grep -q '10\.20\.0\.0/24' <<< "$ALLOWED" && grep -q 'default via 192\.168\.50\.1' <<< "$DEFAULT"; then
    t_pass "GAP 5: split tunnel: allowed-ips '$ALLOWED', and the default route goes via 192.168.50.1"
  else
    t_fail "GAP 5: for the split tunnel, allowed-ips should be 10.20.0.0/24 10.99.0.1/32 (they are '$ALLOWED') and the default route via 192.168.50.1 (it is '$DEFAULT')"
  fi
  try_curl laptop "$WHOAMI"
  if [ "$RC" -eq 0 ] && grep -q 'sees you as 198\.51\.100\.2:' <<< "$OUT"; then
    t_pass "GAP 5: split tunnel: the website sees the cafe again, 198.51.100.2, not the office"
  else
    t_fail "GAP 5: split tunnel: the website should see 198.51.100.2. Curl exit $RC: $OUT"
  fi
  LINES="$(packet_lines "$HERE/cafe-outside-split.txt")"
  if grep -q '198\.51\.100\.2\.[0-9]* > 192\.0\.2\.80\.80: Flags \[S\]' <<< "$LINES" && grep -q '\.51820 > 203\.0\.113\.2\.51820: UDP' <<< "$LINES"; then
    t_pass "cafe-outside-split.txt: the website visit is plain TCP at the cafe, and the office ping is UDP 51820"
  else
    t_fail "cafe-outside-split.txt should show TCP to 192.0.2.80.80 and UDP 51820 to the office. Check GAP 5"
  fi
fi

t_done
