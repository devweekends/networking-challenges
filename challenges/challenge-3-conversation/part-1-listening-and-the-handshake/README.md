# Challenge 3, part 1: listening and the handshake

Goal: run a web server in one computer, and connect to it from another. See what the server's listening address changes. Capture the three packets that start a TCP conversation. Then read the same conversation from both sides with `ss`.

The addresses here (`192.168.1.23` and `192.168.1.80`) belong to the lab only.

This part is **gapped**. The script `conversation.sh` is almost complete. Four small things are missing, and each is marked `TODO`. The test tells you which one is wrong.

## 101: words you need

| Word | Plain meaning |
|---|---|
| Port | A number from 1 to 65535 that names one app on a computer. The address finds the computer. The port finds the app |
| Server | A program that waits for others to connect to it. Here, a tiny web server on port `8080` |
| Client | A program that starts the conversation. Here, `curl` |
| Listening | A server is waiting at one address and port. It is a promise: "I will answer here" |
| `127.0.0.1` | Loopback. It means "this computer itself". Nobody on another computer can use it to reach you |
| `0.0.0.0` | "Any address this computer has." A server that listens here can be reached from outside |
| Socket | One end of a conversation: an address and a port |
| Handshake | The three packets that start a TCP conversation. SYN, then SYN-ACK, then ACK |
| SYN | "I want to talk." The first packet. tcpdump shows it as `Flags [S]` |
| SYN-ACK | "OK, I heard you. Do you hear me?" tcpdump shows `Flags [S.]` |
| ACK | "Yes." The third packet. tcpdump shows `Flags [.]` |
| Connection refused | The computer got your SYN, and nothing was listening there. It answers at once with a "no" (an RST packet). `curl` exits with code `7` |
| `ss` | A tool that lists sockets. `-t` is TCP, `-l` is listening, `-n` is numbers, `-p` is the program name |
| ESTAB | A conversation that is open. Both sides have finished the handshake |

## What you build

```
  laptop                              server
  192.168.1.23/24 --- one cable ---   192.168.1.80/24
  curl                                busybox httpd on port 8080
```

First the server listens on `127.0.0.1:8080`. The laptop is refused. Then the server listens on `0.0.0.0:8080`. The laptop gets the page.

Before you run anything, guess: when the server listens on `127.0.0.1`, does the laptop's `curl` hang, or does it fail at once? What do you think the server's computer does with the SYN?

## Steps

Run these **in the lab**. First:

```
cd /work/challenges/challenge-3-conversation/part-1-listening-and-the-handshake
```

| # | Type this | What it does | Script line |
|---|---|---|---|
| 1 | `bash conversation.sh` | Builds everything and runs every step below. Safe to run again. Until you fill the gaps, some steps print a note instead | whole file |
| 2 | (delete the old network) | Removes what the course built before | [lib.sh#L171](../../../toolkit/lib.sh#L171) |
| 3 | `ip netns add ...`, `ip addr add ...` | Two computers on one cable, with their addresses, as in challenge 1 | [conversation.sh#L21](conversation.sh#L21) |
| 4 | Gap 1 | Start the web server in the server computer, listening on the address you are given | [conversation.sh#L33-L38](conversation.sh#L33-L38) (inside [conversation.sh#L30](conversation.sh#L30)) |
| 5 | Gap 2 | Save the server's listening sockets with `ss` | [conversation.sh#L45-L47](conversation.sh#L45-L47) (inside [conversation.sh#L43](conversation.sh#L43)) |
| 6 | Gap 3 | Save the open conversations, from both computers | [conversation.sh#L53-L55](conversation.sh#L53-L55) (inside [conversation.sh#L52](conversation.sh#L52)) |
| 7 | the server on `127.0.0.1` | Start the server on loopback, save `ss`, then `curl` from the laptop. You should see exit code 7 | [conversation.sh#L63](conversation.sh#L63) |
| 8 | the server on `0.0.0.0` | Restart the server on any address, save `ss`, then `curl`. You should get `hello from the server` | [conversation.sh#L71](conversation.sh#L71) |
| 9 | Gap 4 | Capture the handshake on the server's side and save it. It runs in the background while `curl` makes one connection | [conversation.sh#L79-L86](conversation.sh#L79-L86) (inside [conversation.sh#L78](conversation.sh#L78)) |
| 10 | `nc` held open for a few seconds | One conversation stays open, so `ss -tn` can show it | [conversation.sh#L94](conversation.sh#L94) |
| 11 | `bash test.sh` | Checks all of the above and names the gap that is wrong | the gap checks start at [test.sh#L32](test.sh#L32) |

### What the files should show

`listen-loopback.txt` and `listen-all.txt` come from `ss -tlnp` in the server. Read the column **Local Address:Port**.

```
State   Recv-Q  Send-Q   Local Address:Port   Peer Address:Port  Process
LISTEN  0       9        127.0.0.1:8080       0.0.0.0:*          users:(("busybox",pid=123,fd=3))
```

The first file shows `127.0.0.1:8080`. The second shows `0.0.0.0:8080`. The server's promise changed. That is the whole difference.

`handshake.txt` shows three lines, in this order (the shape, not exact text):

1. `192.168.1.23.PORT > 192.168.1.80.8080: Flags [S], ...` the laptop says "I want to talk". `PORT` is a high number that Linux chose for the laptop's end.
2. `192.168.1.80.8080 > 192.168.1.23.PORT: Flags [S.], ...` the server says "OK, do you hear me?"
3. `192.168.1.23.PORT > 192.168.1.80.8080: Flags [.], ...` the laptop says "Yes".

`connected-laptop.txt` and `connected-server.txt` come from `ss -tn`. The same conversation shows up on both sides with the four numbers swapped:

| File | Local Address:Port | Peer Address:Port |
|---|---|---|
| connected-laptop.txt | `192.168.1.23:PORT` | `192.168.1.80:8080` |
| connected-server.txt | `192.168.1.80:8080` | `192.168.1.23:PORT` |

## Hints

Each gap has a ladder. Try the first step. Open the next one only if you are still stuck.

| Gap | Step 1: a nudge | Step 2: the name | Step 3: the shape of the command |
|---|---|---|---|
| 1 | Read the Local Address column. Who is the server promising to answer? | The program `busybox httpd`. Its `-p` option takes an address and a port | `bg_start web server busybox httpd -f -p ADDRESS:PORT -h FOLDER` |
| 2 | Which tool lists sockets? Which letters ask for listening ones? | `ss -tlnp` | `ip netns exec NAMESPACE ss -tlnp > FILE` |
| 3 | You want both sides of one conversation. Which computers? | `ss -tn` in the laptop and in the server | `ip netns exec NAMESPACE ss -tn > FILE`, twice |
| 4 | The capture must already be running when `curl` starts | `tcpdump` inside the server namespace, filter `tcp port 8080`, in the background | `timeout 10 ip netns exec NAMESPACE tcpdump -n -i INTERFACE -c 3 FILTER > FILE 2>&1 &` |

If you are stuck:

1. Is the server in the namespace you think? `ip netns exec server ss -tlnp`
2. Does `ping 192.168.1.80` work from the laptop? That is the layer below.
3. Is `tcpdump` running inside the `server` namespace and watching `veth-server`?
4. Did you wait for the old server to exit before you started the new one? `start_server` does that with `stop_proc web`. That only works if you named your server `web`.

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `192.168.1.23`, `192.168.1.80` | We chose them. A private range, like a home network |
| `8080` | We chose it. Ports below 1024 are for well-known services like web (`80`) and need extra rights on many systems. `8080` is a common choice for a test web server |
| `127.0.0.1` | The loopback address. Every computer has it |
| `0.0.0.0` | Means "all addresses". It is not an address you send to |
| exit code `7` | `curl` uses 7 for "could not connect". Refused is a fast 7. A silent drop would be a slow 28 (timed out) |
| `-c 3` in tcpdump | Stop after 3 packets: the handshake |
| `PORT` in the capture | Linux picks the laptop's port from a high range. See `/proc/sys/net/ipv4/ip_local_port_range` |
| `sleep 8` and `timeout 9` | Keep one conversation open for about 8 seconds, then close it |

## Results

Fill in [results.md](results.md). Commit it, and the five `.txt` files.

## Draft status (remove before publishing)

Tested (course notes, 2026-10-24 to 2026-10-26): `tcpdump` inside a server namespace, a server on `127.0.0.1` refusing a remote client with exit code 7 while one on `0.0.0.0` answers, `ss -tlnp` showing both, and a refused connection being a fast failure, not a timeout.
Untested: the exact bind syntax `busybox httpd -f -p 127.0.0.1:8080`, the `ss -tlnp` and `ss -tn` column layout the test reads, holding a conversation open with `nc` and a silent pipe, and `Flags [S],` followed by `[S.],` and `[.],` as the first three lines with the filter `tcp port 8080`. The loopback interface is switched on by `ns_add` (a change in `lib.sh`).
