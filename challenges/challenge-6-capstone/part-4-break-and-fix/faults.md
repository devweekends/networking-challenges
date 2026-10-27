# The fault menu

`break.sh` picks **three** faults from this menu. The seed decides which. You do not get to see the pick. That is the exercise.

This page tells you what each fault looks like and which command finds it. Your exact output may differ a little from the words here. Use it as a map, not as an answer sheet.

## The method: work down the layers

Do not guess. Start at the bottom and go up. The first check that fails names the layer.

1. **The test.** Run `bash test.sh`. Read the first `FAIL` line.
2. **Link and address.** Does the device have the address it should? `ip addr`
3. **Gateway.** Does it reach its own router? `ping` the router.
4. **Route.** Does the device know the way out? `ip route get 203.0.113.80`. Does the router?
5. **Name.** Does it work by address but not by name? `curl` by address first, then by name. `dig @ROUTER_ADDRESS web.test`
6. **The page.** Does `curl` get the page?

When you find a fault, fix **only that one**, run the test again, and write it down. If you fix two things at once, you cannot say which one worked.

## The menu

| ID | Fault | What you may see | A command that finds it | Not drawn together with |
|---|---|---|---|---|
| F1 | Wrong mask on the static home web server | From `homeweb`, `ping 192.168.1.1` says `Network is unreachable` at once. From `hrouter`, `ping 192.168.1.20` gets no answer, and the request is visible in a capture on `homeweb`. The forwarded port hangs | `ip netns exec homeweb ip addr` (look at the prefix), `ip netns exec homeweb ip route`, `ping` from both sides | F2, F3, F7 |
| F2 | Forwarding off on the home router | `home1` reaches `192.168.1.1`, but `curl http://203.0.113.80:8080/` hangs. A capture shows the SYN arriving on the inside and nothing leaving on the outside | `ip netns exec hrouter sysctl net.ipv4.ip_forward`, `tcpdump -n` on both router interfaces | F1, F3, F7 |
| F3 | Default route missing on the home router | `home1` gets `Destination Net Unreachable` from `192.168.1.1`, and `curl` fails at once | `ip netns exec hrouter ip route`, `ip netns exec hrouter ip route get 203.0.113.80`, and read who sent the error in the ping output | F1, F2, F5 |
| F4 | The DNS port is blocked on the home router | Leases still work. `dig @192.168.1.1 web.test` times out. `curl http://web.test:8080/` cannot resolve the name. `curl http://203.0.113.80:8080/` works | `curl` by address, then by name; `dig @192.168.1.1 web.test`; `ip netns exec hrouter nft list ruleset`; `tcpdump -n port 53` | F6 |
| F5 | The masquerade rule is missing | `curl http://203.0.113.80:8080/` from `home1` hangs. A capture on the home router's outside interface shows a private source address leaving, and no reply | `tcpdump -n -i OUTSIDE_INTERFACE` in `hrouter`, `nft list ruleset`, `conntrack -L` | F3 |
| F6 | The DHCP pool is too small for a new device | A newly plugged-in device (it appears in `ip netns list`) ends its `udhcpc` run after about 3 seconds with no address | `ip addr` in the new device, `tcpdump -n port 67 or port 68` (a Discover and no Offer), the dnsmasq log and lease file | F4 |
| F7 | The guest isolation rule is missing | Nothing visibly breaks. The test that must fail now passes: `guest1` reaches `192.168.1.20` | The guest-to-home check in part 2's test, `nft list ruleset` in `hrouter` | F1, F2 |

## Why some faults are not drawn together

- F2 and F3 each break the way out of the home router, and hide each other. F3 and F5 do too.
- F1 would be hidden if the way out of the home router is already broken (F2 or F3): the forwarded port would then fail for another reason. F7 would be hidden only by F2 (forwarding off), because guest traffic to the home network never uses the way out. F1 and F7 also stay apart from each other.
- F4 and F6 cannot both be seen from a device that has no lease.

One pair can be drawn together even though it looks alike: F2 with F5. Fix F2 first, and then the symptom of F5 shows. Find one, fix it, test, then look for the next.

## What to write down

For each fault, in `fault-writeup.md`:

1. The symptom: the exact output you saw.
2. The command that found it, and its output.
3. What that output means.
4. The command that fixed it.
5. The test, run again, passing.

Every command in the write-up must be one you ran.
