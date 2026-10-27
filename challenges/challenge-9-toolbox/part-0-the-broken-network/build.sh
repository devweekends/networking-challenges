#!/usr/bin/env bash
# Challenge 9, setup: build the lab network, with no faults.
# You do not need to run this yourself. faults.sh runs it first, and then plants the faults.
#   bash build.sh              build the network for round 1
#   bash build.sh --round 2    build the network for round 2 (the app moves to a new port)
# Safe to run again: it deletes the old network first.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
source "$HERE/seed.sh"
require_root

ROUND=1
if [ "${1:-}" = "--round" ]; then
  ROUND="${2:?--round needs 1 or 2}"
fi
SEED="$(ch9_seed)"
[ -n "$SEED" ] || SEED=default
ch9_values "$SEED" "$ROUND"

WWW="$CH9_STATE/www"
APP="$CH9_STATE/app"

# Step 1: delete anything this course built before.
teardown_all
rm -rf "$CH9_STATE"
mkdir -p "$CH9_STATE"

# Step 2: six computers. The laptop is on the campus network. r1 is the campus router.
# r2 is the provider's router. The server and a public DNS resolver sit behind r2.
for ns in laptop r1 r2 server dns; do
  ns_add "$ns"
  # IPv6 is switched off, so that captures hold only the IPv4 packets this challenge is about.
  in_ns "$ns" sysctl -qw net.ipv6.conf.all.disable_ipv6=1
done

# Step 3: the cables.
#   laptop 192.0.2.10 --- 192.0.2.1 r1 198.51.100.1 --- 198.51.100.2 r2 203.0.113.1 --+-- 203.0.113.80 server
#                                                                                     +-- 203.0.113.53 dns
cable_if laptop veth-laptop r1 veth-r1lan
cable_if r1 veth-r1wan r2 veth-r2wan
in_ns r2 ip link add br-srv type bridge
in_ns r2 ip link set br-srv up
cable_if server veth-server r2 veth-r2srv
cable_if dns veth-dns r2 veth-r2dns
in_ns r2 ip link set veth-r2srv master br-srv
in_ns r2 ip link set veth-r2dns master br-srv

# Step 4: addresses. All three ranges are reserved for examples (RFC 5737). No real computer uses them.
in_ns laptop ip addr add 192.0.2.10/24 dev veth-laptop
in_ns r1 ip addr add 192.0.2.1/24 dev veth-r1lan
in_ns r1 ip addr add 198.51.100.1/30 dev veth-r1wan
in_ns r2 ip addr add 198.51.100.2/30 dev veth-r2wan
in_ns r2 ip addr add 203.0.113.1/24 dev br-srv
in_ns server ip addr add 203.0.113.80/24 dev veth-server
in_ns dns ip addr add 203.0.113.53/24 dev veth-dns

# Step 5: routes and forwarding. No NAT: every address here is "public" in the lab.
in_ns laptop ip route add default via 192.0.2.1
in_ns r1 ip route add default via 198.51.100.2
in_ns r2 ip route add 192.0.2.0/24 via 198.51.100.1
in_ns server ip route add default via 203.0.113.1
in_ns dns ip route add default via 203.0.113.1
in_ns r1 sysctl -qw net.ipv4.ip_forward=1
in_ns r2 sysctl -qw net.ipv4.ip_forward=1

# Step 6: a clean baseline for mtr. A Linux router limits how often it sends "time exceeded" replies
# (net.ipv4.icmp_ratelimit, 1000 ms). mtr then shows false loss at that router. 0 switches the limit off.
# Part 3 switches it on again in r1 for one run, so you can see what a router limiting itself looks like.
in_ns r1 sysctl -qw net.ipv4.icmp_ratelimit=0
in_ns r2 sysctl -qw net.ipv4.icmp_ratelimit=0

# Step 7: the server. A web page on port 80, the app on its own port, and an iperf3 server on 5201.
www_make "$WWW" "lab web server"
www_make "$APP" "the app"
bg_start www server busybox httpd -f -p 80 -h "$WWW"
bg_start app server busybox httpd -f -p "$V_PORT" -h "$APP"
bg_start iperf3 server iperf3 -s

# Step 8: two DNS resolvers.
# The public resolver (dns, 203.0.113.53) knows the four lab names.
cat > "$CH9_STATE/public-dns.conf" <<EOF
# The public resolver. It knows the lab names and nothing else.
interface=veth-dns
bind-interfaces
no-resolv
no-hosts
user=root
# Two dnsmasq programs run in this lab. An empty pid-file stops them both from writing /var/run/dnsmasq.pid.
pid-file=
log-facility=-
log-queries
address=/www.lab.test/203.0.113.80
address=/shop.lab.test/203.0.113.80
address=/docs.lab.test/203.0.113.80
address=/news.lab.test/203.0.113.80
address=/mail.lab.test/203.0.113.80
EOF
# The campus resolver (r1, 192.0.2.1) is the one the laptop uses. It knows no names itself:
# it asks the public resolver and passes the answer on.
cat > "$CH9_STATE/campus-dns.conf" <<EOF
# The campus resolver. It forwards every question to the public resolver.
interface=veth-r1lan
bind-interfaces
no-resolv
no-hosts
user=root
# Two dnsmasq programs run in this lab. An empty pid-file stops them both from writing /var/run/dnsmasq.pid.
pid-file=
log-facility=-
log-queries
server=203.0.113.53
EOF
bg_start public-dns dns dnsmasq --keep-in-foreground --conf-file="$CH9_STATE/public-dns.conf"
bg_start campus-dns r1 dnsmasq --keep-in-foreground --conf-file="$CH9_STATE/campus-dns.conf"
# The laptop asks the campus resolver.
mkdir -p /etc/netns/laptop
echo "nameserver 192.0.2.1" > /etc/netns/laptop/resolv.conf

# Give the servers a moment to start.
sleep 1
for name in www app iperf3 public-dns campus-dns; do
  if ! kill -0 "$(cat "$NET_PID_DIR/$name.pid")" 2>/dev/null; then
    cat "$NET_PID_DIR/$name.log"
    die "$name stopped at once. Its message is above."
  fi
done
echo "$ROUND" > "$CH9_STATE/built-round"
echo "The lab network is built (round $ROUND). No faults yet."
