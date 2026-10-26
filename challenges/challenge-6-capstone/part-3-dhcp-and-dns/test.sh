#!/usr/bin/env bash
# Test for challenge 6, part 3. Run it in the lab AFTER you ran your  bash dhcp-and-dns.sh
# Must pass: home1 and home2 have leases from the home pool, guest1 from the guest pool; each has the right
#   gateway and resolver; names work through dig and through curl; a brand-new device can still get a lease.
# Must fail on purpose: an unknown name gets no answer; with dnsmasq stopped, a new device gets no address
#   after about 3 seconds.
# The test adds two throwaway devices to the home network and removes them again.
# It stops dnsmasq for a moment and starts it again with your dnsmasq.conf. Your dnsmasq must be named "dnsmasq"
# in bg_start, and your config file must be the dnsmasq.conf next to this test.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

HOOK="$(udhcpc_hook_path)"
WHOAMI_BY_NAME=http://web.test:8080/cgi-bin/whoami

# lease_for NS REQUESTS SECONDS: ask for a lease on the namespace's first interface. Sets OUT and RC.
lease_for() {
  RC=0
  OUT="$(NS_NAME="$1" ip netns exec "$1" busybox udhcpc -i "$(first_if "$1")" -s "$HOOK" -n -q -t "$2" -T "$3" 2>&1)" || RC=$?
}

# addr_of NS: print the first IPv4 address of the namespace's first interface, with the prefix
addr_of() {
  local out
  out="$(ip netns exec "$1" ip -4 -o addr show dev "$(first_if "$1")" 2>/dev/null || true)"
  awk '$3 == "inet" && !done { print $4; done = 1 }' <<< "$out"
}

# in_pool ADDRESS/PREFIX THIRD_OCTET_PREFIX: true if the address is PREFIX.100 to PREFIX.150 with a /24 mask
in_pool() {
  local ip="${1%/*}" prefix="${1#*/}" last
  [ "$prefix" = "24" ] || return 1
  case "$ip" in
    "$2".*) last="${ip##*.}" ;;
    *) return 1 ;;
  esac
  [ "$last" -ge 100 ] && [ "$last" -le 150 ]
}

# add_device NAME MAC: a throwaway device on the home bridge, with a fixed hardware address and no IP address
add_device() {
  local bridge
  bridge="$(if_with_addr hrouter 192.168.1.1)"
  # Pin the bridge's own hardware address first. A bridge without one takes the lowest address of its
  # ports, so plugging a device in or out could change the router's address under the other devices.
  ip netns exec hrouter ip link set dev "$bridge" address "$(ip netns exec hrouter cat "/sys/class/net/$bridge/address")"
  ns_add "$1"
  cable_if "$1" "veth-$1" hrouter "veth-r$1"
  ip netns exec "$1" ip link set dev "veth-$1" down
  ip netns exec "$1" ip link set dev "veth-$1" address "$2"
  ip netns exec "$1" ip link set dev "veth-$1" up
  ip netns exec hrouter ip link set "veth-r$1" master "$bridge"
}

remove_device() {
  ip netns del "$1" 2>/dev/null || true
  rm -rf "/etc/netns/$1"
}

# All seven computers must exist.
MISSING=""
for ns in home1 home2 homeweb guest1 hrouter prouter server; do
  ns_exists "$ns" || MISSING="$MISSING $ns"
done
if [ -z "$MISSING" ]; then
  t_pass "all seven namespaces exist"
else
  t_fail "these namespaces are missing:$MISSING. Run your dhcp-and-dns.sh"
  t_done
fi

# dnsmasq must be running.
if [ -f "$NET_PID_DIR/dnsmasq.pid" ] && kill -0 "$(cat "$NET_PID_DIR/dnsmasq.pid")" 2>/dev/null; then
  t_pass "dnsmasq is running (started with bg_start dnsmasq)"
else
  t_fail "dnsmasq is not running, or was not started with: bg_start dnsmasq hrouter dnsmasq ... Log: $(cat "$NET_PID_DIR/dnsmasq.log" 2>/dev/null || echo none)"
fi

# Leases: home1 and home2 from the home pool, guest1 from the guest pool.
HOME1_ADDR="$(addr_of home1)"
HOME2_ADDR="$(addr_of home2)"
GUEST1_ADDR="$(addr_of guest1)"
if in_pool "$HOME1_ADDR" 192.168.1 && in_pool "$HOME2_ADDR" 192.168.1 && [ "$HOME1_ADDR" != "$HOME2_ADDR" ]; then
  t_pass "home1 has $HOME1_ADDR and home2 has $HOME2_ADDR, both in 192.168.1.100 to 192.168.1.150"
else
  t_fail "home1 and home2 need different leases in 192.168.1.100 to 192.168.1.150 (/24). They have '$HOME1_ADDR' and '$HOME2_ADDR'"
fi
if in_pool "$GUEST1_ADDR" 192.168.50; then
  t_pass "guest1 has $GUEST1_ADDR, in 192.168.50.100 to 192.168.50.150"
else
  t_fail "guest1 needs a lease in 192.168.50.100 to 192.168.50.150 (/24). It has '$GUEST1_ADDR'"
fi

# Each subnet's gateway and resolver came from the lease.
HOME1_DEFAULT="$(ip netns exec home1 ip route show default 2>/dev/null || true)"
GUEST1_DEFAULT="$(ip netns exec guest1 ip route show default 2>/dev/null || true)"
if grep -q 'default via 192.168.1.1' <<< "$HOME1_DEFAULT" && grep -q 'default via 192.168.50.1' <<< "$GUEST1_DEFAULT"; then
  t_pass "home1's gateway is 192.168.1.1 and guest1's is 192.168.50.1"
else
  t_fail "gateways: home1 should have 'default via 192.168.1.1' and guest1 'default via 192.168.50.1'. They have: '$HOME1_DEFAULT' and '$GUEST1_DEFAULT'"
fi
HOME1_RESOLV="$(cat /etc/netns/home1/resolv.conf 2>/dev/null || true)"
GUEST1_RESOLV="$(cat /etc/netns/guest1/resolv.conf 2>/dev/null || true)"
if grep -q '^nameserver 192.168.1.1$' <<< "$HOME1_RESOLV" && grep -q '^nameserver 192.168.50.1$' <<< "$GUEST1_RESOLV"; then
  t_pass "home1's resolver is 192.168.1.1 and guest1's is 192.168.50.1"
else
  t_fail "resolvers: /etc/netns/home1/resolv.conf should say 'nameserver 192.168.1.1' and guest1's 'nameserver 192.168.50.1'. They say: '$HOME1_RESOLV' and '$GUEST1_RESOLV'"
fi

# Names, by dig (asks one server) and by curl (uses the resolver file).
DIG_HOME="$(ip netns exec home1 dig +short +time=2 +tries=1 @192.168.1.1 web.test 2>&1 || true)"
DIG_GUEST="$(ip netns exec guest1 dig +short +time=2 +tries=1 @192.168.50.1 web.test 2>&1 || true)"
if [ "$DIG_HOME" = "203.0.113.80" ]; then
  t_pass "home1: dig @192.168.1.1 web.test returns 203.0.113.80"
else
  t_fail "home1: dig @192.168.1.1 web.test should return 203.0.113.80. It returned: $DIG_HOME"
fi
if [ "$DIG_GUEST" = "203.0.113.80" ]; then
  t_pass "guest1: dig @192.168.50.1 web.test returns 203.0.113.80 (the guest can ask the router for names)"
else
  t_fail "guest1: dig @192.168.50.1 web.test should return 203.0.113.80. It returned: $DIG_GUEST"
fi
for device in home1 guest1; do
  try_curl "$device" "$WHOAMI_BY_NAME"
  if [ "$RC" -eq 0 ] && grep -q 'sees you as 198\.51\.100\.2:' <<< "$OUT"; then
    t_pass "$device: curl http://web.test:8080/ works, and the server sees 198.51.100.2"
  else
    t_fail "$device: curl http://web.test:8080/ failed (exit $RC). Check the resolver file, the name, and NAT. Curl said: $OUT"
  fi
done

# Must fail: a name the router does not know gets no answer.
UNKNOWN="$(ip netns exec home1 dig +short +time=2 +tries=1 @192.168.1.1 nosuch.test 2>&1 || true)"
if [ -z "$UNKNOWN" ]; then
  t_pass "dig @192.168.1.1 nosuch.test returns no answer"
else
  t_fail "dig for nosuch.test should return no answer. It returned: $UNKNOWN"
fi

# A brand-new device can still get a lease. (If the pool is too small, it cannot.)
add_device tmpnew 02:00:00:00:99:01
lease_for tmpnew 5 2
NEW_ADDR="$(addr_of tmpnew)"
if [ "$RC" -eq 0 ] && in_pool "$NEW_ADDR" 192.168.1; then
  t_pass "a brand-new device gets a lease ($NEW_ADDR), so the home pool still has room"
else
  t_fail "a brand-new device could not get a lease (udhcpc exit $RC, address '$NEW_ADDR'). Is the home pool full? Look at dnsmasq's log: $(tail -n 3 "$NET_PID_DIR/dnsmasq.log" 2>/dev/null || true)"
fi
remove_device tmpnew

# Must fail: with dnsmasq stopped, a new device gets no address after about 3 seconds.
stop_proc dnsmasq
add_device tmpfail 02:00:00:00:99:02
STARTED=$SECONDS
lease_for tmpfail 3 1
TOOK=$((SECONDS - STARTED))
FAIL_ADDR="$(addr_of tmpfail)"
if [ "$RC" -ne 0 ] && [ -z "$FAIL_ADDR" ] && [ "$TOOK" -le 8 ]; then
  t_pass "with dnsmasq stopped, a new device gets no lease and ends with no address after about $TOOK seconds"
else
  t_fail "with dnsmasq stopped, a new device should end with no address. It exited $RC, has '$FAIL_ADDR', took $TOOK seconds"
fi
remove_device tmpfail

# Put dnsmasq back with your config, as your script left it.
bg_start dnsmasq hrouter dnsmasq --keep-in-foreground --conf-file="$HERE/dnsmasq.conf"
sleep 3
if kill -0 "$(cat "$NET_PID_DIR/dnsmasq.pid")" 2>/dev/null; then
  t_pass "dnsmasq is running again with your dnsmasq.conf"
else
  t_fail "dnsmasq did not start again. Log: $(cat "$NET_PID_DIR/dnsmasq.log" 2>/dev/null || echo none)"
fi

t_done
