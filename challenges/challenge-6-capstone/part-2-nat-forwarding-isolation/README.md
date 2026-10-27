# Challenge 6, part 2: NAT, forwarding and isolation

Goal: add three jobs to the home router. Masquerade, so every home and guest device reaches the public server as one address. One forwarded port, so the outside can reach the home web server. One filter rule, so the guest cannot reach the home network.

Read the [challenge 6 overview](../README.md) first. This part is **open with hints**: you write the whole script. Your script builds part 1 first (it runs your part 1 script), then adds the three jobs.

## 101: words you need

New words only. The rest are from challenge 4.

| Word | Plain meaning |
|---|---|
| Outside address | The home router's address on the provider link, `198.51.100.2`. It is the only address the public side ever sees |
| Isolation | Keeping two networks apart with a rule. Here, the guest subnet and the home subnet |
| Must-fail test | A test that passes when something is blocked. It proves that the wall is there |
| Across the provider router | The forwarded request travels from `server`, through `prouter`, to `hrouter`, and on to `homeweb` |

## What you build

```
  home1 -+                                          masquerade: oifname on the outside plug
  guest1 -+- [ hrouter ] ---- 198.51.100.2 ~~~ [ prouter ] ---- 203.0.113.80 server
          |       |
          |       +-- dnat: 198.51.100.2:8080  ->  192.168.1.20:80  (homeweb)
          +-- filter: guest subnet -> home subnet = drop
```

Before you run anything, guess: the `server` connects to `198.51.100.2` on port `22`, where nothing listens. Refused or timeout?

## What the test checks

Run `bash test.sh` after your script. It checks:

1. The router has a masquerade rule and a rule that forwards a port to `192.168.1.20`.
2. `home1` and `guest1` reach `http://203.0.113.80:8080/cgi-bin/whoami`, and the server reports `198.51.100.2`. The test never checks the port number, because the port only changes on a clash.
3. `conntrack -L` in `hrouter` lists a connection to `203.0.113.80:8080`.
4. `server` visits `http://198.51.100.2:8080/` and gets the home web server's page, across the provider router.
5. Must fail: `guest1` to `192.168.1.20` times out (the drop rule is silent, so `curl` exits with code 28).
6. Must fail: `server` to `192.168.1.20` fails at once (no route, `curl` exit code 7).
7. Must fail: `server` to `198.51.100.2:22` is refused at once (`curl` exit code 7, "Connection refused").

## Hints

Open one step at a time. Stop as soon as you can go on.

1. **A nudge.** Which hook do the NAT rules use? Source NAT runs just before the packet leaves. Destination NAT runs before the routing decision. Which chain does the isolation rule need? The one that sees packets passing through the router.
2. **Which test names the missing rule?** Run `bash test.sh` and read the first `FAIL`. Then, in `hrouter`: `nft list ruleset`. Then `tcpdump -n` on the outside interface to see which source address leaves.
3. **The shape of the rules.**
   <details>
   <summary>Open</summary>

   - nft table `nat`, chain `postrouting`, type `nat`, hook `postrouting`: a rule with `oifname "INTERFACE" masquerade`
   - nft table `nat`, chain `prerouting`, type `nat`, hook `prerouting`: a rule with `iifname "INTERFACE" tcp dport PORT dnat to ADDRESS:PORT`
   - nft table `filter`, chain `forward`, type `filter`, hook `forward`: a rule with `ip saddr NETWORK ip daddr NETWORK drop`
   - nft wants one setting per line: send the rules with `nft -f -` and a small file with line breaks.
   </details>
4. **The exact rules.**
   <details>
   <summary>Open</summary>

   ```
   in_ns hrouter nft -f - <<'RULES'
   table ip nat {
     chain postrouting {
       type nat hook postrouting priority 100 ; policy accept ;
       oifname "veth-hout" masquerade
     }
     chain prerouting {
       type nat hook prerouting priority -100 ; policy accept ;
       iifname "veth-hout" tcp dport 8080 dnat to 192.168.1.20:80
     }
   }
   table ip filter {
     chain forward {
       type filter hook forward priority 0 ; policy accept ;
       ip saddr 192.168.50.0/24 ip daddr 192.168.1.0/24 drop
     }
   }
   RULES
   ```

   Use the name of your own outside interface in place of `veth-hout`. Keep the isolation rule as the only rule with the word `drop`.
   </details>

If you are stuck: `nft list ruleset` in `hrouter`, then `tcpdump -n` on the outside interface to see which source address leaves. Fallback: your part 1 still works. Fix one rule at a time and run the test again.

If your part 1 is not ready, have your script run `bash /work/toolkit/restore.sh 6.1` instead of your own part 1 script. It builds the course's part 1 network. It runs the course's own answer: read [If you are stuck on a part](../../../README.md#if-you-are-stuck-on-a-part) first.

## Captures to commit

These feed your demo. In [results.md](results.md):

- `tcpdump -n` on both router interfaces for one `home1` curl: the inside shows `192.168.1.x` to the server, the outside shows `198.51.100.2` to the server.
- The `conntrack -L` line for that connection.
- The output of `nft list ruleset` in `hrouter`.

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `198.51.100.2` | The home router's outside address from part 1. It is what the server sees |
| `8080` outside, `80` inside | The forwarded port. The public side asks for 8080. The home web server listens on 80 |
| `192.168.1.20` | The static home web server. A forwarded port needs a fixed target |
| `priority 100`, `priority -100`, `priority 0` | Where each chain runs in the order of hooks: source NAT after routing, destination NAT before, filter in the middle |
| `-m 3` | Give up after 3 seconds. A drop shows up as exit code 28 |
| port `22` | A port where nothing listens. The "not forwarded" example |

## Results

Fill in [results.md](results.md). Commit it.

## Draft status (remove before publishing)

Tested (course notes, 2026-10-24 to 2026-10-26): masquerade from a bridge LAN, `conntrack -L`, port forwarding tested from an outside namespace and across a provider router, a guest `forward` drop rule, an unforwarded port giving connection refused, and a server with no route to a private address failing at once.
Untested: the exact nft text of the DNAT and forward rules written as a file (verified in the same layout in challenge 4), `curl` exit code 28 for the guest, and `curl -v` printing `Connection refused`.
