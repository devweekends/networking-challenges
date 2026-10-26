#!/usr/bin/env bash
# Challenge 1, part 1: build two computers inside the lab and join them with a virtual cable.
# Run it in the lab:  bash cable.sh
# Safe to run again: it deletes the old network first.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

# Step 1: delete anything this course built before.
teardown_all

# Step 2: make two computers. Each one is a network namespace.
ns_add laptop
ns_add phone

# Step 3: make one virtual cable. It has two ends. Both ends start in the lab itself.
ip link add veth-laptop type veth peer name veth-phone

# Step 4: plug one end into each computer.
ip link set veth-laptop netns laptop
ip link set veth-phone netns phone

# Step 5: give each end an address. The /24 means the first three numbers name the network.
ip netns exec laptop ip addr add 192.168.1.10/24 dev veth-laptop
ip netns exec phone ip addr add 192.168.1.20/24 dev veth-phone

# Step 6: switch each end on.
ip netns exec laptop ip link set veth-laptop up
ip netns exec phone ip link set veth-phone up

# Step 7: look at the result.
ip netns exec laptop ip addr show dev veth-laptop
ip netns exec phone ip addr show dev veth-phone
echo "Done. Next: ip netns exec laptop ping -c2 -W1 192.168.1.20"
