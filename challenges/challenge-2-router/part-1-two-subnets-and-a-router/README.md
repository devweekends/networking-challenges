# Challenge 2, part 1: two subnets and a router

Goal: build a router out of a computer with two plugs. Put a laptop on one network and a server on another. Make a ping cross the router, then capture it and see which addresses change.

The addresses here belong to the lab only. `192.168.1.x` is a private range. `203.0.113.x` is a range made for examples, so no real website uses it. We use it to play "the internet".

This part is **gapped**. The script `router.sh` is almost complete. Three small things are missing, and each is marked `TODO`. The test tells you which one is wrong.

## 101: words you need

| Word | Plain meaning |
|---|---|
| Router | A computer with two or more plugs, each on a different network. It passes packets from one network to the other |
| Subnet | One small network. Here there are two: `192.168.1.0/24` and `203.0.113.0/24` |
| Route | A rule that says where to send packets for some addresses: "for addresses like this, go that way" |
| Default route | The rule of last resort: "for everything else, send it to the router". Written `default via 192.168.1.1` |
| Gateway | The router that your computer sends everything else to. Here, the laptop's gateway is `192.168.1.1` |
| Forwarding | A router passing on a packet that is not for itself. Linux has it off by default |
| Next hop | The next computer a packet is handed to on its way. Every router on the way is one hop |
| MAC address | The hardware address of one plug. It only matters on one cable. Every cable has its own pair |
| TTL | "Time to live." A counter in each packet. Every router lowers it by one. Linux starts it at 64 |
| ICMP unreachable | A message from a router that says "I got your packet, but I do not know where to send it" |
| traceroute | A tool that lists every router on the way to an address |

## What you build

```
  laptop                    router                          server
  192.168.1.23/24 --cable-- 192.168.1.1/24   203.0.113.1/24 --cable-- 203.0.113.80/24
  veth-laptop               veth-rin         veth-rout               veth-server
```

The router has two plugs. `veth-rin` is on the home side. `veth-rout` is on the "internet" side. There is no NAT in this part. The router only forwards. NAT comes in challenge 4.

Three things must be true before a ping can cross:

1. The laptop must know the way out (a default route to the router).
2. The router must be willing to forward (forwarding on).
3. The server must know the way back (a route to the home network through the router).

Before you run anything, guess: if you forget only the third one, does the laptop's ping get through to the server?

## Steps

Run these **in the lab**. First:

```
cd /work/challenges/challenge-2-router/part-1-two-subnets-and-a-router
```

| # | Type this | What it does | Script line |
|---|---|---|---|
| 1 | `bash router.sh` | Builds everything below. Safe to run again. Until you fill the gaps, the last ping fails. That is expected | whole file |
| 2 | (delete the old network) | Removes what the course built before | [router.sh#L13](router.sh#L13) |
| 3 | `ip netns add laptop` and two more | Makes three computers: laptop, router, server | [router.sh#L16](router.sh#L16) |
| 4 | `cable_if ...` twice | Makes two cables. The router gets two plugs, `veth-rin` and `veth-rout`. See [lib.sh#L85](../../../toolkit/lib.sh#L85) | [router.sh#L22](router.sh#L22) |
| 5 | `ip addr add ...` four times | Gives each plug an address. The router gets one on each network | [router.sh#L29](router.sh#L29) |
| 6 | `ping` twice | The mid-point check: each side reaches its own router. No gap is needed for this | [router.sh#L35](router.sh#L35) |
| 7 | Gap 1 | The laptop's default route | [router.sh#L39-L42](router.sh#L39-L42) |
| 8 | Gap 2 | Switch forwarding on in the router | [router.sh#L44-L46](router.sh#L44-L46) |
| 9 | Gap 3 | The server's route back to the home network | [router.sh#L48-L50](router.sh#L48-L50) |
| 10 | (look at the result) | Prints the routes and sends a ping across | [router.sh#L53](router.sh#L53) |
| 11 | `bash test.sh` | Checks all of the above and names the gap that is wrong | the gap checks start at [test.sh#L55](test.sh#L55) |
| 12 | `ip netns exec laptop ping -c1 -W1 198.51.100.7` | Pings an address the router has no route for. You should see `Destination Net Unreachable` from `192.168.1.1`. The router answered. It just has nowhere to send it | [test.sh#L105](test.sh#L105) |
| 13 | `ip netns exec laptop traceroute -n 203.0.113.80` | Lists the hops. You should see two lines: the router `192.168.1.1`, then the server | none |
| 14 | the capture, below | You watch one ping on both sides of the router | [test.sh#L127](test.sh#L127) |

### The capture

You want to see the same ping on both cables. You have one terminal, so run both captures in the background with `&`.

```
ip netns exec router tcpdump -n -e -v -i veth-rin -c 2 icmp > inside.txt 2>&1 &
ip netns exec router tcpdump -n -e -v -i veth-rout -c 2 icmp > outside.txt 2>&1 &
sleep 1
ip netns exec laptop ping -c1 -W1 203.0.113.80
wait
cat inside.txt outside.txt
```

Line by line:

- `-i veth-rin` watches the router's inside plug. `-i veth-rout` watches the outside plug.
- `-n` shows numbers, not names. `-e` shows hardware addresses (MAC). `-v` shows more detail, such as TTL.
- `icmp` shows only pings. Without a filter, a new cable also carries IPv6 chatter.
- `-c 2` stops after 2 packets: the request and the reply.
- `sleep 1` gives tcpdump a second to start. `wait` waits until both are done.

To find the MAC addresses of the four plugs, run `ip netns exec router ip link` and the same in `laptop` and `server`. Look for `link/ether`.

What you should see (the shape, not exact text):

| Cable | Line | Source MAC to destination MAC | IP addresses | TTL |
|---|---|---|---|---|
| Inside | request | laptop to router (`veth-rin`) | `192.168.1.23 > 203.0.113.80` | 64 |
| Inside | reply | router (`veth-rin`) to laptop | `203.0.113.80 > 192.168.1.23` | 63 |
| Outside | request | router (`veth-rout`) to server | `192.168.1.23 > 203.0.113.80` | 63 |
| Outside | reply | server to router (`veth-rout`) | `203.0.113.80 > 192.168.1.23` | 64 |

The IP addresses are the same on both cables. The MAC addresses are not. The TTL goes down by one at the router. The MAC pair belongs to one cable only. The router makes a new frame for the next cable.

## Hints

Each gap has a ladder. Try the first step. Open the next one only if you are still stuck.

| Gap | Step 1: a nudge | Step 2: the name | Step 3: the shape of the command |
|---|---|---|---|
| 1 | A packet for another network has to leave the laptop. Where does the laptop send it? | A default route | `ip route add default via ROUTER_ADDRESS` inside the laptop |
| 2 | A ping that arrives on one router plug and never leaves the other means the router is not forwarding | The setting `net.ipv4.ip_forward` | `sysctl -w net.ipv4.ip_forward=VALUE` inside the router |
| 3 | The ping arrives. Does the answer know the way home? | A route on the server | `ip route add NETWORK via ROUTER_ADDRESS` inside the server |

If you are stuck:

1. Do both sides reach their own router? (The mid-point check.)
2. Is `ip netns exec router sysctl net.ipv4.ip_forward` equal to `1`?
3. Does `ip netns exec server ip route` show the way back to `192.168.1.0/24`?
4. Run `tcpdump -n -i veth-rin icmp` and `tcpdump -n -i veth-rout icmp` in the router, send one ping, and find where the echo stops.

If you are still stuck after the hints, build the finished network of this part and go on with steps 12 to 14:

```
bash /work/toolkit/restore.sh 2.1
```

It changes only the lab network, not your `router.sh`. It runs the course's own answer: read [If you are stuck on a part](../../../README.md#if-you-are-stuck-on-a-part) first.

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `192.168.1.23`, `192.168.1.1` | We chose them. A private range, like a home network. `.1` for the router is a common habit |
| `203.0.113.0/24` | A range reserved for examples (RFC 5737). It stands for "the internet" and no real server uses it |
| `203.0.113.1`, `203.0.113.80` | The router's outside plug and the server. We chose them |
| `198.51.100.7` | Another example-only range. We chose it because the router has no route to it, so it is a ping that must fail |
| `/24` | The first three numbers name the network, as in challenge 1 |
| `-c1`, `-c2`, `-W1` | Send 1 or 2 pings. Wait 1 second for each answer |
| `ttl 64`, then `ttl 63` | Linux starts a packet at 64. The router lowers it by one |
| `-c 2` in tcpdump | Stop after 2 packets: the request and the reply |
| 2 hops in traceroute | One router, then the server |

## Results

Fill in [results.md](results.md). Commit it.

## Draft status (remove before publishing)

Tested (course notes, 2026-10-24 to 2026-10-26): namespaces, virtual cables, forwarding on with `sysctl`, routes, `traceroute -n` showing the router then the destination, the router answering `Destination Net Unreachable` when it has no default route, `tcpdump -e` showing MAC addresses, and the TTL arithmetic (64 minus the number of routers).
Untested: the new `cable_if` helper in `lib.sh`, the exact `tcpdump -n -e -v -U -c 2 icmp` output the test matches, the text `From 192.168.1.1 icmp_seq=1 Destination Net Unreachable` with `-c1 -W1`, and the flags `-w 1 -q 1 -m 5` for `traceroute`.
