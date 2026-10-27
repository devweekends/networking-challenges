#!/usr/bin/env bash
# Challenge 7, part 4: steal a block in your own lab, then stop it with a filter.
# Run it in the lab:  bash hijack.sh
# Safe to run again: it stops the old BIRD programs and deletes the old network first.
# It saves three files here: before-hijack.txt, hijack.txt and after-filter.txt.
# Three things are missing on purpose. Each gap is marked TODO. Fill them in, then run:  bash test.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

wait_until() {
  local end=$((SECONDS + $1))
  shift
  until "$@" > /dev/null 2>&1; do
    [ "$SECONDS" -lt "$end" ] || return 1
    sleep 0.5
  done
}
established() { birdc -s "/tmp/bird-$1.ctl" show protocols "$2" | grep -q Established; }
has_route() { ip netns exec "$1" ip route show "$2" | grep -q .; }
no_route() { ! has_route "$@"; }
# routes_for ROUTER BLOCK COUNT: true when BIRD in ROUTER knows at least COUNT routes for BLOCK.
routes_for() { [ "$(birdc -s "/tmp/bird-$1.ctl" show route "$2" | grep -c unicast)" -ge "$3" ]; }
# visit ADDRESS: r3 asks the web page at ADDRESS who answers. It sends from its own block.
visit() { ip netns exec r3 curl -sS -m 3 --interface 203.0.113.1 "http://$1:8080/" 2>&1 || true; }
# look: what r3 knows, and who answers, saved in one file.
look() {
  echo "### birdc -s /tmp/bird-r3.ctl show route"
  birdc -s /tmp/bird-r3.ctl show route || true
  echo "### ip netns exec r3 ip route get 198.51.100.130"
  in_ns r3 ip route get 198.51.100.130 || true
  echo "### r3 visits 198.51.100.130"
  visit 198.51.100.130
  echo "### r3 visits 198.51.100.1"
  visit 198.51.100.1
}

# Step 1: delete anything this course built before. This also stops old BIRD programs.
teardown_all

# Step 2: the same three routers.
ns_add r1
ns_add r2
ns_add r3

# Step 3: the triangle of part 3: r1 -- r2 -- r3, and the direct link r1 -- r3.
cable_if r1 veth-to-r2 r2 veth-to-r1
cable_if r2 veth-to-r3 r3 veth-to-r2
cable_if r1 veth-to-r3 r3 veth-to-r1
in_ns r1 ip addr add 10.0.12.1/24 dev veth-to-r2
in_ns r2 ip addr add 10.0.12.2/24 dev veth-to-r1
in_ns r2 ip addr add 10.0.23.2/24 dev veth-to-r3
in_ns r3 ip addr add 10.0.23.3/24 dev veth-to-r2
in_ns r1 ip addr add 10.0.13.1/24 dev veth-to-r3
in_ns r3 ip addr add 10.0.13.3/24 dev veth-to-r1
for r in r1 r2 r3; do
  in_ns "$r" sysctl -qw net.ipv4.ip_forward=1
done

# Step 4: the blocks. r1 owns 198.51.100.0/24 and runs a web server at 198.51.100.130 inside it.
# r2 gets an empty dummy interface. It owns nothing yet.
in_ns r1 ip link add dummy0 type dummy
in_ns r1 ip addr add 198.51.100.1/24 dev dummy0
in_ns r1 ip addr add 198.51.100.130/24 dev dummy0
in_ns r1 ip link set dummy0 up
in_ns r2 ip link add dummy0 type dummy
in_ns r2 ip link set dummy0 up
in_ns r3 ip link add dummy0 type dummy
in_ns r3 ip addr add 203.0.113.1/24 dev dummy0
in_ns r3 ip link set dummy0 up

# Step 5: a tiny web page in r1 and in r2. Each page says who answered.
www_make /tmp/networking-course-www-r1 "r1 (AS64496), the real owner of 198.51.100.0/24"
www_make /tmp/networking-course-www-r2 "r2 (AS64497), the wrong network"
bg_start web-r1 r1 busybox httpd -f -p 0.0.0.0:8080 -h /tmp/networking-course-www-r1
bg_start web-r2 r2 busybox httpd -f -p 0.0.0.0:8080 -h /tmp/networking-course-www-r2

# Step 6: the BIRD configs. In this part every session takes every route: the direct link is a
# normal link again, not a backup, so r3 reaches r1 straight over it.
cat > "$HERE/r1.conf" <<'CONF'
# r1.conf: BIRD config for r1, the network AS64496. Written by hijack.sh.
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

protocol bgp to_r3 {
  local as 64496;
  neighbor 10.0.13.3 as 64498;
  ipv4 {
    import all;
    export all;
  };
}
CONF

cat > "$HERE/r2.conf" <<'CONF'
# r2.conf: BIRD config for r2, the network AS64497. Written by hijack.sh.
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

# write_r3_conf IMPORT_LINE: write r3.conf. IMPORT_LINE is the import line of both of r3's sessions.
write_r3_conf() {
  cat > "$HERE/r3.conf" <<CONF
# r3.conf: BIRD config for r3, the network AS64498. Written by hijack.sh.
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

# A hand-written list of who may announce what. It has one entry: 198.51.100.0/24 belongs to AS64496.
filter owner_only {
# TODO 2: ONE line. Accept the route when the block is exactly 198.51.100.0/24 AND the last AS in its path is 64496.
#   Why: the last AS in the path is the network that first announced the block, the origin.
#   Shape: if net = BLOCK && bgp_path.last = ASN then accept;
  reject;
}

protocol bgp to_r2 {
  local as 64498;
  neighbor 10.0.23.2 as 64497;
  ipv4 {
    import keep filtered on;
    $1
    export all;
  };
}

protocol bgp to_r1 {
  local as 64498;
  neighbor 10.0.13.1 as 64496;
  ipv4 {
    import keep filtered on;
    $1
    export all;
  };
}
CONF
}

# Step 7: first, r3 takes every route, like r1 and r2.
write_r3_conf 'import all;'
for r in r1 r2 r3; do
  bird -p -c "$HERE/$r.conf"
  rm -f "/tmp/bird-$r.ctl"
  bg_start "bird-$r" "$r" bird -f -c "$HERE/$r.conf" -s "/tmp/bird-$r.ctl"
done
echo "--- waiting for BGP (this takes about 5 seconds)"
wait_until 30 established r3 to_r1 || echo "(r3's session to r1 is not up yet)"
wait_until 30 established r3 to_r2 || echo "(r3's session to r2 is not up yet)"
wait_until 15 has_route r3 198.51.100.0/24 || echo "(r3 has no route to 198.51.100.0/24 yet)"
wait_until 15 routes_for r3 198.51.100.0/24 2 || echo "(r3 knows only one way to 198.51.100.0/24 yet)"

# Step 8: before the hijack. r3 reaches r1's block over the direct link.
look > "$HERE/before-hijack.txt" 2>&1
echo "--- before the hijack"
cat "$HERE/before-hijack.txt"

# Step 9: the hijack. r2 announces a more specific block, inside r1's /24.
# TODO 1: ONE command. Give r2's dummy0 the address 198.51.100.130 with a /25 mask.
#   Why: BIRD's direct protocol announces every block on dummy0. 198.51.100.130/25 is the block 198.51.100.128/25.
#   Shape: in_ns ROUTER ip addr add ADDRESS/MASK dev INTERFACE
wait_until 15 has_route r3 198.51.100.128/25 || echo "(r3 has no route to 198.51.100.128/25. Check Gap 1)"
look > "$HERE/hijack.txt" 2>&1
echo "--- during the hijack"
cat "$HERE/hijack.txt"

# Step 10: the filter. r3 uses owner_only on both sessions.
# TODO 3: Set R3_IMPORT to the import line that uses the filter owner_only.
#   Shape: R3_IMPORT='import filter FILTER_NAME;'
R3_IMPORT='import all;'
write_r3_conf "$R3_IMPORT"
bird -p -c "$HERE/r3.conf"
birdc -s /tmp/bird-r3.ctl configure
wait_until 15 no_route r3 198.51.100.128/25 || echo "(r3 still has the /25. Check Gap 2 and Gap 3)"
wait_until 15 has_route r3 198.51.100.0/24 || echo "(r3 has no route to 198.51.100.0/24. Check Gap 2)"
{
  look
  echo "### birdc -s /tmp/bird-r3.ctl show route filtered"
  birdc -s /tmp/bird-r3.ctl show route filtered || true
} > "$HERE/after-filter.txt" 2>&1
echo "--- after the filter"
cat "$HERE/after-filter.txt"
echo "Done. Next: bash test.sh"
