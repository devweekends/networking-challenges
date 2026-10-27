# Challenge 8, part 3: what each side sees

Goal: watch the tunnel from two places. At the café's outside plug you see what the café and its provider see. On the VPN box's `wg0` you see what the office sees after the tunnel. Then work out the size of one outer packet, and check your sum in a capture.

Do part 2 first. The script of this part starts by running **your** `tunnel.sh`, so part 2's test must pass before you begin.

This part is **gapped**. The script `captures.sh` is almost complete. Three small things are missing, and each is marked `TODO`. The test tells you which one is wrong.

## 101: words you need

| Word | Plain meaning |
|---|---|
| Outer packet | The UDP packet between `198.51.100.2` and `203.0.113.2`. This is all the internet sees |
| Inner packet | Your real packet, `10.99.0.2 > 10.20.0.5`. It is encrypted inside the outer one |
| Capture filter | The words at the end of a tcpdump line. `ip` means every IPv4 packet. `icmp` means only pings |
| `-l` | tcpdump prints each line at once. Without it, lines can sit in a buffer when the capture stops |
| `-v` | tcpdump prints more detail, such as the length of the whole IP packet |
| Padding | Zeros added to the end of the inner packet, so its length is a multiple of 16 |
| Header | The label at the front of a packet: addresses, ports, lengths |
| Link type RAW | `wg0` has no Ethernet header. tcpdump says `link-type RAW` for it |
| Keepalive | A tiny packet sent on purpose, only to keep a NAT mapping alive |

## What you build

```
  laptop -- [ caferouter ] ---- capture 1: veth-cafe-out ---- [ internet ] -- [ officert ] -- vpnbox --- officesrv
             veth-cafe-out      "what the café sees"                                         wg0
                                                                                             capture 2: "what the office sees"
```

Nothing new is built. You only look.

Before you run anything, guess:

1. During a ping and a web page fetch, which protocols does the café see on its outside plug? ICMP? TCP? UDP?
2. A ping packet is 84 bytes. How big is the outer packet that carries it?

## Steps

Run these **in the lab**. First:

```
cd /work/challenges/challenge-8-vpn/part-3-what-each-side-sees
```

| # | Type this | What it does | Script line |
|---|---|---|---|
| 1 | `bash captures.sh` | Builds everything and runs every step below. Safe to run again | whole file |
| 2 | (run your part 2) | The office, the café and the tunnel | [captures.sh#L15](captures.sh#L15) |
| 3 | Gap 1 | Capture every IPv4 packet on the café's outside plug for 6 seconds, while the laptop pings `10.20.0.5` 3 times and fetches the office page. Saved in `cafe-outside.txt` | [captures.sh#L27-L31](captures.sh#L27-L31) (traffic in [captures.sh#L33](captures.sh#L33)) |
| 4 | Gap 2 | Capture pings on the VPN box's `wg0`. Saved in `wg0.txt` | [captures.sh#L40-L42](captures.sh#L40-L42) |
| 5 | Gap 3 | Work out the outer size of an 84-byte ping. Saved in `size.txt` | [captures.sh#L51-L54](captures.sh#L51-L54) (with [captures.sh#L50](captures.sh#L50)) |
| 6 | `tcpdump -v ... -c 1` | One outer packet with its full length. The script compares it with your sum. Saved in `size-capture.txt` | [captures.sh#L58](captures.sh#L58) |
| 7 | `bash test.sh` | Checks all of the above and names the gap that is wrong | the gap checks start at [test.sh#L59](test.sh#L59) |

### Capture 1: the café's outside plug

`cafe-outside.txt` looks like this (times differ):

```
16:02:23.187210 IP 198.51.100.2.51820 > 203.0.113.2.51820: UDP, length 128
16:02:23.187326 IP 203.0.113.2.51820 > 198.51.100.2.51820: UDP, length 128
16:02:24.214950 IP 198.51.100.2.51820 > 203.0.113.2.51820: UDP, length 128
16:02:24.215170 IP 203.0.113.2.51820 > 198.51.100.2.51820: UDP, length 128
16:02:25.238517 IP 198.51.100.2.51820 > 203.0.113.2.51820: UDP, length 128
16:02:25.238621 IP 203.0.113.2.51820 > 198.51.100.2.51820: UDP, length 128
16:02:25.245212 IP 198.51.100.2.51820 > 203.0.113.2.51820: UDP, length 96
...
16:02:25.246285 IP 203.0.113.2.51820 > 198.51.100.2.51820: UDP, length 304
```

| What you see | What it tells the café |
|---|---|
| `198.51.100.2.51820 > 203.0.113.2.51820` | Someone here talks to `203.0.113.2`, port 51820. Probably a WireGuard VPN |
| `UDP` on every line | Only UDP. No ICMP, no TCP. The ping and the web page are hidden inside |
| `length 128`, six times | Three requests and three answers, all the same size, one second apart. That looks like a ping |
| other lengths (96, 160, 304) | The web page fetch. Sizes and timing are still visible |
| no `10.20.0.5` | The inner destination is not visible |

So the café sees **who** you talk to, **when**, and **how much**. It does not see **what**, or the address inside the office.

Try one thing: capture the café's **inside** plug (`veth-cafe-in`) instead. You still see only UDP 51820, from `192.168.50.23`. The tunnel starts on the laptop itself, so even the café Wi-Fi sees only the outer packet.

### Capture 2: the VPN box's wg0

`wg0.txt` looks like this:

```
listening on wg0, link-type RAW (Raw IP), snapshot length 262144 bytes
16:02:29.221667 IP 10.99.0.2 > 10.20.0.5: ICMP echo request, id 468, seq 1, length 64
16:02:29.221697 IP 10.20.0.5 > 10.99.0.2: ICMP echo reply, id 468, seq 1, length 64
```

This is the inner packet, after the VPN box opened it. Here the ping is plain to see. The office sees everything you send through the tunnel. Choose who you trust to run the other end.

### The outer size

The inner packet: 56 bytes of ping data, 8 bytes of ICMP header, 20 bytes of IP header. That is 84.

| Layer | Bytes | Running total |
|---|---|---|
| Inner IP packet | 84 | 84 |
| Padding to a multiple of 16 | 12 | 96 |
| WireGuard: 16 header (type, receiver, counter) and 16 check value | 32 | 128 (the `UDP, length 128` in capture 1) |
| UDP header | 8 | 136 |
| Outer IPv4 header | 20 | 156 |

`size-capture.txt` shows it:

```
16:02:31.340890 IP (tos 0x0, ttl 63, id 29141, offset 0, flags [none], proto UDP (17), length 156)
    198.51.100.2.51820 > 203.0.113.2.51820: UDP, length 128
```

`length 156` is the whole outer IP packet. `length 128` is the UDP data in it. If you forget the padding, you get 144, and the capture says you are wrong.

This is also why `wg0` has `mtu 1420`, not 1500. The outer headers need room.

## Optional extra: keepalive

So far the laptop always starts. Now let the office start, after a quiet time. To make the café router forget fast, give it short UDP timeouts (10 seconds). Run `bash captures.sh` first, then type:

```
ip netns exec caferouter sysctl -w net.netfilter.nf_conntrack_udp_timeout=10 net.netfilter.nf_conntrack_udp_timeout_stream=10
ip netns exec laptop ping -c1 -W2 10.20.0.5 > /dev/null
sleep 25
ip netns exec caferouter conntrack -L -p udp
ip netns exec vpnbox ping -c2 -W1 10.99.0.2
```

The first `ping` resets the timer with the new 10 seconds. WireGuard sends one last small packet about 10 seconds after it last heard from the other side, so wait 25 seconds. Then `conntrack -L` shows `0 flow entries`, and the VPN box's ping gets `0 received`. The café router has forgotten the mapping, so it does not know the laptop should get the VPN box's packet.

Now switch keepalive on, on the laptop (the side behind NAT), and try again:

```
ip netns exec laptop wg set wg0 peer "$(cat /tmp/networking-course-wg/vpnbox.pub)" persistent-keepalive 3
ip netns exec laptop ping -c1 -W2 10.20.0.5 > /dev/null
sleep 25
ip netns exec caferouter conntrack -L -p udp
ip netns exec vpnbox ping -c2 -W1 10.99.0.2
```

Now the mapping is still there, and the VPN box gets `2 received`. The laptop sends a keepalive every 3 seconds, so the café router never forgets. Look at the conntrack line: the café router may now use another outside port than 51820, because the VPN box's lost packets left a memory on 51820. The VPN box does not mind. It learns the new endpoint from the next packet. Real defaults are 30 and 120 seconds, and 25 seconds is the usual keepalive.

## Hints

Each gap has a ladder. Try the first step. Open the next one only if you are still stuck.

| Gap | Step 1: a nudge | Step 2: the name | Step 3: the shape |
|---|---|---|---|
| 1 | Where does the café meet the internet? Which filter shows everything, not one port? | `caferouter`, `veth-cafe-out`, the filter `ip`, and `timeout 6` | `timeout 6 ip netns exec caferouter tcpdump -n -l -i veth-cafe-out ip > "$HERE/cafe-outside.txt" 2>&1 &` then `CAFE_PID=$!` |
| 2 | Where is the inner packet plain again? | `vpnbox`, `wg0`, the filter `icmp`, `-c 4` | `timeout 5 ip netns exec vpnbox tcpdump -n -l -i wg0 -c 4 icmp > "$HERE/wg0.txt" 2>&1 &` then `WG_PID=$!` |
| 3 | Round up first, then add three headers | `(INNER + 15) / 16 * 16` rounds up to a multiple of 16 | `PADDED=$(( (INNER + 15) / 16 * 16 ))` and `OUTER=$(( PADDED + 32 + 8 + 20 ))` |

If you are stuck:

1. `cafe-outside.txt` shows `192.168.50.23`? You captured the inside plug. Use `veth-cafe-out`.
2. `wg0.txt` is empty? Is the capture in `vpnbox`, and did the ping work? `ip netns exec laptop ping -c1 10.20.0.5`
3. Your sum is 144? You forgot the padding.

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `84` | 56 bytes of ping data (the default), 8 of ICMP header, 20 of IP header. `ping` prints `56(84)` |
| `16` | WireGuard pads to a multiple of 16 bytes |
| `32` | WireGuard's data message: 4 bytes type and reserved, 4 receiver index, 8 counter, 16 check value |
| `8`, `20` | The UDP header and the IPv4 header. An IPv6 outer header would be 40 |
| `156` | 96 + 32 + 8 + 20 |
| `1420` | WireGuard's default MTU: 1500, minus the most the outer headers can take with IPv6 (80) |
| `6`, `5` seconds | How long each capture runs. Long enough for 3 pings and a page |
| `10`, `25`, `3` seconds (keepalive) | Short NAT timeouts so you do not wait two minutes, a wait longer than 10 + 10, and a keepalive shorter than the timeout |

## Results

Fill in [results.md](results.md). Commit it, `cafe-outside.txt`, `wg0.txt`, `size.txt` and `size-capture.txt`.

## Draft status (remove before publishing)

Tested (lab image, 2026-10-27): the café outside capture with only UDP 51820 both ways (16 lines, lengths 96 to 304); the `wg0` capture with link type RAW and the inner ping; `length 156` and `UDP, length 128` with `-v`; the inside plug showing UDP from `192.168.50.23`; the keepalive extra as written (0 received without keepalive, 2 received with it, and the café router choosing another outside port); `bash test.sh` passing, and failing with the right gap named for empty gaps, the wrong plug, and a sum without padding.
Untested: opening the captures in Wireshark.
