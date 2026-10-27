# Challenge 7, part 3: a backup link and your own preference

Goal: add a direct cable from r1 to r3. Watch it win, because its AS path is shorter. Then write a one-line import filter that lowers its local preference, so it becomes the backup. Cut the main link and watch traffic move to the backup. Then put the main link back.

Do parts 1 and 2 first. This script builds the three routers again, with one more cable.

This part is **gapped**. The script `backup-link.sh` is almost complete. Four small things are missing, and each is marked `TODO`. The test tells you which one is wrong.

## 101: words you need

| Word | Plain meaning |
|---|---|
| Direct link | A cable straight from r1 to r3, without r2 in the middle |
| Backup link | A link that carries traffic only when the main one is down |
| Best path | The one route BIRD chooses for a block, out of all it knows. It is marked `*` |
| Local preference | A number this network gives a route, for its own use. Higher wins. The default is 100. It is checked **before** the AS path length |
| Import filter | A rule that runs on every route a neighbour sends, before BIRD keeps it. It can change the route or reject it |
| `bgp_local_pref` | The name of the local preference inside a BIRD filter |
| Policy | Your network's own choices about routes. A filter is how you write them down |
| `birdc configure` | Makes BIRD read its config file again, without a restart. The sessions stay up |
| `disable`, `enable` | Switch one BGP session off or on. Like pulling a cable out and putting it back |

## What you build

```
                  AS64497
                  [ r2 ]
        10.0.12.2 /    \ 10.0.23.2
                 /      \
       10.0.12.1/        \10.0.23.3
  AS64496 [ r1 ]----------[ r3 ] AS64498
          10.0.13.1   10.0.13.3
     198.51.100.0/24       203.0.113.0/24
```

The new cable is `10.0.13.0/24`: `13` because it joins r1 and r3. Now r1 knows two ways to `203.0.113.0/24`:

| Way | AS path | Length |
|---|---|---|
| Through r2 | `64497 64498` | 2 |
| Direct | `64498` | 1 |

How BIRD picks the best path, in the order this course uses:

1. A longer prefix wins (a `/25` beats a `/24`). Both ways here are the same `/24`, so this does not decide.
2. Higher local preference wins. Both start at 100, so this does not decide either.
3. A shorter AS path wins. The direct way wins.

Say the direct cable is cheap but slow, and r2 is your paid provider with a fast link. You want r2 as the main path. Path length cannot know that. Local preference can, because it is your choice, and it comes before path length.

Before you fill the gaps, guess: when r1 gives the direct route local preference 50, which way does r1 send traffic? And when you then cut r2's session to r1?

## Steps

Run these **in the lab**. First:

```
cd /work/challenges/challenge-7-bgp/part-3-backup-link
```

| # | Type this | What it does | Script line |
|---|---|---|---|
| 1 | `bash backup-link.sh` | Builds everything and runs every step below. Safe to run again | whole file |
| 2 | (the routers and cables) | The same as part 1, plus the cable `10.0.13.0/24` | [backup-link.sh#L35](backup-link.sh#L35) |
| 3 | (r2's config) | The same as in part 1 | [backup-link.sh#L63](backup-link.sh#L63) |
| 4 | `write_r1_conf` | Writes `r1.conf`, now with a second session, `to_r3`. Its import line is a setting, so the script can change it later | [backup-link.sh#L101](backup-link.sh#L101) |
| 5 | Gap 1 | Writes r3's session to r1, `to_r1`, in `write_r3_conf` | [backup-link.sh#L169-L172](backup-link.sh#L169-L172) |
| 6 | (start BIRD, wait) | First with `import all;` on the direct link | [backup-link.sh#L175](backup-link.sh#L175) |
| 7 | `birdc -s /tmp/bird-r1.ctl show route all 203.0.113.0/24` | The mid-point check: two routes. The direct one has the `*`. Saved in `before-preference.txt` | [backup-link.sh#L193](backup-link.sh#L193) |
| 8 | Gap 2 | The one-line import filter, on both ends of the direct link | [backup-link.sh#L196-L200](backup-link.sh#L196-L200) |
| 9 | `birdc -s /tmp/bird-r1.ctl configure` | BIRD reads the new file. Now the route through r2 has the `*`. Saved in `after-preference.txt` | [backup-link.sh#L204](backup-link.sh#L204) |
| 10 | Gap 3 | Cut the main link: r2 switches off its session to r1 | [backup-link.sh#L211-L212](backup-link.sh#L211-L212) |
| 11 | (look) | r1 now uses `via 10.0.13.3`, and the ping still works. Saved in `failover.txt` | [backup-link.sh#L214](backup-link.sh#L214) |
| 12 | Gap 4 | Put the main link back | [backup-link.sh#L226-L227](backup-link.sh#L226-L227) |
| 13 | (look) | r1 uses `via 10.0.12.2` again. Saved in `restored.txt` | [backup-link.sh#L229](backup-link.sh#L229) |
| 14 | `ip netns exec r1 traceroute -n -s 198.51.100.1 203.0.113.1` | Run it with the main link up, and again during the cut. Count the hops | none |
| 15 | `bash test.sh` | Checks all of the above, cuts and restores the link itself, and names the gap that is wrong | the gap checks start at [test.sh#L46](test.sh#L46) |

## The one-line filter

Gap 2 asks for this shape:

```
import filter { bgp_local_pref = NUMBER; accept; };
```

| Piece | Meaning |
|---|---|
| `import filter { ... };` | Instead of `import all;`, run these commands on every route from this neighbour |
| `bgp_local_pref = NUMBER;` | Set this route's local preference |
| `accept;` | Keep the route. A filter that ends without `accept` drops it |

It goes on the session to the direct link only. Routes from r2 keep the default, 100.

Why on **both** ends? r1's filter decides how r1 sends. r3 decides how its answers come back. With only r1's filter, the ping goes through r2 and the answer comes back direct. It still works, but the two directions take different roads. That is common on the internet. Here we want both on r2.

## Reading the result

`after-preference.txt` shows both routes. Find the `*` and the `BGP.local_pref` lines:

```
203.0.113.0/24       unicast [to_r2 15:58:01.092] * (100) [AS64498i]
	via 10.0.12.2 on veth-to-r2
	...
	BGP.as_path: 64497 64498
	BGP.local_pref: 100
                     unicast [to_r3 15:58:01.275] (100) [AS64498i]
	via 10.0.13.3 on veth-to-r3
	...
	BGP.as_path: 64498
	BGP.local_pref: 50
```

The direct route is still there. It has the shorter path, but its local preference is 50, so it lost. When the route through r2 goes away, the direct route is the only one left, so it wins.

Look at the `ttl` in the pings too. Through r2 it is `ttl=63`, one router on the way. During the cut it is `ttl=64`: no router in between.

## Hints

Each gap has a ladder. Try the first step. Open the next one only if you are still stuck.

| Gap | Step 1: a nudge | Step 2: the name | Step 3: the shape |
|---|---|---|---|
| 1 | r1 has a session to r3. Does r3 have one to r1? | A `protocol bgp` block called `to_r1`, inside `write_r3_conf` | Copy r1's `to_r3` block. Change the name, `local as 64498;` and `neighbor 10.0.13.1 as 64496;` |
| 2 | Which number is checked before the AS path length? | `bgp_local_pref`, in an import filter | `R1_FROM_R3='import filter { bgp_local_pref = 50; accept; };'` and the same for `R3_FROM_R1` |
| 3 | Which session carries the main path from r1 to r2? | `to_r1` in **r2**, and `birdc ... disable` | `birdc -s /tmp/bird-r2.ctl disable SESSION` |
| 4 | The opposite of Gap 3 | `birdc ... enable` | `birdc -s /tmp/bird-r2.ctl enable SESSION` |

If you are stuck:

1. Is the direct session up? `birdc -s /tmp/bird-r1.ctl show protocols` should show `to_r3 ... Established`.
2. Does BIRD accept your file? `bird -p -c r3.conf`. It prints nothing when the file is fine.
3. Did the filter apply? `birdc -s /tmp/bird-r1.ctl show route all 203.0.113.0/24 protocol to_r3` should show `BGP.local_pref: 50`.
4. Are r1 and r3 both on r2? Check `ip netns exec r3 ip route` too.

Why does Gap 3 switch off a session and not the cable? If you pull the cable with `ip link set ... down`, BIRD notices at once. But when you put the cable back, BIRD waits a long time before it tries again. `disable` and `enable` come back in a few seconds.

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `10.0.13.0/24` | The new cable. `13` joins r1 and r3 |
| `100` | The default local preference |
| `50` | We chose it. Any number below 100 makes the direct link the backup |
| `64498` | The direct path: only r3's own number |
| `ttl=63`, `ttl=64` | 63 means one router on the way (r2). 64 means none |
| a few seconds | How long BIRD took to move the route in this lab, after `disable` and after `enable` |

## Results

Fill in [results.md](results.md). Commit it with the four `.txt` files and the three `.conf` files the script wrote.

## Draft status (remove before publishing)

Tested in the lab image (BIRD 2.14), 2026-10-27: the reference script and `test.sh` pass; the template with all gaps empty fails with GAP messages; each gap left empty alone fails with its own GAP message. `birdc configure` applied the new import filter without a session restart. `disable to_r1` on r2 moved both r1 and r3 to the direct link in under a second; `enable` moved them back in about 4 seconds. After `ip link set down` and `up`, a session sat in `Idle` (not used here). `traceroute -n -s 198.51.100.1` showed 2 hops through r2 and 1 hop during the cut. An inline filter with no `accept` dropped the route.
Untested: the lab on macOS and on native Linux.
