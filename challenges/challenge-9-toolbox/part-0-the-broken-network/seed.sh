#!/usr/bin/env bash
# seed.sh: turn your seed into the numbers of challenge 9. Source it. Do not run it.
#
# Every learner gets different numbers: a different loss, name, address, port, speed and capture.
# The same seed always gives the same numbers, so a mentor can repeat your run.
# The tests use these functions too. They compare your answers with the numbers of YOUR seed.
#
#   ch9_seed                  print the seed saved in fault-seed.txt (empty if there is none)
#   ch9_values SEED ROUND     set the fault numbers for round 1 or round 2:
#                               V_LOSS   loss on the link between r1 and r2, in percent
#                               V_NAME   the name that the campus resolver answers wrongly
#                               V_WRONG  the wrong address it gives
#                               V_PORT   the port of the app on the server
#                               V_RATE   the speed limit on the link to the server, in Mbit/s
#   ch9_round2_picks SEED     print the two faults that round 2 plants, for example "1 3"
#   ch9_capture_values SEED   set the numbers of the part 1 capture:
#                               C_PORT     the source port of the laptop's first web visit
#                               C_TTL      the starting TTL of the server's packets
#                               C_VISITS   how many web visits the capture holds

CH9_PART0="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CH9_SEED_FILE="$CH9_PART0/fault-seed.txt"
CH9_STATE=/tmp/networking-course-ch9
CH9_NAMES=(shop docs news mail)

ch9_seed() {
  if [ -s "$CH9_SEED_FILE" ]; then
    head -n 1 "$CH9_SEED_FILE" | tr -d '\r'
  fi
}

# ch9_num SEED KEY MIN MAX: one number between MIN and MAX. The same SEED and KEY always give the same number.
ch9_num() {
  local h
  h="$(printf '%s|%s' "$1" "$2" | cksum | cut -d' ' -f1)"
  echo $(( $3 + h % ($4 - $3 + 1) ))
}

ch9_values() {
  local seed="${1:?ch9_values needs a seed}" round="${2:-1}"
  V_LOSS="$(ch9_num "$seed" "r$round-loss" 8 15)"
  V_NAME="${CH9_NAMES[$(ch9_num "$seed" "r$round-name" 0 3)]}.lab.test"
  V_WRONG="203.0.113.$(ch9_num "$seed" "r$round-wrong" 100 199)"
  V_PORT="$(ch9_num "$seed" "r$round-port" 7000 7999)"
  V_RATE="$(ch9_num "$seed" "r$round-rate" 5 15)"
}

ch9_round2_picks() {
  local pairs=("1 2" "1 3" "1 4" "2 3" "2 4" "3 4")
  echo "${pairs[$(ch9_num "${1:?ch9_round2_picks needs a seed}" round2-picks 0 5)]}"
}

ch9_capture_values() {
  local seed="${1:?ch9_capture_values needs a seed}"
  C_PORT="$(ch9_num "$seed" capture-port 40000 49000)"
  C_TTL="$(ch9_num "$seed" capture-ttl 40 120)"
  # 64 is the usual starting TTL. Skip it, so that the answer always needs reading.
  [ "$C_TTL" -ne 64 ] || C_TTL=65
  C_VISITS="$(ch9_num "$seed" capture-visits 2 4)"
}

# faults.sh writes what is in the network now: "1", "2", "clean" or "only 1 4". "none" if it never ran.
ch9_current_round() {
  cat "$CH9_STATE/round" 2>/dev/null || echo none
}

# ---- helpers for the test.sh files of challenge 9 ----

# md_section FILE HEADING: print the lines under the heading that starts with HEADING (any level),
# up to the next heading of the same level or higher.
md_section() {
  awk -v h="$2" '
    /^#+ / {
      level = index($0, " ") - 1
      text = substr($0, level + 2)
      if (on && level <= onlevel) { on = 0 }
      if (!on && !done && index(text, h) == 1) { on = 1; onlevel = level; done = 1; next }
    }
    on { print }
  ' "$1" 2>/dev/null || true
}

# md_field TEXT LABEL: the value of a line "- LABEL: value", with backticks taken away.
md_field() {
  awk -v l="- $2:" 'index($0, l) == 1 && !done { print substr($0, length(l) + 1); done = 1 }' <<< "$1" \
    | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^`//' -e 's/`$//'
}

# is_unfilled VALUE: true if VALUE is empty or still a <placeholder>.
is_unfilled() {
  [ -z "$1" ] || grep -q '<.*>' <<< "$1"
}

# mtr_rows TEXT: one line "HOP HOST LOSS" for each row of an mtr report in TEXT.
mtr_rows() {
  sed -n -E 's/^[[:space:]]*`?[[:space:]]*([0-9]+)\.[[:space:]]*\|--[[:space:]]+([0-9.]+)[[:space:]]+([0-9.]+)%.*/\1 \2 \3/p' <<< "$1"
}

# to_mbits LINE: the bitrate in an iperf3 line, in Mbit/s (empty if there is none).
to_mbits() {
  sed -n -E 's/.*[[:space:]]([0-9.]+) ([KMG])bits\/sec.*/\1 \2/p' <<< "$1" | head -n 1 \
    | awk '{ v = $1; if ($2 == "K") v = v / 1000; if ($2 == "G") v = v * 1000; print v }'
}

# num_ge A B: true if the number A is at least B.  num_gt A B: true if A is more than B.
num_ge() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a + 0 >= b + 0) }'; }
num_gt() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a + 0 > b + 0) }'; }

# fault_matches N LINE: true if LINE is the output line that proves fault N, with the numbers in V_*.
# It sets WHY to a short reason when it is not.
fault_matches() {
  local n="$1" line="$2" row hop host loss mbits
  WHY=""
  case "$n" in
    1)
      row="$(mtr_rows "$line" | head -n 1)"
      if [ -z "$row" ]; then
        WHY="it is not a row of an mtr report (it should look like: 2.|-- 198.51.100.2  12.0%  50 ...)"
        return 1
      fi
      read -r hop host loss <<< "$row"
      if [ "$host" = "192.0.2.1" ]; then
        WHY="it is the row of hop 1. Loss at one hop only can be the router limiting its own replies. Quote a hop after the lossy link"
        return 1
      fi
      if [ "$host" != "198.51.100.2" ] && [ "$host" != "203.0.113.80" ]; then
        WHY="the host $host is not on the path from the laptop to the server"
        return 1
      fi
      if ! num_gt "$loss" 0; then
        WHY="it shows 0% loss"
        return 1
      fi
      ;;
    2)
      if ! grep -qE "(^|[^0-9.])${V_WRONG//./\.}([^0-9]|$)" <<< "$line"; then
        WHY="it does not show the wrong address the campus resolver gives for $V_NAME"
        return 1
      fi
      ;;
    3)
      if ! grep -qE "(^|[^0-9])$V_PORT/tcp[[:space:]]+filtered" <<< "$line"; then
        WHY="it should be the nmap line of the app's port, $V_PORT, with the state filtered"
        return 1
      fi
      ;;
    4)
      mbits="$(to_mbits "$line")"
      if [ -z "$mbits" ] || ! grep -q 'receiver' <<< "$line"; then
        WHY="it should be the iperf3 line that ends with receiver"
        return 1
      fi
      if ! num_ge "$mbits" "$(awk -v r="$V_RATE" 'BEGIN { print r * 0.5 }')" \
        || ! num_ge "$(awk -v r="$V_RATE" 'BEGIN { print r * 1.1 }')" "$mbits"; then
        WHY="its speed, $mbits Mbit/s, is not near the speed limit of the slow link"
        return 1
      fi
      ;;
    *) WHY="there is no fault $n"; return 1 ;;
  esac
  return 0
}

# fault_tool N: the tool that is best for fault N.
fault_tool() {
  case "$1" in
    1) echo mtr ;;
    2) echo dig ;;
    3) echo nmap ;;
    4) echo iperf3 ;;
  esac
}

# check_fault_entry N: check the "Fault N" entry of round 1 in faults.md. One PASS or FAIL line.
check_fault_entry() {
  local n="$1" file="$CH9_PART0/faults.md" entry tool cmd line want
  want="$(fault_tool "$n")"
  entry="$(md_section "$file" "Fault $n")"
  tool="$(md_field "$entry" Tool)"
  cmd="$(md_field "$entry" Command)"
  line="$(md_field "$entry" "Output line")"
  if is_unfilled "$tool" || is_unfilled "$cmd" || is_unfilled "$line"; then
    t_fail "faults.md, Fault $n: fill in Tool, Command and Output line (in part-0-the-broken-network/faults.md)"
    return
  fi
  if ! grep -qi "$want" <<< "$tool" || ! grep -q "$want" <<< "$cmd"; then
    t_fail "faults.md, Fault $n: this fault is found with $want. Tool and Command should both name it. Tool: '$tool' Command: '$cmd'"
    return
  fi
  if fault_matches "$n" "$line"; then
    t_pass "faults.md, Fault $n: the output line proves the fault your seed planted"
  else
    t_fail "faults.md, Fault $n: the output line does not prove it: $WHY. Line: '$line'"
  fi
}
