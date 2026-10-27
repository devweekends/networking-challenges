# Challenge 9, part 6: iperf3, how fast is this path really

The link should carry far more than you need. The file copy crawls. Where did the speed go? iperf3 sends as much data as it can for a few seconds and measures how much arrived.

Goal: find fault 4, a speed limit with no loss. Measure both directions, use UDP to read loss, and see why fault 1 and fault 4 make the same complaint but are not the same fault.

Clear fault 1 in part 3 first. With both faults in the network, the numbers mix.

## 101: words you need

| Word | Plain meaning |
|---|---|
| iperf3 | A tool for throughput. One side runs `iperf3 -s` (the server), the other `iperf3 -c ADDRESS` (the client) |
| Throughput | How much data arrives each second, in Mbit/s or Gbit/s |
| Sender line, receiver line | The two summary lines at the end. The **receiver** line is what really arrived. The sender line counts what left the program, and some of it may still be waiting in a queue |
| `Retr` | Retransmits: TCP segments the sender had to send again, because they were lost |
| `-R` | Reverse: the server sends and the laptop receives. The other direction of the same path |
| `-u -b 2M` | UDP at 2 Mbit/s. UDP does not resend, so iperf3 can count what was lost: `Lost/Total` |
| `-t 5` | Run for 5 seconds |
| Speed limit (rate) | A queue lets out at most so many bits each second. Packets wait. They are not lost |
| Egress | Traffic leaving an interface. Linux's `tc` shapes only egress, so a limit on one side slows one direction |

## What you build

```
  laptop ---- r1 ---- r2 ===== server (iperf3 -s on port 5201)
                         ^
                         r2's interface toward the server, veth-r2srv, lets out at most a few Mbit/s (fault 4)
  laptop -> server : passes the limit, slow
  server -> laptop : does not, fast  (-R)
```

## Steps

Run these **in the lab**, after part 3:

```
cd /work/challenges/challenge-9-toolbox/part-6-iperf3
ip netns exec laptop iperf3 -c 203.0.113.80 -t 5
```

| # | Type this | What it does | Script line |
|---|---|---|---|
| 1 | `ip netns exec laptop iperf3 -c 203.0.113.80 -t 5` | The laptop sends for 5 seconds. Read the receiver line and the `Retr` number | none |
| 2 | `ip netns exec laptop iperf3 -c 203.0.113.80 -t 5 -R` | The other direction | none |
| 3 | `ip netns exec laptop iperf3 -c 203.0.113.80 -t 5 -u -b 2M` | UDP, below the limit. Read `Lost/Total` on the receiver line | none |
| 4 | (open) Find the limit. Look at the queues on the path, like in part 3 | `tc qdisc show` in r1 and r2. Which one has `rate`? | none |
| 5 | (open) Remove it. Write the command in `faults.md` as the fix | `tc qdisc del dev INTERFACE root` | none |
| 6 | Step 1 again | Fast now | none |
| 7 | Fill in `results.md` and **Fault 4** in `faults.md` | The output line is the receiver line from step 1 | none |
| 8 | `bash test.sh` | Checks the speeds as ratios, your Fault 4 entry, and that the limit is gone | [test.sh#L30](test.sh#L30) |
| 9 | (read the script) | How fault 4 was planted | [faults.sh#L109-L112](../part-0-the-broken-network/faults.sh#L109-L112) |

### Reading iperf3

```
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-5.00   sec  10.2 MBytes  17.2 Mbits/sec    0             sender
[  5]   0.00-5.95   sec  8.75 MBytes  12.3 Mbits/sec                  receiver
```

| Part | Meaning |
|---|---|
| `17.2 Mbits/sec ... sender` | What left the program. Too high: part of it was still waiting in the queue when the 5 seconds ended |
| `12.3 Mbits/sec ... receiver` | What arrived. This is the speed of the path |
| `0` under `Retr` | Nothing was lost. The link is slow, not broken |
| `0.00-5.95` | The receiver needed almost one more second to empty the queue |

Your speed will differ: the limit comes from your seed.

### Fault 1 and fault 4 side by side

| | Fault 1: loss on one link | Fault 4: a speed limit |
|---|---|---|
| The complaint | "Copying a file is slow" | "Copying a file is slow" |
| mtr | Loss from one hop to the last hop | 0% at every hop |
| iperf3 TCP, receiver | Low | Low, near the limit |
| iperf3 `Retr` | Hundreds | 0, or a few |
| iperf3 UDP below the limit | The same percentage lost as mtr shows | 0% lost |

One trap: on a clean virtual cable, iperf3 runs at many Gbit/s, and the `Retr` column can show thousands there too. At that speed, queues inside the lab overflow. Read `Retr` together with the speed: many retransmits at a few Mbit/s means loss on the path.

## Hints

| Step 1: a nudge | Step 2: the name | Step 3: the shape |
|---|---|---|
| One direction is slow and the other is fast. Which interfaces carry the slow direction out? | `tc qdisc show` in r1 and r2 | `ip netns exec r2 tc qdisc show`, then `ip netns exec r2 tc qdisc del dev veth-r2srv root` |

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `5201` | iperf3's default port |
| `-t 5` | Long enough for a steady number, short enough to repeat |
| `-b 2M` | Below every speed limit a seed can give (5 to 15 Mbit/s), so UDP shows loss, not the limit |
| Gbit/s on a clean path | A virtual cable is limited only by the CPU. A real cable is much slower |
| The speed limit | Your seed, between 5 and 15 Mbit/s |

## Results

Fill in [results.md](results.md) and Fault 4 in [faults.md](../part-0-the-broken-network/faults.md). Commit both.

## Draft status (remove before publishing)

Tested in the lab image (2026-10-27): fault 4 alone (receiver near the limit, 0 retransmits, a sender line above the limit), `-R` many times faster, UDP at 2 Mbit/s with 0% lost; fault 1 alone (hundreds of retransmits, UDP loss near the planted loss). `verify-faults.sh` checks that faults 1 and 4 do not look alike, for three seeds.
Untested: macOS Docker Desktop and native Linux kernels without the `sch_netem` module.
