#!/usr/bin/env bash
# Challenge 8, part 1: an office and a cafe, each behind NAT, with the internet between them.
# Run it in the lab:
#   bash office-cafe.sh              build everything, then break the port forward on purpose and mend it
#   bash office-cafe.sh build-only   build everything and stop (parts 2 to 4 use this)
# Safe to run again: it deletes the old network first.
# This part is guided: nothing is missing. Read each step, then run:  bash test.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

MODE="${1:-full}"
WEB=/tmp/networking-course-www-website
OFFICEWEB=/tmp/networking-course-www-office

# Step 1: delete anything this course built before.
teardown_all

# Step 2: seven computers.
ns_add internet
ns_add website
ns_add officert
ns_add vpnbox
ns_add officesrv
ns_add caferouter
ns_add laptop

# Step 3: the internet. One router with three plugs: the office, the cafe and a website.
# All three ranges are made for examples (RFC 5737). Here they stand for public addresses.
cable_if internet veth-inet-off officert veth-office-out
cable_if internet veth-inet-cafe caferouter veth-cafe-out
cable_if internet veth-inet-web website veth-website
in_ns internet ip addr add 203.0.113.1/24 dev veth-inet-off
in_ns internet ip addr add 198.51.100.1/24 dev veth-inet-cafe
in_ns internet ip addr add 192.0.2.1/24 dev veth-inet-web
in_ns internet sysctl -qw net.ipv4.ip_forward=1
in_ns website ip addr add 192.0.2.80/24 dev veth-website
in_ns website ip route add default via 192.0.2.1

# Step 4: the office. A bridge in the office router joins the VPN box and the test server.
in_ns officert ip link add br-office type bridge
in_ns officert ip link set br-office up
cable_if vpnbox veth-vpnbox officert veth-o-vpnbox
cable_if officesrv veth-officesrv officert veth-o-srv
in_ns officert ip link set veth-o-vpnbox master br-office
in_ns officert ip link set veth-o-srv master br-office
in_ns officert ip addr add 10.20.0.1/24 dev br-office
in_ns officert ip addr add 203.0.113.2/24 dev veth-office-out
in_ns officert ip route add default via 203.0.113.1
in_ns officert sysctl -qw net.ipv4.ip_forward=1
in_ns vpnbox ip addr add 10.20.0.2/24 dev veth-vpnbox
in_ns vpnbox ip route add default via 10.20.0.1
in_ns officesrv ip addr add 10.20.0.5/24 dev veth-officesrv
in_ns officesrv ip route add default via 10.20.0.1

# Step 5: the cafe. One laptop on one cable to the cafe router.
cable_if laptop veth-laptop caferouter veth-cafe-in
in_ns caferouter ip addr add 192.168.50.1/24 dev veth-cafe-in
in_ns caferouter ip addr add 198.51.100.2/24 dev veth-cafe-out
in_ns caferouter ip route add default via 198.51.100.1
in_ns caferouter sysctl -qw net.ipv4.ip_forward=1
in_ns laptop ip addr add 192.168.50.23/24 dev veth-laptop
in_ns laptop ip route add default via 192.168.50.1

# Step 6: fixed hardware addresses, so every run looks the same. They start with 02: (made up, never on a real card).
while read -r ns ifname mac; do
  in_ns "$ns" ip link set dev "$ifname" address "$mac"
done <<'MACS'
internet veth-inet-off 02:00:00:01:00:01
internet veth-inet-cafe 02:00:00:01:00:02
internet veth-inet-web 02:00:00:01:00:03
officert veth-office-out 02:00:00:02:00:01
officert br-office 02:00:00:02:00:02
vpnbox veth-vpnbox 02:00:00:02:00:12
officesrv veth-officesrv 02:00:00:02:00:15
caferouter veth-cafe-out 02:00:00:03:00:01
caferouter veth-cafe-in 02:00:00:03:00:02
laptop veth-laptop 02:00:00:03:00:23
website veth-website 02:00:00:04:00:80
MACS

# Step 7: NAT on both routers, as in challenge 4.
# The office: masquerade on the way out, and one port forward on the way in:
# UDP port 51820 on 203.0.113.2 goes on to the VPN box, 10.20.0.2.
in_ns officert nft -f - <<'RULES'
table ip nat {
  chain prerouting {
    type nat hook prerouting priority -100 ; policy accept ;
    iifname "veth-office-out" udp dport 51820 dnat to 10.20.0.2:51820
  }
  chain postrouting {
    type nat hook postrouting priority 100 ; policy accept ;
    oifname "veth-office-out" masquerade
  }
}
RULES
# The cafe: masquerade on the way out. No port forward.
in_ns caferouter nft -f - <<'RULES'
table ip nat {
  chain postrouting {
    type nat hook postrouting priority 100 ; policy accept ;
    oifname "veth-cafe-out" masquerade
  }
}
RULES

# Step 8: two web servers.
# The lab website on the internet: its page /cgi-bin/whoami says which address it sees.
# The office test server: a page that only people inside the office can reach.
www_make "$WEB" "lab website"
bg_start website-web website busybox httpd -f -p 0.0.0.0:80 -h "$WEB"
www_make "$OFFICEWEB" "office test server"
bg_start office-web officesrv busybox httpd -f -p 0.0.0.0:80 -h "$OFFICEWEB"
sleep 1

# Step 9: three checks.
echo "--- the laptop visits the lab website. Which address does the website see?"
in_ns laptop curl -sS -m 3 http://192.0.2.80/cgi-bin/whoami || echo "(failed)"
echo "--- the office server visits the lab website"
in_ns officesrv curl -sS -m 3 http://192.0.2.80/cgi-bin/whoami || echo "(failed)"
echo "--- the laptop pings the office server, 10.20.0.5 (this must fail: the internet has no route to it)"
in_ns laptop ping -c1 -W1 10.20.0.5 || echo "(no answer, as expected)"

if [ "$MODE" = "build-only" ]; then
  echo "Done (build only)."
  exit 0
fi

# Step 10: prove the port forward works by breaking it on purpose.
# send_and_watch LABEL: the VPN box listens for one UDP packet on port 51820,
# the laptop sends one (always from its own port 51820), and one line goes into forward-test.txt.
send_and_watch() {
  local label="$1" seen pid
  timeout 3 ip netns exec vpnbox tcpdump -n -l -i veth-vpnbox -c 1 udp port 51820 > /tmp/networking-course-watch.txt 2>/dev/null &
  pid=$!
  sleep 1
  echo hello | ip netns exec laptop nc -u -w1 -p 51820 203.0.113.2 51820 > /dev/null 2>&1 || true
  wait "$pid" || true
  seen="$(grep ' UDP' /tmp/networking-course-watch.txt || true)"
  if [ -n "$seen" ]; then
    echo "$label: arrived at the VPN box ($seen)" | tee -a "$HERE/forward-test.txt"
  else
    echo "$label: nothing arrived at the VPN box" | tee -a "$HERE/forward-test.txt"
  fi
}

: > "$HERE/forward-test.txt"
in_ns officert conntrack -F > /dev/null 2>&1 || true
echo "--- the forward experiment"
send_and_watch "1 rule on"

# Break it: empty the prerouting chain. The port forward rule is gone.
in_ns officert nft flush chain ip nat prerouting
send_and_watch "2 rule off, old NAT state kept"
echo "The office router still remembers the conversation:"
in_ns officert conntrack -L -p udp --dport 51820 2>/dev/null || true

# Forget the old conversations. Now the router must decide again, and there is no rule.
in_ns officert conntrack -F > /dev/null 2>&1
send_and_watch "3 rule off, NAT state flushed"

# Mend it: put the rule back. The router remembers the failed conversation from send 3, so flush again.
in_ns officert nft add rule ip nat prerouting iifname '"veth-office-out"' udp dport 51820 dnat to 10.20.0.2:51820
send_and_watch "4 rule back, old NAT state kept"
in_ns officert conntrack -F > /dev/null 2>&1
send_and_watch "5 rule back, NAT state flushed"

echo "Done. Next: bash test.sh"
