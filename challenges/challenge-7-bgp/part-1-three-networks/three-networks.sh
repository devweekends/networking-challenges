#!/usr/bin/env bash
# Challenge 7, part 1: three networks that talk BGP.
# Run it in the lab:  bash three-networks.sh
# Safe to run again: it stops the old BIRD programs and deletes the old network first.
# Part 2 runs this script to build the same three networks.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

# wait_until SECONDS COMMAND...: run COMMAND every half second until it works, or until SECONDS have passed.
wait_until() {
  local end=$((SECONDS + $1))
  shift
  until "$@" > /dev/null 2>&1; do
    [ "$SECONDS" -lt "$end" ] || return 1
    sleep 0.5
  done
}
# established ROUTER SESSION: true when that BGP session is up and talking.
established() { birdc -s "/tmp/bird-$1.ctl" show protocols "$2" | grep -q Established; }
# has_route ROUTER BLOCK: true when Linux in ROUTER has a route for BLOCK.
has_route() { ip netns exec "$1" ip route show "$2" | grep -q .; }

# Step 1: delete anything this course built before. This also stops old BIRD programs.
teardown_all

# Step 2: three routers. Each one plays a whole network, an autonomous system (AS).
ns_add r1
ns_add r2
ns_add r3

# Step 3: two cables, in a line: r1 -- r2 -- r3. Each cable is its own small network.
cable_if r1 veth-to-r2 r2 veth-to-r1
cable_if r2 veth-to-r3 r3 veth-to-r2
in_ns r1 ip addr add 10.0.12.1/24 dev veth-to-r2
in_ns r2 ip addr add 10.0.12.2/24 dev veth-to-r1
in_ns r2 ip addr add 10.0.23.2/24 dev veth-to-r3
in_ns r3 ip addr add 10.0.23.3/24 dev veth-to-r2

# Step 4: every router may pass on packets that are not for itself.
for r in r1 r2 r3; do
  in_ns "$r" sysctl -qw net.ipv4.ip_forward=1
done

# Step 5: r1 and r3 each own a block of addresses. A dummy interface holds the first address
# of the block. It plays a server inside that network.
in_ns r1 ip link add dummy0 type dummy
in_ns r1 ip addr add 198.51.100.1/24 dev dummy0
in_ns r1 ip link set dummy0 up
in_ns r3 ip link add dummy0 type dummy
in_ns r3 ip addr add 203.0.113.1/24 dev dummy0
in_ns r3 ip link set dummy0 up

# Step 6: one BIRD config per router. The README explains every line.
cat > "$HERE/r1.conf" <<'CONF'
# r1.conf: BIRD config for r1, the network AS64496. Written by three-networks.sh.
router id 10.0.0.1;

protocol device {
}

protocol direct {
  ipv4;
  interface "dummy0";
}

protocol kernel {
  ipv4 {
    export where source = RTS_BGP;
  };
}

protocol bgp to_r2 {
  local as 64496;
  neighbor 10.0.12.2 as 64497;
  ipv4 {
    import all;
    export all;
  };
}
CONF

cat > "$HERE/r2.conf" <<'CONF'
# r2.conf: BIRD config for r2, the network AS64497. Written by three-networks.sh.
# r2 owns no block. It carries traffic between its two neighbours.
router id 10.0.0.2;

protocol device {
}

protocol direct {
  ipv4;
  interface "dummy0";
}

protocol kernel {
  ipv4 {
    export where source = RTS_BGP;
  };
}

protocol bgp to_r1 {
  local as 64497;
  neighbor 10.0.12.1 as 64496;
  ipv4 {
    import all;
    export all;
  };
}

protocol bgp to_r3 {
  local as 64497;
  neighbor 10.0.23.3 as 64498;
  ipv4 {
    import all;
    export all;
  };
}
CONF

cat > "$HERE/r3.conf" <<'CONF'
# r3.conf: BIRD config for r3, the network AS64498. Written by three-networks.sh.
router id 10.0.0.3;

protocol device {
}

protocol direct {
  ipv4;
  interface "dummy0";
}

protocol kernel {
  ipv4 {
    export where source = RTS_BGP;
  };
}

protocol bgp to_r2 {
  local as 64498;
  neighbor 10.0.23.2 as 64497;
  ipv4 {
    import all;
    export all;
  };
}
CONF

# Step 7: check each file, then start one BIRD program inside each router.
# -f keeps BIRD in the foreground, so the course can stop it later. -s names its control socket.
for r in r1 r2 r3; do
  bird -p -c "$HERE/$r.conf"
  rm -f "/tmp/bird-$r.ctl"
  bg_start "bird-$r" "$r" bird -f -c "$HERE/$r.conf" -s "/tmp/bird-$r.ctl"
done

# Step 8: wait until the three BGP sessions are up, and the routes have arrived.
echo "--- waiting for BGP (this takes about 5 seconds)"
wait_until 30 established r1 to_r2 || echo "(r1's session to r2 is not up yet)"
wait_until 30 established r3 to_r2 || echo "(r3's session to r2 is not up yet)"
wait_until 15 has_route r1 203.0.113.0/24 || echo "(r1 has no route to 203.0.113.0/24 yet)"
wait_until 15 has_route r3 198.51.100.0/24 || echo "(r3 has no route to 198.51.100.0/24 yet)"

# Step 9: look at the result.
echo "--- r1's BGP sessions"
birdc -s /tmp/bird-r1.ctl show protocols
echo "--- r1's routes, as BIRD sees them"
birdc -s /tmp/bird-r1.ctl show route
echo "--- r1's routes, as Linux sees them"
in_ns r1 ip route
echo "--- r1 pings r3's block, from its own block"
in_ns r1 ping -c2 -W1 -I 198.51.100.1 203.0.113.1 || echo "(no answer)"
echo "Done. Next: bash test.sh"
