#!/usr/bin/env bash
# Test for challenge 5, part 1. Run it in the lab AFTER you ran:  bash dhcp-dns.sh
# When a check fails, the message says which GAP to look at (dnsmasq.conf Gap 1 to 4, dhcp-dns.sh Gap 5).
# Must pass: the laptop and the phone have addresses from the pool, a gateway and a resolver file;
#   dig returns 203.0.113.80 for web.test; curl by name works.
# Must fail on purpose: nobody on the outside can ask the router for names; an unknown name gets no answer;
#   with dnsmasq stopped, a client ends with no address after about 3 seconds.
# The test stops dnsmasq for a moment and starts it again at the end.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

HOOK="$(udhcpc_hook_path)"

# lease_for NS IFACE REQUESTS SECONDS: ask for a lease. Sets OUT and RC.
lease_for() {
  RC=0
  OUT="$(NS_NAME="$1" ip netns exec "$1" busybox udhcpc -i "$2" -s "$HOOK" -n -q -t "$3" -T "$4" 2>&1)" || RC=$?
}

# address_of NS IFACE: print the IPv4 address with its prefix, or nothing
address_of() {
  local out
  out="$(ip netns exec "$1" ip -4 -o addr show dev "$2" 2>/dev/null || true)"
  awk '$3 == "inet" && !done { print $4; done = 1 }' <<< "$out"
}

# in_pool ADDRESS_WITH_PREFIX: true if it is 192.168.1.100 to 192.168.1.150 with a /24 mask
in_pool() {
  local ip="${1%/*}" prefix="${1#*/}" last
  [ "$prefix" = "24" ] || return 1
  case "$ip" in
    192.168.1.*) last="${ip##*.}" ;;
    *) return 1 ;;
  esac
  [ "$last" -ge 100 ] && [ "$last" -le 150 ]
}

# The four computers must exist.
if ns_exists laptop && ns_exists phone && ns_exists router && ns_exists server; then
  t_pass "namespaces laptop, phone, router and server exist"
else
  t_fail "namespaces are missing. Run: bash dhcp-dns.sh"
  t_done
fi

# dnsmasq must be running.
if [ -f "$NET_PID_DIR/dnsmasq.pid" ] && kill -0 "$(cat "$NET_PID_DIR/dnsmasq.pid")" 2>/dev/null; then
  t_pass "dnsmasq is running in the router"
else
  t_fail "dnsmasq is not running. Run bash dhcp-dns.sh again. Its log: $(cat "$NET_PID_DIR/dnsmasq.log" 2>/dev/null || echo none)"
fi

# Gap 1 and 2: the laptop and the phone got addresses from the pool.
LAPTOP_ADDR="$(address_of laptop veth-laptop)"
PHONE_ADDR="$(address_of phone veth-phone)"
if [ -z "$LAPTOP_ADDR" ]; then
  t_fail "the laptop has no address. Check dnsmasq.conf Gap 1 (interface) and Gap 2 (dhcp-range), and Gap 5 (the client command in dhcp-dns.sh). dnsmasq log: $(tail -n 5 "$NET_PID_DIR/dnsmasq.log" 2>/dev/null || true)"
elif in_pool "$LAPTOP_ADDR"; then
  t_pass "GAP 2: the laptop has $LAPTOP_ADDR, inside the pool 192.168.1.100 to 192.168.1.150"
else
  t_fail "GAP 2: the laptop has $LAPTOP_ADDR. It should be 192.168.1.100 to 192.168.1.150 with a /24 mask. Check dnsmasq.conf Gap 2"
fi
if [ -z "$PHONE_ADDR" ]; then
  t_fail "the phone has no address. The laptop worked? Then run bash dhcp-dns.sh again and read the output for the phone"
elif in_pool "$PHONE_ADDR" && [ "$PHONE_ADDR" != "$LAPTOP_ADDR" ]; then
  t_pass "the phone has $PHONE_ADDR, a different address from the laptop"
else
  t_fail "the phone has $PHONE_ADDR. It should be in the pool and different from the laptop's $LAPTOP_ADDR"
fi

# Gap 3: the lease carried the router address, so the laptop has a default route.
LAPTOP_DEFAULT="$(ip netns exec laptop ip route show default 2>/dev/null || true)"
if grep -q 'default via 192.168.1.1' <<< "$LAPTOP_DEFAULT"; then
  t_pass "GAP 3: the laptop has a default route via 192.168.1.1, from the lease"
else
  t_fail "GAP 3: the laptop has no default route via 192.168.1.1. The lease should carry the router option. Check dnsmasq.conf Gap 3"
fi

# Gap 3: the lease carried the DNS server, so the hook wrote the laptop's resolver file.
RESOLV="$(cat /etc/netns/laptop/resolv.conf 2>/dev/null || true)"
if grep -q '^nameserver 192.168.1.1$' <<< "$RESOLV"; then
  t_pass "GAP 3: /etc/netns/laptop/resolv.conf says nameserver 192.168.1.1, from the lease"
else
  t_fail "GAP 3: /etc/netns/laptop/resolv.conf has no 'nameserver 192.168.1.1'. The lease should carry the dns-server option. Check dnsmasq.conf Gap 3. The file has: $RESOLV"
fi

# Gap 4: the name web.test.
DIG="$(ip netns exec laptop dig +short +time=2 +tries=1 @192.168.1.1 web.test 2>&1 || true)"
if [ "$DIG" = "203.0.113.80" ]; then
  t_pass "GAP 4: dig @192.168.1.1 web.test returns 203.0.113.80"
else
  t_fail "GAP 4: dig @192.168.1.1 web.test should return 203.0.113.80. It returned: $DIG"
fi

# Must pass: curl by name uses the resolver file, and the server sees the router's outside address.
try_curl laptop http://web.test:8080/cgi-bin/whoami
if [ "$RC" -eq 0 ] && grep -q 'sees you as 203\.0\.113\.1:' <<< "$OUT"; then
  t_pass "curl http://web.test:8080/ works from the laptop, and the server sees 203.0.113.1"
else
  t_fail "curl http://web.test:8080/ failed (exit $RC). Check the resolver file and Gap 4. Curl said: $OUT"
fi

# Must fail: the router must not answer name questions on its outside plug.
OUTSIDE_DIG="$(ip netns exec server dig +short +time=2 +tries=1 @203.0.113.1 web.test 2>&1 || true)"
if grep -q '203\.0\.113\.80' <<< "$OUTSIDE_DIG"; then
  t_fail "GAP 1: the server, on the outside, got an answer for web.test from 203.0.113.1. dnsmasq listens on the outside too. Set interface= to the inside bridge only"
else
  t_pass "the server cannot ask the router for names on 203.0.113.1, as it should"
fi

# Must fail: a name the router does not know gets no answer.
UNKNOWN="$(ip netns exec laptop dig +short +time=2 +tries=1 @192.168.1.1 nosuch.test 2>&1 || true)"
if [ -z "$UNKNOWN" ]; then
  t_pass "dig @192.168.1.1 nosuch.test returns no answer"
else
  t_fail "dig for nosuch.test should return no answer. It returned: $UNKNOWN"
fi

# Your capture, written by the script.
if [ -s "$HERE/dhcp-capture.txt" ] && [ "$(grep -c 'BOOTP/DHCP' "$HERE/dhcp-capture.txt" || true)" -ge 4 ]; then
  t_pass "dhcp-capture.txt holds four DHCP packets"
else
  t_fail "dhcp-capture.txt should hold four BOOTP/DHCP lines. Run bash dhcp-dns.sh again. It has: $(cat "$HERE/dhcp-capture.txt" 2>/dev/null || echo nothing)"
fi

# Must fail: with dnsmasq stopped, a client gets no address. The client gives up after about 3 seconds.
stop_proc dnsmasq
ip netns exec phone ip addr flush dev veth-phone
STARTED=$SECONDS
lease_for phone veth-phone 3 1
TOOK=$((SECONDS - STARTED))
PHONE_NOW="$(address_of phone veth-phone)"
if [ "$RC" -ne 0 ] && [ -z "$PHONE_NOW" ] && [ "$TOOK" -le 8 ]; then
  t_pass "with dnsmasq stopped, the phone gets no lease and ends with no address after about $TOOK seconds"
else
  t_fail "with dnsmasq stopped, the phone should end with no address. It exited $RC, has '$PHONE_NOW', took $TOOK seconds. Output: $OUT"
fi

# Put dnsmasq and the phone's lease back, as the script left them.
rm -f /tmp/networking-course-dnsmasq.leases
bg_start dnsmasq router dnsmasq --keep-in-foreground --conf-file="$HERE/dnsmasq.conf"
sleep 3
lease_for phone veth-phone 5 2
if [ "$RC" -eq 0 ]; then
  t_pass "dnsmasq is back and the phone has a lease again"
else
  t_fail "dnsmasq did not come back. Output: $OUT"
fi

t_done
