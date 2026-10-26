#!/usr/bin/env bash
# Challenge 6, part 1: addresses and routes.
# This is YOUR script. Start from your scripts from challenge 2 and challenge 4.
# Run it in the lab:  bash addresses-and-routes.sh
# Then check it:      bash test.sh
# Keep the file name. Part 2 runs this script, and break.sh depends on it.
#
# What this script must build (no NAT, DHCP or DNS yet; those are parts 2 and 3):
#
#   Seven computers (namespaces): home1 home2 homeweb guest1 hrouter prouter server
#
#   Link                      Subnet             Addresses
#   Home LAN                  192.168.1.0/24     hrouter 192.168.1.1, homeweb 192.168.1.20,
#                                                home1 192.168.1.30, home2 192.168.1.31 (placeholders)
#   Guest LAN                 192.168.50.0/24    hrouter 192.168.50.1, guest1 192.168.50.30 (placeholder)
#   Home router to provider   198.51.100.0/30    hrouter 198.51.100.2, prouter 198.51.100.1
#   Public side               203.0.113.0/24     prouter 203.0.113.1, server 203.0.113.80
#
#   Routes and forwarding: every device sends everything else to its router; hrouter sends everything
#   else to prouter; the server sends everything else to prouter; both routers forward.
#
#   Two web servers, made with www_make and started with bg_start and busybox httpd:
#   server on 0.0.0.0:8080 (the page /cgi-bin/whoami tells a visitor its address) and homeweb on 0.0.0.0:80.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

# Step 1: delete anything this course built before.
teardown_all

# Step 2: write your network here.
