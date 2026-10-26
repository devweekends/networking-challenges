# Challenge 5, part 1: leases and names

Goal: make your router hand out addresses (DHCP) and answer name questions (DNS). A laptop and a phone join with no address typed in. They get an address, a gateway and a DNS server from a lease. Then `web.test` turns into the server's address.

Do challenge 4 first. The first part of the script rebuilds the home router you built there, so you do not type it again. The difference: the laptop and the phone start with **no address**.

This part is **gapped**. Most gaps are lines in `dnsmasq.conf`. One more is in the script. The test tells you which one is wrong.

## 101: words you need

| Word | Plain meaning |
|---|---|
| DHCP | Dynamic Host Configuration Protocol. A device that joins a network asks "who am I?" and a server answers with its settings |
| Lease | The settings a DHCP server gives you, for a limited time: address, mask, gateway, DNS server, and how long they are yours |
| Pool (range) | The addresses the DHCP server may give out. Ours: `192.168.1.100` to `192.168.1.150` |
| Discover, Offer, Request, Ack | The four DHCP messages. "Is anyone there?", "Take this address", "I take it", "It is yours" |
| DHCP client | The program on the device that asks. Here, `busybox udhcpc` |
| DNS | The Domain Name System. It turns a name like `web.test` into an address |
| DNS server (resolver) | The computer you ask about names. The lease tells your device which one to ask |
| Resolver file | `resolv.conf`. A small file that lists the DNS servers a program should ask. Each lab computer can have its own |
| Record | One fact a DNS server knows, like "`web.test` is `203.0.113.80`" |
| dnsmasq | One small program that is both a DHCP server and a DNS server |
| Hook script | A script the DHCP client runs when it gets a lease. It puts the lease on the interface |
| REFUSED | The status of a DNS answer when the server will not look up a name. dnsmasq says this for names it does not know, in this lab |
| `dig` | A tool that asks a DNS server a question and prints the answer |

## What you build

```
  laptop  (no address) --+
                         +-- br-home 192.168.1.1  [ router + dnsmasq ]  203.0.113.1 --- 203.0.113.80 server
  phone   (no address) --+   DHCP + DNS            masquerade                          web.test = 203.0.113.80
```

Two kinds of question go to the router: "who am I?" (DHCP, ports 67 and 68) and "what is this name?" (DNS, port 53). dnsmasq answers both.

Two commands ask the DNS differently. Do not mix them up:

- `dig @192.168.1.1 web.test` asks **that one server**, whatever the computer's own settings say.
- `curl http://web.test:8080/` asks the servers in the computer's **resolver file**. The lease fills that file in.

Before you run anything, guess: dnsmasq is stopped, and a new device asks for a lease. Does it get an address, or none? How long does it wait?

## Steps

Run these **in the lab**. First:

```
cd /work/challenges/challenge-5-dhcp-dns/part-1-leases-and-names
```

| # | Type this | What it does | Script line |
|---|---|---|---|
| 1 | `bash dhcp-dns.sh` | Builds everything and runs every step below. Safe to run again | whole file |
| 2 | (rebuild the router) | The home router from challenge 4. The laptop and the phone have no address | [dhcp-dns.sh#L21](dhcp-dns.sh#L21) |
| 3 | Gap 1 in `dnsmasq.conf` | Listen on the inside only: `interface=` | [dnsmasq.conf#L7-L9](dnsmasq.conf#L7-L9) |
| 4 | Gap 2 in `dnsmasq.conf` | The pool: `dhcp-range=` | [dnsmasq.conf#L28-L30](dnsmasq.conf#L28-L30) |
| 5 | Gap 3 in `dnsmasq.conf` | The gateway and the DNS server in the lease: two `dhcp-option=` lines | [dnsmasq.conf#L33-L37](dnsmasq.conf#L33-L37) |
| 6 | Gap 4 in `dnsmasq.conf` | The name `web.test`: `address=` | [dnsmasq.conf#L40-L42](dnsmasq.conf#L40-L42) |
| 7 | start dnsmasq | Runs dnsmasq inside the router with your config, waits 3 seconds, and stops with its message if it died | [dhcp-dns.sh#L49](dhcp-dns.sh#L49) |
| 8 | Gap 5 | The DHCP client command | [dhcp-dns.sh#L69-L76](dhcp-dns.sh#L69-L76) (in [dhcp-dns.sh#L64](dhcp-dns.sh#L64)) |
| 9 | (look at the leases) | Prints each device's address, route and resolver file | [dhcp-dns.sh#L83](dhcp-dns.sh#L83) |
| 10 | `dig`, `dig`, `curl` | Ask for `web.test`, ask for a name that does not exist, then fetch a page by name | [dhcp-dns.sh#L92](dhcp-dns.sh#L92) |
| 11 | one lease on camera | The phone asks again while `tcpdump` listens. Saved in `dhcp-capture.txt` | [dhcp-dns.sh#L101](dhcp-dns.sh#L101) |
| 12 | `bash test.sh` | Checks all of the above and names the gap that is wrong | the gap checks start at [test.sh#L57](test.sh#L57) |

### What you should see

After the clients run, each device has an address from the pool, a default route, and a resolver file:

```
--- laptop
2: veth-laptop    inet 192.168.1.1xx/24 ...
default via 192.168.1.1 dev veth-laptop
192.168.1.0/24 dev veth-laptop proto kernel scope link src 192.168.1.1xx
nameserver 192.168.1.1
```

`dig @192.168.1.1 web.test` prints `203.0.113.80`. A name that does not exist prints `status: REFUSED`. The `curl` fetch prints `the server sees you as 203.0.113.1:PORT`: the name worked, the route worked, and the masquerade rule worked.

`dhcp-capture.txt` holds four packets, with `-v` showing the message type of each:

1. Discover (client to everyone): `0.0.0.0.68 > 255.255.255.255.67`. The client has no address yet, so it uses `0.0.0.0` and broadcasts.
2. Offer (server to client): "take this address".
3. Request (client to everyone): "I take it".
4. Ack (server to client): "it is yours, for this long".

Why `-t 5 -T 2` and a 3 second wait? dnsmasq can take a moment before it answers the first request. The client sends up to 5 requests, 2 seconds apart. A client with no server at all gives up after its tries and is left with **no address**. Linux clients do not invent a `169.254.x.x` address here. Windows and macOS do.

## Hints

Each gap has a ladder. Try the first step. Open the next one only if you are still stuck.

| Gap | Step 1: a nudge | Step 2: the name | Step 3: the shape |
|---|---|---|---|
| 1 (conf) | Which interface faces your home devices? | The option `interface=` | `interface=NAME` |
| 2 (conf) | The test says whether the address is in the pool. What are the first and last addresses, and the mask? | The option `dhcp-range=` | `dhcp-range=FIRST,LAST,MASK,LEASE_TIME` |
| 3 (conf) | A lease also tells the device where to send everything else, and who to ask for names | `dhcp-option=option:router,...` and `dhcp-option=option:dns-server,...` | `dhcp-option=option:NAME,ADDRESS` |
| 4 (conf) | `dig` returns nothing for `web.test`. The server needs a record | The option `address=` | `address=/NAME/ADDRESS` |
| 5 (script) | The client finds a lease but does not apply it. Something must run when it gets one | `busybox udhcpc` with `-s` for the hook script, and `NS_NAME=` in front | `NS_NAME="$ns" ip netns exec "$ns" busybox udhcpc -i "$iface" -s "$HOOK" -n -q -t 5 -T 2` |

If you are stuck:

1. Is dnsmasq listening? `ip netns exec router ss -ulnp`
2. Watch the conversation. `ip netns exec router tcpdump -n -i br-home port 67 or port 68` while a client asks.
3. Read dnsmasq's own log: `cat /tmp/networking-course-pids/dnsmasq.log`
4. Ask the server directly: `ip netns exec laptop dig @192.168.1.1 web.test`
5. If the client prints "lease obtained" but the interface has no address, the hook script did not run. Check the `-s` option.

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `192.168.1.1` | The router's inside address. The gateway and the DNS server in the lease |
| `192.168.1.100` to `192.168.1.150` | We chose the pool. It starts at `.100` so it never clashes with addresses set by hand below that |
| `255.255.255.0` | The mask for `/24` |
| `1h` | The lease time. One hour is dnsmasq's usual default. After that the device must ask again |
| `web.test` | A made-up name. `.test` is a top-level name reserved for tests, so it never clashes with a real website |
| `203.0.113.80` | The public web server, in the range reserved for examples |
| `-t 5 -T 2` | Up to 5 requests, 2 seconds apart |
| `sleep 3` | dnsmasq needs a few seconds before the first client asks |
| `-c 4` in tcpdump | Four packets: discover, offer, request, ack |
| ports 67 and 68 | 67 is the DHCP server's port. 68 is the DHCP client's port |
| port 53 | DNS |

## Results

Fill in [results.md](results.md). Commit it and `dhcp-capture.txt`.

## Draft status (remove before publishing)

Tested (course notes, 2026-10-24 to 2026-10-26): dnsmasq serving DHCP and DNS on a bridge in a router namespace; two DHCP ranges on two interfaces from one dnsmasq; clients that start about 3 seconds after dnsmasq and retry (`-t 5 -T 2`); `busybox udhcpc` needing a hook script, and a short hook that sets the address, the default route and `/etc/netns/<ns>/resolv.conf`; a client with no server giving up with no address; an unknown name answered with `REFUSED` when dnsmasq has `--no-resolv`; and `curl` by name through a per-namespace resolver file.
Untested: the exact config text (`interface=`, `dhcp-range=`, `dhcp-option=option:router`, `dhcp-option=option:dns-server`, `address=/web.test/...`, `user=root`, `no-hosts`, `log-facility=-`), `ss -ulnp` output in a router namespace, the `tcpdump -v` DHCP capture with four packets, and the new `udhcpc-hook.sh` (its prefix calculation from the dotted mask).
