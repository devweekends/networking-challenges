#!/usr/bin/env bash
# Test for challenge 3, part 1. Run it in the lab AFTER you ran:  bash conversation.sh
# When a check fails, the message says which GAP in conversation.sh to look at.
# Must pass: with the server on 0.0.0.0, curl from the laptop works, and your evidence files are right:
#   the handshake (SYN, SYN-ACK, ACK) and both sides of one open conversation.
# Must fail on purpose: with the server on 127.0.0.1, the same curl is refused (exit code 7).
# The test restarts the server twice. It leaves the server listening on 0.0.0.0 at the end.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

WWW=/tmp/networking-course-www-conversation

# test_server ADDRESS: stop every server we know about, then start one on ADDRESS port 8080
test_server() {
  stop_all_procs
  bg_start web server busybox httpd -f -p "$1:8080" -h "$WWW"
  sleep 1
}

# The two computers must exist.
if ns_exists laptop && ns_exists server; then
  t_pass "namespaces laptop and server exist"
else
  t_fail "namespaces laptop and server are missing. Run: bash conversation.sh"
  t_done
fi

# Gap 1: the server listens on 0.0.0.0, port 8080, after the script.
LISTENING="$(ip netns exec server ss -tln 2>/dev/null || true)"
if awk '$1 == "LISTEN" && $4 == "0.0.0.0:8080" { found = 1 } END { exit !found }' <<< "$LISTENING"; then
  t_pass "GAP 1: the server listens on 0.0.0.0:8080"
else
  t_fail "GAP 1: nothing listens on 0.0.0.0:8080 in the server computer. Run: ip netns exec server ss -tln"
fi

# Must pass: curl from the laptop.
try_curl laptop http://192.168.1.80:8080/
if [ "$RC" -eq 0 ] && grep -q 'hello from the server' <<< "$OUT"; then
  t_pass "curl from the laptop to 192.168.1.80:8080 works"
else
  t_fail "curl from the laptop to 192.168.1.80:8080 failed (exit $RC). If it says refused, the server is not listening on 0.0.0.0. Curl said: $OUT"
fi

# Gap 2: the listening sockets, saved by the script.
if [ ! -s "$HERE/listen-loopback.txt" ] || [ ! -s "$HERE/listen-all.txt" ]; then
  t_fail "GAP 2: listen-loopback.txt or listen-all.txt is missing or empty. Fill in the gap in save_listening, then run bash conversation.sh again"
else
  if grep -qF '127.0.0.1:8080' "$HERE/listen-loopback.txt" && ! grep -qF '0.0.0.0:8080' "$HERE/listen-loopback.txt"; then
    t_pass "GAP 2: listen-loopback.txt shows the server on 127.0.0.1:8080 only"
  else
    t_fail "GAP 2: listen-loopback.txt should show 127.0.0.1:8080 and not 0.0.0.0:8080. It has: $(cat "$HERE/listen-loopback.txt")"
  fi
  if grep -qF '0.0.0.0:8080' "$HERE/listen-all.txt"; then
    t_pass "GAP 2: listen-all.txt shows the server on 0.0.0.0:8080"
  else
    t_fail "GAP 2: listen-all.txt should show 0.0.0.0:8080. It has: $(cat "$HERE/listen-all.txt")"
  fi
fi

# Gap 3: both sides of one open conversation. The same four numbers, mirrored.
if [ ! -s "$HERE/connected-laptop.txt" ] || [ ! -s "$HERE/connected-server.txt" ]; then
  t_fail "GAP 3: connected-laptop.txt or connected-server.txt is missing or empty. Fill in the gap in save_connections, then run bash conversation.sh again"
else
  LAPTOP_PORT="$(awk '$1 == "ESTAB" && $5 == "192.168.1.80:8080" { n = split($4, a, ":"); print a[n]; exit }' "$HERE/connected-laptop.txt")"
  if [ -z "$LAPTOP_PORT" ]; then
    t_fail "GAP 3: connected-laptop.txt has no ESTAB line to 192.168.1.80:8080. Use ss -tn (no -l) and run it while the conversation is open. It has: $(cat "$HERE/connected-laptop.txt")"
  elif awk -v p="$LAPTOP_PORT" '$1 == "ESTAB" && $4 == "192.168.1.80:8080" && $5 == ("192.168.1.23:" p) { found = 1 } END { exit !found }' "$HERE/connected-server.txt"; then
    t_pass "GAP 3: the laptop says 192.168.1.23:$LAPTOP_PORT to 192.168.1.80:8080, the server says the same numbers the other way round"
  else
    t_fail "GAP 3: the server's file should show 192.168.1.80:8080 with peer 192.168.1.23:$LAPTOP_PORT. It has: $(cat "$HERE/connected-server.txt")"
  fi
fi

# Gap 4: the handshake, saved by the script.
if [ ! -s "$HERE/handshake.txt" ]; then
  t_fail "GAP 4: handshake.txt is missing or empty. Fill in the capture gap, then run bash conversation.sh again"
else
  FLAGS="$(grep -F 'Flags [' "$HERE/handshake.txt" || true)"
  FIRST="$(sed -n 1p <<< "$FLAGS")"
  SECOND="$(sed -n 2p <<< "$FLAGS")"
  THIRD="$(sed -n 3p <<< "$FLAGS")"
  if grep -qF 'Flags [S],' <<< "$FIRST" && grep -qF 'Flags [S.],' <<< "$SECOND" && grep -qF 'Flags [.],' <<< "$THIRD"; then
    t_pass "GAP 4: handshake.txt shows SYN, SYN-ACK, ACK in that order"
  else
    t_fail "GAP 4: handshake.txt should hold three lines with Flags [S], then [S.], then [.]. It has: $(cat "$HERE/handshake.txt")"
  fi
  if grep -qE '192\.168\.1\.23\.[0-9]+ > 192\.168\.1\.80\.8080: Flags \[S\]' "$HERE/handshake.txt" \
     && grep -qE '192\.168\.1\.80\.8080 > 192\.168\.1\.23\.[0-9]+: Flags \[S\.\]' "$HERE/handshake.txt"; then
    t_pass "GAP 4: the SYN goes laptop to server:8080, the SYN-ACK comes back"
  else
    t_fail "GAP 4: expected '192.168.1.23.PORT > 192.168.1.80.8080: Flags [S]' then the answer. Capture was: $(cat "$HERE/handshake.txt")"
  fi
fi

# Must fail on purpose: the server listens on 127.0.0.1 only. The laptop is refused.
test_server 127.0.0.1
LISTENING="$(ip netns exec server ss -tln 2>/dev/null || true)"
if awk '$1 == "LISTEN" && $4 == "127.0.0.1:8080" { found = 1 } END { exit !found }' <<< "$LISTENING"; then
  t_pass "the test server listens on 127.0.0.1:8080"
else
  t_fail "the test server did not start on 127.0.0.1:8080. Log: $(cat "$NET_PID_DIR/web.log" 2>/dev/null || true)"
fi
try_curl laptop -o /dev/null http://192.168.1.80:8080/
if [ "$RC" -eq 7 ] && [ "$ELAPSED" -lt 3 ]; then
  t_pass "with the server on 127.0.0.1, curl from the laptop is refused at once (exit 7)"
else
  t_fail "with the server on 127.0.0.1, curl should exit 7 at once. It exited $RC after $ELAPSED seconds. Curl said: $OUT"
fi

# Put the server back on 0.0.0.0, as the script left it.
test_server 0.0.0.0
try_curl laptop http://192.168.1.80:8080/
if [ "$RC" -eq 0 ]; then
  t_pass "server is back on 0.0.0.0 and the laptop reaches it again"
else
  t_fail "the server did not come back on 0.0.0.0. Curl said: $OUT"
fi

t_done
