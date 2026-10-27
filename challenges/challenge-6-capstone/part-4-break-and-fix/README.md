# Challenge 6, part 4: break it, fix it

Goal: your network works. Someone changes three things. Find each change from evidence, fix it, and write down what you saw.

Read the [challenge 6 overview](../README.md) first. This part is **open with hints**. You write no network code here. The script `break.sh` is given. Your work is to find the faults.

## 101: words you need

New words only.

| Word | Plain meaning |
|---|---|
| Fault | Something wrong in the network. Here, put there on purpose |
| Seed | A word or number you give `break.sh`. The same seed always picks the same three faults, so a mentor can repeat your run |
| Symptom | What you see go wrong. For example: "the page does not load" |
| Finder | The command that shows you the cause behind a symptom |
| Fix | The smallest change that removes the cause |
| Layer | A step on the way from a device to a web page: address, gateway, route, name, page. You check them in order |
| Root cause | The real reason, not the first thing that looks wrong |

## What you do

1. Make sure your parts 1 to 3 pass: `bash ../part-1-addresses-and-routes/test.sh` and the same for parts 2 and 3.
2. Pick a seed. Any word or number. Write it down. Then run:

   ```
   cd /work/challenges/challenge-6-capstone/part-4-break-and-fix
   bash break.sh YOUR_SEED
   ```

   `break.sh` rebuilds a healthy network with **your** part 3 script, then injects three faults. It saves your seed in `fault-seed.txt`.
3. Run `bash test.sh`. It runs the test sets of parts 1, 2 and 3 and prints every `FAIL` line. Each fault makes at least one test fail. The failing line is your first clue.
4. Read [faults.md](faults.md). It lists the seven possible faults, with the symptom and a finder command for each. It does not say which three you have.
5. For each fault: find it with commands, write down the symptom and the finder's output, fix it with one small change, and run the test again.
6. When `bash test.sh` passes, fill in `fault-writeup.md`.

Do not run `break.sh --list` on your own seed. It prints the answer, and finding the faults is the exercise. A mentor uses it to check your write-up.

## Rules that keep the exercise honest

- Fix **one fault at a time**. Run the test between fixes. If you fix two at once, you cannot say which one worked.
- Do **not** run your build scripts to fix things. They rebuild the healthy network and erase the faults, and you learn nothing. Fix the live network with single commands.
- If you break more than `break.sh` did, run `bash break.sh YOUR_SEED` again with the same seed. It rebuilds the healthy network and injects the same three faults.
- Every command in your write-up must be one you really ran.

If your part 3 is not ready, build the healthy network with the course's part 3, then inject the faults into it:

```
bash /work/toolkit/restore.sh 6.3
bash break.sh YOUR_SEED --no-rebuild
```

To start again, run both lines again. The part 3 test (which `bash test.sh` runs) and one of the faults still read your own `part-3-dhcp-and-dns/dnsmasq.conf`, so finish that file first: hints 3 and 4 in part 3 give it line by line. The restore runs the course's own answer: read [If you are stuck on a part](../../../README.md#if-you-are-stuck-on-a-part) first.

## Hints

Open one step at a time. Stop as soon as you can go on.

1. **A nudge.** Which layer fails first? Work in this order: the test, the address, the gateway, the route, the name, the page. The first check that fails names the layer.
2. **A row of the menu.** Which row of the table in [faults.md](faults.md) has the symptom you see? Compare the words exactly. `Network is unreachable` and `Destination Net Unreachable` come from different places.
3. **The finder.**
   <details>
   <summary>Open</summary>

   Use the "command that finds it" column of the menu row you chose. Run it on the computer it names. Compare what you see with what a healthy network shows in your part 1, 2 and 3 `results.md`.
   </details>
4. **The fix.**
   <details>
   <summary>Open</summary>

   The fix undoes the one cause. If an address is wrong, set it right. If a setting is off, switch it on. If a route or a rule is missing, add it the way your build script did. Then run the test again and confirm the FAIL line is gone.
   </details>

If you are stuck, try these in order: `ip addr` (is the address what it should be?), `ip route get 203.0.113.80` (does the device know the way?), `ping` the gateway and then a public address, `curl` by address and then by name, `tcpdump -n` on both sides of `hrouter`, `nft list ruleset`, `conntrack -L`.

## A worked example (not valid for your write-up)

This shows the method on one fault that you will not be asked to write up. A mentor runs `bash break.sh --only F3` to get it.

| Step | What you do | What you see |
|---|---|---|
| Symptom | `ip netns exec home1 ping -c1 -W1 203.0.113.80` | `From 192.168.1.1 icmp_seq=1 Destination Net Unreachable`. The router at `192.168.1.1` answered, so the first hop is fine. It does not know where to send the packet |
| Finder | `ip netns exec hrouter ip route` | There is no `default via ...` line |
| Finder | `ip netns exec hrouter ip route get 203.0.113.80` | `RTNETLINK answers: Network is unreachable` |
| Fix | `ip netns exec hrouter ip route add default via 198.51.100.1` | no output |
| Check | `bash test.sh` | The `hrouter reaches the public server` line passes again |

## The write-up

Fill in `fault-writeup.md`. Put in the seed from `fault-seed.txt`. For each of the three faults: the symptom, the command that found it with its output, what it means, the fix command, and the test passing again. Commit it and `fault-seed.txt`.

## Where each number comes from

| Number | Where it comes from |
|---|---|
| 3 faults | Enough to need a method, few enough to find in an hour |
| 7 faults in the menu | The seven most common ways this network breaks, each a layer from module 7 |
| The seed | Any word. `break.sh` turns it into a number, and uses that number to pick. The same word always gives the same pick |
| `198.51.100.1` | The provider router, the home router's default gateway |

## Results

Fill in `fault-writeup.md`. Commit it and `fault-seed.txt`.

## Draft status (remove before publishing)

Tested (course notes, 2026-10-24 to 2026-10-26): a mask mismatch (`Network is unreachable` one way, silent loss the other); a missing default route on the home router giving `Destination Net Unreachable` and a `curl` that fails at once; blocking only port 53 so that `dig` gets no answer while a lease still works.
Untested: the `nft -a list ruleset` layout that `break.sh` parses to find a rule's handle; forwarding switched off in a running network (a SYN arriving inside and nothing leaving outside); a masquerade rule deleted by handle; the pool-exhausted case (a new device ending with no address); the guest rule deleted; the exact symptom text of F1's forwarded port hanging; `ip route get` text when the default route is missing; the order of injection when three faults are combined. The draw itself is deterministic (the same seed gives the same three) and was checked on a laptop with `bash break.sh --list`.
