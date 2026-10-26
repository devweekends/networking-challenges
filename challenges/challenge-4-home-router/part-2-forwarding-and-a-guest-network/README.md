# Challenge 4, part 2: port forwarding and a guest network

Goal: let "a friend on the internet" reach a web page on your laptop through one forwarded port. Then add a guest computer on its own subnet and use one rule to keep it away from your home network.

Do part 1 first. The script of this part starts by running **your** `masquerade.sh`, so part 1's test must pass before you begin.

This part is **gapped**. The script `forwarding-guest.sh` is almost complete. Three small things are missing, and each is marked `TODO`. The test tells you which one is wrong.

## 101: words you need

| Word | Plain meaning |
|---|---|
| Port forwarding | A router sends packets that arrive for one of its ports on to a device inside. "Port 8080 on me goes to the laptop's port 80" |
| DNAT | Destination NAT. The router rewrites the destination address (and port) of a packet. Masquerade rewrites the source. This rewrites the destination |
| `prerouting` | The hook that runs when a packet arrives, before the router decides where to send it. DNAT must happen here |
| `forward` | The hook for packets that pass through the router, from one side to the other |
| Filter | A rule that decides to let a packet pass or to throw it away. NAT rewrites. A filter allows or blocks. They are different jobs |
| Policy | What a chain does with packets that match no rule. `accept` means let them pass |
| Drop | Throw the packet away without telling anyone. The sender hears nothing and times out |
| Refused | The computer got your packet, nothing was listening, and it said no at once. `curl` exit code 7 |
| Timeout | Nothing came back. `curl -m 3` stops after 3 seconds and exits with code 28 |
| Guest network | A separate subnet for visitors. It may reach the internet and must not reach your devices |
| Isolation | Keeping two networks apart with a rule |

## What you build

```
  laptop 192.168.1.23 --+                                              
                        +-- br-home 192.168.1.1  [ router ]  203.0.113.1 -- 203.0.113.80 server
  phone  192.168.1.24 --+                         |  masquerade
                                                  +-- veth-rguest 192.168.50.1 -- 192.168.50.10 guest
```

The laptop now also runs a web page on port 80. The server plays "a friend": it visits `203.0.113.1:8080`, the router's outside address.

Before you run anything, guess: the server visits `203.0.113.1` on port `22`, where nothing listens. Does it hang, or fail at once?

## Steps

Run these **in the lab**. First:

```
cd /work/challenges/challenge-4-home-router/part-2-forwarding-and-a-guest-network
```

| # | Type this | What it does | Script line |
|---|---|---|---|
| 1 | `bash forwarding-guest.sh` | Builds everything and runs every step below. Safe to run again | whole file |
| 2 | (run your part 1) | Builds laptop, phone, router, server and masquerade | [forwarding-guest.sh#L17](forwarding-guest.sh#L17) |
| 3 | `ip netns add guest`, a cable, two addresses | The guest gets its own cable, its own subnet `192.168.50.0/24`, and the router as its way out | [forwarding-guest.sh#L26](forwarding-guest.sh#L26) |
| 4 | `busybox httpd` on the laptop, port 80 | The page we want a friend to reach | [forwarding-guest.sh#L33](forwarding-guest.sh#L33) |
| 5 | Gap 1 | The port forwarding rule (DNAT) in a `prerouting` chain | [forwarding-guest.sh#L42-L47](forwarding-guest.sh#L42-L47) (in [forwarding-guest.sh#L40](forwarding-guest.sh#L40)) |
| 6 | Gap 2 | The rule that keeps the guest away from the home network, in a `forward` chain | [forwarding-guest.sh#L53-L57](forwarding-guest.sh#L53-L57) (in [forwarding-guest.sh#L51](forwarding-guest.sh#L51)) |
| 7 | Gap 3 | Three tests from the server, saved in `outside-tests.txt` | [forwarding-guest.sh#L70-L74](forwarding-guest.sh#L70-L74) (with [forwarding-guest.sh#L62](forwarding-guest.sh#L62)) |
| 8 | the guest tests | The guest reaches the server. The guest asking for the laptop's page times out | [forwarding-guest.sh#L77](forwarding-guest.sh#L77) |
| 9 | `bash test.sh` | Checks all of the above and names the gap that is wrong | the gap checks are [test.sh#L46](test.sh#L46), [test.sh#L83](test.sh#L83) and [test.sh#L101](test.sh#L101) |
| 10 | `ip netns exec router nft list ruleset > ruleset.txt` | Saves all the router's rules. You will read them in your results | none |
| 11 | the capture, below | You watch the forwarded request on both sides of the router | none |

### The capture

You want to see one forwarded request on the outside cable and on the inside. Run both captures in the background with `&`.

```
ip netns exec router tcpdump -n -i veth-rout -c 3 tcp port 8080 > outside.txt 2>&1 &
ip netns exec router tcpdump -n -i br-home -c 3 tcp port 80 > inside.txt 2>&1 &
sleep 1
ip netns exec server curl -s http://203.0.113.1:8080/
wait
cat outside.txt inside.txt
```

What you should see: on the outside, the SYN goes from `203.0.113.80.PORT` to `203.0.113.1.8080`. On the inside, the same SYN goes from `203.0.113.80.PORT` to `192.168.1.23.80`. The **destination** was rewritten (address and port). The source was not.

### Three results to read

`outside-tests.txt` should say:

```
forwarded: exit 0
unforwarded: exit 7
direct: exit 7
```

| Line | Meaning |
|---|---|
| `forwarded: exit 0` | The front door works. The server reached the laptop's page through `203.0.113.1:8080` |
| `unforwarded: exit 7` | Port 22 is not forwarded and nothing listens on the router. The router refuses at once. It is not a timeout |
| `direct: exit 7` | The server cannot reach the private address `192.168.1.23` at all. It has no route. Only the forwarded port gets in |

NAT is not a firewall. The server could not reach `192.168.1.23` because it has no route to a private address. It was not the masquerade rule that stopped it. If the outside had a route to your home network, a masquerade-only router would let the connection through. Keeping someone out takes a filter, which is a separate rule. The guest rule here is a filter.

## Hints

Each gap has a ladder. Try the first step. Open the next one only if you are still stuck.

| Gap | Step 1: a nudge | Step 2: the name | Step 3: the shape |
|---|---|---|---|
| 1 | Which hook sees the packet before the routing decision? | The `prerouting` hook, and the `dnat to` action | `add chain ip nat NAME { type nat hook HOOK priority NUMBER ; }` then `add rule ip nat NAME iifname "INTERFACE" tcp dport PORT dnat to ADDRESS:PORT` |
| 2 | The rule must see packets that pass through the router, not packets for the router | The `forward` hook, with `ip saddr` and `ip daddr` matches and the `drop` action | `add chain ip filter NAME { type filter hook HOOK priority NUMBER ; policy accept ; }` then `add rule ip filter NAME ip saddr NETWORK ip daddr NETWORK drop` |
| 3 | Each test is one `curl` from the server, with a label | `run_check` takes a label, then the command | `run_check LABEL in_ns NAMESPACE curl -sS -m 3 URL` |

If you are stuck:

1. Is the web server on the laptop listening on `0.0.0.0`? `ip netns exec laptop ss -tlnp`
2. Does the port in your rule match? The outside port is `8080`. The inside port is `80`.
3. Did the guest rule land after a rule that accepts everything? Order matters: the first match wins.
4. Does `ip netns exec router nft list ruleset` show both new rules?

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `203.0.113.1:8080` | The router's outside address and the port we open. We chose 8080 so it differs from the laptop's own port 80 |
| `192.168.1.23:80` | The laptop's web server. Port 80 is the usual port for web pages |
| `192.168.50.0/24` | The guest subnet. A new private range, different from the home one. We chose it |
| `192.168.50.1`, `192.168.50.10` | The router's guest plug and the guest. We chose them |
| `priority -100` | The conventional place for destination NAT in the `prerouting` hook, before routing |
| `priority 0` | The usual place for a filter chain |
| `-m 3` in curl | Give up after 3 seconds. A drop shows up as exit code 28 |
| exit code 7, exit code 28 | 7: could not connect (refused, or no route). 28: timed out |
| port 22 | A port where nothing listens. We use it as the "not forwarded" example |

## Results

Fill in [results.md](results.md). Commit it, `ruleset.txt`, `outside.txt`, `inside.txt` and `outside-tests.txt`.

## Draft status (remove before publishing)

Tested (course notes, 2026-10-24 to 2026-10-26): a DNAT forward from `203.0.113.1:8080` to a device inside, tested from an outside namespace; an unforwarded port giving connection refused (curl exit 7); a server with no route to a private address failing at once; a guest `forward` drop rule blocking guest to home while guest to server works and is seen as `203.0.113.1`.
Untested: the exact `nft` text of the `prerouting` chain and the `dnat to` rule, and of the `forward` chain, written as separate lines; a drop showing up as `curl` exit 28; `curl -v` printing `Connection refused`; and the `tcpdump -i br-home` capture of the rewritten destination.
