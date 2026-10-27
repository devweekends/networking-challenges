# Challenge 4, part 1: a home router with masquerade

Goal: put two devices behind a router, give the router one rule that hides them behind its own address, and watch the router's NAT table. Then make both devices use the same source port and see what the server sees.

The addresses here belong to the lab only. `192.168.1.x` is a private range, like a home network. `203.0.113.x` is a range made for examples. It stands for "the internet".

This part is **gapped**. The script `masquerade.sh` is almost complete. Four small things are missing, and each is marked `TODO`. The test tells you which one is wrong. The first gap repeats what you did in challenge 2.

## 101: words you need

| Word | Plain meaning |
|---|---|
| NAT | Network Address Translation. A router rewrites the address in a packet as it passes |
| Masquerade | One kind of NAT. Every packet leaving by one interface gets that interface's address as its source |
| Source address | Who sent the packet. The server sees this and answers to it |
| Source port | The sender's port. A new conversation gets a fresh one, chosen by the sender |
| Private address | An address like `192.168.1.23` that the internet does not route. Many homes use the same ones |
| nftables, `nft` | The Linux tool for packet rules and rewriting |
| Table, chain, rule | nft keeps rules in chains, and chains in tables. A rule says: match this, then do that |
| Hook | The moment in a packet's trip when a chain runs. `postrouting` runs just before the packet leaves |
| NAT table (conntrack) | The router's memory of each conversation: the original, and what it was rewritten to. `conntrack -L` prints it |
| Clash | Two conversations that would look the same after rewriting. The router changes one port to keep them apart |
| Bridge | A virtual switch. Here it joins the laptop and the phone to the router's inside address |

## What you build

```
  laptop 192.168.1.23 --+
                        +-- br-home 192.168.1.1  [ router ]  203.0.113.1 -- cable -- 203.0.113.80 server
  phone  192.168.1.24 --+                          masquerade                         web server on :8080
```

The router has an inside address on the bridge `br-home` and an outside address on `veth-rout`. The server runs a tiny web page, `/cgi-bin/whoami`, that tells a visitor the address and port it sees.

Before you run anything, guess: when the laptop visits the server, which address does the server see? `192.168.1.23` or `203.0.113.1`?

## Steps

Run these **in the lab**. First:

```
cd /work/challenges/challenge-4-home-router/part-1-masquerade
```

| # | Type this | What it does | Script line |
|---|---|---|---|
| 1 | `bash masquerade.sh` | Builds everything and runs every step below. Safe to run again. `bash masquerade.sh build-only` stops before the experiment | whole file |
| 2 | (make four computers) | laptop, phone, router, server | [masquerade.sh#L21](masquerade.sh#L21) |
| 3 | `ip link add br-home type bridge`, two cables | The home side: a bridge in the router, the laptop and the phone plugged into it | [masquerade.sh#L28](masquerade.sh#L28) |
| 4 | one more cable | The outside: router to server | [masquerade.sh#L39](masquerade.sh#L39) |
| 5 | `busybox httpd` in the server | A tiny web server. Its page tells a visitor what address it sees | [masquerade.sh#L45](masquerade.sh#L45) |
| 6 | Gap 1 | Forwarding on in the router, a default route in each device | [masquerade.sh#L50-L55](masquerade.sh#L50-L55) |
| 7 | `ping` the server | Before masquerade there is no answer. The server cannot reach `192.168.1.23` | [masquerade.sh#L59](masquerade.sh#L59) |
| 8 | Gap 2 | The masquerade rule, in the `postrouting` chain | [masquerade.sh#L69-L71](masquerade.sh#L69-L71) (in [masquerade.sh#L65](masquerade.sh#L65)) |
| 9 | `curl` from each device | The mid-point check: a device reaches the server. You should see `the server sees you as 203.0.113.1:PORT` | [masquerade.sh#L77](masquerade.sh#L77) |
| 10 | Gap 3 | Both devices send from source port `41000` | [masquerade.sh#L91-L95](masquerade.sh#L91-L95) (in [masquerade.sh#L88](masquerade.sh#L88)) |
| 11 | Gap 4 | Read the NAT table with `conntrack -L` | [masquerade.sh#L98-L100](masquerade.sh#L98-L100) |
| 12 | `bash test.sh` | Checks all of the above and names the gap that is wrong | the gap checks start at [test.sh#L51](test.sh#L51) |
| 13 | the capture, below | You watch one conversation on both sides of the router | none |

### The capture

You want to see one conversation on the inside cable and on the outside cable. You have one terminal, so run both captures in the background with `&`.

```
cd /work/challenges/challenge-4-home-router/part-1-masquerade
ip netns exec router tcpdump -n -i br-home -c 3 tcp port 8080 > inside.txt 2>&1 &
ip netns exec router tcpdump -n -i veth-rout -c 3 tcp port 8080 > outside.txt 2>&1 &
sleep 1
ip netns exec laptop curl -s http://203.0.113.80:8080/cgi-bin/whoami
wait
cat inside.txt outside.txt
```

- `-i br-home` watches the home side. `-i veth-rout` watches the outside plug.
- `-c 3` stops after 3 packets: the handshake.
- `tcp port 8080` keeps ARP and IPv6 chatter out.

What you should see: on `br-home`, the SYN comes from `192.168.1.23.PORT`. On `veth-rout`, the same SYN comes from `203.0.113.1.PORT`. The address changed. The port did not, because nothing else used it.

### The NAT table

`conntrack.txt` has one line per conversation. Read one like this:

```
tcp 6 117 TIME_WAIT src=192.168.1.24 dst=203.0.113.80 sport=41000 dport=8080 src=203.0.113.80 dst=203.0.113.1 sport=8080 dport=37613 [ASSURED] mark=0 use=1
```

| Part | Meaning |
|---|---|
| `src=192.168.1.24 ... sport=41000 dport=8080` | The first half: what the phone sent, before the router rewrote it |
| `src=203.0.113.80 dst=203.0.113.1 sport=8080 dport=37613` | The second half: the server's answer, as it arrives at the router. The last number is the source port the server saw. Here it is `37613`, not `41000` |

Both devices asked from port `41000`. The laptop's conversation was open first, so it kept `41000`. The phone's would have clashed, so the router gave it a new port. Your number will differ.

## Hints

Each gap has a ladder. Try the first step. Open the next one only if you are still stuck.

| Gap | Step 1: a nudge | Step 2: the name | Step 3: the shape |
|---|---|---|---|
| 1 | The server rejects `192.168.1.x`. First the packet has to get out of the router | `net.ipv4.ip_forward`, and a default route in each device | `sysctl -w SETTING=VALUE` and `ip route add default via ROUTER_ADDRESS` |
| 2 | The server cannot answer `192.168.1.x`. Which part of the packet must change? | The `oifname` match and the `masquerade` action | `oifname "INTERFACE" masquerade` |
| 3 | Both devices must use one port. Does `curl` have an option for it? | `--local-port` | `in_ns NAMESPACE curl -sS --local-port PORT URL > FILE 2>&1`. The laptop's line ends with `&` |
| 4 | The router keeps a table of conversations | `conntrack -L`, filtered with `grep 'dport=8080'` | `in_ns router conntrack -L 2>/dev/null \| grep 'dport=8080' > FILE` |

If you are stuck:

1. Does the router have forwarding on? `ip netns exec router sysctl net.ipv4.ip_forward`
2. Does `ip netns exec router nft list ruleset` show the rule, on the outside interface?
3. Does the server show the packet arriving? Capture on the outside plug.
4. Is the interface name in the rule the one on the outside? `ip netns exec router ip addr`

If you are still stuck after the hints, build the finished network of this part, so you can do the capture or go on to part 2:

```
bash /work/toolkit/restore.sh 4.1
```

It changes only the lab network, not your `masquerade.sh`. The files it writes go to `/tmp/networking-restore/`, so the test's checks for your three `.txt` files still need your own script. It runs the course's own answer: read [If you are stuck on a part](../../../README.md#if-you-are-stuck-on-a-part) first.

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `192.168.1.0/24` | The home network. We chose it. A private range |
| `192.168.1.23`, `.24`, `.1` | The laptop, the phone and the router. We chose them |
| `203.0.113.0/24` | A range reserved for examples (RFC 5737). It stands for the internet |
| `203.0.113.1`, `203.0.113.80` | The router's outside address and the server |
| `8080` | The server's port. We chose it |
| `41000` | A source port we picked for both devices, high enough that nothing else uses it. A real client gets one from Linux's high range |
| `priority 100` | Where in the order of hooks the `postrouting` NAT chain runs. 100 is the usual value for source NAT |
| `sleep 4` | The slow page waits 4 seconds, so the laptop's conversation is still open when the phone asks |
| `37613` (an example) | A port the router chose on a clash. It differs each run |

## Results

Fill in [results.md](results.md). Commit it, `inside.txt`, `outside.txt` and the three `.txt` files the script wrote.

## Draft status (remove before publishing)

Tested (course notes, 2026-10-24 to 2026-10-26): forwarding plus an nft masquerade rule (a table named `nat`, a `postrouting` chain of type nat, `oifname ... masquerade`); the server seeing the router's outside address; the port kept for one client and rewritten when a second client used the same port while the first was open; `conntrack -L` showing both mappings; a server with no route failing at once (curl exit 7); a bridge inside a namespace; `nft` rulesets needing line breaks.
Untested: `curl --local-port`, the exact conntrack line layout the test parses, the `tcpdump -i br-home` capture, the `busybox httpd` page that reports `REMOTE_ADDR` and `REMOTE_PORT`, and reuse of a fixed source port straight after a close (the test uses a different random port each run for this reason).
