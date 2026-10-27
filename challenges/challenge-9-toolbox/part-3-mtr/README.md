# Challenge 9, part 3: mtr, traceroute that keeps watching

One report says hop 1 loses 20% of its packets. Is hop 1 broken? Not always. mtr sends probes again and again and counts the answers from every hop. You learn to read three cases: a clean path, real loss, and a router that limits its own answers.

Goal: find fault 1, the lossy link, with mtr. Clear it. Then see what a router limiting itself looks like, so you never mistake it for loss.

## 101: words you need

| Word | Plain meaning |
|---|---|
| mtr | "My traceroute". It runs traceroute and ping together, many times, and keeps a table |
| Hop | One router on the path. mtr numbers them 1, 2, 3 |
| Probe | One packet mtr sends to one hop. A probe with TTL 1 dies at hop 1, and hop 1 answers "time exceeded" |
| `Loss%` | The share of probes to that hop with no answer |
| `Snt` | How many probes mtr sent to that hop |
| Real loss | Packets lost on a link. Every hop **after** that link shows loss too, down to the last hop |
| Rate limiting | A router answers probes only so often, to protect itself. Loss shows at **that hop only**. The hops after it are fine |
| `icmp_ratelimit` | The Linux setting for that limit, in milliseconds. 1000 is the usual value. 0 switches it off |
| `tc qdisc` | Linux's tool for the queue on each interface. It can add delay, loss or a speed limit. `tc qdisc show` lists them |
| netem | "Network emulator", a kind of queue that adds loss, delay or a speed limit on purpose |

## What you build

```
  laptop ---------- r1 ======================== r2 ---------- server
           hop 1: 192.0.2.1         hop 2: 198.51.100.2     hop 3: 203.0.113.80
                         this cable loses packets (fault 1)
                         so hops 2 and 3 show loss; hop 1 does not
```

`build.sh` switched the rate limit off in both routers, so that the clean case is really clean ([build.sh#L68-L72](../part-0-the-broken-network/build.sh#L68-L72)).

## Steps

Run these **in the lab**, with the round 1 faults planted:

```
cd /work/challenges/challenge-9-toolbox/part-3-mtr
ip netns exec laptop mtr -rn -c 50 -i 0.2 203.0.113.80
```

| # | Type this | What it does | Script line |
|---|---|---|---|
| 1 | `ip netns exec laptop mtr -rn -c 50 -i 0.2 203.0.113.80` | 50 probes to each hop, five each second, then one report. Paste it into `results.md` | none |
| 2 | (read the report) | Which is the first hop with loss? Does the loss go on to the last hop? | none |
| 3 | (open) Look at the queues of the two routers at the ends of that cable | `tc qdisc show` in each one. Which one has `loss`? | none |
| 4 | (open) Remove that queue | `tc qdisc del dev INTERFACE root` in the right router. Write the command in `faults.md` as the fix | none |
| 5 | `ip netns exec r1 sysctl -w net.ipv4.icmp_ratelimit=1000` | Switch r1's limit back on, then run step 1 again | none |
| 6 | `ip netns exec r1 sysctl -w net.ipv4.icmp_ratelimit=0` | Switch it off again, then run step 1 a last time: a clean report | none |
| 7 | Fill in `results.md` and **Fault 1** in `faults.md` | Tool, command, the one output line that proves the loss, and the fix | none |
| 8 | `bash test.sh` | Checks the three reports, your Fault 1 entry, and that the loss is gone | [test.sh#L28](test.sh#L28) |
| 9 | (read the script) | How fault 1 was planted | [faults.sh#L85-L88](../part-0-the-broken-network/faults.sh#L85-L88) |

### Reading an mtr report

```
Start: 2026-10-27T16:26:23+0000
HOST: 9acde94c9099                Loss%   Snt   Last   Avg  Best  Wrst StDev
  1.|-- 192.0.2.1                  0.0%    50    0.1   0.1   0.1   0.2   0.0
  2.|-- 198.51.100.2              10.0%    50    0.1   0.1   0.1   0.2   0.0
  3.|-- 203.0.113.80              10.0%    50    0.2   0.2   0.2   0.4   0.1
```

| Part | Meaning |
|---|---|
| `-r` | Report: run, then print one table. Without it, mtr draws a live screen |
| `-n` | Addresses, not names |
| `-c 50` | 50 probes to each hop |
| `-i 0.2` | 0.2 seconds between rounds. Below 1 second needs root. In the lab you are root |
| `HOST: 9acde94c9099` | The name of the computer mtr ran on: the lab container. Yours differs |
| Hop 1 0.0%, hops 2 and 3 10.0% | The loss starts at hop 2 and goes on to the end. The cable between hop 1 and hop 2 is the lossy one |

Your percentages will differ. In the case of a router limiting itself, hop 1 shows loss and hops 2 and 3 show 0.0%. A hop that loses probes while the hops after it do not is not losing your traffic.

## On your own computer

mtr also runs on your computer, against a real website.

| Computer | Command |
|---|---|
| macOS (with Homebrew) | `sudo mtr -rn -c 50 example.com` |
| Linux | `mtr -rn -c 50 example.com` |
| Windows | `pathping -n example.com` (built in), or WinMTR |

On a real path, many routers limit their answers. Loss at one hop in the middle, with 0% at the last hop, is almost always that.

## Hints

| Step 1: a nudge | Step 2: the name | Step 3: the shape |
|---|---|---|
| The first hop with loss is hop 2. The cable to hop 2 starts at which router? | `tc qdisc show` in r1, and in r2 | `ip netns exec r1 tc qdisc show`, then `ip netns exec r1 tc qdisc del dev veth-r1wan root` |

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `-c 50 -i 0.2` | 50 probes in about ten seconds. With a few percent of loss, 50 probes almost always catch some |
| `1000` | The usual Linux `icmp_ratelimit`: about one answer per second, with a small burst |
| The loss on fault 1 | Your seed, between 8% and 15% |

## Results

Fill in [results.md](results.md) and Fault 1 in [faults.md](../part-0-the-broken-network/faults.md). Commit both.

## Draft status (remove before publishing)

Tested in the lab image (2026-10-27): the three cases. With fault 1, hops 2 and 3 show loss and hop 1 none. With r1's limit at 1000 and `-i 0.2`, hop 1 showed 55% and 70% loss in two runs and the last hop none. With the limit at 1000 and the default 1-second interval, 10 probes showed no loss (the burst covers them), so the steps use `-i 0.2`.
Untested: `pathping` and WinMTR on Windows, and mtr from Homebrew on macOS.
