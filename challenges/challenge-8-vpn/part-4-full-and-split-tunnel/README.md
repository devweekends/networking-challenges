# Challenge 8, part 4: full tunnel and split tunnel

Goal: send **everything** from the laptop through the office. The lab website should then see the office's address, not the café's. This is what a VPN app does when it says "your address is hidden". Then find the leak that stays: your name lookups still go to the café. Fix it. Last, split the tunnel: only office traffic goes inside, and the rest goes out through the café as before.

Remember the question from chapter 1.1: which address does a website see? Here you change the answer on purpose.

Do part 2 first. The script of this part starts by running **your** `tunnel.sh`, so part 2's test must pass before you begin.

This part is **gapped**. The script `full-split.sh` is almost complete. Five small things are missing, and each is marked `TODO`. The test tells you which one is wrong.

## 101: words you need

| Word | Plain meaning |
|---|---|
| Full tunnel | Every packet goes into the tunnel. The default route is `wg0` |
| Split tunnel | Only some networks go into the tunnel (here, the office). Everything else goes the normal way |
| `0.0.0.0/0` | Every IPv4 address. In AllowedIPs it means "this peer gets everything" |
| Default route | The route for every address that has no more exact route |
| `/32` | One single address. It is more exact than any other route, so it wins |
| Endpoint route | A `/32` for the peer's public address, outside the tunnel. The outer packets need it |
| Name server (resolver) | The computer that turns a name like `web.test` into an address. The laptop's is in `/etc/netns/laptop/resolv.conf` |
| DNS leak | Name questions that go outside the tunnel while you think everything is inside |
| dnsmasq | A small name server. You used it in challenge 5. Here one runs in each router |
| `dig` | Asks a name server a question and prints the answer |

## What you build

```
  FULL TUNNEL                                                          
  laptop: default dev wg0 ====== tunnel ======> vpnbox --> officert --(masquerade 203.0.113.2)--> website
          203.0.113.2/32 via 192.168.50.1 (the outer packets, outside the tunnel)
          name server: 192.168.50.1 (café) at first, then 10.20.0.1 (office, through the tunnel)

  SPLIT TUNNEL
  laptop: 10.20.0.0/24 dev wg0 ====== tunnel ======> vpnbox --> officesrv
          default via 192.168.50.1 --> caferouter --(masquerade 198.51.100.2)--> website
```

Two name servers, both given:

| File | Runs in | Answers |
|---|---|---|
| `cafe-dns.conf` | `caferouter`, on `192.168.50.1` | `web.test` is `192.0.2.80` |
| `office-dns.conf` | `officert`, on `10.20.0.1` | `web.test` is `192.0.2.80`, and `intranet.test` is `10.20.0.5` (a name only the office knows) |

Before you run anything, guess:

1. In the full tunnel, the laptop asks for `web.test`. Can the café see the question?
2. In the split tunnel, which address does the website see?

## Steps

Run these **in the lab**. First:

```
cd /work/challenges/challenge-8-vpn/part-4-full-and-split-tunnel
```

| # | Type this | What it does | Script line |
|---|---|---|---|
| 1 | `bash full-split.sh` | Builds everything and runs every step below. Safe to run again | whole file |
| 2 | (run your part 2) | The office, the café and the tunnel, split as part 2 left it | [full-split.sh#L17](full-split.sh#L17) |
| 3 | `dnsmasq` twice | A name server in each router. The laptop starts with the café's | [full-split.sh#L27](full-split.sh#L27) |
| 4 | `curl` the website | Before: it sees `198.51.100.2`. Saved in `website-before.txt` | [full-split.sh#L48](full-split.sh#L48) |
| 5 | Gap 1 | The endpoint route: `203.0.113.2/32` outside the tunnel | [full-split.sh#L53-L57](full-split.sh#L53-L57) |
| 6 | Gap 2 | Everything into the tunnel: AllowedIPs `0.0.0.0/0` and the default route into `wg0` | [full-split.sh#L59-L62](full-split.sh#L59-L62) |
| 7 | Gap 3 | The way back, in the office router | [full-split.sh#L64-L68](full-split.sh#L64-L68) |
| 8 | `curl` the website, with a capture | Full tunnel: the website sees `203.0.113.2`. The café sees only UDP 51820. Saved in `routes-full.txt`, `website-full.txt`, `cafe-outside-full.txt` | [full-split.sh#L70](full-split.sh#L70) |
| 9 | `dig web.test`, with a capture | The question still goes to the café, in the clear. Saved in `dns-cafe.txt` | [full-split.sh#L84](full-split.sh#L84) |
| 10 | Gap 4 | Point the laptop's name server through the tunnel | [full-split.sh#L92-L95](full-split.sh#L92-L95) |
| 11 | `dig` twice, two captures | The questions now travel inside `wg0`. Saved in `dns-cafe-after.txt` and `dns-tunnel.txt` | [full-split.sh#L97](full-split.sh#L97) |
| 12 | Gap 5 | Split the tunnel again | [full-split.sh#L110-L114](full-split.sh#L110-L114) |
| 13 | `curl` and `ping`, with a capture | Split tunnel: the website sees `198.51.100.2`. The office is still reached through the tunnel. Saved in `routes-split.txt`, `website-split.txt`, `cafe-outside-split.txt` | [full-split.sh#L118](full-split.sh#L118) |
| 14 | `bash test.sh` | Checks all of the above and names the gap that is wrong | the gap checks start at [test.sh#L50](test.sh#L50) |

### Three things a full tunnel needs

**Gap 1, the endpoint route.** The laptop's outer packets go to `203.0.113.2`. If the default route is `wg0`, they would go into `wg0` too: the tunnel inside itself. WireGuard drops them, and the tunnel stops. A `/32` route for `203.0.113.2` through the café router is more exact than the default, so the outer packets still go out the normal way. `wg-quick` sets this up for you. Without it, `website-full.txt` says `curl: (28) Connection timed out`.

**Gap 2, everything in.** Two changes. AllowedIPs `0.0.0.0/0` lets the VPN box receive packets for any address. The default route into `wg0` puts them in the tunnel. You need both. With only the route, the laptop has no peer for `192.0.2.80`. With only AllowedIPs, nothing goes into `wg0`.

**Gap 3, the way back.** The VPN box hands `10.99.0.2 > 192.0.2.80` to the office router. The router masquerades it, so the website sees `203.0.113.2`. The answer comes back, and the router turns it back into `> 10.99.0.2`. Now it needs a route to `10.99.0.0/24`. Without one, it sends the answer to the internet. Another fix is masquerade on the VPN box: then the office router only ever sees `10.20.0.2`. We use the route.

`routes-full.txt` should show:

```
default dev wg0 scope link
10.20.0.0/24 dev wg0 scope link
10.99.0.0/24 dev wg0 proto kernel scope link src 10.99.0.2
192.168.50.0/24 dev veth-laptop proto kernel scope link src 192.168.50.23
203.0.113.2 via 192.168.50.1 dev veth-laptop
```

### The DNS leak

`dns-cafe.txt`, in the full tunnel (times left out):

```
IP 192.168.50.23.49165 > 192.168.50.1.53: 58617+ [1au] A? web.test. (49)
IP 192.168.50.1.53 > 192.168.50.23.49165: 58617* 1/0/1 A 192.0.2.80 (53)
```

The default route is `wg0`, but `192.168.50.1` is on the laptop's own cable. The route for `192.168.50.0/24` is more exact than the default. So the question goes to the café's name server, in plain text. The café now knows every name you look up, even though your web traffic is hidden.

After Gap 4, `dns-cafe-after.txt` has no DNS lines, and `dns-tunnel.txt` (on the VPN box's `wg0`) has (times left out):

```
IP 10.99.0.2.58897 > 10.20.0.1.53: 28881+ [1au] A? web.test. (49)
IP 10.20.0.1.53 > 10.99.0.2.58897: 28881* 1/0/1 A 192.0.2.80 (53)
IP 10.99.0.2.34872 > 10.20.0.1.53: 14612+ [1au] A? intranet.test. (54)
IP 10.20.0.1.53 > 10.99.0.2.34872: 14612* 1/0/1 A 10.20.0.5 (58)
```

The office now sees your questions, and the café does not. And the laptop can use office names like `intranet.test`. The café's name server says `Refused` for it. A real VPN app sets the name server for you when it connects. When it does not, this is the leak.

### The split tunnel

`cafe-outside-split.txt` shows both kinds of traffic side by side (times and some lines left out):

```
IP 198.51.100.2.50376 > 192.0.2.80.80: Flags [S], seq 423879124, ...
...
IP 198.51.100.2.50376 > 192.0.2.80.80: Flags [P.], seq 1:88, ... length 87: HTTP: GET /cgi-bin/whoami HTTP/1.1
...
IP 198.51.100.2.51820 > 203.0.113.2.51820: UDP, length 128
IP 203.0.113.2.51820 > 198.51.100.2.51820: UDP, length 128
```

The website visit is plain TCP, and the café can even read `GET /cgi-bin/whoami`. The ping to the office is one UDP packet each way. Only office traffic is inside the tunnel. A company VPN is often split like this, so your video calls do not go through the office.

## Hints

Each gap has a ladder. Try the first step. Open the next one only if you are still stuck.

| Gap | Step 1: a nudge | Step 2: the name | Step 3: the shape |
|---|---|---|---|
| 1 | The outer packets must not use the new default route. Which route is always more exact? | A `/32` route with `via` | `in_ns laptop ip route add 203.0.113.2/32 via 192.168.50.1` |
| 2 | Two settings decide what goes into the tunnel, and to which peer | AllowedIPs `0.0.0.0/0`, and `ip route replace default` | `in_ns laptop wg set wg0 peer "$VPNBOX_PUB" allowed-ips 0.0.0.0/0` and `in_ns laptop ip route replace default dev wg0` |
| 3 | Part 2's Gap 4 again, in another computer | A route to `10.99.0.0/24` in `officert` | `in_ns officert ip route add 10.99.0.0/24 via 10.20.0.2` |
| 4 | Where does the laptop read its name server from? | `/etc/netns/laptop/resolv.conf`, and the office's name server `10.20.0.1` | `echo "nameserver 10.20.0.1" > /etc/netns/laptop/resolv.conf` |
| 5 | Undo Gap 2. The route for `10.20.0.0/24` from part 2 is still there | AllowedIPs as in part 2, and the default route via the café router | `in_ns laptop wg set wg0 peer "$VPNBOX_PUB" allowed-ips 10.20.0.0/24,10.99.0.1/32` and `in_ns laptop ip route replace default via 192.168.50.1` |

If you are stuck:

1. The website times out in the full tunnel? `ip netns exec laptop wg show`: is `latest handshake` recent? If not, look at Gap 1.
2. The handshake is fine but the page does not come? `ip netns exec officert ip route get 10.99.0.2`. Look at Gap 3.
3. The website still sees `198.51.100.2`? `ip netns exec laptop ip route get 192.0.2.80` should say `dev wg0`.
4. Which name server does the laptop use? `cat /etc/netns/laptop/resolv.conf`

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `0.0.0.0/0` | Every IPv4 address |
| `203.0.113.2/32` | The office router's public address, the tunnel's endpoint |
| `192.168.50.1` | The café router, and the café's name server |
| `10.20.0.1` | The office router, and the office's name server |
| `web.test`, `intranet.test` | Names we made up. `.test` is reserved for tests (RFC 6761) |
| `192.0.2.80` | The lab website |
| port `53` | The usual port for DNS |
| `[1au]` in the capture | `dig` adds one extra record that says which DNS features it supports |
| `Refused` | The café's name server does not know `intranet.test`, and it has no one to ask |

## Results

Fill in [results.md](results.md). Commit it and the `.txt` files the script wrote.

## Draft status (remove before publishing)

Tested (lab image, 2026-10-27): the website seeing `198.51.100.2`, then `203.0.113.2` in the full tunnel, then `198.51.100.2` again in the split tunnel; the café outside plug carrying only UDP 51820 in the full tunnel, and TCP to `192.0.2.80` plus UDP 51820 in the split tunnel; the full tunnel timing out without Gap 1 and without Gap 3; DNS to `192.168.50.1` in the clear in the full tunnel; DNS through `wg0` to `10.20.0.1` after Gap 4; `Refused` for `intranet.test` from the café; `bash test.sh` passing, and failing with the right gap named when gaps are left empty.
Untested: IPv6 (the lab has none, so the IPv6 leak is taught in chapter 11.7 only); `wg-quick` and its DNS setting.
