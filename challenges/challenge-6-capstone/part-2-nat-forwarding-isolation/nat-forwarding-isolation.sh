#!/usr/bin/env bash
# Challenge 6, part 2: NAT, forwarding and isolation.
# This is YOUR script. It must build part 1 first, then add three jobs to the home router.
# Run it in the lab:  bash nat-forwarding-isolation.sh
# Then check it:      bash test.sh
# Keep the file name. Part 3 runs this script, and break.sh depends on it.
#
# Model: look at how challenge 4 part 2 ran part 1 with  bash "$PART1" ...  before adding its own work.
#
# The three jobs (all in the home router, hrouter):
#   masquerade   every packet that leaves by the outside plug gets the router's outside address, 198.51.100.2
#   forwarding   a request to 198.51.100.2 port 8080 goes on to the home web server, 192.168.1.20 port 80
#   isolation    packets from the guest subnet 192.168.50.0/24 to the home subnet 192.168.1.0/24 are dropped
# Remember: nft wants one setting per line. Send the rules as a small file with line breaks.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

# Step 1: build part 1 (it deletes the old network first).

# Step 2: add the three jobs.
