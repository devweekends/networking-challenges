# Challenge 6, part 3: DHCP and DNS

Goal: give both subnets leases and names. `home1`, `home2` and `guest1` give up their placeholder addresses and ask the router. Then `curl http://web.test:8080/` works from the home and from the guest network.

Read the [challenge 6 overview](../README.md) first. This part is **open with hints**: you write the whole script. Start from your challenge 5 script and `dnsmasq.conf`. Your script builds parts 1 and 2 first, then starts dnsmasq and asks for leases.

## 101: words you need

New words only. The rest are from challenge 5.

| Word | Plain meaning |
|---|---|
| Tag | A label you put on a pool with `set:NAME`. Options with `tag:NAME` go only to that pool. This is how two subnets get two different gateways from one dnsmasq |
| Pool exhausted | Every address in the pool is taken, so a new device gets no offer. It ends with no address |
| Throwaway device | A test computer the test adds and removes. It has a fixed hardware address, so it gets the same lease each time |
| Lease file | dnsmasq's list of who has which address |

## What you build

```
  home1 -+
  home2 -+-- br-home 192.168.1.1 [ hrouter + ONE dnsmasq ] veth-hguest 192.168.50.1 --- guest1
  homeweb (static 192.168.1.20)    pool .100 to .150  |  pool .100 to .150
                                   gateway + DNS .1   |  gateway + DNS .1
                                   web.test = 203.0.113.80
```

One dnsmasq serves both subnets. Each subnet has its own pool, its own gateway and its own DNS address. The guest can ask the router for names, even though the guest is blocked from the home network. The router's own address is not part of the home network, so the isolation rule does not match a question to the router.

Before you run anything, guess: the isolation rule drops packets from `192.168.50.0/24` to `192.168.1.0/24`. A guest asks the router at `192.168.50.1` for a name. Does the rule match that packet? Why or why not?

## What the test checks

Run `bash test.sh` after your script. It checks:

1. dnsmasq is running, and was started with `bg_start dnsmasq`.
2. `home1` and `home2` have different leases in `192.168.1.100` to `192.168.1.150`, and `guest1` has one in `192.168.50.100` to `192.168.50.150`.
3. Each has the right gateway and the right resolver file (`/etc/netns/NAME/resolv.conf`): `192.168.1.1` for home, `192.168.50.1` for the guest.
4. `dig @192.168.1.1 web.test` and `dig @192.168.50.1 web.test` return `203.0.113.80`.
5. `curl http://web.test:8080/cgi-bin/whoami` works from `home1` and from `guest1`, and the server sees `198.51.100.2`.
6. A brand-new throwaway device can get a lease.
7. Must fail: `dig @192.168.1.1 nosuch.test` returns no answer.
8. Must fail: with dnsmasq stopped, a new throwaway device ends with no address after about 3 seconds.

The test then starts dnsmasq again with your `dnsmasq.conf`.

## Hints

Open one step at a time. Stop as soon as you can go on.

1. **A nudge.** One range per subnet. Which interface does each range belong to?
2. **Where to look.** Is dnsmasq listening on both inside interfaces? `ip netns exec hrouter ss -ulnp`. Is it giving offers? `ip netns exec hrouter tcpdump -n -i br-home port 67 or port 68` while a device asks. Read dnsmasq's own log: `cat /tmp/networking-course-pids/dnsmasq.log`.
3. **The shape of the lines.**
   <details>
   <summary>Open</summary>

   - Two `interface=NAME` lines, one for the home bridge and one for the guest plug, and `bind-interfaces`
   - A pool per subnet, tagged: `dhcp-range=set:TAG,FIRST,LAST,MASK,LEASE_TIME`
   - Options per pool: `dhcp-option=tag:TAG,option:router,ADDRESS` and `dhcp-option=tag:TAG,option:dns-server,ADDRESS`
   - A name: `address=/NAME/ADDRESS`
   - Also useful: `no-resolv`, `no-hosts`, `user=root`, `log-facility=-`, `log-dhcp`, `dhcp-leasefile=FILE`
   - In your script: delete the old lease file, start dnsmasq, `sleep 3`, then ask for leases with `NS_NAME=... ip netns exec ... busybox udhcpc -i INTERFACE -s "$(udhcpc_hook_path)" -n -q -t 5 -T 2`
   </details>
4. **The exact lines.**
   <details>
   <summary>Open</summary>

   ```
   interface=br-home
   interface=veth-hguest
   bind-interfaces
   no-resolv
   no-hosts
   user=root
   log-facility=-
   log-dhcp
   dhcp-leasefile=/tmp/networking-course-dnsmasq.leases
   dhcp-range=set:home,192.168.1.100,192.168.1.150,255.255.255.0,1h
   dhcp-range=set:guest,192.168.50.100,192.168.50.150,255.255.255.0,1h
   dhcp-option=tag:home,option:router,192.168.1.1
   dhcp-option=tag:home,option:dns-server,192.168.1.1
   dhcp-option=tag:guest,option:router,192.168.50.1
   dhcp-option=tag:guest,option:dns-server,192.168.50.1
   address=/web.test/203.0.113.80
   ```

   Use the names of your own interfaces if they differ from `br-home` and `veth-hguest`.
   </details>

If you are stuck, read the log, watch ports 67 and 68 while one device asks, and ask the router directly with `dig @ADDRESS`. Fallback: parts 1 and 2 still work without DHCP.

If your part 2 is not ready, have your script run `bash /work/toolkit/restore.sh 6.2` instead of your own part 2 script. It builds the course's parts 1 and 2 network. It runs the course's own answer: read [If you are stuck on a part](../../../README.md#if-you-are-stuck-on-a-part) first.

## Captures to commit

In [results.md](results.md): the lease lines for both subnets (the `lease applied` lines), one `tcpdump -n` of ports 67 and 68 during a lease, and the `dig` answer.

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `192.168.1.100` to `192.168.1.150` | The home pool. It starts at `.100`, so it never clashes with `.20` (homeweb) or the placeholders `.30` and `.31` |
| `192.168.50.100` to `192.168.50.150` | The guest pool. The same idea on the guest subnet |
| `1h` | The lease time. After an hour a device must ask again |
| `192.168.1.1`, `192.168.50.1` | The router's address on each subnet. It is the gateway and the DNS server for that subnet |
| `web.test` | A made-up name. `.test` is reserved for tests |
| `sleep 3`, `-t 5 -T 2` | dnsmasq needs a few seconds before the first client asks. A client sends up to 5 requests, 2 seconds apart |
| `-t 3 -T 1` in the "must fail" test | A client with no server gives up after about 3 seconds |

## Results

Fill in [results.md](results.md). Commit it.

## Draft status (remove before publishing)

Tested (course notes, 2026-10-24 to 2026-10-26): one dnsmasq with two DHCP ranges on two interfaces, with clients that start about 3 seconds after dnsmasq and retry (`-t 5 -T 2`); the hook script for `udhcpc`; names through the resolver file; an unknown name giving `REFUSED`; a client with no server ending with no address after about 3 seconds; blocking only port 53 leaving DHCP working.
Untested: the tag syntax (`dhcp-range=set:...` with `dhcp-option=tag:...,option:router`), whether a guest's question to the router is matched by the isolation rule (the brief expects it is not, because the destination is the router itself), and a throwaway device with a fixed hardware address getting the same lease each time.
