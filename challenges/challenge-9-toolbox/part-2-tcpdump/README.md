# Challenge 9, part 2: tcpdump, capture only what you need

A ten-minute capture on a busy computer holds tens of thousands of packets. You need the DNS ones. A capture filter keeps only those, so the file is small and every packet in it matters.

Goal: write capture filters by port, by host and by network; save to a file and read it back; stop after a count.

## 101: words you need

| Word | Plain meaning |
|---|---|
| Capture filter | Words at the end of a tcpdump command. Only packets that match are kept. Examples: `port 53`, `host 203.0.113.80`, `net 203.0.113.0/24` |
| `port 53` | Packets to or from port 53, the DNS port, on UDP or TCP |
| `host ADDRESS` | Packets to or from one address |
| `net RANGE` | Packets to or from any address in a range |
| `-w FILE` | Write the packets to a file, instead of printing them |
| `-r FILE` | Read packets from a file, instead of from a cable. The same filters work |
| `-c N` | Stop after N packets. The file is then complete |
| `-U` | Write each packet to the file at once. Without it, tcpdump keeps packets in memory for a while, and a file opened too early looks empty |
| `-nn` | Print addresses and ports as numbers, not names |

## What you build

```
  laptop ======= r1 ======= r2 ---+--- server
    ^             ^               +--- dns
    |             |
    |             capture 3: in r1, on the cable to r2 (veth-r1wan), only net 203.0.113.0/24
    captures 1 and 2: on the laptop's cable (veth-laptop), only port 53, then only host 203.0.113.80
```

`traffic.sh` makes mixed traffic from the laptop every second: two name questions, a web visit, and a ping.

## Steps

Run these **in the lab**:

```
cd /work/challenges/challenge-9-toolbox/part-2-tcpdump
```

| # | Type this | What it does | Script line |
|---|---|---|---|
| 1 | `tcpdump -nn -r ../part-1-wireshark/capture.pcap port 53` | Reads your part 1 file, and shows only DNS. Paste it into `results.md` | none |
| 2 | `bash traffic.sh 60 &` | Mixed traffic for 60 seconds, in the background. `&` gives you the prompt back | [traffic.sh#L17-L23](traffic.sh#L17-L23) |
| 3 | `ip netns exec laptop tcpdump -nn -i veth-laptop -c 10 -w dns-only.pcap port 53` | Saves the first 10 DNS packets. It prints nothing until it stops | none |
| 4 | `tcpdump -nn -r dns-only.pcap` | Reads the file back. Every line should have `.53` | none |
| 5 | (open) Write `server-only.pcap`: 10 packets on the laptop's cable, to or from the server only | A filter by host | none |
| 6 | (open) Write `public-net.pcap`: 20 packets in `r1` on `veth-r1wan`, to or from the server network only | A filter by network | none |
| 7 | `bash test.sh` | Checks that each file holds only what its filter allows | [test.sh#L38](test.sh#L38) |

If `traffic.sh` has ended before your capture, start it again. A capture with `-c` waits until it has its count.

### Reading a tcpdump line

```
16:25:45.067394 IP 192.0.2.10.44469 > 192.0.2.1.53: 41492+ [1au] A? www.lab.test. (53)
```

| Part | Meaning |
|---|---|
| `192.0.2.10.44469` | From the laptop, source port 44469. The last number after the address is the port |
| `> 192.0.2.1.53` | To the campus resolver, port 53 |
| `A? www.lab.test.` | A question: what is the IPv4 address (A) of this name? |

Your times and ports will differ.

## Hints

| Step 1: a nudge | Step 2: the name | Step 3: the shape |
|---|---|---|
| The test says a file holds packets that do not match. Where does the filter go? | At the end of the command, after every option | `ip netns exec NAMESPACE tcpdump -nn -i INTERFACE -c COUNT -w FILE FILTER` |

Why are the DNS packets in `public-net.pcap` from `198.51.100.1`? The laptop asks the campus resolver in r1. r1 asks the public resolver for it.

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `53` | The port DNS uses |
| `-c 10`, `-c 20` | Small enough to read, big enough to see the pattern |
| `203.0.113.0/24` | The server network behind r2 |
| `60` seconds | Enough time for all three captures |

## Results

Fill in [results.md](results.md). Commit it, `dns-only.pcap`, `server-only.pcap` and `public-net.pcap`.

## Draft status (remove before publishing)

Tested in the lab image (2026-10-27): the three capture filters with `-c` and `-w`, reading back with `-r`, the test's "nothing that does not match" check, and stopping a background tcpdump: a program started with `&` from a script ignores Ctrl-C (SIGINT), so `make-capture.sh` stops it with TERM.
