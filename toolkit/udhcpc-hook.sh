#!/bin/sh
# toolkit/udhcpc-hook.sh: applies a DHCP lease to an interface.
#
# Why this exists: the DHCP client in the lab (busybox udhcpc) finds a lease, but it does not
# put the address on the interface by itself. It calls a script and passes the lease in
# environment variables. This is that script.
#
# You do not run it yourself. The client runs it:
#   NS_NAME=laptop ip netns exec laptop busybox udhcpc -i veth-laptop -s "$(udhcpc_hook_path)" -n -q -t 5 -T 2
# (udhcpc_hook_path is a helper in lib.sh. It prints the path of a runnable copy of this file.)
#
# udhcpc gives this script one word in $1:
#   deconfig   a request starts, or a lease is lost: clear the interface
#   bound      a new lease: apply it
#   renew      the same lease again: apply it again
#   nak        the server said no
# and the lease in $interface, $ip, $subnet, $router, $dns and $lease.
# NS_NAME is our own variable. It is the name of the namespace, so we can write that
# namespace's resolver file, /etc/netns/NS_NAME/resolv.conf.

prefix_from_mask() {
  # 255.255.255.0 -> 24
  bits=0
  for octet in $(echo "$1" | tr '.' ' '); do
    case "$octet" in
      255) bits=$((bits + 8)) ;;
      254) bits=$((bits + 7)) ;;
      252) bits=$((bits + 6)) ;;
      248) bits=$((bits + 5)) ;;
      240) bits=$((bits + 4)) ;;
      224) bits=$((bits + 3)) ;;
      192) bits=$((bits + 2)) ;;
      128) bits=$((bits + 1)) ;;
    esac
  done
  echo "$bits"
}

case "$1" in
  deconfig)
    ip addr flush dev "$interface"
    ip link set dev "$interface" up
    ;;
  bound|renew)
    if [ -n "$subnet" ]; then
      prefix="$(prefix_from_mask "$subnet")"
    else
      prefix="${mask:-24}"
    fi
    ip addr flush dev "$interface"
    ip addr add "$ip/$prefix" dev "$interface"
    for gateway in $router; do
      ip route replace default via "$gateway" dev "$interface"
      break
    done
    if [ -n "$dns" ] && [ -n "$NS_NAME" ]; then
      mkdir -p "/etc/netns/$NS_NAME"
      : > "/etc/netns/$NS_NAME/resolv.conf"
      for server in $dns; do
        echo "nameserver $server" >> "/etc/netns/$NS_NAME/resolv.conf"
      done
    fi
    echo "lease applied: $ip/$prefix router=${router:-none} dns=${dns:-none} lease=${lease:-unknown}s"
    ;;
esac
exit 0
