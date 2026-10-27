#!/usr/bin/env bash
# Restore: the network from the end of challenge 6, part 2 (NAT, forwarding and isolation).
# This is the course's reference build, the answer. Use it only after you have tried the part yourself.
# If you use it, say so in your capstone demo.
# Run it with:  bash /work/toolkit/restore.sh 6.2
# It is a copy of the reference nat-forwarding-isolation.sh. It builds part 1 with 6.1.sh, next to it, then adds three jobs to the home router:
#   masquerade   every home and guest packet leaves with the router's outside address, 198.51.100.2
#   forwarding   a request to 198.51.100.2 port 8080 goes on to the home web server, 192.168.1.20 port 80
#   isolation    the guest subnet cannot reach the home subnet
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../lib.sh"
require_root

PART1="$HERE/6.1.sh"
[ -f "$PART1" ] || die "part 1 is missing: $PART1"
echo "--- building part 1"
if ! bash "$PART1" > /tmp/networking-course-capstone-part1.log 2>&1; then
  cat /tmp/networking-course-capstone-part1.log
  die "your part 1 script failed. Make part 1's test pass first."
fi

# nft wants one setting per line, so the rules go in as a small file with line breaks.
in_ns hrouter nft -f - <<'RULES'
table ip nat {
  chain postrouting {
    type nat hook postrouting priority 100 ; policy accept ;
    oifname "veth-hout" masquerade
  }
  chain prerouting {
    type nat hook prerouting priority -100 ; policy accept ;
    iifname "veth-hout" tcp dport 8080 dnat to 192.168.1.20:80
  }
}
table ip filter {
  chain forward {
    type filter hook forward priority 0 ; policy accept ;
    ip saddr 192.168.50.0/24 ip daddr 192.168.1.0/24 drop
  }
}
RULES

echo "--- the router's rules"
in_ns hrouter nft list ruleset
echo "--- home1 and guest1 visit the public server"
in_ns home1 curl -sS -m 3 http://203.0.113.80:8080/cgi-bin/whoami || echo "(home1 failed)"
in_ns guest1 curl -sS -m 3 http://203.0.113.80:8080/cgi-bin/whoami || echo "(guest1 failed)"
echo "--- the server visits the forwarded port"
in_ns server curl -sS -m 3 http://198.51.100.2:8080/ || echo "(the forwarded port failed)"
echo "--- the router's NAT table"
in_ns hrouter conntrack -L 2>/dev/null | grep 'dport=8080' || true
echo "Done. Next: bash test.sh"
