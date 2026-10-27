# Challenge 9, part 5: nmap, which doors are open

Your teammate says the port is open. Your app cannot connect. Who is right? Both can be. The program listens, but something on the way drops the packets. nmap knocks on each port and tells you what came back: an answer, a refusal, or nothing at all.

Goal: scan the lab server, read the three states, and find fault 3: a filtered port.

## Only scan what you own

Scanning a computer that is not yours can break the rules of your network, your school or your provider, and in many countries the law. Scan only computers you own, or that you have written permission to scan. In this challenge you scan only the lab network, which lives inside your own laptop.

Before your first scan, type this line into `results.md`, under **Consent**, word for word:

```
I scan only computers that I own or that I have written permission to scan. In this challenge I scan only the lab network.
```

The test checks that the line is there, and that it comes before your first scan.

## 101: words you need

| Word | Plain meaning |
|---|---|
| nmap | A tool that sends a packet to many ports and reports what came back |
| Port scan | Knocking on many ports, one after the other |
| `open` | A program listens on the port. nmap got a SYN-ACK back |
| `closed` | Nothing listens. The computer answered with a reset (RST). It is there, and it said no |
| `filtered` | nmap got no answer, or an error from a router. It **could not tell** if something listens. Often a firewall rule drops the packets |
| `-n` | Do not look up names. Faster, and no DNS traffic |
| `-p` | Which ports. `-p 80,81` or `-p 1-10000`. Without it, nmap tries the 1000 most common ports |
| `ss -ltn` | On the server itself: which TCP ports a program listens on |
| `nft list ruleset` | Print every packet rule in a computer |

## What you build

```
  laptop ---- r1 ---- r2 ---- server 203.0.113.80
                      |         port 80    web page        -> open
                      |         port 81    nothing         -> closed  (the server says "no")
                      |         the app's port, listening   -> filtered (r2 drops it, nobody says anything)
                      +-- a drop rule for the app's port (fault 3)
```

## Steps

Type the consent line first. Then, **in the lab**:

```
cd /work/challenges/challenge-9-toolbox/part-5-nmap
ip netns exec laptop nmap -n 203.0.113.80
```

| # | Type this | What it does | Script line |
|---|---|---|---|
| 1 | `ip netns exec laptop nmap -n 203.0.113.80` | The 1000 most common ports. Is the app's port in the list? | none |
| 2 | `ip netns exec laptop nmap -n -p 1-10000 203.0.113.80` | Ports 1 to 10000. With fault 1 cleared it takes a few seconds. While a link loses packets, nmap slows down and tries again, and it can take 20 seconds | none |
| 3 | `ip netns exec laptop nmap -n -p 80,81,PORT 203.0.113.80` | Three ports, three states. Use the app's port from the service sheet | none |
| 4 | `ip netns exec server ss -ltn` | On the server: the app **is** listening. So who is right? | [build.sh#L78](../part-0-the-broken-network/build.sh#L78) |
| 5 | (open) Find the rule. Which computer is on the way? Look at its ruleset | `nft list ruleset` in that computer | none |
| 6 | (open) Remove the table that holds the rule | `nft delete table FAMILY NAME`. Write the command in `faults.md` as the fix | none |
| 7 | Step 3 again | The app's port is `open` now | none |
| 8 | Fill in `results.md` and **Fault 3** in `faults.md` | The output line is the `filtered` line from step 3 | none |
| 9 | `bash test.sh` | Checks the consent line, the scans, your Fault 3 entry, and that the app answers | [test.sh#L23](test.sh#L23) |
| 10 | (read the script) | How fault 3 was planted | [faults.sh#L97-L107](../part-0-the-broken-network/faults.sh#L97-L107) |

### Reading an nmap report

```
PORT     STATE    SERVICE
80/tcp   open     http
81/tcp   closed   hosts2-ns
7630/tcp filtered hawk
```

| Part | Meaning |
|---|---|
| `80/tcp open` | The web server answered |
| `81/tcp closed` | The server answered with a reset: nothing listens |
| `7630/tcp filtered` | No answer at all. nmap cannot tell what is behind it |
| `SERVICE` | nmap's guess from a list of usual ports. It did not ask the program. Ignore it for ports above 1024 |

Your app's port will differ.

## Hints

| Step 1: a nudge | Step 2: the name | Step 3: the shape |
|---|---|---|
| The server listens, but the laptop gets no answer. Which computers are between them? | `nft list ruleset` in r1, then in r2 | `ip netns exec r2 nft list ruleset`, then `ip netns exec r2 nft delete table inet NAME` |

Do not scan your home router or anything outside the lab from the lab. The lab reaches the outside through Docker's own NAT, so a scan there tests Docker, not your router, and it is not your network to scan.

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `80` | The web page |
| `81` | A port where nothing listens, so it is closed |
| `1000` | nmap's default: the 1000 most common ports |
| `1-10000` | Wide enough to hold the app's port |
| The app's port | Your seed, between 7000 and 7999 |

## Results

Fill in [results.md](results.md) and Fault 3 in [faults.md](../part-0-the-broken-network/faults.md). Commit both.

## Draft status (remove before publishing)

Tested in the lab image (2026-10-27): open (busybox httpd), closed (no listener) and filtered (an nft drop rule in r2) in one scan of three ports in about 1.4 seconds; the default scan in 0.2 seconds (3.5 seconds while fault 1 loses packets); ports 1 to 10000 in 1.7 seconds (17 to 22 seconds while fault 1 loses packets); after the table is deleted, the port is open.
