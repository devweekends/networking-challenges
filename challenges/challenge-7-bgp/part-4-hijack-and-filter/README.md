# Challenge 7, part 4: steal a block, then stop it with a filter

Goal: from the wrong network, announce a small piece of someone else's block. Watch traffic for that piece go to the wrong network, while the rest still goes to the owner. Then give r3 a filter that accepts only the owner's exact block, and watch the theft fail.

Do part 3 first. This script builds the same triangle again.

This part is **gapped**. The script `hijack.sh` is almost complete. Three small things are missing, and each is marked `TODO`. The test tells you which one is wrong.

You do this only inside your own lab. Announcing someone else's block on the real internet breaks their service and can be a crime.

## 101: words you need

| Word | Plain meaning |
|---|---|
| Hijack | A network announces a block that is not its own. Traffic for that block goes to it |
| More specific | A smaller block inside a bigger one. `198.51.100.128/25` is the top half of `198.51.100.0/24` |
| Longest prefix match | When two routes cover an address, the router uses the one with the longer prefix: `/25` beats `/24`. You met it in chapter 4.3 |
| Origin | The network that first announced a block: the last number in the AS path |
| Filter | A rule BIRD runs on every route a neighbour sends. It accepts or rejects the route |
| `net` | Inside a BIRD filter: the block of this route |
| `bgp_path.last` | Inside a BIRD filter: the last AS in the path, the origin |
| `show route filtered` | Routes that a filter rejected. BIRD keeps them, so you can see them, but never uses them |
| RPKI | A system where block owners sign a record: "this block is announced by this AS". Routers can fetch the records and check each route |
| Route origin validation | Checking each route's origin against those signed records. Your filter in this part does the same job, by hand |

## What you build

The triangle of part 3, with no backup filter. Every session takes every route, so r3 reaches r1 straight over the direct link.

```
                       AS64497 (the wrong network)
                       [ r2 ]  dummy0: 198.51.100.130/25 (Gap 1)
                      /      \
                     /        \
  AS64496 (owner) [ r1 ]------[ r3 ] AS64498
   198.51.100.0/24             203.0.113.0/24
   web page at .1 and .130     r3 visits the web pages
```

r1 owns `198.51.100.0/24`. It runs a tiny web page on `198.51.100.1` and on `198.51.100.130`. r2 runs a web page too. Each page says who answered:

- `r1 (AS64496), the real owner of 198.51.100.0/24`
- `r2 (AS64497), the wrong network`

r2 then gives itself `198.51.100.130/25`. BIRD in r2 announces the block `198.51.100.128/25` (the addresses `.128` to `.255`) as if it were r2's own.

Before you fill the gaps, guess: during the hijack, who answers when r3 visits `198.51.100.130`? And who answers for `198.51.100.1`?

## Steps

Run these **in the lab**. First:

```
cd /work/challenges/challenge-7-bgp/part-4-hijack-and-filter
```

| # | Type this | What it does | Script line |
|---|---|---|---|
| 1 | `bash hijack.sh` | Builds everything and runs every step below. Safe to run again | whole file |
| 2 | (the triangle) | The same routers and cables as part 3 | [hijack.sh#L48](hijack.sh#L48) |
| 3 | (the blocks) | r1 gets `.1` and `.130` in its `/24`. r2 gets an empty `dummy0` | [hijack.sh#L62](hijack.sh#L62) |
| 4 | `busybox httpd` in r1 and r2 | The two web pages | [hijack.sh#L74](hijack.sh#L74) |
| 5 | (the configs) | r1 and r2 take every route. r3's file has the filter `owner_only`, not used yet | [hijack.sh#L80](hijack.sh#L80) |
| 6 | Gap 2 | The accept line of the filter `owner_only` | [hijack.sh#L178-L181](hijack.sh#L178-L181) |
| 7 | (start BIRD, wait) | r3 starts with `import all;` | [hijack.sh#L206](hijack.sh#L206) |
| 8 | (look) | The mid-point check: before the hijack, r1 answers for both addresses. Saved in `before-hijack.txt` | [hijack.sh#L220](hijack.sh#L220) |
| 9 | Gap 1 | The hijack: r2 announces `198.51.100.128/25` | [hijack.sh#L225-L227](hijack.sh#L225-L227) |
| 10 | (look) | r2 answers for `.130`. r1 still answers for `.1`. Saved in `hijack.txt` | [hijack.sh#L229](hijack.sh#L229) |
| 11 | Gap 3 | r3 uses the filter on both of its sessions | [hijack.sh#L234-L236](hijack.sh#L234-L236) |
| 12 | `birdc -s /tmp/bird-r3.ctl configure` | BIRD reads the new file. The `/25` leaves r3's table | [hijack.sh#L239](hijack.sh#L239) |
| 13 | (look) | r1 answers for both again. Saved in `after-filter.txt` | [hijack.sh#L242](hijack.sh#L242) |
| 14 | `birdc -s /tmp/bird-r3.ctl show route filtered` | The `/25` is kept, but marked as rejected | none |
| 15 | `birdc -s /tmp/bird-r1.ctl show route all 198.51.100.128/25` | r1 has the stolen block too: r1 takes everything. Its path is `64497` | none |
| 16 | `bash test.sh` | Checks all of the above, then tries a second kind of theft. It names the gap that is wrong | the gap checks start at [test.sh#L53](test.sh#L53) |

Each "look" runs four commands. You can type them yourself:

```
birdc -s /tmp/bird-r3.ctl show route
ip netns exec r3 ip route get 198.51.100.130
ip netns exec r3 curl -sS -m 3 --interface 203.0.113.1 http://198.51.100.130:8080/
ip netns exec r3 curl -sS -m 3 --interface 203.0.113.1 http://198.51.100.1:8080/
```

`--interface 203.0.113.1` makes curl send from r3's block, like `ping -I` in part 1.

## Why the theft works

During the hijack, r3 has two routes that cover `198.51.100.130`:

```
198.51.100.0/24      unicast [to_r1 ...] * (100) [AS64496i]
	via 10.0.13.1 on veth-to-r1
198.51.100.128/25    unicast [to_r2 ...] * (100) [AS64497i]
	via 10.0.23.2 on veth-to-r2
```

Both have a `*`, because they are two different blocks. Linux gets both. For `198.51.100.130`, Linux uses the longest prefix that matches: the `/25`. So the visit goes to r2. For `198.51.100.1`, only the `/24` matches, so it still goes to r1. Traffic is split.

The AS path does not help. It says `AS64497i`: r2 is the origin. A router does not know who should own a block, unless someone tells it.

## The filter, line by line

```
filter owner_only {
  if net = 198.51.100.0/24 && bgp_path.last = 64496 then accept;
  reject;
}
```

| Line | Meaning |
|---|---|
| `filter owner_only {` | A named filter. `owner_only` is a name we chose |
| `if net = 198.51.100.0/24` | The block must be exactly this one. A `/25` inside it is a different block, so it does not match |
| `&& bgp_path.last = 64496` | And its origin must be AS64496, the owner. `&&` means "and" |
| `then accept;` | Keep this route |
| `reject;` | Everything else is dropped |
| `}` | The end of the filter |

The session line `import filter owner_only;` (Gap 3) runs it on every route from that neighbour.

The `/24` that comes through r2 still passes: its path is `64497 64496`, and the last number is the owner's. The filter checks who announced the block, not who passed it on.

This list is written by hand and has one line. It is a stand-in. Real route origin validation (RPKI) checks signed records that any network can fetch, for millions of blocks, and nobody writes them into each router by hand. It catches a wrong origin, like this hijack. It does not catch a route with the right origin that went somewhere it should not go.

Note: this filter rejects every block that is not on its list. That is fine in this lab, where r3 needs only r1's block. A real list has a line for every signed block, and a router usually still accepts a block that has no record at all.

r3's two sessions have one more line, `import keep filtered on;`. It tells BIRD to keep the rejected routes in a side list, so `show route filtered` can show them. Without it, BIRD drops them and forgets them.

## The second theft (in test.sh)

The test also lets r2 announce the whole `198.51.100.0/24`, with r2 as the origin. The block is exact, so a filter that checks only the block would let it in. Your filter must reject it, because the last AS is `64497`, not `64496`.

## Hints

Each gap has a ladder. Try the first step. Open the next one only if you are still stuck.

| Gap | Step 1: a nudge | Step 2: the name | Step 3: the shape |
|---|---|---|---|
| 1 | BIRD in r2 announces every block on `dummy0`. What block does `198.51.100.130/25` sit in? | `ip addr add`, inside r2 | `in_ns r2 ip addr add 198.51.100.130/25 dev dummy0` |
| 2 | Which two things make a route "the owner's own"? | `net` and `bgp_path.last`, joined by `&&` | `if net = 198.51.100.0/24 && bgp_path.last = 64496 then accept;` |
| 3 | A filter does nothing until a session uses it | The import line | `R3_IMPORT='import filter owner_only;'` |

If you are stuck:

1. Does BIRD accept r3's file? `bird -p -c r3.conf`.
2. Does r3 use the filter? `birdc -s /tmp/bird-r3.ctl show protocols all to_r2` should show `Input filter:   owner_only`.
3. Does r3 still have the real `/24`? If not, the filter rejects everything. Check the accept line.
4. Is the `/25` in `show route filtered`? Then the filter works.

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `198.51.100.0/24` | r1's block, from part 1 |
| `198.51.100.128/25` | The top half of it: `.128` to `.255`. `/25` means 25 bits name the network, so it holds 128 addresses |
| `198.51.100.130` | An address in the top half. We chose it for r1's second web page |
| `198.51.100.1` | An address in the bottom half. Only the `/24` covers it |
| `198.51.100.200/24` | Used by the test for the second theft: r2 claims the whole `/24` |
| `64496` | The owner, AS64496 |
| `64497` | The wrong network |
| `8080` | The web pages' port. We chose it |

## Results

Fill in [results.md](results.md). Commit it with the three `.txt` files and the three `.conf` files the script wrote.

## Draft status (remove before publishing)

Tested in the lab image (BIRD 2.14), 2026-10-27: the reference script and `test.sh` pass; the template with all gaps empty fails with GAP messages; each gap left empty alone fails with its own GAP message; a filter without the origin check fails the second theft with a GAP 2 message. `birdc configure` removed the `/25` from r3 with no session restart, and `show route filtered` lists it (with `import keep filtered on`).
Untested: the lab on macOS and on native Linux.
