# Challenge 6: the capstone, a whole internet on one laptop

You press Enter on a link. Before the page appears, your laptop uses almost everything in this course. In this challenge you build all of it yourself, in four parts, and then break it and fix it.

This challenge is **open with hints**. There is no half-written script. You get the goal, the address plan, the tests, and a ladder of hints that goes from a small nudge to the exact command. Start from your own scripts from challenges 2, 4 and 5. They already hold most of what you need.

## The network

```
  home1  --+
  home2  --+-- br-home 192.168.1.1  [ hrouter ]  198.51.100.2 --- 198.51.100.1 [ prouter ] 203.0.113.1 --- 203.0.113.80 server
  homeweb -+   (192.168.1.20)        NAT, DHCP,                     /30 link              public side         web server :8080
  guest1 ---- veth-hguest 192.168.50.1  DNS, filter
```

| Link | Subnet | Addresses |
|---|---|---|
| Home LAN | `192.168.1.0/24` | `hrouter` `192.168.1.1`. Static web server `homeweb` `192.168.1.20`. DHCP pool `192.168.1.100` to `192.168.1.150`. Devices `home1`, `home2` |
| Guest LAN | `192.168.50.0/24` | `hrouter` `192.168.50.1`. DHCP pool `192.168.50.100` to `192.168.50.150`. Device `guest1` |
| Home router to provider | `198.51.100.0/30` | `hrouter` outside `198.51.100.2`. `prouter` `198.51.100.1` |
| Public side | `203.0.113.0/24` | `prouter` `203.0.113.1`. `server` `203.0.113.80`, port `8080` |

- Until part 3, `home1`, `home2` and `guest1` have static placeholder addresses outside the pools (for example `192.168.1.30`, `192.168.1.31` and `192.168.50.30`). In part 3 they give those up and ask for leases.
- The name `web.test` answers `203.0.113.80`.
- The forwarded port: `198.51.100.2:8080` goes to `192.168.1.20:80`.
- `server` runs a web page, `/cgi-bin/whoami`, that tells a visitor the address and port it sees. `homeweb` serves a page that says `home web server`. Make both with `www_make` from `toolkit/lib.sh`.
- All the public-looking addresses come from ranges reserved for examples. No real website uses them.

## The four parts

| Part | Folder | You build | Your script (keep this name) |
|---|---|---|---|
| 1 | `part-1-addresses-and-routes` | The subnets, the cables, the addresses, the routes, forwarding, the two web servers | `addresses-and-routes.sh` |
| 2 | `part-2-nat-forwarding-isolation` | Masquerade, one forwarded port, and the rule that keeps the guest away from home | `nat-forwarding-isolation.sh` |
| 3 | `part-3-dhcp-and-dns` | DHCP and DNS for both subnets | `dhcp-and-dns.sh` and `dnsmasq.conf` |
| 4 | `part-4-break-and-fix` | You do not build. A script injects three faults, and you find and fix them | `break.sh` is given |

Each of your scripts **builds everything up to its own part**, and does it from nothing. The simplest way: part 2's script runs part 1's script, then adds its own work. Part 3's script runs part 2's script, then adds its own work. Look at how challenge 4 part 2 ran part 1 for a model. Every script starts by deleting the old network, so it is safe to run again.

## The contract: what the tests and `break.sh` expect

The tests look at your running network. They find most things by address. They need these names to be exactly right:

| What | Name |
|---|---|
| Namespaces | `home1`, `home2`, `homeweb`, `guest1`, `hrouter`, `prouter`, `server` |
| The home bridge | any name. The test finds it by the address `192.168.1.1` |
| Script file names | `addresses-and-routes.sh`, `nat-forwarding-isolation.sh`, `dhcp-and-dns.sh` (each in its own part folder), and `dnsmasq.conf` in part 3 |
| Web servers | started with `bg_start` and `busybox httpd`. `server` listens on `0.0.0.0:8080` and `homeweb` on `0.0.0.0:80` |
| dnsmasq | started with `bg_start dnsmasq hrouter dnsmasq --keep-in-foreground --conf-file=...`, so that the name is `dnsmasq` and the config file is the `dnsmasq.conf` in part 3 |
| NAT rule | uses the word `masquerade`. The forwarded port uses `dnat to 192.168.1.20` |
| Isolation rule | the only rule in your ruleset with the word `drop` |
| Home pool line | the `dhcp-range` for the home pool contains `192.168.1.100,192.168.1.150` |

## Start

```
cd /work/challenges/challenge-6-capstone/part-1-addresses-and-routes
```

Read that part's README. Write the script. Run it. Run `bash test.sh`. Read the first `FAIL` line. Repeat. Then go on to part 2.

## What you hand in

A repository with the four parts, the tests passing, your captures, the fault write-up, and a recorded demo from `demo-template.md`.

## Draft status (remove before publishing)

Everything in this challenge builds on behaviour from the course's lab tests (2026-10-24 to 2026-10-26). The full capstone path through a provider router with a forwarded port was tested (dossier 5.7). The pieces that are new and untested are listed in each part's README.
