#!/usr/bin/env bash
# Challenge 9: build the lab network and plant faults in it.
#
#   bash faults.sh                  round 1: build the network, then plant all four faults
#   bash faults.sh --seed WORD      the same, with your own seed (any word, for example your name)
#   bash faults.sh --round 2        the blind round: build again, then plant two of the four, with new numbers
#   bash faults.sh --clean          build the network with no faults (to see what "healthy" looks like)
#   bash faults.sh --only 1,4       (mentor) plant only these faults, with the round 1 numbers
#   bash faults.sh --list           (mentor) print the numbers of your seed and the round 2 pick. Changes nothing
#
# The seed: --seed WORD if you give one. If not, the seed in fault-seed.txt. If there is none,
# your git user name (when git is installed), else a random word. It is saved in fault-seed.txt.
# The same seed always gives the same faults and numbers, so a mentor can repeat your run.
# Do not use --list on your own run: it prints the answers.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
source "$HERE/seed.sh"

SEED=""
MODE=round1
ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --seed) shift; SEED="${1:?--seed needs a word}" ;;
    --round)
      shift
      case "${1:-}" in
        1) MODE=round1 ;;
        2) MODE=round2 ;;
        *) die "--round needs 1 or 2" ;;
      esac
      ;;
    --clean) MODE=clean ;;
    --only) shift; MODE=only; ONLY="$(echo "${1:?--only needs a list like 1,4}" | tr ',' ' ')" ;;
    --list) MODE=list ;;
    *) die "unknown option $1. Read the top of faults.sh." ;;
  esac
  shift
done

# Choose the seed, and save it.
if [ -z "$SEED" ]; then
  SEED="$(ch9_seed)"
fi
if [ -z "$SEED" ] && command -v git > /dev/null 2>&1; then
  SEED="$(git config user.name 2>/dev/null | tr -s ' ' '-' || true)"
fi
if [ -z "$SEED" ]; then
  SEED="seed-$(od -An -N3 -tu4 /dev/urandom | tr -d ' ')"
fi
if [ "$(ch9_seed)" != "$SEED" ]; then
  echo "$SEED" > "$CH9_SEED_FILE"
fi

if [ "$MODE" = list ]; then
  for r in 1 2; do
    ch9_values "$SEED" "$r"
    echo "Seed '$SEED', round $r: loss ${V_LOSS}% on r1 to r2; $V_NAME answers $V_WRONG at the campus resolver;" \
      "app port $V_PORT filtered; ${V_RATE} Mbit/s limit on r2 to the server"
  done
  echo "Round 2 plants faults: $(ch9_round2_picks "$SEED")"
  ch9_capture_values "$SEED"
  echo "Part 1 capture: first source port $C_PORT, server TTL $C_TTL (it arrives as $((C_TTL - 2))), $C_VISITS web visits"
  exit 0
fi

require_root

ROUND=1
FAULTS="1 2 3 4"
case "$MODE" in
  round2) ROUND=2; FAULTS="$(ch9_round2_picks "$SEED")" ;;
  clean) FAULTS="" ;;
  only) FAULTS="$ONLY" ;;
esac
for f in $FAULTS; do
  case "$f" in 1|2|3|4) ;; *) die "unknown fault $f. Faults are 1, 2, 3 and 4." ;; esac
done
ch9_values "$SEED" "$ROUND"

# ---- the four faults ----

# Fault 1: the cable from r1 to r2 loses some packets.
plant_1() {
  in_ns r1 tc qdisc replace dev veth-r1wan root netem loss "${V_LOSS}%"
}

# Fault 2: the campus resolver gives a wrong address for one name.
plant_2() {
  echo "address=/$V_NAME/$V_WRONG" >> "$CH9_STATE/campus-dns.conf"
  bg_start campus-dns r1 dnsmasq --keep-in-foreground --conf-file="$CH9_STATE/campus-dns.conf"
  sleep 1
}

# Fault 3: r2 drops every packet to the app's port. It sends no answer at all.
plant_3() {
  in_ns r2 nft -f - <<EOF
table inet fault3 {
  chain forward {
    type filter hook forward priority 0 ; policy accept ;
    tcp dport $V_PORT drop
  }
}
EOF
}

# Fault 4: the cable from r2 to the server sends at most V_RATE Mbit/s. It loses nothing: packets wait in a queue.
plant_4() {
  in_ns r2 tc qdisc replace dev veth-r2srv root netem rate "${V_RATE}mbit"
}

# ---- go ----

echo "--- building the lab network"
bash "$HERE/build.sh" --round "$ROUND" > "$CH9_STATE.build.log" 2>&1 || { cat "$CH9_STATE.build.log" >&2; die "build.sh failed. Its output is above."; }
for f in $FAULTS; do
  "plant_$f"
done
case "$MODE" in
  round1|round2) echo "$ROUND" > "$CH9_STATE/round" ;;
  clean) echo clean > "$CH9_STATE/round" ;;
  only) echo "only $FAULTS" > "$CH9_STATE/round" ;;
esac

cat <<EOF
--- seed '$SEED' (saved in fault-seed.txt)

What should be true in this network (the service sheet):
  www.lab.test, shop.lab.test, docs.lab.test, news.lab.test and mail.lab.test all mean 203.0.113.80.
  The laptop asks the campus resolver, 192.0.2.1. The public resolver is 203.0.113.53.
  The server has a web page on port 80, the app on port $V_PORT, and an iperf3 server on port 5201.
  Every cable is virtual. It carries more than 1 Gbit/s and loses nothing.

EOF
case "$MODE" in
  round1)
    cat <<EOF
Four faults are planted. What people say:
  "Copying a file to the server is slow."  (two different faults make this complaint)
  "$V_NAME does not load for me. www.lab.test works."
  "The app on port $V_PORT does not answer."
Write a best guess for each one in faults.md before you start part 1.
EOF
    ;;
  round2)
    echo "The blind round: two of the four kinds of fault are planted, with new numbers. Which two? Find out."
    ;;
  clean) echo "No faults are planted. This is the healthy network." ;;
  only) echo "Planted only: $FAULTS" ;;
esac
