# Challenge 9, part 1: Wireshark, read any capture

Your tcpdump captures from earlier challenges are walls of text. Wireshark shows the same packets as a list you can click, filter and follow.

Goal: make your own capture file in the lab, open it in Wireshark on your computer, and read three values from it. The test reads the same three values from the same file with `tcpdump -r`, and compares.

## 101: words you need

| Word | Plain meaning |
|---|---|
| Wireshark | A program for your computer that opens capture files and shows each packet, layer by layer |
| Capture file, pcap | A file that holds captured packets. `tcpdump -w` writes one. Wireshark opens it |
| Display filter | Wireshark's filter, typed in the bar at the top. It hides packets from view. It names fields: `ip.dst == 203.0.113.80` |
| Capture filter | tcpdump's filter, at the end of its command. It decides which packets are saved at all: `host 203.0.113.80` |
| Field | One value in a packet, like the source port or the TTL. Wireshark shows its name at the bottom of the window when you click it |
| Follow TCP stream | Wireshark puts the data of one conversation together, in order, as text |
| TTL | Time to live. A number in every IP packet. Each router takes 1 off. The sender chooses where it starts |

## What you build

```
  laptop ---- r1 ---- r2 ---- server
    ^
    tcpdump on the laptop's cable writes capture.pcap into /work, which is your repository folder
```

`make-capture.sh` captures on the laptop while the laptop asks two names, pings its router and visits the web page a few times. The numbers come from your seed: the source port of the first visit, the TTL the server starts with, and how many visits.

## Steps

**In the lab**, after part 0:

```
cd /work/challenges/challenge-9-toolbox/part-1-wireshark
bash make-capture.sh
```

| # | Where | Type or do this | What it does | Script line |
|---|---|---|---|---|
| 1 | lab | `bash make-capture.sh` | Writes `capture.pcap` in this folder | whole file |
| 2 | lab | (read the script) | The server's TTL for the capture, and the capture itself with `-U` | [make-capture.sh#L24](make-capture.sh#L24), [make-capture.sh#L28](make-capture.sh#L28) |
| 3 | lab | (read the script) | The web visits, each from a chosen source port with `curl --local-port` | [make-capture.sh#L36-L39](make-capture.sh#L36-L39) |
| 4 | your computer | Install Wireshark from its own download page. Read the download size there first | It is a normal program for Windows, macOS and Linux | none |
| 5 | your computer | Open `challenges/challenge-9-toolbox/part-1-wireshark/capture.pcap` from your repository folder | The lab wrote the file into your repository, so your computer sees it | none |
| 6 | your computer | (open) Find the three values below. For each one, type a display filter that shows only the packets you need | Fill in the table in `results.md` | none |
| 7 | your computer | Right-click a web packet, **Follow**, **TCP Stream** | The whole conversation as text | none |
| 8 | lab | `bash test.sh` | Reads the same values with `tcpdump -r` and compares them with yours | [test.sh#L37](test.sh#L37) |

### The three values

| Question | Where to look |
|---|---|
| The source port of the laptop's first web connection | The first packet from `192.0.2.10` with the SYN flag. Click it. Open the **Transmission Control Protocol** layer |
| The TTL of the server's packets, as they reach the laptop | Any packet from `203.0.113.80`. Open the **Internet Protocol** layer |
| How many packets were sent to `203.0.113.80` | A display filter on the destination. Wireshark shows the count at the bottom: **Displayed** |

Display filters that help: `ip.src == 192.0.2.10`, `ip.dst == 203.0.113.80`, `tcp.flags.syn == 1`. Join two with `&&`.

## Hints

| Step 1: a nudge | Step 2: the name | Step 3: the shape |
|---|---|---|
| Too many packets? Filter first, then read | The fields are `tcp.srcport`, `ip.ttl`, `ip.dst` | `ip.src == 192.0.2.10 && tcp.flags.syn == 1`, then look at the first row |

If the test says your capture was not made from your seed, run `bash make-capture.sh` again and open the new file.

If Wireshark says the file is cut short, the capture was still running when it was opened. `make-capture.sh` stops tcpdump before it ends, so wait until it prints `capture.pcap is ready`.

## Where each number comes from

| Number | Where it comes from |
|---|---|
| The source port | Your seed, between 40000 and 49000. Without `--local-port`, Linux picks a random one |
| The server's starting TTL | Your seed, between 40 and 120. Linux starts at 64. The script changes it for the capture only |
| 2 | The TTL drops by one at each router: r2, then r1 |
| The number of visits | Your seed, 2 to 4 |

## Results

Fill in [results.md](results.md). Commit it and `capture.pcap`.

## Draft status (remove before publishing)

Tested in the lab image (2026-10-27): `make-capture.sh` with several seeds; the test reading the port, the TTL and the count with `tcpdump -r`; `-Z root` so the file is not owned by the `tcpdump` user.
Untested: opening the file in Wireshark on Windows and macOS, the exact Wireshark menu names, and the Wireshark download size.
