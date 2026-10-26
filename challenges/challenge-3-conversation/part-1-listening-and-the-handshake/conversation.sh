#!/usr/bin/env bash
# Challenge 3, part 1: where a server listens, and the handshake.
# Run it in the lab:  bash conversation.sh
# Safe to run again: it deletes the old network first.
# Four things are missing on purpose. Each gap is marked TODO. Fill them in, then run:  bash test.sh
# The script writes five evidence files next to itself: listen-loopback.txt, listen-all.txt,
# handshake.txt, connected-laptop.txt and connected-server.txt. The test reads them.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

# The folder with the web page the server will serve.
WWW=/tmp/networking-course-www-conversation

# Step 1: delete anything this course built before.
teardown_all

# Step 2: two computers on one cable, as in challenge 1.
ns_add laptop
ns_add server
cable laptop server
in_ns laptop ip addr add 192.168.1.23/24 dev veth-laptop
in_ns server ip addr add 192.168.1.80/24 dev veth-server
www_make "$WWW" "hello from the server"

# start_server ADDRESS: run a tiny web server in the server computer. It listens on ADDRESS, port 8080.
# It stops the old server first, so you can call it again with a different address.
start_server() {
  local address="$1"
  stop_proc web
  # TODO 1: Start the web server inside the namespace "server", in the background. It must listen on $address, port 8080.
  #   The program is  busybox httpd  and it needs three things:
  #     -f              stay in the foreground (so we can run it in the background ourselves and remember it)
  #     -p ADDRESS:PORT where to listen
  #     -h FOLDER       the folder with the web page. Use $WWW
  #   Shape of the command: bg_start NAME NAMESPACE PROGRAM...    Use the name  web  (the line above, stop_proc web, needs it).
  sleep 1
}

# save_listening FILE: write the server's list of listening sockets into FILE.
save_listening() {
  local file="$1"
  # TODO 2: Ask the server computer which sockets are listening for TCP, and save the answer in $file.
  #   The tool is  ss  and it needs four letters: -t for TCP, -l for listening, -n for numbers, -p for the program name.
  #   Shape of the command: ip netns exec NAMESPACE ss -tlnp > FILE
  cat "$file" 2>/dev/null || echo "(nothing saved yet. Fill in Gap 2.)"
}

# save_connections: write the open conversations, as each side sees them, into two files.
save_connections() {
  # TODO 3: Ask BOTH computers for their open TCP conversations. Use  ss -tn  (no -l: that is only for listening sockets).
  #   Save the laptop's answer in $HERE/connected-laptop.txt and the server's answer in $HERE/connected-server.txt.
  #   Shape of each command: ip netns exec NAMESPACE ss -tn > FILE
  echo "laptop sees:"
  cat "$HERE/connected-laptop.txt" 2>/dev/null || echo "(nothing saved yet. Fill in Gap 3.)"
  echo "server sees:"
  cat "$HERE/connected-server.txt" 2>/dev/null || echo "(nothing saved yet. Fill in Gap 3.)"
}

# Step 3: the server listens on 127.0.0.1 only. 127.0.0.1 means "this computer itself".
echo "--- 3. the server listens on 127.0.0.1 only"
start_server 127.0.0.1
save_listening "$HERE/listen-loopback.txt"
RC=0
ip netns exec laptop curl -sS -m 3 -o /dev/null http://192.168.1.80:8080/ || RC=$?
echo "curl from the laptop exited with $RC. Exit code 7 means curl could not connect. Here that is a refused connection: nothing listens on that address and port."

# Step 4: the server listens on 0.0.0.0. 0.0.0.0 means "any address this computer has".
echo "--- 4. the server listens on 0.0.0.0"
start_server 0.0.0.0
save_listening "$HERE/listen-all.txt"
ip netns exec laptop curl -sS -m 3 http://192.168.1.80:8080/ || echo "curl failed (exit $?). Is the server running? Check Gap 1."

# Step 5: watch the handshake. Start the capture first, then make the connection.
# tcpdump stops by itself after 3 packets: SYN, SYN-ACK, ACK.
echo "--- 5. the handshake"
# TODO 4: Capture the handshake on the server's side of the cable, and save it in $HERE/handshake.txt.
#   Run tcpdump inside the namespace "server". It needs:
#     -n                numbers, not names
#     -i veth-server    the plug to watch
#     -c 3              stop after 3 packets
#     tcp port 8080     only this conversation (the filter keeps ARP and IPv6 chatter out)
#   Save the output with  > "$HERE/handshake.txt" 2>&1  and put it in the background with  &  at the end,
#   because the capture must be running while curl runs on the next lines. Wrap it in  timeout 10  as a safety stop.
sleep 1
ip netns exec laptop curl -sS -m 3 -o /dev/null http://192.168.1.80:8080/ || echo "curl failed (exit $?). Is the server running? Check Gap 1."
sleep 2
cat "$HERE/handshake.txt" 2>/dev/null || echo "(no capture yet. Fill in Gap 4.)"

# Step 6: keep one conversation open for a few seconds, then look at it from both sides.
# nc connects and then says nothing. The server waits, so the conversation stays open.
echo "--- 6. one open conversation, seen from both sides"
( sleep 8 | timeout 9 ip netns exec laptop nc 192.168.1.80 8080 ) > /dev/null 2>&1 &
sleep 2
save_connections

echo "Done. The server is still listening on 0.0.0.0:8080. Next: bash test.sh"
