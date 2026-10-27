#!/usr/bin/env bash
# Challenge 9, part 2: make mixed traffic from the laptop, so your captures have something to catch.
# Run it in the background, then start a capture:
#   bash traffic.sh 30 &       mixed traffic for 30 seconds (the default is 20)
# Every second the laptop asks two names (DNS, port 53), visits the web page (port 80),
# and pings the provider's router.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

SECONDS_TO_RUN="${1:-20}"
ns_exists laptop || die "the lab network is missing. Run: bash ../part-0-the-broken-network/faults.sh"

END=$((SECONDS + SECONDS_TO_RUN))
while [ "$SECONDS" -lt "$END" ]; do
  in_ns laptop dig +short +tries=1 +time=1 www.lab.test > /dev/null 2>&1 || true
  in_ns laptop dig +short +tries=1 +time=1 @203.0.113.53 news.lab.test > /dev/null 2>&1 || true
  in_ns laptop curl -s -m 2 -o /dev/null http://203.0.113.80/ || true
  in_ns laptop ping -c 1 -W 1 198.51.100.2 > /dev/null 2>&1 || true
  sleep 1
done
