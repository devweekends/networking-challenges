#!/usr/bin/env bash
# Restore: the network from the end of challenge 6, part 1 (addresses and routes).
# This is the course's reference build, the answer. Use it only after you have tried the part yourself.
# If you use it, say so in your capstone demo.
# Run it with:  bash /work/toolkit/restore.sh 6.1
# It is a copy of the reference addresses-and-routes.sh. It builds the whole capstone network, without NAT, DHCP or DNS:
#
#   home1 home2 homeweb --- br-home 192.168.1.1  [ hrouter ]  198.51.100.2/30 -- 198.51.100.1 [ prouter ] 203.0.113.1 -- 203.0.113.80 server
#   guest1 ---------------- veth-hguest 192.168.50.1 [ hrouter ]
#
# It deletes the old network first, so it is safe to run again.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../lib.sh"
require_root

PUBLIC_WWW=/tmp/networking-course-www-public
HOME_WWW=/tmp/networking-course-www-homeweb

teardown_all

# Seven computers. A router is a computer too.
ns_add home1
ns_add home2
ns_add homeweb
ns_add guest1
ns_add hrouter
ns_add prouter
ns_add server

# The home LAN: a bridge in the home router, with three devices plugged into it.
in_ns hrouter ip link add br-home type bridge
in_ns hrouter ip link set br-home up
cable_if home1 veth-home1 hrouter veth-rhome1
cable_if home2 veth-home2 hrouter veth-rhome2
cable_if homeweb veth-homeweb hrouter veth-rhomeweb
in_ns hrouter ip link set veth-rhome1 master br-home
in_ns hrouter ip link set veth-rhome2 master br-home
in_ns hrouter ip link set veth-rhomeweb master br-home

# The guest LAN: its own cable and its own subnet.
cable_if guest1 veth-guest1 hrouter veth-hguest

# The home router to the provider router: a tiny /30 subnet, two usable addresses.
cable_if hrouter veth-hout prouter veth-pin

# The provider router to the public web server.
cable_if prouter veth-pout server veth-server

# Addresses. Every link has its own subnet.
in_ns hrouter ip addr add 192.168.1.1/24 dev br-home
in_ns hrouter ip addr add 192.168.50.1/24 dev veth-hguest
in_ns hrouter ip addr add 198.51.100.2/30 dev veth-hout
in_ns prouter ip addr add 198.51.100.1/30 dev veth-pin
in_ns prouter ip addr add 203.0.113.1/24 dev veth-pout
in_ns server ip addr add 203.0.113.80/24 dev veth-server

# Static placeholders for the devices. Part 3 replaces the two laptops' and the guest's addresses with leases.
in_ns homeweb ip addr add 192.168.1.20/24 dev veth-homeweb
in_ns home1 ip addr add 192.168.1.30/24 dev veth-home1
in_ns home2 ip addr add 192.168.1.31/24 dev veth-home2
in_ns guest1 ip addr add 192.168.50.30/24 dev veth-guest1

# Routes. Each device sends everything else to its router. The home router sends everything else to the
# provider router. The server sends everything else to the provider router, so it can answer 198.51.100.2.
# The provider router needs no extra route: it is connected to every subnet it forwards between.
in_ns homeweb ip route add default via 192.168.1.1
in_ns home1 ip route add default via 192.168.1.1
in_ns home2 ip route add default via 192.168.1.1
in_ns guest1 ip route add default via 192.168.50.1
in_ns hrouter ip route add default via 198.51.100.1
in_ns server ip route add default via 203.0.113.1

# Both routers forward.
in_ns hrouter sysctl -qw net.ipv4.ip_forward=1
in_ns prouter sysctl -qw net.ipv4.ip_forward=1

# The two web servers. The public one tells a visitor the address and port it sees.
# The home one is a static page.
www_make "$PUBLIC_WWW" "public web server"
www_make "$HOME_WWW" "home web server"
bg_start server-web server busybox httpd -f -p 0.0.0.0:8080 -h "$PUBLIC_WWW"
bg_start homeweb-web homeweb busybox httpd -f -p 0.0.0.0:80 -h "$HOME_WWW"
sleep 1

echo "--- hrouter routes"
in_ns hrouter ip route
echo "--- home1: how to reach the server"
in_ns home1 ip route get 203.0.113.80
echo "--- hrouter: how to reach the server"
in_ns hrouter ip route get 203.0.113.80
echo "Done. Next: bash test.sh"
