#!/usr/bin/env bash
# Challenge 6, part 3: DHCP and DNS.
# This is YOUR script. It must build parts 1 and 2 first, then start dnsmasq and give leases to the devices.
# Run it in the lab:  bash dhcp-and-dns.sh
# Then check it:      bash test.sh
# Keep the file name. break.sh runs this script to rebuild a healthy network.
#
# Start from your challenge 5 script and config.
#
# What this part must do:
#   - start ONE dnsmasq inside hrouter with  bg_start dnsmasq hrouter dnsmasq --keep-in-foreground --conf-file=...
#     (the name "dnsmasq" and the file "dnsmasq.conf" next to this script are what the tests use)
#   - serve both subnets: a home pool and a guest pool, each with its own gateway and DNS address
#   - make the name web.test answer 203.0.113.80
#   - home1, home2 and guest1 give up their placeholder addresses and ask for leases with busybox udhcpc and
#     the hook script (udhcpc_hook_path in lib.sh). Wait about 3 seconds after starting dnsmasq.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

# Step 1: build parts 1 and 2 (they delete the old network first).

# Step 2: start dnsmasq.

# Step 3: ask for leases.
