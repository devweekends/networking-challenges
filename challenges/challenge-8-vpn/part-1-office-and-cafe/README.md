# Challenge 8, part 1: an office and a café, each behind NAT

Goal: build two private networks far apart. One is an office. The other is a café where you sit with your laptop. Each one hides behind its own router with NAT, as your home does. Then open one door in the office router: UDP port 51820 goes on to a VPN box inside. Prove the door works by breaking it on purpose.

In parts 2 to 4 you build a VPN tunnel through these two routers. This part builds the ground it stands on.

The addresses here belong to the lab only. `10.20.0.x` and `192.168.50.x` are private ranges. `203.0.113.x`, `198.51.100.x` and `192.0.2.x` are ranges made for examples. Here they stand for public addresses on the internet.

This part is **guided**. Nothing is missing. The script `office-cafe.sh` builds everything. You can run it whole, or type its lines one by one. Read each step. The test checks that it all works.

## 101: words you need

| Word | Plain meaning |
|---|---|
| Office network | `10.20.0.0/24`. A private network with a VPN box and a test server. The internet cannot reach it |
| Café network | `192.168.50.0/24`. A private network with your laptop in it |
| NAT, masquerade | The router rewrites the source address of each packet that leaves. You met it in challenge 4 |
| Public address | The router's outside address. The rest of the internet sees only this one. Office: `203.0.113.2`. Café: `198.51.100.2` |
| Port forward (DNAT) | The router sends packets for one of its ports on to a computer inside. Here: UDP 51820 goes to `10.20.0.2` |
| UDP | A way to send single packets with no handshake. WireGuard, the VPN in part 2, uses it |
| Port 51820 | The usual port for WireGuard. We use it on both sides |
| VPN box | The office computer that will hold the office end of the tunnel |
| NAT state (conntrack) | The router's memory of each conversation. A packet that matches an old conversation is handled the old way, even if the rules changed |
| `conntrack -F` | Forget every conversation. F is for flush |
| `nc -u` | netcat. A tiny tool that sends what you type. `-u` means UDP |

## What you build

```
     CAFÉ                         INTERNET                         OFFICE

  laptop                                                     vpnbox        officesrv
  192.168.50.23                                              10.20.0.2     10.20.0.5 (a web page)
     |                                                           |            |
  192.168.50.1                                               +---+------------+---+
  [ caferouter ]  masquerade                                 |  br-office 10.20.0.1 |
  198.51.100.2                                               [ officert ]  masquerade, and
     |                                                       203.0.113.2   UDP 51820 to 10.20.0.2
     |                                                           |
     +----- 198.51.100.1 [ internet ] 203.0.113.1 ---------------+
                         192.0.2.1
                             |
                         192.0.2.80 website (it tells you the address it sees)
```

Seven computers. Each one is a namespace, as in every challenge so far. The internet is one router that knows only the three public ranges. It has no route to `10.20.0.0/24` or to `192.168.50.0/24`.

Before you run anything, guess:

1. The laptop visits the website. Which address does the website see: `192.168.50.23` or `198.51.100.2`?
2. You delete the port forward rule, then send one more packet to `203.0.113.2:51820`. Does it still reach the VPN box?

## Steps

Run these **in the lab**. First:

```
cd /work/challenges/challenge-8-vpn/part-1-office-and-cafe
```

| # | Type this | What it does | Script line |
|---|---|---|---|
| 1 | `bash office-cafe.sh` | Builds everything and runs every step below. Safe to run again. `bash office-cafe.sh build-only` stops after step 9 | whole file |
| 2 | (make seven computers) | internet, website, officert, vpnbox, officesrv, caferouter, laptop | [office-cafe.sh#L21](office-cafe.sh#L21) |
| 3 | three cables to the internet router | The office, the café and the website each get a cable to `internet`. `internet` forwards between them | [office-cafe.sh#L30](office-cafe.sh#L30) |
| 4 | `ip link add br-office type bridge`, two cables | The office side: a bridge in the office router, with the VPN box and the server plugged in | [office-cafe.sh#L42](office-cafe.sh#L42) |
| 5 | one cable, two addresses | The café side: the laptop on a cable to the café router | [office-cafe.sh#L58](office-cafe.sh#L58) |
| 6 | `ip link set dev ... address 02:...` | Fixed hardware addresses, so every run looks the same | [office-cafe.sh#L67](office-cafe.sh#L67) |
| 7 | `nft -f -` in each router | Masquerade in both routers. In the office router, also the port forward for UDP 51820 | [office-cafe.sh#L84](office-cafe.sh#L84) |
| 8 | `busybox httpd` twice | The website's `/cgi-bin/whoami` page, and the office test page on `10.20.0.5` | [office-cafe.sh#L109](office-cafe.sh#L109) |
| 9 | `curl` twice, `ping` once | The website sees `198.51.100.2` for the laptop and `203.0.113.2` for the office server. The laptop cannot ping `10.20.0.5` | [office-cafe.sh#L118](office-cafe.sh#L118) |
| 10 | the forward experiment | Five packets to `203.0.113.2:51820`, with the rule on, off and on again. Each line goes into `forward-test.txt` | [office-cafe.sh#L131](office-cafe.sh#L131) |
| 11 | `bash test.sh` | Checks all of the above | [test.sh#L28](test.sh#L28) to [test.sh#L83](test.sh#L83) |

### Why the laptop cannot reach 10.20.0.5

Step 9 prints this:

```
From 198.51.100.1 icmp_seq=1 Destination Net Unreachable
```

`198.51.100.1` is the internet router. It got the ping, looked for `10.20.0.0/24` in its table, found nothing, and said so. A private address is not routed on the internet. This is the problem the tunnel solves in part 2.

### The forward experiment

The script sends one UDP packet from the laptop to `203.0.113.2` port `51820`, five times. Each time the VPN box listens with tcpdump. The laptop always sends from its own port 51820, so the five packets look the same to the routers.

`forward-test.txt` should say this (times differ):

```
1 rule on: arrived at the VPN box (... IP 198.51.100.2.51820 > 10.20.0.2.51820: UDP, length 6)
2 rule off, old NAT state kept: arrived at the VPN box (... IP 198.51.100.2.51820 > 10.20.0.2.51820: UDP, length 6)
3 rule off, NAT state flushed: nothing arrived at the VPN box
4 rule back, old NAT state kept: nothing arrived at the VPN box
5 rule back, NAT state flushed: arrived at the VPN box (... IP 198.51.100.2.51820 > 10.20.0.2.51820: UDP, length 6)
```

| Line | What happened |
|---|---|
| 1 | The rule sends the packet to `10.20.0.2`. The source is `198.51.100.2`: the café router masqueraded it. The port stayed 51820 |
| 2 | The rule is gone, but the packet still arrives. The office router remembers this conversation from line 1 and handles it the old way. A rule is only read for the first packet of a conversation |
| 3 | After `conntrack -F` the router has forgotten. It reads the rules again and finds no forward. The packet stops at the router |
| 4 | The rule is back, and still nothing arrives. The router remembers the failed conversation from line 3 |
| 5 | Flush again. Now the first packet meets the rule, and it arrives |

Lines 2 and 4 are the trap. When you change a NAT rule and nothing changes, the old state is the first thing to check. Step 10 prints the remembered conversation. It looks like this:

```
udp 17 29 src=198.51.100.2 dst=203.0.113.2 sport=51820 dport=51820 [UNREPLIED] src=10.20.0.2 dst=198.51.100.2 sport=51820 dport=51820 mark=0 use=1
```

The second half says "answers come from `10.20.0.2`". That is the forward, kept in memory. `29` is the number of seconds left before the router forgets on its own.

## Hints

1. A computer cannot reach its router? `ip netns exec NAME ip addr` and `ip netns exec NAME ip route`.
2. The website sees no answer? Is forwarding on in `internet`, `officert` and `caferouter`? `ip netns exec officert sysctl net.ipv4.ip_forward`
3. The forward does not work? `ip netns exec officert nft list ruleset`, then `ip netns exec officert conntrack -L`.
4. Lost? Run `bash office-cafe.sh` again. It starts from nothing.

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `10.20.0.0/24` | The office network. We chose it. A private range |
| `10.20.0.1`, `.2`, `.5` | The office router, the VPN box and the test server. We chose them |
| `192.168.50.0/24`, `.1`, `.23` | The café network, the café router and the laptop. We chose them. Not the same range as the office: two networks with the same range break a VPN |
| `203.0.113.0/24`, `198.51.100.0/24`, `192.0.2.0/24` | Ranges reserved for examples (RFC 5737). They stand for the internet |
| `203.0.113.2`, `198.51.100.2` | The office's and the café's public addresses |
| `192.0.2.80` | The lab website |
| `51820` | The usual WireGuard port. The office forwards it to the VPN box |
| `02:00:00:...` | Made-up hardware addresses. A first byte of `02` marks an address as set by hand, never burned into a card |
| `priority -100`, `priority 100` | The usual places for destination NAT (before routing) and source NAT (after routing), as in challenge 4 |
| `29` in the conntrack line | Seconds left. A UDP conversation with no answer is kept for 30 seconds |

## Results

Fill in [results.md](results.md). Commit it and `forward-test.txt`.

## Draft status (remove before publishing)

Tested (lab image, 2026-10-27): the seven-namespace build; the website seeing `198.51.100.2` and `203.0.113.2`; `Destination Net Unreachable` from `198.51.100.1`; the five-line forward experiment with the results shown above, including the conntrack line; `bash test.sh` passing.
Untested: the build with a learner typing the lines one by one.
