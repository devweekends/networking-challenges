#!/usr/bin/env bash
# Restore: the network from the end of challenge 2, part 1 (two subnets and a router).
# This is the course's reference build, the answer. Use it only after you have tried the part yourself.
# If you use it, say so in your capstone demo.
# Run it with:  bash /work/toolkit/restore.sh 2.1
# It is a copy of the reference router.sh. It deletes the old network first, so it is safe to run again.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../lib.sh"
require_root

# Step 1: delete anything this course built before.
teardown_all

# Step 2: make three computers. The router is a computer too.
ns_add laptop
ns_add router
ns_add server

# Step 3: make two cables. The router sits between them and has two plugs.
# cable_if lets us choose the name of each end: veth-rin is the router's inside plug, veth-rout is its outside plug.
cable_if laptop veth-laptop router veth-rin
cable_if router veth-rout server veth-server

# Step 4: give every plug an address. There are two networks:
#   192.168.1.0/24   the home side (laptop and the router's inside plug)
#   203.0.113.0/24   the "internet" side (the server and the router's outside plug)
# The router has one address on each network. That is what makes it a router.
in_ns laptop ip addr add 192.168.1.23/24 dev veth-laptop
in_ns router ip addr add 192.168.1.1/24 dev veth-rin
in_ns router ip addr add 203.0.113.1/24 dev veth-rout
in_ns server ip addr add 203.0.113.80/24 dev veth-server

# Step 5: the mid-point check. Each side can reach its own router. No gap is needed for this.
in_ns laptop ping -c1 -W1 192.168.1.1
in_ns server ping -c1 -W1 203.0.113.1

# Step 6: the three things that make the packets cross the router.
# Gap 1: The laptop does not know where to send a packet for another network, so today it says "Network is unreachable".
#   Add a default route to the laptop: "everything that is not on my own network goes to the router".
#   The router's address on the laptop's side is 192.168.1.1.
#   Shape of the command: ip route add default via ROUTER_ADDRESS   (run it inside the laptop, with in_ns)
in_ns laptop ip route add default via 192.168.1.1

# Gap 2: A Linux computer throws away packets that are addressed to someone else. A router must pass them on.
#   Switch forwarding on, inside the router only. The setting is net.ipv4.ip_forward and 1 means on.
#   Shape of the command: sysctl -w SETTING=VALUE   (run it inside the router, with in_ns)
in_ns router sysctl -w net.ipv4.ip_forward=1

# Gap 3: The server gets the laptop's ping, but its answer has no way back: the server has never heard of 192.168.1.0/24.
#   Add a route to the server for the home network, through the router's address on the server's side (203.0.113.1).
#   Shape of the command: ip route add NETWORK via ROUTER_ADDRESS   (run it inside the server, with in_ns)
in_ns server ip route add 192.168.1.0/24 via 203.0.113.1

# Step 7: look at the result.
in_ns laptop ip route
in_ns router ip route
in_ns server ip route
in_ns laptop ping -c2 -W1 203.0.113.80 || echo "That ping failed. Run: bash test.sh. It names the gap that is wrong."
echo "Done. Next: bash test.sh"
