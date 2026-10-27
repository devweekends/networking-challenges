#!/usr/bin/env bash
# Challenge 9, part 1: make YOUR capture file, capture.pcap, in this folder.
# Run it in the lab, after bash ../part-0-the-broken-network/faults.sh:
#   bash make-capture.sh
# The capture is made from your seed: the laptop's source port, the server's TTL and the number of
# web visits are yours. Another learner's capture has other numbers.
# Run it once, then commit capture.pcap. If you run it again, the test reads the new file.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
source "$HERE/../part-0-the-broken-network/seed.sh"
require_root

SEED="$(ch9_seed)"
[ -n "$SEED" ] || die "there is no seed yet. Run: bash ../part-0-the-broken-network/faults.sh --seed YOUR_NAME"
ns_exists laptop && ns_exists server || die "the lab network is missing. Run: bash ../part-0-the-broken-network/faults.sh"
ch9_capture_values "$SEED"

OUT="$HERE/capture.pcap"
rm -f "$OUT"

# Step 1: the server starts its packets with your TTL for a moment. (Linux starts with 64.)
in_ns server sysctl -qw net.ipv4.ip_default_ttl="$C_TTL"

# Step 2: capture on the laptop's own cable, like Wireshark on your laptop.
#   --immediate-mode and -U hand each packet to the file at once. -Z root keeps the file owned by root.
ip netns exec laptop tcpdump -n -i veth-laptop --immediate-mode -U -Z root -w "$OUT" > /tmp/networking-course-ch9-capture.log 2>&1 &
TCPDUMP=$!
sleep 2

# Step 3: some traffic. Two name questions, two pings to the router, and the web visits.
in_ns laptop dig +short www.lab.test > /dev/null || true
in_ns laptop dig +short @203.0.113.53 docs.lab.test > /dev/null || true
in_ns laptop ping -c 2 -W 1 192.0.2.1 > /dev/null || true
for i in $(seq 0 $((C_VISITS - 1))); do
  # --local-port: the laptop sends from this source port, not from a random one.
  in_ns laptop curl -sS -m 5 -o /dev/null --local-port "$((C_PORT + i))" http://203.0.113.80/ || true
done
sleep 1

# Step 4: stop the capture cleanly (tcpdump finishes the file when it gets TERM). Then put the TTL back.
kill -TERM "$TCPDUMP"
wait "$TCPDUMP" 2>/dev/null || true
in_ns server sysctl -qw net.ipv4.ip_default_ttl=64
chmod 644 "$OUT"

COUNT="$(tcpdump -n -r "$OUT" 2>/dev/null | wc -l)"
echo "capture.pcap is ready: $COUNT packets, made from your seed '$SEED'."
echo "Open it in Wireshark on your computer. It is in your repository folder, in"
echo "challenges/challenge-9-toolbox/part-1-wireshark/"
