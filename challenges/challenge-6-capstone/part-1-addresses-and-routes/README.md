# Challenge 6, part 1: addresses and routes

Goal: build the home subnet, the guest subnet, the home router, a provider router and a public web server. Every path must work, except one: a home device cannot yet get an answer from the public server, because there is no NAT.

Read the [challenge 6 overview](../README.md) first. It has the address plan and the names the tests expect. This part is **open with hints**: you write the whole script. Start from your scripts from challenges 2 and 4.

The addresses belong to the lab only. `192.168.x.x` is private. `198.51.100.x` and `203.0.113.x` are ranges reserved for examples, so no real website uses them.

## 101: words you need

New words only. The rest are from earlier challenges.

| Word | Plain meaning |
|---|---|
| Address plan | A table that says which subnet each link gets, and which address each plug gets. You write it before you type commands |
| Provider router | The router of your internet provider. It sits between your home router and the rest of the internet |
| `/30` | A tiny subnet with 4 addresses, 2 of them usable. Perfect for one cable between two routers |
| Connected route | The route a computer gets for free for each subnet it has an address on. The provider router needs no extra route for the subnets it is plugged into |
| Next hop | The next router a packet is handed to. `ip route get ADDRESS` tells you the next hop and the plug |
| Public side | The "internet" part of the lab. It uses addresses from the ranges reserved for examples |

## What you build

```
  home1 .30 --+
  home2 .31 --+-- br-home 192.168.1.1 [ hrouter ] 198.51.100.2/30 --- 198.51.100.1 [ prouter ] 203.0.113.1/24 --- 203.0.113.80 server
  homeweb .20-+                            |                                                                       web page :8080
  guest1 .30 -- veth-hguest 192.168.50.1 --+
```

There is no NAT in this part. A packet from `home1` can travel all the way to the server, but its source address is still private, so no answer comes back.

Before you run anything, guess: `home1` pings `203.0.113.80`. Does it get a reply? Why or why not?

## What the test checks

Run `bash test.sh` after your script. It checks:

1. All seven namespaces exist.
2. The address plan: `hrouter`, `prouter`, `server` and `homeweb` have their addresses. The devices have addresses in the right subnets.
3. Forwarding is on in both routers.
4. Every device reaches its own router.
5. The routers reach the devices and each other.
6. `hrouter` reaches the public server through `prouter`, and the server sees `198.51.100.2`.
7. `ip route get 203.0.113.80` picks the gateway on `home1` and on `hrouter`, and `traceroute` from `hrouter` shows `198.51.100.1` then the server.
8. Must fail on purpose: while there is no NAT, `home1` pings the public server and gets no reply. The capture on the home router's outside link shows the private source address leaving.

Check 8 is skipped once part 2 has added NAT, so this test also passes on the finished network.

## Hints

Open one step at a time. Stop as soon as you can go on.

1. **A nudge.** Which subnet does each link need? Count the links: the home LAN, the guest LAN, the cable between the routers, and the cable to the server. Each link is a different subnet.
2. **Where to look.** Which computer is missing a route? Run `ip route get 203.0.113.80` in each computer in order, starting with `home1`. Then `ping` hop by hop. Then check forwarding in each router.
3. **The shape of the commands.**
   <details>
   <summary>Open</summary>

   - An address: `ip addr add ADDRESS/PREFIX dev INTERFACE`
   - A default route: `ip route add default via GATEWAY`
   - Forwarding: `sysctl -w net.ipv4.ip_forward=1` (inside each router)
   - Run each one in the right computer with `in_ns NAMESPACE ...`
   - Cables: `cable_if NS_A NAME_A NS_B NAME_B`, as in challenge 2. The home devices plug into a bridge in `hrouter`, as in challenge 4.
   </details>
4. **The commands.**
   <details>
   <summary>Open</summary>

   The routes and forwarding, the part that people forget:

   ```
   in_ns home1 ip route add default via 192.168.1.1
   in_ns home2 ip route add default via 192.168.1.1
   in_ns homeweb ip route add default via 192.168.1.1
   in_ns guest1 ip route add default via 192.168.50.1
   in_ns hrouter ip route add default via 198.51.100.1
   in_ns server ip route add default via 203.0.113.1
   in_ns hrouter sysctl -w net.ipv4.ip_forward=1
   in_ns prouter sysctl -w net.ipv4.ip_forward=1
   ```

   The provider router needs no route of its own: it is plugged into every subnet it forwards between. The server needs a default route through the provider router, so that it can answer `198.51.100.2` later.
   </details>

If you are stuck, work down in this order: `ip route get <destination>` in each computer, then `ping` the next hop, then `sysctl net.ipv4.ip_forward` in each router.

## Capture to commit

In [results.md](results.md): `ip addr` and `ip route` for `hrouter` and `prouter`, and the `tcpdump -n` on the home router's outside interface during the failing ping, showing the private source leaving. Use `-i` with the interface that holds `198.51.100.2`, and the filter `icmp`.

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `192.168.1.0/24`, `192.168.50.0/24` | The home and guest subnets. Two different private ranges, so they never overlap |
| `.1` for each router | A common habit: the router takes the first address |
| `192.168.1.20` | The home web server. It is static, so it has a fixed address a forwarded port can point at |
| `.30`, `.31` | Placeholder addresses for the devices. They sit outside the DHCP pools, so they never clash with leases in part 3 |
| `198.51.100.0/30` | A range reserved for examples (RFC 5737), cut to 4 addresses. `.1` is the provider router and `.2` is the home router. `.0` and `.3` are the network and broadcast addresses |
| `203.0.113.0/24` | Another example range. It stands for the public side |
| `203.0.113.80`, port `8080` | The public web server |
| `-m 3`, `-W1`, `-c1` | Wait 3 seconds, wait 1 second per answer, send 1 ping |
| `-w 1 -q 1 -m 5` in the test's `traceroute` | One probe per hop, wait 1 second, give up after 5 hops |

## Results

Fill in [results.md](results.md). Commit it.

## Draft status (remove before publishing)

Tested (course notes, 2026-10-24 to 2026-10-26): the home router, a provider router and a public server, with the server seeing the home router's outside address; a missing default route on the home router giving `Destination Net Unreachable`; a mask mismatch giving `Network is unreachable` from one side and silent loss from the other; `ip route get`; `traceroute -n` across routers.
Untested: the exact two-line `traceroute` from the home router in this layout (a one-router case and a two-router case were tested); the capture of a private source leaving with no NAT; and the reason no reply arrives (the server may have no way back, or the provider router may drop a private source address; the test only requires silence).
