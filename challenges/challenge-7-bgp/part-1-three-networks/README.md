# Challenge 7, part 1: three networks that talk BGP

Goal: build three small networks in a line. Each one is its own autonomous system with its own number. Run BGP in each, so that the two ends learn each other's address block. Then read the AS path and send a ping across.

The addresses here belong to the lab only. `198.51.100.0/24` and `203.0.113.0/24` are ranges made for examples. They stand for two blocks on the internet. The AS numbers `64496` to `64511` are also made for examples. No real network uses them.

This part is **guided**. The script `three-networks.sh` is complete. Read it, run it, and read what it prints. Part 2 uses the same three networks.

## 101: words you need

| Word | Plain meaning |
|---|---|
| Autonomous system (AS) | One network run by one organisation, with one routing policy. A home provider, a university, a cloud company |
| AS number (ASN) | The number that names an AS. Here: `64496`, `64497`, `64498` |
| Address block, prefix | A range of addresses that one network owns. `198.51.100.0/24` is the 256 addresses from `198.51.100.0` to `198.51.100.255` |
| BGP | Border Gateway Protocol. Networks use it to tell their neighbours which blocks they can reach |
| Session, neighbour | Two BGP routers that talk to each other over TCP port 179. Each one is the other's neighbour |
| Announce | "I can reach this block. Send its traffic to me." |
| AS path | The list of networks an announcement crossed. Each network adds its own number to the front |
| Established | The state of a BGP session that is up. Routes flow only in this state |
| BIRD | A BGP program for Linux. One config file, one program per router. `bird` is the program, `birdc` asks it questions |
| Control socket | A file that `birdc` uses to talk to one running `bird`. Here: `/tmp/bird-r1.ctl` and so on |
| Dummy interface | A pretend interface that is always up. It holds an address, like a server inside the network |

## What you build

```
     AS64496                        AS64497                        AS64498
  [ r1 ] 10.0.12.1 --- cable --- 10.0.12.2 [ r2 ] 10.0.23.2 --- cable --- 10.0.23.3 [ r3 ]
  dummy0 198.51.100.1/24                   (owns no block)                 dummy0 203.0.113.1/24
  owns 198.51.100.0/24                                                     owns 203.0.113.0/24
```

Each router is a namespace, as in challenges 1 to 6. Each cable is its own small network: `10.0.12.0/24` joins r1 and r2, `10.0.23.0/24` joins r2 and r3. The last number of each address is the router's number.

r1 and r3 own a block each. r2 owns nothing. It only carries traffic between them, like a provider.

Before you run anything, guess: when r1 learns the way to `203.0.113.0/24`, which AS numbers are in the AS path, and in which order?

## Steps

Run these **in the lab**. First:

```
cd /work/challenges/challenge-7-bgp/part-1-three-networks
```

| # | Type this | What it does | Script line |
|---|---|---|---|
| 1 | `bash three-networks.sh` | Builds everything below and prints the result. Safe to run again | whole file |
| 2 | (delete the old network) | Removes what the course built before. It also stops old BIRD programs | [three-networks.sh#L26](three-networks.sh#L26) |
| 3 | (make three routers) | r1, r2 and r3 | [three-networks.sh#L29](three-networks.sh#L29) |
| 4 | two cables, four addresses | The line r1 -- r2 -- r3 | [three-networks.sh#L34](three-networks.sh#L34) |
| 5 | `sysctl -w net.ipv4.ip_forward=1` in each | Each router may pass on packets. r2 needs it most: the ping crosses it | [three-networks.sh#L42](three-networks.sh#L42) |
| 6 | `ip link add dummy0 type dummy` | r1 and r3 get their block, on a dummy interface | [three-networks.sh#L47](three-networks.sh#L47) |
| 7 | (write three config files) | `r1.conf`, `r2.conf` and `r3.conf` appear in this folder. See [The config, line by line](#the-config-line-by-line) | [three-networks.sh#L56](three-networks.sh#L56) |
| 8 | `bird -p -c r1.conf` | Checks the file. It prints nothing when the file is fine | [three-networks.sh#L154](three-networks.sh#L154) |
| 9 | `ip netns exec r1 bird -f -c r1.conf -s /tmp/bird-r1.ctl` | Starts BIRD inside r1. The script does this for each router, in the background | [three-networks.sh#L156](three-networks.sh#L156) |
| 10 | (wait about 5 seconds) | The sessions come up, then the routes arrive | [three-networks.sh#L159](three-networks.sh#L159) |
| 11 | `birdc -s /tmp/bird-r1.ctl show protocols` | Lists r1's protocols. `to_r2` should say `Established` | [three-networks.sh#L168](three-networks.sh#L168) |
| 12 | `birdc -s /tmp/bird-r1.ctl show route` | What r1's BIRD knows. You should see `203.0.113.0/24 ... [AS64498i] via 10.0.12.2` | [three-networks.sh#L170](three-networks.sh#L170) |
| 13 | `ip netns exec r1 ip route` | What Linux in r1 uses. The BIRD route has `proto bird` | [three-networks.sh#L172](three-networks.sh#L172) |
| 14 | `ip netns exec r1 ping -c2 -W1 -I 198.51.100.1 203.0.113.1` | A ping from r1's block to r3's block. You should see `2 received` and `ttl=63` | [three-networks.sh#L174](three-networks.sh#L174) |
| 15 | `ip netns exec r1 ping -c2 -W1 203.0.113.1` | The same ping without `-I`. It gets no answer. See [Why the ping needs -I](#why-the-ping-needs--i) | none |
| 16 | `birdc -s /tmp/bird-r3.ctl show route all 198.51.100.0/24` | The other direction. Look for `BGP.as_path: 64497 64496` | none |
| 17 | `bash test.sh` | Checks all of the above and names the step that is wrong | [test.sh#L36](test.sh#L36) |

`birdc` does not need `ip netns exec`. It talks to BIRD through the control socket, which is a file. So you can ask any router from the lab's own shell.

## The config, line by line

Open `r1.conf` (the script wrote it). Here it is with every line explained.

| Line | What it means |
|---|---|
| `router id 10.0.0.1;` | A name for this router, written like an address. It does not need to be an address the router owns. We use `10.0.0.N`, where N is the router number |
| `protocol device {` and `}` | Lets BIRD see the interfaces (cables and dummy0). Every BIRD config needs it |
| `protocol direct {` | Takes the blocks on some interfaces and puts them in BIRD's table, so BIRD can announce them |
| `ipv4;` | Only IPv4 blocks |
| `interface "dummy0";` | Only the block on `dummy0`. The cables are not announced. That is why step 15 fails |
| `protocol kernel {` | Joins BIRD's table to Linux's route table |
| `ipv4 {` | The IPv4 part of it |
| `export where source = RTS_BGP;` | Gives Linux only the routes BIRD learned by BGP. Linux knows its own blocks already |
| `protocol bgp to_r2 {` | One BGP session. `to_r2` is a name we chose. It shows in `show protocols` |
| `local as 64496;` | My own AS number |
| `neighbor 10.0.12.2 as 64497;` | The other end: its address on our cable, and its AS number. BIRD checks the number when the session starts |
| `ipv4 {` | The IPv4 routes on this session |
| `import all;` | Take every route this neighbour announces. BGP between networks needs a written rule here. Without one, BIRD refuses to take anything |
| `export all;` | Announce every route I have to this neighbour: my own block, and what I learned from others |
| `};` and `}` | The end of the `ipv4` part, and the end of the session |

`r3.conf` has the same lines with r3's numbers. `r2.conf` has two sessions, one to each neighbour. Its `dummy0` does not exist in this part, so r2 announces nothing of its own. It only passes on what it hears.

`import all` and `export all` are a choice. Real networks write longer rules here. You write your first one in part 3.

## Reading one route

`birdc -s /tmp/bird-r1.ctl show route` prints:

```
203.0.113.0/24       unicast [to_r2 15:55:08.826] * (100) [AS64498i]
	via 10.0.12.2 on veth-to-r2
```

| Part | Meaning |
|---|---|
| `203.0.113.0/24` | The block |
| `[to_r2 15:55:08.826]` | It came from the session `to_r2`, at this time |
| `*` | This is the route BIRD chose. Only chosen routes go to Linux |
| `(100)` | BIRD's own preference for the protocol. BGP routes get 100. It is not BGP's local preference |
| `[AS64498i]` | The network that first announced it, the origin: AS64498. `i` is the origin code IGP: the origin network put the block into BGP from inside its own network (part 2 shows it as `BGP.origin: IGP`) |
| `via 10.0.12.2 on veth-to-r2` | Send the traffic to r2, out of the cable to r2 |

Part 2 reads the long form, `show route all`.

## Why the ping needs -I

Without `-I`, Linux picks the source address of the cable: `10.0.12.1`. The ping reaches r3. But nobody announces `10.0.12.0/24`, so r3 has no way back. The answer is lost.

With `-I 198.51.100.1`, the ping comes from r1's block. r3 learned that block by BGP, so the answer finds its way home.

This is true on the internet too. A packet needs a way there, and a way back.

## Hints

1. A session that is not `Established`: check the `neighbor` line. Is the address on the same cable? Is the AS number the one in the other router's `local as`?
2. A session that stays in `Active` or `Connect`: can the two routers ping each other's cable address? `ip netns exec r1 ping -c1 -W1 10.0.12.2`
3. BIRD did not start: read its log, `cat /tmp/networking-course-pids/bird-r1.log`. Check the file with `bird -p -c r1.conf`.
4. The route is in BIRD but not in `ip route`: look at the `protocol kernel` block.
5. Many lines show the time a route arrived. Your times will differ.

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `64496`, `64497`, `64498` | AS numbers reserved for examples (RFC 5398). We chose the first three |
| `198.51.100.0/24`, `203.0.113.0/24` | Ranges reserved for examples (RFC 5737). They play two public blocks |
| `10.0.12.0/24`, `10.0.23.0/24` | Private ranges for the cables. `12` is the cable from r1 to r2. `23` is r2 to r3 |
| `.1`, `.2`, `.3` | The router's number |
| `10.0.0.1` to `10.0.0.3` | Router ids. Only a name. We chose them |
| `179` | The TCP port BGP uses |
| `(100)` | BIRD's default preference for BGP routes |
| `ttl=63` | Linux starts at 64. r2 is one router on the way, so the answer arrives with 63 |
| about 5 seconds | The time BIRD takes to open a session and send the first routes in this lab |

## Results

Fill in [results.md](results.md). Commit it and the three `.conf` files the script wrote.

## Draft status (remove before publishing)

Tested in the lab image (BIRD 2.14), 2026-10-27: this script and `test.sh` pass. Sessions come up in about 5 seconds. The ping without `-I` gets no answer. `birdc` works from the lab's own shell through the control socket.
Untested: the lab on macOS and on native Linux.
