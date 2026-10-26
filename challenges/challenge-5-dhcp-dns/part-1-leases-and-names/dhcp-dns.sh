#!/usr/bin/env bash
# Challenge 5, part 1: DHCP and DNS on your router.
# Run it in the lab:  bash dhcp-dns.sh
# Safe to run again: it deletes the old network first.
# Most of the work is in dnsmasq.conf (four gaps). One more gap is in this script: the DHCP client command.
# The script writes dhcp-capture.txt next to itself. The test reads it.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

WWW=/tmp/networking-course-www-server
LEASES=/tmp/networking-course-dnsmasq.leases

# Step 1: delete anything this course built before.
teardown_all

# Step 2: the home router from challenge 4. You built this already, so it is given.
# The difference: the laptop and the phone get NO address. DHCP will give them one.
ns_add laptop
ns_add phone
ns_add router
ns_add server
in_ns router ip link add br-home type bridge
in_ns router ip link set br-home up
cable_if laptop veth-laptop router veth-rlaptop
cable_if phone veth-phone router veth-rphone
in_ns router ip link set veth-rlaptop master br-home
in_ns router ip link set veth-rphone master br-home
in_ns router ip addr add 192.168.1.1/24 dev br-home
cable_if router veth-rout server veth-server
in_ns router ip addr add 203.0.113.1/24 dev veth-rout
in_ns server ip addr add 203.0.113.80/24 dev veth-server
in_ns router sysctl -w net.ipv4.ip_forward=1 > /dev/null
in_ns router nft -f - <<'RULES'
table ip nat {
  chain postrouting {
    type nat hook postrouting priority 100 ; policy accept ;
    oifname "veth-rout" masquerade
  }
}
RULES
www_make "$WWW" "public web server"
bg_start server-web server busybox httpd -f -p 0.0.0.0:8080 -h "$WWW"

# Step 3: start dnsmasq inside the router, with the config file next to this script.
# --keep-in-foreground lets bg_start run it in the background and remember it under the name "dnsmasq".
rm -f "$LEASES"
bg_start dnsmasq router dnsmasq --keep-in-foreground --conf-file="$HERE/dnsmasq.conf"
# dnsmasq needs a few seconds before the first client asks. Without the wait, the first requests often get no answer.
sleep 3
if ! kill -0 "$(cat "$NET_PID_DIR/dnsmasq.pid")" 2>/dev/null; then
  echo "dnsmasq stopped at once. Its message was:"
  cat "$NET_PID_DIR/dnsmasq.log"
  echo "Look at dnsmasq.conf. A line may be wrong."
  exit 1
fi
echo "dnsmasq is running."

# Step 4: the DHCP client. busybox udhcpc finds a lease but does not apply it by itself.
# It runs a hook script that sets the address, the default route and the resolver file.
# udhcpc_hook_path prints the path of toolkit/udhcpc-hook.sh (a runnable copy).
HOOK="$(udhcpc_hook_path)"

# get_lease NAMESPACE INTERFACE: ask the DHCP server for an address and apply it
get_lease() {
  local ns="$1" iface="$2"
  # TODO 5: Run the DHCP client busybox udhcpc inside the computer NS, on the plug IFACE. It needs:
  #     -i INTERFACE   the plug to configure
  #     -s "$HOOK"     the script that applies the lease
  #     -n             give up if there is no lease (do not keep trying in the background)
  #     -q             quit as soon as the lease is applied
  #     -t 5 -T 2      send up to 5 requests, 2 seconds apart (dnsmasq can be slow to answer the first one)
  #   The hook also needs the computer's name, to write its resolver file. Put NS_NAME="$ns" in front of the command.
  #   Shape: NS_NAME="$ns" ip netns exec "$ns" busybox udhcpc -i "$iface" -s "$HOOK" -n -q -t 5 -T 2
}

echo "--- the laptop and the phone ask for addresses"
get_lease laptop veth-laptop || echo "(the laptop got no lease. Look at dnsmasq.conf Gap 1 and Gap 2, and at Gap 5)"
get_lease phone veth-phone || echo "(the phone got no lease)"

for device in laptop phone; do
  echo "--- $device"
  in_ns "$device" ip -4 -o addr show dev "veth-$device"
  in_ns "$device" ip route
  cat "/etc/netns/$device/resolv.conf" 2>/dev/null || echo "(no resolver file yet)"
done

# Step 5: names. dig @ADDRESS asks that one server. curl uses the computer's own resolver file,
# which the lease filled in (/etc/netns/laptop/resolv.conf).
echo "--- dig asks the router directly: web.test"
in_ns laptop dig +short +time=2 +tries=1 @192.168.1.1 web.test || true
echo "--- dig asks about a name the router does not know"
in_ns laptop dig +time=2 +tries=1 @192.168.1.1 nosuch.test | grep 'status:' || true
echo "--- curl uses the resolver file from the lease"
in_ns laptop curl -sS -m 3 http://web.test:8080/cgi-bin/whoami || echo "(failed. Check dnsmasq.conf Gap 3 and Gap 4)"

# Step 6: one lease on camera. The phone asks again while tcpdump listens to ports 67 (server) and 68 (client).
# -v makes tcpdump print the DHCP message type. -c 4 stops after four packets: discover, offer, request, ack.
echo "--- one lease on camera"
timeout 15 ip netns exec router tcpdump -n -v -i br-home -c 4 'port 67 or port 68' > "$HERE/dhcp-capture.txt" 2>&1 &
sleep 1
get_lease phone veth-phone > /dev/null 2>&1 || echo "(the phone got no lease)"
sleep 2
grep -E 'BOOTP/DHCP|Message' "$HERE/dhcp-capture.txt" || true

echo "Done. Next: bash test.sh"
