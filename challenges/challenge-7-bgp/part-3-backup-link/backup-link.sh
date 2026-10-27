#!/usr/bin/env bash
# Challenge 7, part 3: a backup link and your own preference.
# Run it in the lab:  bash backup-link.sh
# Safe to run again: it stops the old BIRD programs and deletes the old network first.
# It saves four files here: before-preference.txt, after-preference.txt, failover.txt and restored.txt.
# Four things are missing on purpose. Each gap is marked TODO. Fill them in, then run:  bash test.sh
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
# uses ROUTER BLOCK NEXT_HOP: true when Linux in ROUTER sends BLOCK to NEXT_HOP.
uses() { ip netns exec "$1" ip route show "$2" | grep -q "via $3 "; }
# routes_for ROUTER BLOCK COUNT: true when BIRD in ROUTER knows at least COUNT routes for BLOCK.
routes_for() { [ "$(birdc -s "/tmp/bird-$1.ctl" show route "$2" | grep -c unicast)" -ge "$3" ]; }

# Step 1: delete anything this course built before. This also stops old BIRD programs.
teardown_all

# Step 2: the same three routers as in part 1.
ns_add r1
ns_add r2
ns_add r3

# Step 3: the two cables of part 1, and a third one: a direct link from r1 to r3.
#   r1 -- r2 -- r3, and r1 -- r3
cable_if r1 veth-to-r2 r2 veth-to-r1
cable_if r2 veth-to-r3 r3 veth-to-r2
cable_if r1 veth-to-r3 r3 veth-to-r1
in_ns r1 ip addr add 10.0.12.1/24 dev veth-to-r2
in_ns r2 ip addr add 10.0.12.2/24 dev veth-to-r1
in_ns r2 ip addr add 10.0.23.2/24 dev veth-to-r3
in_ns r3 ip addr add 10.0.23.3/24 dev veth-to-r2
in_ns r1 ip addr add 10.0.13.1/24 dev veth-to-r3
in_ns r3 ip addr add 10.0.13.3/24 dev veth-to-r1

# Step 4: every router may pass on packets that are not for itself.
for r in r1 r2 r3; do
  in_ns "$r" sysctl -qw net.ipv4.ip_forward=1
done

# Step 5: the two blocks, as in part 1.
in_ns r1 ip link add dummy0 type dummy
in_ns r1 ip addr add 198.51.100.1/24 dev dummy0
in_ns r1 ip link set dummy0 up
in_ns r3 ip link add dummy0 type dummy
in_ns r3 ip addr add 203.0.113.1/24 dev dummy0
in_ns r3 ip link set dummy0 up

# Step 6: the BIRD configs. r2's is the same as in part 1.
# r1 and r3 now have two sessions each. The import line of the direct session is a setting,
# so the script can write the file again later with a different line.
cat > "$HERE/r2.conf" <<'CONF'
# r2.conf: BIRD config for r2, the network AS64497. Written by backup-link.sh.
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

# write_r1_conf IMPORT_LINE: write r1.conf. IMPORT_LINE is the import line of r1's session to r3.
write_r1_conf() {
  cat > "$HERE/r1.conf" <<CONF
# r1.conf: BIRD config for r1, the network AS64496. Written by backup-link.sh.
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
    $1
    export all;
  };
}
CONF
}

# write_r3_conf IMPORT_LINE: write r3.conf. IMPORT_LINE is the import line of r3's session to r1.
write_r3_conf() {
  cat > "$HERE/r3.conf" <<CONF
# r3.conf: BIRD config for r3, the network AS64498. Written by backup-link.sh.
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

# TODO 1: r3's session to r1, over the direct link. Copy r1's session to r3 above (in write_r1_conf) and change three things:
#   the name (to_r1), the local AS (r3 is 64498), and the neighbour (r1 is 10.0.13.1, AS 64496).
#   Keep its import line exactly as it is in r1's block. The script fills it in.
CONF
}

# Step 7: first, both ends of the direct link take every route as it is.
write_r1_conf 'import all;'
write_r3_conf 'import all;'

# Step 8: check each file, then start one BIRD program inside each router.
for r in r1 r2 r3; do
  bird -p -c "$HERE/$r.conf"
  rm -f "/tmp/bird-$r.ctl"
  bg_start "bird-$r" "$r" bird -f -c "$HERE/$r.conf" -s "/tmp/bird-$r.ctl"
done
echo "--- waiting for BGP (this takes about 5 seconds)"
wait_until 30 established r1 to_r2 || echo "(r1's session to r2 is not up yet)"
wait_until 30 established r1 to_r3 || echo "(r1's session to r3 is not up. Check Gap 1)"
wait_until 15 uses r1 203.0.113.0/24 10.0.13.3 || echo "(r1 does not use the direct link. Check Gap 1)"
wait_until 15 routes_for r1 203.0.113.0/24 2 || echo "(r1 knows only one way to 203.0.113.0/24. Check Gap 1)"

# Step 9: r1 now knows two ways to 203.0.113.0/24. The direct one has the shorter AS path, so it wins.
echo "--- before the preference: r1's routes to 203.0.113.0/24"
birdc -s /tmp/bird-r1.ctl show route all 203.0.113.0/24 | tee "$HERE/before-preference.txt"

# Step 10: make the direct link the backup. Your network's own preference comes before path length.
# TODO 2: Set both lines below to a one-line import filter. It sets the local preference of the
#   routes from the direct link to 50 (lower than the normal 100), then accepts them.
#   Shape: 'import filter { bgp_local_pref = NUMBER; accept; };'
R1_FROM_R3='import all;'
R3_FROM_R1='import all;'
write_r1_conf "$R1_FROM_R3"
write_r3_conf "$R3_FROM_R1"
# birdc configure makes BIRD read its file again, without a restart.
birdc -s /tmp/bird-r1.ctl configure
birdc -s /tmp/bird-r3.ctl configure
wait_until 15 uses r1 203.0.113.0/24 10.0.12.2 || echo "(r1 still uses the direct link. Check Gap 2)"
echo "--- after the preference: r1's routes to 203.0.113.0/24"
birdc -s /tmp/bird-r1.ctl show route all 203.0.113.0/24 | tee "$HERE/after-preference.txt"

# Step 11: cut the main link. r2 switches off its BGP session to r1.
# TODO 3: one birdc command. Ask r2's BIRD to disable its session to r1, to_r1.
#   Shape: birdc -s SOCKET disable SESSION
wait_until 15 uses r1 203.0.113.0/24 10.0.13.3 || echo "(r1 did not move to the direct link. Check Gap 3)"
{
  echo "### ip netns exec r1 ip route"
  in_ns r1 ip route
  echo "### ip netns exec r1 ping -c2 -W1 -I 198.51.100.1 203.0.113.1"
  in_ns r1 ping -c2 -W1 -I 198.51.100.1 203.0.113.1 2>&1 || true
  echo "### birdc -s /tmp/bird-r1.ctl show protocols"
  birdc -s /tmp/bird-r1.ctl show protocols
} > "$HERE/failover.txt" 2>&1
echo "--- the main link is cut"
cat "$HERE/failover.txt"

# Step 12: put the main link back.
# TODO 4: one birdc command. Switch r2's session to r1 on again.
#   Shape: birdc -s SOCKET enable SESSION
wait_until 30 uses r1 203.0.113.0/24 10.0.12.2 || echo "(r1 did not move back to r2. Check Gap 4)"
{
  echo "### ip netns exec r1 ip route"
  in_ns r1 ip route
  echo "### ip netns exec r1 ping -c2 -W1 -I 198.51.100.1 203.0.113.1"
  in_ns r1 ping -c2 -W1 -I 198.51.100.1 203.0.113.1 2>&1 || true
} > "$HERE/restored.txt" 2>&1
echo "--- the main link is back"
cat "$HERE/restored.txt"
echo "Done. Next: bash test.sh"
