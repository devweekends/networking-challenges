# Challenge 9, setup: the slow, broken network

Goal: build the lab network, let a script hide four faults in it, and see how far `ping` and `traceroute` get you. Then write a best guess for each complaint.

Read the [challenge 9 overview](../README.md) first, but **not** the fault matrix yet.

## 101: words you need

| Word | Plain meaning |
|---|---|
| Fault | Something wrong in the network. Here, put there on purpose by a script |
| Seed | A word you give the script, for example your name. It turns the word into numbers: how much loss, which port, which address. The same seed always gives the same numbers |
| Complaint | What a person says when something is wrong: "it is slow". A complaint is not a cause |
| Symptom | What you can see go wrong, with a tool: "12% of pings get no answer" |
| Evidence | One line of a tool's output that proves the cause |
| Resolver | A server that answers questions about names. The laptop asks the campus resolver |
| Packet loss | Packets that leave and never arrive |
| Throughput | How much data a path carries each second, in Mbit/s |
| Service sheet | A short list of what should be true: which names mean which address, which ports are open |

## What you build

```
  laptop -------------- [ r1 ] ---------------------- [ r2 ] --+-- server  203.0.113.80
  192.0.2.10     192.0.2.1    198.51.100.1    198.51.100.2     |   web page :80, the app :PORT, iperf3 :5201
                 campus router and            provider router  |
                 campus DNS resolver          203.0.113.1      +-- dns     203.0.113.53
                                                                   public DNS resolver
```

You do not write network code in this challenge. `build.sh` builds the network. `faults.sh` runs `build.sh`, then plants the faults.

## Steps

Run these **in the lab**. First:

```
cd /work/challenges/challenge-9-toolbox/part-0-the-broken-network
```

| # | Type this | What it does | Script line |
|---|---|---|---|
| 1 | `bash faults.sh --seed YOUR_NAME` | Builds the network and plants four faults. Use your first name, or any word. It is saved in `fault-seed.txt` | whole file |
| 2 | (read the output) | The service sheet (what should be true) and three complaints. Copy the complaints. Your app port is in the service sheet | [faults.sh#L130](faults.sh#L130) |
| 3 | (the six computers and the cables) | What `build.sh` made | [build.sh#L30](build.sh#L30), [build.sh#L38](build.sh#L38) |
| 4 | `ip netns exec laptop ping -c 50 -i 0.2 203.0.113.80` | 50 pings, five each second. Read the last line: how many were lost? | none |
| 5 | `ip netns exec laptop traceroute -n 203.0.113.80` | The routers on the way. `-n` prints addresses, not names | none |
| 6 | `ip netns exec laptop curl -sS -m 5 http://www.lab.test/` | The web page, by name. It works | none |
| 7 | (open) | Try the name and the port from the complaints with `ping` and `curl`. What can you find? Stop after ten minutes | none |
| 8 | Fill in `results.md` and the **Best guesses** in `faults.md` | Your evidence so far, and one guess for each complaint | none |
| 9 | `bash test.sh` | Checks the network, your seed, your results and your guesses | [test.sh#L38](test.sh#L38) |

Then read the fault matrix in the [overview](../README.md#the-fault-matrix), and go on to part 1.

### Reading ping

```
50 packets transmitted, 45 received, 10% packet loss, time 9906ms
rtt min/avg/max/mdev = 0.142/0.230/0.482/0.066 ms
```

| Part | Meaning |
|---|---|
| `10% packet loss` | 5 of 50 pings got no answer. Something loses packets. Ping cannot say where |
| `avg 0.230 ms` | A virtual cable is fast. A slow path would not show here: ping sends tiny packets |

Your numbers will differ.

## What `faults.sh` can do

| Command | What it does |
|---|---|
| `bash faults.sh --seed WORD` | Round 1: build, then plant all four faults. Use it again with the same word to start over |
| `bash faults.sh` | The same, with the seed in `fault-seed.txt` |
| `bash faults.sh --clean` | Build the network with no faults, to see what healthy looks like. Run `bash faults.sh` again to bring the faults back |
| `bash faults.sh --round 2` | The blind round, for the gate. Only after parts 3 to 6 pass |

Do not run `faults.sh --list`. It prints the answers. A mentor uses it.

Each run of `faults.sh` builds the whole network again. Anything you fixed is broken again. Fix the live network with single commands, as the parts show.

## Hints

| Step 1: a nudge | Step 2: the name | Step 3: the shape |
|---|---|---|
| Ping lost some packets. Does traceroute tell you at which hop? | Ping and traceroute send few, small packets. They cannot show speed, names, or blocked ports | `ip netns exec laptop ping -c 3 NAME` and `ip netns exec laptop curl -sS -m 5 http://203.0.113.80:PORT/` |

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `-c 50 -i 0.2` | 50 pings, 0.2 seconds apart: ten seconds. Enough to see a few percent of loss |
| `-m 5` | curl gives up after 5 seconds, so a hang does not block your terminal |
| The complaints | Printed by `faults.sh`. Two complaints are the same on purpose |
| Your app port | Your seed, through `seed.sh` |

## Results

Fill in [results.md](results.md) and the best guesses in [faults.md](faults.md). Commit both and `fault-seed.txt`.

## Draft status (remove before publishing)

Tested in the lab image (2026-10-27): `faults.sh` with several seeds, `--clean`, `--only`, `--round 2` and `--list`; ping and traceroute through the faults. Two dnsmasq programs in one lab need an empty `pid-file=` line, or the second one stops at once.
