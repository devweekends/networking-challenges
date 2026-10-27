# Challenge 7, part 2: read a route, then withdraw it

Goal: read everything r1 knows about one route. Then make r3 stop announcing its block. Watch the route vanish from r2 and r1, and the ping fail. Then bring it back.

Do part 1 first. This script builds part 1 again, so you always start from the same place.

This part is **guided**. The script `withdraw.sh` is complete. It saves three files: `route-all.txt`, `withdrawn.txt` and `back.txt`.

## 101: words you need

| Word | Plain meaning |
|---|---|
| Withdraw | "I can no longer reach this block. Forget my route." A BGP message, sent to every neighbour |
| `show route all` | The long form of a route in BIRD: every attribute it carries |
| Attribute | One piece of information that travels with a route, such as the AS path or the next hop |
| Origin | The network that first announced the block. It is the last number in the AS path |
| Next hop | The address to send the traffic to. Here, the neighbour's address on the cable |
| Local preference | A number a network gives a route for its own use. Higher wins. It is never sent to other networks. The default is 100 |
| Network not found | What BIRD says when it has no route for a block |
| Unreachable | Nobody on the way knows where the block is |

## What you build

The same line as part 1:

```
     AS64496                AS64497                AS64498
  [ r1 ] ---- cable ---- [ r2 ] ---- cable ---- [ r3 ]
  198.51.100.0/24                               203.0.113.0/24
```

The withdrawal travels the same way the announcement did. r3 tells r2. r2 tells r1.

```
  r3: "withdraw 203.0.113.0/24"  -->  r2 forgets it  -->  r2: "withdraw 203.0.113.0/24"  -->  r1 forgets it
```

Before you run anything, guess: after r3 withdraws, does r1's ping fail at once, or only after a while?

## Steps

Run these **in the lab**. First:

```
cd /work/challenges/challenge-7-bgp/part-2-read-and-withdraw
```

| # | Type this | What it does | Script line |
|---|---|---|---|
| 1 | `bash withdraw.sh` | Builds part 1 again, then runs every step below. Safe to run again | whole file |
| 2 | (build part 1 again) | Runs `three-networks.sh` from part 1, quietly | [withdraw.sh#L23](withdraw.sh#L23) |
| 3 | `birdc -s /tmp/bird-r1.ctl show route all 203.0.113.0/24` | The whole route, in r1. Saved in `route-all.txt`. See [Reading show route all](#reading-show-route-all) | [withdraw.sh#L30](withdraw.sh#L30) |
| 4 | `birdc -s /tmp/bird-r2.ctl show route all 203.0.113.0/24` | The same block in r2. Its AS path is only `64498` | [withdraw.sh#L34](withdraw.sh#L34) |
| 5 | `birdc -s /tmp/bird-r3.ctl disable direct1` | r3 stops announcing its block. The address `203.0.113.1` stays on r3 | [withdraw.sh#L39](withdraw.sh#L39) |
| 6 | `birdc -s /tmp/bird-r1.ctl show route all 203.0.113.0/24` | Now it says `Network not found` | [withdraw.sh#L46](withdraw.sh#L46) |
| 7 | `ip netns exec r1 ip route` | The `203.0.113.0/24` line is gone | [withdraw.sh#L48](withdraw.sh#L48) |
| 8 | `ip netns exec r1 ping -c2 -W1 -I 198.51.100.1 203.0.113.1` | `2 packets transmitted, 0 received, 100% packet loss` | [withdraw.sh#L50](withdraw.sh#L50) |
| 9 | `birdc -s /tmp/bird-r1.ctl show protocols all to_r2` | Find `Import withdraws`. The first number is how many withdrawals r1 received | [withdraw.sh#L52](withdraw.sh#L52) |
| 10 | `birdc -s /tmp/bird-r3.ctl enable direct1` | r3 announces its block again | [withdraw.sh#L58](withdraw.sh#L58) |
| 11 | `ip netns exec r1 ip route` and the ping | The route is back. `2 received`. Saved in `back.txt` | [withdraw.sh#L60](withdraw.sh#L60) |
| 12 | `ip netns exec r1 ip route get 203.0.113.1` | Try this after step 5 and after step 10. With no route, Linux says `Network is unreachable` | none |
| 13 | `bash test.sh` | Checks your three files, then does a withdrawal of its own | [test.sh#L58](test.sh#L58) |

`direct1` is the name BIRD gave r3's `protocol direct` block. You can see it in `birdc -s /tmp/bird-r3.ctl show protocols`. To disable it means: BIRD forgets r3's own blocks, so it withdraws them from every neighbour.

## Reading show route all

`route-all.txt` looks like this:

```
203.0.113.0/24       unicast [to_r2 15:55:53.550] * (100) [AS64498i]
	via 10.0.12.2 on veth-to-r2
	Type: BGP univ
	BGP.origin: IGP
	BGP.as_path: 64497 64498
	BGP.next_hop: 10.0.12.2
	BGP.local_pref: 100
```

| Line | Meaning |
|---|---|
| `203.0.113.0/24 ... * (100) [AS64498i]` | The short form from part 1: the block, the session, chosen (`*`), the origin AS |
| `via 10.0.12.2 on veth-to-r2` | Where Linux sends the traffic |
| `Type: BGP univ` | A route learned by BGP. `univ` means it is good everywhere, not only on one cable |
| `BGP.origin: IGP` | How the origin network got the block into BGP. `IGP` means it came from inside that network. It is the `i` in `[AS64498i]` |
| `BGP.as_path: 64497 64498` | The networks on the way. Read it from the right: AS64498 announced it, then AS64497 passed it on |
| `BGP.next_hop: 10.0.12.2` | The address the announcement says to send traffic to: r2's end of our cable |
| `BGP.local_pref: 100` | r1's own preference for this route. 100 is the default. r1 did not receive this number. It added it itself |

Why does r1's path not start with `64496`? A network adds its own number only when it sends a route out. r1 adds `64496` when it passes this route on. It does not add it to its own copy.

## Why the ping fails at once

When the route goes, r1 has no route at all for `203.0.113.1`. It has no default route either. So Linux drops the packet inside r1. Nothing leaves.

The address `203.0.113.1` is still on r3, and r3 is still running. Nobody can reach it, because nobody knows the way. A network that withdraws its blocks disappears from the internet, even if its computers are fine.

## Hints

1. The route does not go away: did you disable `direct1` in **r3**? `birdc -s /tmp/bird-r3.ctl show protocols` should show `direct1 ... down`.
2. The route does not come back: `birdc -s /tmp/bird-r3.ctl enable direct1`, then wait a second.
3. `Network not found` before you withdrew: run part 1's test first. Are the sessions `Established`?

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `64497 64498` | The AS path: r2's number, then r3's |
| `100` | The default local preference in BIRD, and in most BGP software |
| `10.0.12.2` | r2's address on the cable to r1 |
| `Import withdraws: 1` (or more) | Each withdrawal r1 received. It grows each time you run the step again |
| `0 received` | The ping during the withdrawal |
| about 1 second | How long the withdrawal took to reach r1 in this lab |

## Results

Fill in [results.md](results.md). Commit it with `route-all.txt`, `withdrawn.txt` and `back.txt`.

## Draft status (remove before publishing)

Tested in the lab image (BIRD 2.14), 2026-10-27: this script and `test.sh` pass. `disable direct1` in r3 removed the route from r2 and r1 in about 1 second, the ping failed, `Import withdraws` counted 1, and `enable direct1` brought the route back.
Untested: the lab on macOS and on native Linux.
