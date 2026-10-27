# Challenge 8, part 2: the tunnel

Goal: from the café laptop, ping the office server `10.20.0.5`. In part 1 the internet said "Destination Net Unreachable". Now you build a WireGuard tunnel from the laptop to the VPN box. Your private packet travels inside a public one. Then you send one packet with a false source and watch the VPN box throw it away.

Do part 1 first. The script of this part starts by running **your** `office-cafe.sh`, so part 1's test must pass before you begin.

This part is **gapped**. The script `tunnel.sh` is almost complete. Four small things are missing, and each is marked `TODO`. The test tells you which one is wrong.

## 101: words you need

| Word | Plain meaning |
|---|---|
| Tunnel | A packet inside a packet. The inner packet goes to `10.20.0.5`. The outer packet goes between the two public addresses |
| WireGuard | The VPN we use. It runs in the Linux kernel. `wg` is its tool |
| `wg0` | The tunnel's interface. Packets that go into `wg0` come out at the other end, at the peer |
| Private key | A secret number. It never leaves its computer. `wg genkey` makes one |
| Public key | Worked out from the private key with `wg pubkey`. You give it to the other side. With it, they can check that a packet came from you. They cannot pretend to be you |
| Peer | The other end of the tunnel, known by its public key |
| Endpoint | Where the outer packets go: the peer's public address and port |
| AllowedIPs | Two jobs. Going out: which inner addresses go to this peer. Coming in: which inner source addresses this peer may use. Anything else is dropped |
| Handshake | The first message between the peers. It proves the keys and agrees on fresh keys for the data |
| Return route | The way back. The office server must know where answers to `10.99.0.2` go |
| RX errors | A counter on an interface: received packets that were thrown away |

## What you build

```
  laptop                                                                     vpnbox                  officesrv
  wg0 10.99.0.2 ======================= the tunnel ========================= wg0 10.99.0.1
  192.168.50.23 -- [ caferouter ] -- [ internet ] -- [ officert ] --------- 10.20.0.2 -- br-office -- 10.20.0.5
                     198.51.100.2                      203.0.113.2
                                                       UDP 51820 to 10.20.0.2 (part 1)
```

The tunnel network is `10.99.0.0/24`: the laptop is `10.99.0.2`, the VPN box is `10.99.0.1`. The ping goes like this:

1. The laptop sends `10.99.0.2 > 10.20.0.5`. Its route sends it into `wg0` (Gap 3).
2. WireGuard on the laptop encrypts it and puts it in a UDP packet: `192.168.50.23:51820 > 203.0.113.2:51820` (Gap 2).
3. The café router masquerades it. The office router forwards it to the VPN box (part 1).
4. The VPN box opens it, checks the source against AllowedIPs, and passes `10.99.0.2 > 10.20.0.5` on to the server.
5. The server answers `10.20.0.5 > 10.99.0.2`, through the VPN box (Gap 4), and back the same way.

Before you run anything, guess: the server gets a ping from `10.99.0.2`. Without Gap 4, where does it send the answer?

## Steps

Run these **in the lab**. First:

```
cd /work/challenges/challenge-8-vpn/part-2-the-tunnel
```

| # | Type this | What it does | Script line |
|---|---|---|---|
| 1 | `bash tunnel.sh` | Builds everything and runs every step below. Safe to run again. `bash tunnel.sh build-only` stops before step 9 | whole file |
| 2 | (run your part 1) | The office, the café and the internet | [tunnel.sh#L19](tunnel.sh#L19) |
| 3 | `ping 10.20.0.5` | Before the tunnel: no answer. Saved in `before-tunnel.txt` | [tunnel.sh#L27](tunnel.sh#L27) |
| 4 | Gap 1 | Two key pairs, in `/tmp/networking-course-wg` | [tunnel.sh#L38-L42](tunnel.sh#L38-L42) |
| 5 | `ip link add wg0 type wireguard`, `wg set` | The office end on the VPN box. Given: read it, Gap 2 is its mirror | [tunnel.sh#L48](tunnel.sh#L48) |
| 6 | Gap 2 | The café end on the laptop: key, port, peer, endpoint, allowed-ips | [tunnel.sh#L61-L67](tunnel.sh#L61-L67) (in [tunnel.sh#L59](tunnel.sh#L59)) |
| 7 | Gap 3 | The route that puts `10.20.0.0/24` into `wg0` on the laptop | [tunnel.sh#L73-L75](tunnel.sh#L73-L75) |
| 8 | Gap 4 | The return route on the office server | [tunnel.sh#L77-L80](tunnel.sh#L77-L80) |
| 9 | `ping`, `curl` | With the tunnel: answers from `10.99.0.1` and `10.20.0.5`, and the office page. Saved in `with-tunnel.txt` | [tunnel.sh#L82](tunnel.sh#L82) |
| 10 | `wg show wg0` on both ends | What each end knows. Saved in `wg-show.txt` | [tunnel.sh#L90](tunnel.sh#L90) |
| 11 | the false source | One ping from `10.99.0.66`. Saved in `spoof.txt` and `spoof-capture.txt` | [tunnel.sh#L105](tunnel.sh#L105) |
| 12 | `bash test.sh` | Checks all of the above and names the gap that is wrong | the gap checks start at [test.sh#L23](test.sh#L23) |

### Read `wg-show.txt`

```
=== laptop
interface: wg0
  public key: TGmo...akY=
  private key: (hidden)
  listening port: 51820

peer: P22I...J2A=
  endpoint: 203.0.113.2:51820
  allowed ips: 10.20.0.0/24, 10.99.0.1/32
  latest handshake: 1 second ago
  transfer: 1.15 KiB received, 1.05 KiB sent
```

| Line | Meaning |
|---|---|
| `public key` | The laptop's own public key. The VPN box has the same text under `peer:` |
| `private key: (hidden)` | `wg show` never prints it. `wg show wg0 private-key` would |
| `endpoint: 203.0.113.2:51820` | You wrote this. The laptop sends outer packets there |
| `allowed ips` | Which inner addresses go to this peer |
| `latest handshake` | The keys worked. If this line is missing, no handshake happened |

On the VPN box, the peer's endpoint is `198.51.100.2:51820`. You never wrote that. The VPN box learned it from the first packet: the café's public address, after masquerade. This is why the café side needs no port forward. It starts the conversation.

Your keys differ on every run. They are made new each time.

### Two routes, and why

**Gap 3.** AllowedIPs chooses the peer once a packet is in `wg0`. It does not put packets into `wg0`. The routing table does. Without the route, `ip netns exec laptop ip route get 10.20.0.5` says `via 192.168.50.1`: the café router. The ping goes to the internet and fails, as in part 1. (`wg-quick`, a tool that reads a config file, adds this route for you. Here you add it by hand to see it.)

**Gap 4.** The server gets a ping from `10.99.0.2`. It has never heard of `10.99.0.0/24`, so it sends the answer to its default route, the office router. The office router sends it to the internet, and it is lost. The ping to `10.99.0.1` works without Gap 4, because the VPN box itself knows the tunnel. The ping to `10.20.0.5` does not. With the route, the answer goes to `10.20.0.2`, the VPN box, which puts it in the tunnel.

### The false source

The laptop gets a second tunnel address, `10.99.0.66`, and pings the server from it. The laptop's WireGuard encrypts it and sends it, because the destination `10.20.0.5` is in its AllowedIPs. The VPN box opens it and checks the source. Its AllowedIPs for the laptop is `10.99.0.2/32` only. So it drops the packet.

You can see this two ways:

- `spoof.txt` says `VPN box wg0 receive errors: before 0, after 1`. The drop counts as one RX error.
- `spoof-capture.txt` has `0 packets captured`. tcpdump on the VPN box's `wg0` never saw it. The packet was dropped before it reached `wg0`.

This is the second job of AllowedIPs: a peer can only speak from its own addresses.

## Hints

Each gap has a ladder. Try the first step. Open the next one only if you are still stuck.

| Gap | Step 1: a nudge | Step 2: the name | Step 3: the shape |
|---|---|---|---|
| 1 | Each side needs a private key, and the public key made from it | `wg genkey`, `wg pubkey`, and `tee` to keep a copy | `wg genkey \| tee PRIVATE_FILE \| wg pubkey > PUBLIC_FILE`, once for `vpnbox`, once for `laptop` |
| 2 | Copy the VPN box's line in step 4, and swap what is different | The laptop's key, the VPN box's public key, an `endpoint`, two networks in `allowed-ips` | `in_ns laptop wg set wg0 private-key FILE listen-port 51820 peer "$(cat "$KEYS/vpnbox.pub")" endpoint 203.0.113.2:51820 allowed-ips 10.20.0.0/24,10.99.0.1/32` |
| 3 | What decides which packets go into `wg0`? | A route with `dev wg0` | `in_ns laptop ip route add 10.20.0.0/24 dev wg0` |
| 4 | Where does the server send an answer for an address it does not know? | A route to `10.99.0.0/24` with `via` | `in_ns officesrv ip route add NETWORK via 10.20.0.2` |

If you are stuck:

1. No `latest handshake` in `wg show`? Check the endpoint and both public keys. The laptop's peer must be the VPN box's **public** key.
2. `ping` says `sendmsg: Required key not available`? The packet went into `wg0`, but no peer has that address in its AllowedIPs. Look at Gap 2.
3. `10.99.0.1` answers but `10.20.0.5` does not? Look at Gap 4. Then `ip netns exec vpnbox sysctl net.ipv4.ip_forward`.
4. Where does a packet go? `ip netns exec laptop ip route get 10.20.0.5`.
5. Is the packet leaving? `ip netns exec caferouter tcpdump -n -i veth-cafe-out udp port 51820`.

## Gotcha: who starts the conversation

The café router masquerades the laptop's packets, and it forgets a quiet conversation after a while (30 seconds, or 120 once both sides have talked). That is fine while the laptop starts things. The laptop's packet makes a new mapping each time. But if the office wants to reach the laptop first, after a quiet time, its packet hits the café router and nothing is waiting for it. WireGuard's `persistent-keepalive` makes the NATed side send a tiny packet every few seconds, to keep the mapping alive. Part 3 has an optional extra where you watch this happen.

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `10.99.0.0/24` | The tunnel network. We chose it. A private range, different from both ends |
| `10.99.0.1`, `10.99.0.2` | The VPN box's and the laptop's tunnel addresses |
| `10.99.0.1/32` | One single address: the VPN box's end. The laptop needs it in AllowedIPs to ping `10.99.0.1` |
| `10.99.0.66`, `10.99.0.77` | False sources that are not in the VPN box's AllowedIPs. The script uses `.66`, the test uses `.77` |
| `51820` | WireGuard's usual port. Both ends listen on it, so the capture tools can recognize it |
| `203.0.113.2:51820` | The office router's public address and the forwarded port from part 1 |
| `mtu 1420` in `ip link show wg0` | WireGuard's default. The outer headers need room inside the usual 1500. Part 3 works out how much |
| `ttl=63` in the ping answer | The server's 64, lowered by one at the VPN box. The routers in between only see the outer packet |
| `-W2` | Wait 2 seconds. The first packet waits for the handshake |

## Results

Fill in [results.md](results.md). Commit it, `before-tunnel.txt`, `with-tunnel.txt`, `wg-show.txt`, `spoof.txt` and `spoof-capture.txt`. Never commit the key files from `/tmp/networking-course-wg`.

## Draft status (remove before publishing)

Tested (lab image, 2026-10-27): keys with `wg genkey` and `wg pubkey`; `wg set` on both ends with `listen-port 51820`; the handshake through two NATs; the laptop's endpoint learned as `198.51.100.2:51820`; ping to `10.99.0.1` working without Gap 4 and `10.20.0.5` failing without it; ping and the office page with all gaps; `wg0` down removing the route; the false source adding one RX error and nothing in the `wg0` capture; `bash test.sh` passing, and failing with the right gap named when Gaps 1, 3 or 4 are left empty.
Untested: `wg-quick` (the lab does not use it).
