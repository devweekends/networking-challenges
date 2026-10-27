#!/usr/bin/env bash
# Restore the network from the end of an earlier part, so you can keep going when you are stuck.
# Run it in the lab:
#   bash /work/toolkit/restore.sh 4.1      build the network from the end of challenge 4, part 1
#   bash /work/toolkit/restore.sh --list   list the parts you can restore, and what each one builds
#
# Each restore runs one of the course's reference builds, the answers, from toolkit/restore/.
# Read them only after you have tried the part yourself, and say in your capstone demo if you used one.
# A restore changes only the lab network. It never changes your own files in the repository.
# Its output goes to a log file in /tmp/networking-restore/, so you see one line when it works.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

RESTORE_DIR="$HERE/restore"
LOG_DIR=/tmp/networking-restore

# The parts you can restore, and what each one builds. One line each: "PART|WHAT IT BUILDS".
CHECKPOINTS="2.1|challenge 2 part 1: laptop, router and server on two subnets, with routes and forwarding
4.1|challenge 4 part 1: laptop and phone behind a home router with masquerade, and the server's web page
4.2|challenge 4 part 2: part 1, plus a guest network, a forwarded port to the laptop, and the guest filter
6.1|challenge 6 part 1: the seven capstone computers, with addresses, routes, forwarding and two web servers
6.2|challenge 6 part 2: part 1, plus masquerade, the forwarded port and guest isolation in the home router
6.3|challenge 6 part 3: part 2, plus one dnsmasq for DHCP and DNS, and leases for home1, home2 and guest1"

usage() {
  echo "Usage: bash /work/toolkit/restore.sh PART"
  echo "       bash /work/toolkit/restore.sh --list"
  echo "PART is a challenge and a part, like 4.1. The list shows every part you can restore."
}

list() {
  local part what
  echo "Parts you can restore (bash /work/toolkit/restore.sh PART):"
  while IFS='|' read -r part what; do
    printf '  %s   %s\n' "$part" "$what"
  done <<< "$CHECKPOINTS"
  echo "These are the course's own answers. Read them after you have tried, and say in your capstone demo if you used one."
}

# is_checkpoint PART: true if PART is one of the parts in the list
is_checkpoint() {
  local part what
  while IFS='|' read -r part what; do
    [ "$part" = "$1" ] && return 0
  done <<< "$CHECKPOINTS"
  return 1
}

if [ "$#" -ne 1 ]; then
  usage
  exit 1
fi

case "$1" in
  --list)
    list
    exit 0
    ;;
esac

if ! is_checkpoint "$1"; then
  usage
  exit 1
fi

require_root

PART="$1"
CHALLENGE="${PART%.*}"
PART_NUMBER="${PART#*.}"
SCRIPT="$RESTORE_DIR/$PART.sh"
LOG="$LOG_DIR/$PART.log"
[ -f "$SCRIPT" ] || die "the restore script is missing: $SCRIPT"

mkdir -p "$LOG_DIR"
if bash "$SCRIPT" > "$LOG" 2>&1; then
  echo "Restored the network from the end of challenge $CHALLENGE, part $PART_NUMBER. Your own files were not changed."
else
  echo "The restore of challenge $CHALLENGE, part $PART_NUMBER failed. Read what happened in: $LOG"
  exit 1
fi
