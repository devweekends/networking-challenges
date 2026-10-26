#!/usr/bin/env bash
# Challenge 1, part 2: one cable, two computers that disagree about the mask.
# Run it in the lab:
#   bash wrong-mask.sh       laptop is /24, phone is /28: they disagree
#   bash wrong-mask.sh 24    both are /24: the fix
# Safe to run again: it deletes the old network first.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

# The phone's mask. The default is the wrong one on purpose.
PHONE_PREFIX="${1:-28}"
if ! [[ "$PHONE_PREFIX" =~ ^[0-9]+$ ]] || [ "$PHONE_PREFIX" -lt 8 ] || [ "$PHONE_PREFIX" -gt 30 ]; then
  die "the phone prefix must be a number from 8 to 30, for example: bash wrong-mask.sh 24"
fi

# Start clean, make two computers, join them with one cable (cable also switches both ends on).
teardown_all
ns_add laptop
ns_add phone
cable laptop phone

# Same two addresses as part 1. Only the phone's mask can change.
ip netns exec laptop ip addr add 192.168.1.10/24 dev veth-laptop
ip netns exec phone ip addr add "192.168.1.20/$PHONE_PREFIX" dev veth-phone

ip netns exec laptop ip -4 addr show dev veth-laptop
ip netns exec phone ip -4 addr show dev veth-phone
echo "Done. laptop is 192.168.1.10/24 and phone is 192.168.1.20/$PHONE_PREFIX."
