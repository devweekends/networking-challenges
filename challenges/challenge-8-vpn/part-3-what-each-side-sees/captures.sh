#!/usr/bin/env bash
# Challenge 8, part 3: what each side sees. Two captures and one sum.
# Run it in the lab:  bash captures.sh
# It starts by running YOUR part 2 script, so part 2's test must pass first.
# Safe to run again: part 2 rebuilds everything.
# Three things are missing on purpose. Each gap is marked TODO. Fill them in, then run:  bash test.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

PART2="$HERE/../part-2-the-tunnel/tunnel.sh"

# Step 1: rebuild parts 1 and 2: the office, the cafe, and the tunnel.
[ -f "$PART2" ] || die "part 2 is missing: $PART2"
echo "--- building parts 1 and 2"
if ! bash "$PART2" build-only > /tmp/networking-course-part2.log 2>&1; then
  cat /tmp/networking-course-part2.log
  die "your part 2 script failed. Make bash ../part-2-the-tunnel/test.sh pass first."
fi

# Step 2: the cafe's view. The cafe router's outside plug, veth-cafe-out, is where the cafe meets the internet.
# Anyone there (the cafe, its provider) sees these packets. While the capture runs, the laptop pings
# the office server 3 times and fetches the office page. That is ICMP and TCP inside the tunnel.
rm -f "$HERE/cafe-outside.txt" "$HERE/wg0.txt" "$HERE/size.txt" "$HERE/size-capture.txt"
# TODO 1: Capture on the cafe router's outside plug for 6 seconds and save it in $HERE/cafe-outside.txt.
#   Use the filter "ip": every IPv4 packet. Do NOT filter on a port. You want to see that nothing else is there.
#   -n shows numbers, not names. -l prints each line at once.
#   Put it in the background with &, and remember its process id in CAFE_PID (CAFE_PID=$!).
#   Shape: timeout SECONDS ip netns exec NAMESPACE tcpdump -n -l -i INTERFACE ip > FILE 2>&1 &
sleep 1
in_ns laptop ping -c3 -W2 10.20.0.5 > /dev/null || echo "(the ping failed. Is part 2 working?)"
in_ns laptop curl -sS -m 3 -o /dev/null http://10.20.0.5/ || echo "(curl failed)"
[ -n "${CAFE_PID:-}" ] && { wait "$CAFE_PID" || true; }
echo "--- the cafe's outside plug (cafe-outside.txt):"
cat "$HERE/cafe-outside.txt" 2>/dev/null || echo "(missing. Fill in Gap 1.)"

# Step 3: the office's view, inside the tunnel. wg0 on the VPN box shows the inner packets, after decryption.
# TODO 2: Capture ICMP on the VPN box's wg0, stop after 4 packets (-c 4), give up after 5 seconds,
#   and save it in $HERE/wg0.txt. Background it with & and keep its process id in WG_PID.
#   Shape: timeout SECONDS ip netns exec NAMESPACE tcpdump -n -l -i INTERFACE -c COUNT icmp > FILE 2>&1 &
sleep 1
in_ns laptop ping -c2 -W2 10.20.0.5 > /dev/null || echo "(the ping failed)"
[ -n "${WG_PID:-}" ] && { wait "$WG_PID" || true; }
echo "--- the VPN box's wg0 (wg0.txt):"
cat "$HERE/wg0.txt" 2>/dev/null || echo "(missing. Fill in Gap 2.)"

# Step 4: the outer size. ping sends 56 bytes of data. With 8 bytes of ICMP header and 20 of IP, the inner packet is 84 bytes.
INNER=84
# TODO 3: Work out the size of the outer packet that carries it.
#   a) WireGuard pads the inner packet with zeros up to a multiple of 16. Round INNER up: PADDED=$(( (INNER + 15) / 16 * 16 ))
#   b) Then add 32 bytes of WireGuard (16 header, 16 check value), 8 of UDP header and 20 of IPv4 header.
#   Shape: PADDED=$(( ... ))   and   OUTER=$(( PADDED + NUMBER + NUMBER + NUMBER ))
echo "inner $INNER, padded ${PADDED:-?}, outer ${OUTER:-?}" | tee "$HERE/size.txt"

# Check the sum in a capture. -v prints the length of the whole outer IP packet.
timeout 5 ip netns exec caferouter tcpdump -n -l -v -i veth-cafe-out -c 1 udp port 51820 > "$HERE/size-capture.txt" 2>&1 &
SIZE_PID=$!
sleep 1
in_ns laptop ping -c1 -W2 10.20.0.5 > /dev/null || true
wait "$SIZE_PID" || true
echo "--- one outer packet, with -v (size-capture.txt):"
cat "$HERE/size-capture.txt"
if [ -n "${OUTER:-}" ] && grep -q "length $OUTER)" "$HERE/size-capture.txt"; then
  echo "Your sum, $OUTER, matches the capture."
else
  echo "Your sum, ${OUTER:-(none)}, does not match the capture. Look at Gap 3."
fi

echo "Done. Next: bash test.sh"
