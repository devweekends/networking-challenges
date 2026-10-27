# Challenge 9: your network toolbox

A friend says "the internet is slow". You know a dozen places where a network can break. Which tool tells you which one, in under a minute?

In this challenge a script builds one small network and hides four faults in it. Each part teaches one tool and uses it to find one fault, with evidence. At the end, the script hides faults again, with new numbers, and you find them without help.

This challenge is **guided to the first command, then open**. Each part shows you the first command and explains its output. After that you choose the commands yourself.

## The network

```
  laptop -------------- [ r1 ] ---------------------- [ r2 ] --+-- server  203.0.113.80
  192.0.2.10     192.0.2.1    198.51.100.1    198.51.100.2     |   web page :80, the app :PORT, iperf3 :5201
                 campus router and            provider router  |
                 campus DNS resolver          203.0.113.1      +-- dns     203.0.113.53
                                                                   public DNS resolver
```

| Computer | Address | What it does |
|---|---|---|
| `laptop` | `192.0.2.10` | Your computer. Every command in this challenge runs here unless the README says otherwise |
| `r1` | `192.0.2.1` and `198.51.100.1` | The campus router. It also runs the campus DNS resolver, which the laptop asks for names |
| `r2` | `198.51.100.2` and `203.0.113.1` | The provider's router. The server and the public resolver are behind it |
| `server` | `203.0.113.80` | A web page on port 80, an app on its own port, and an iperf3 server on port 5201 |
| `dns` | `203.0.113.53` | A public DNS resolver |

All three address ranges are reserved for examples (RFC 5737). No real computer uses them. There is no NAT here: in the lab, every address is "public".

## The parts

| Part | Folder | Tool | You find |
|---|---|---|---|
| 0 | `part-0-the-broken-network` | `ping`, `traceroute` | Plant the faults. Write a best guess for each complaint |
| 1 | `part-1-wireshark` | Wireshark, on your computer | Three values in your own capture file |
| 2 | `part-2-tcpdump` | `tcpdump` | Only the packets you need, in a file |
| 3 | `part-3-mtr` | `mtr` | Fault 1 |
| 4 | `part-4-dig` | `dig` | Fault 2 |
| 5 | `part-5-nmap` | `nmap` (lab only) | Fault 3 |
| 6 | `part-6-iperf3` | `iperf3` | Fault 4 |
| 7 | `part-7-curl` | `curl` | Where the time of a page goes |

Do the parts in order. Part 6 needs fault 1 cleared in part 3 first.

## The fault matrix

Read this **after** you wrote your best guesses in part 0. It tells you which tool finds which fault. It does not tell you the numbers. Those come from your seed, and only your tools can show them.

| Fault | Complaint | Best tool | What the tool shows |
|---|---|---|---|
| 1 | "Copying a file to the server is slow." | `mtr` | Loss that starts at one hop and goes on to the last hop. In iperf3: many retransmits (the `Retr` column) |
| 2 | "One name does not load. www.lab.test works." | `dig` | Two resolvers give two different answers for the same name |
| 3 | "The app on its port does not answer." | `nmap` | The app's port is `filtered`, while another port is `open` and one is `closed` |
| 4 | "Copying a file to the server is slow." | `iperf3` | A low, steady speed with almost no retransmits. mtr is clean |

Faults 1 and 4 make the same complaint on purpose. A file copy is slow in both. Only the evidence tells them apart.

## The gate: your toolbox

When parts 3 to 6 pass:

1. Run the blind round: `bash part-0-the-broken-network/faults.sh --round 2`. It builds the network again and plants **two** of the four kinds of fault, with new numbers. It does not say which two.
2. Find both, with the tools, and without this matrix. Write each finding at the end of `faults.md`.
3. Run `bash part-0-the-broken-network/test.sh --round 2`. It checks all of `faults.md`.
4. Make a one-page cheat sheet, `cheat-sheet.md`, in this folder: one real output from each tool, from your own runs, and one line on how to read it.

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `192.0.2.0/24`, `198.51.100.0/30`, `203.0.113.0/24` | Ranges reserved for examples (RFC 5737). We chose them |
| `.10`, `.1`, `.2`, `.80`, `.53` | The laptop, the routers, the server and the resolver. We chose them |
| Port `80` | The usual port for a web page |
| Port `5201` | The port iperf3 listens on by default |
| The app's port, the loss, the speed limit, the wrong address | Your seed. `faults.sh` turns it into numbers with `seed.sh`. Another learner gets other numbers |

## Draft status (remove before publishing)

Tested in the lab image (2026-10-27): the network build, all four faults alone and together, and each fault's signature (`verify-faults.sh` with seeds alpha, beta and gamma); mtr showing loss from hop 2 to the last hop with fault 1, a clean report with fault 4, and loss at hop 1 only with r1's `icmp_ratelimit` at 1000 and `-i 0.2`; iperf3 with fault 1 (hundreds of retransmits) and with fault 4 (a speed near the limit, 0 retransmits, a misleading sender line); `-R` and UDP; nmap open, closed and filtered; `dig` against two resolvers; `dig +trace @1.1.1.1`; curl `-v` and `-w`; tcpdump capture filters by host, port and net.
Untested: opening `capture.pcap` in Wireshark on Windows and macOS (the file is a normal pcap file, read here with `tcpdump -r`); the lab on macOS Docker Desktop and on native Linux (`tc netem` needs the `sch_netem` module); `git config user.name` as the default seed (the lab image has no git, so the default is a random word).
