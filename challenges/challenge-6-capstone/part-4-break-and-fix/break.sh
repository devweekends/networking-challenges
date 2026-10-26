#!/usr/bin/env bash
# Challenge 6, part 4: break the network on purpose.
#
#   bash break.sh SEED                 rebuild the healthy network with YOUR part 3 script, then inject
#                                      three faults. The seed picks which three. The same seed always picks
#                                      the same three, so a mentor can repeat your run.
#   bash break.sh SEED --no-rebuild    inject into the network that exists now (it must be healthy)
#   bash break.sh --list SEED          (mentor) print which faults a seed picks, and change nothing
#   bash break.sh --only F1,F4         (mentor) inject exactly these faults, on a rebuilt network
#
# The seed can be any word or number. It is saved in fault-seed.txt. Put the same seed in your write-up.
# Do not use --list on your own run: it tells you the answer. Finding the faults is the exercise.
#
# The fault menu, with the symptoms and the commands that find each one, is in faults.md.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"

PART3="$HERE/../part-3-dhcp-and-dns"
CONF_BACKUP=/tmp/networking-course-dnsmasq.conf.orig

# Faults that must not be drawn together, and why:
#   F1 hides behind F2, F3 and F7: with the way out of the home router broken, the web server's mask
#      cannot be seen from outside, and the guest rule cannot be tested.
#   F2 and F3 break the same path out of the home router and hide each other. F3 and F5 do too.
#   F7 hides behind F2: with forwarding off, the guest cannot reach the home network anyway.
#   F4 and F6: a device without a lease cannot show a DNS fault.
# F2 and F5 may be drawn together: fix F2 first, and then the symptom of F5 shows.
# (The matrix in the module brief also kept F2 and F5 apart. Then F2 had no partner, and could never be drawn.)
conflicts_of() {
  case "$1" in
    F1) echo "F2 F3 F7" ;;
    F2) echo "F1 F3 F7" ;;
    F3) echo "F1 F2 F5" ;;
    F4) echo "F6" ;;
    F5) echo "F3" ;;
    F6) echo "F4" ;;
    F7) echo "F1 F2" ;;
  esac
}

fault_name() {
  case "$1" in
    F1) echo "wrong mask on the home web server" ;;
    F2) echo "forwarding off on the home router" ;;
    F3) echo "default route missing on the home router" ;;
    F4) echo "DNS port blocked on the home router" ;;
    F5) echo "masquerade rule missing" ;;
    F6) echo "DHCP pool too small for a new device" ;;
    F7) echo "guest isolation rule missing" ;;
    *) return 1 ;;
  esac
}

# draw SEED: print three different faults that may be combined. Same seed, same answer.
draw() {
  local state tries=0 pick other bad
  local picks=()
  state="$(printf '%s' "$1" | cksum | cut -d' ' -f1)"
  while [ "${#picks[@]}" -lt 3 ]; do
    state=$(( (state * 1103515245 + 12345) % 2147483648 ))
    pick="F$(( (state / 65536) % 7 + 1 ))"
    tries=$((tries + 1))
    [ "$tries" -le 500 ] || die "could not draw three faults for this seed. Try another seed."
    if [[ " ${picks[*]:-} " == *" $pick "* ]]; then
      continue
    fi
    bad=0
    for other in $(conflicts_of "$pick"); do
      if [[ " ${picks[*]:-} " == *" $other "* ]]; then
        bad=1
      fi
    done
    if [ "$bad" -eq 0 ]; then
      picks+=("$pick")
    fi
  done
  printf '%s\n' "${picks[@]}" | sort | tr '\n' ' ' | sed 's/ $//'
  echo
}

SEED=""
LIST=0
ONLY=""
REBUILD=1
while [ $# -gt 0 ]; do
  case "$1" in
    --list) LIST=1 ;;
    --no-rebuild) REBUILD=0 ;;
    --only) shift; ONLY="${1:?--only needs a list like F1,F4}" ;;
    -*) die "unknown option $1. Read the top of break.sh." ;;
    *) SEED="$1" ;;
  esac
  shift
done

if [ "$LIST" -eq 1 ]; then
  [ -n "$SEED" ] || die "--list needs a seed: bash break.sh --list SEED"
  FAULTS="$(draw "$SEED")"
  echo "Seed '$SEED' picks: $FAULTS"
  for f in $FAULTS; do
    echo "  $f $(fault_name "$f")"
  done
  exit 0
fi

if [ -n "$ONLY" ]; then
  FAULTS="$(echo "$ONLY" | tr ',' ' ' | tr -s ' ')"
  for f in $FAULTS; do
    fault_name "$f" > /dev/null || die "unknown fault $f in --only"
  done
else
  [ -n "$SEED" ] || die "give a seed: bash break.sh SEED   (any word or number)"
  FAULTS="$(draw "$SEED")"
fi

require_root

# ---- helpers used by the injections ----

# find_rule PATTERN: print "FAMILY TABLE CHAIN HANDLE" for the first rule in the home router that matches PATTERN.
# It skips the table that fault F4 adds.
find_rule() {
  local listing
  listing="$(ip netns exec hrouter nft -a list ruleset)"
  awk -v pat="$1" '
    $1 == "table" { fam = $2; tbl = $3 }
    $1 == "chain" { ch = $2 }
    tbl != "fault4" && !done && $1 != "table" && $1 != "chain" && $0 ~ pat && $0 ~ /# handle [0-9]+$/ {
      print fam, tbl, ch, $NF
      done = 1
    }
  ' <<< "$listing"
}

delete_rule() {
  local fam tbl ch handle
  read -r fam tbl ch handle <<< "$(find_rule "$1")"
  [ -n "${handle:-}" ] || die "could not find a rule matching '$1' in the home router. $2"
  ip netns exec hrouter nft delete rule "$fam" "$tbl" "$ch" handle "$handle"
}

HOOK=""
lease_attempt() {
  local ns="$1" requests="$2" seconds="$3"
  [ -n "$HOOK" ] || HOOK="$(udhcpc_hook_path)"
  NS_NAME="$ns" ip netns exec "$ns" busybox udhcpc -i "$(first_if "$ns")" -s "$HOOK" -n -q -t "$requests" -T "$seconds" > /dev/null 2>&1
}

# ---- the seven injections ----

inject_F1() {
  local dev
  dev="$(first_if homeweb)"
  ip netns exec homeweb ip addr flush dev "$dev"
  ip netns exec homeweb ip addr add 192.168.1.20/28 dev "$dev"
}

inject_F2() {
  ip netns exec hrouter sysctl -qw net.ipv4.ip_forward=0
}

inject_F3() {
  ip netns exec hrouter ip route del default
}

inject_F4() {
  ip netns exec hrouter nft -f - <<'RULES'
table ip fault4 {
  chain input {
    type filter hook input priority 0 ; policy accept ;
    udp dport 53 drop
    tcp dport 53 drop
  }
}
RULES
}

inject_F5() {
  delete_rule masquerade "Your NAT rule must use the word masquerade."
}

inject_F6() {
  local conf="$PART3/dnsmasq.conf" leases
  [ -f "$conf" ] || die "$conf is missing"
  cp "$conf" "$CONF_BACKUP"
  sed -i -E '/^dhcp-range=.*192\.168\.1\.100,/ s/192\.168\.1\.150/192.168.1.101/' "$conf"
  grep -q '192\.168\.1\.100,192\.168\.1\.101' "$conf" \
    || die "could not shrink the home pool. Your dnsmasq.conf needs a dhcp-range line with 192.168.1.100,192.168.1.150"
  leases="$(sed -n 's/^dhcp-leasefile=//p' "$conf" | head -n 1)"
  stop_proc dnsmasq
  rm -f "${leases:-/var/lib/misc/dnsmasq.leases}"
  bg_start dnsmasq hrouter dnsmasq --keep-in-foreground --conf-file="$conf"
  sleep 3
  # Two devices take the two addresses that are left. Then a third device is plugged in.
  lease_attempt home1 5 2 || true
  lease_attempt home2 5 2 || true
  local bridge
  bridge="$(if_with_addr hrouter 192.168.1.1)"
  # Pin the bridge's own hardware address first. A bridge without one takes the lowest address of its
  # ports, so plugging a device in or out could change the router's address under the other devices.
  ip netns exec hrouter ip link set dev "$bridge" address "$(ip netns exec hrouter cat "/sys/class/net/$bridge/address")"
  ns_add home3
  cable_if home3 veth-home3 hrouter veth-rhome3
  ip netns exec hrouter ip link set veth-rhome3 master "$bridge"
  lease_attempt home3 3 1 || true
}

inject_F7() {
  delete_rule drop "Your guest isolation rule must use the word drop."
}

# ---- go ----

if [ "$REBUILD" -eq 1 ]; then
  SCRIPT="$PART3/dhcp-and-dns.sh"
  [ -f "$SCRIPT" ] || die "your part 3 script is missing: $SCRIPT. Build parts 1 to 3 first."
  echo "--- rebuilding the healthy network with your part 3 script"
  if ! bash "$SCRIPT" > /tmp/networking-course-rebuild.log 2>&1; then
    cat /tmp/networking-course-rebuild.log
    die "your part 3 script failed. Make the part 3 test pass first."
  fi
fi

for f in $FAULTS; do
  "inject_$f"
done

if [ -z "$ONLY" ]; then
  echo "$SEED" > "$HERE/fault-seed.txt"
  echo "Seed '$SEED' is saved in fault-seed.txt. Put it in your write-up."
fi
echo "The faults are now in the network. Find each one from evidence: run the tests, read the errors,"
echo "and use the commands in faults.md. Write down every command you run and what it showed."
