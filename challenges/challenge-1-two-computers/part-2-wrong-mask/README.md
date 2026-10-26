# Challenge 1, part 2: same cable, wrong mask

Goal: give two computers on one cable masks that disagree. Read the two different failures. Then ping an address nobody owns and watch the ARP go unanswered.

Do part 1 first. This part uses the same two computers and the same two addresses.

## 101: words you need

| Word | Plain meaning |
|---|---|
| Mask | Tells a computer which addresses are on its own network. `/24` and `/28` are masks written short |
| Prefix length | The number after the slash. `/24` means 24 bits name the network. `/28` means 28 bits |
| On-link | An address on your own network. You send to it directly, on the cable |
| Route | A rule that says where to send a packet. "For addresses like this, use this interface" |
| Network is unreachable | The computer has no route for that address. It stops at once and sends nothing |
| Silent loss | You send and nothing comes back. No error. Only `100% packet loss` |
| ARP request | "Who has this address?" sent to everyone on the cable |
| Unanswered ARP | An ARP request that nobody answers. The address has no owner on this cable |

## What you build

```
  laptop                              phone
  192.168.1.10/24 --- one cable ---   192.168.1.20/28
```

Each computer decides alone whether the other is "on my network". They use their own mask. So two computers can disagree.

- The laptop has `/24`. Its network is `192.168.1.0` to `192.168.1.255`. It thinks `.20` is on its network.
- The phone has `/28`. A `/28` network holds 16 addresses. The networks start at `.0`, `.16`, `.32` and so on. The phone's network is `192.168.1.16` to `192.168.1.31`. The laptop's address `.10` is outside it. The phone thinks `.10` is not on its network and has no route to it.

Neither computer has a gateway. So there is nowhere else to send.

Before you run anything, guess: which computer thinks the other is NOT on its own network, the one with `/24` or the one with `/28`?

## Steps

Run these **in the lab**. First:

```
cd /work/challenges/challenge-1-two-computers/part-2-wrong-mask
```

| # | Type this | What you should see | Script line |
|---|---|---|---|
| 1 | `bash wrong-mask.sh` | Both computers built. The phone has `/28` | [wrong-mask.sh#L14](wrong-mask.sh#L14) picks the phone's prefix (28 by default), [L26](wrong-mask.sh#L26) and [L27](wrong-mask.sh#L27) set the addresses |
| 2 | `ip netns exec laptop ip addr` and `ip netns exec phone ip addr` | `192.168.1.10/24` on the laptop and `192.168.1.20/28` on the phone. Compare the two masks | [wrong-mask.sh#L27](wrong-mask.sh#L27) |
| 3 | `ip netns exec laptop ip route` and `ip netns exec phone ip route` | Each computer has a route for its own network only. The phone's route is for `192.168.1.16/28` (the exact lines are untested) | none |
| 4 | `ip netns exec laptop ping -c2 -W1 192.168.1.20` | Silent loss: `2 packets transmitted, 0 received`. No error message | none |
| 5 | `ip netns exec phone ping -c2 -W1 192.168.1.10` | At once: `ping: connect: Network is unreachable`. The phone sent nothing | none |
| 6 | the capture, below | You see the laptop's ARP request, and how the phone reacts | none |
| 7 | `bash wrong-mask.sh 24` | The fix. Both computers are `/24` | [wrong-mask.sh#L14](wrong-mask.sh#L14) takes the number you give |
| 8 | Ping both ways again (steps 4 and 5) | `0% packet loss` both ways | none |
| 9 | `bash test.sh` | The test builds the broken network and the fixed one, and checks both. It deletes your two computers and rebuilds them. Save your capture first | [test.sh#L28](test.sh#L28), [L36](test.sh#L36), [L47](test.sh#L47), [L63](test.sh#L63) |

### The capture

First rebuild the broken network with `bash wrong-mask.sh`. Then run:

```
ip netns exec laptop ip neigh flush dev veth-laptop
timeout 12 ip netns exec phone tcpdump -n -v -e -i veth-phone arp or icmp > capture.txt 2>&1 &
sleep 1
ip netns exec laptop ping -c2 -W1 192.168.1.20
ip netns exec laptop ping -c2 -W1 192.168.1.99
wait
cat capture.txt
```

This runs for about 12 seconds. The capture holds two things:

- The pings to `.20`. You should see the laptop's ARP request for `192.168.1.20`. What the phone does next is for you to read. Does the phone send an ARP reply? Does an echo request arrive? The course has not isolated why the laptop gets no answer, so write down what your capture shows. (Untested: whether the phone sends an ARP reply.)
- The pings to `.99`. Nobody owns `192.168.1.99`. You should see ARP requests for it, and no reply. This is the same silent loss as in part 1, now explained: the laptop asks "Who has `.99`?", nobody answers, so it has nowhere to send.

## Hints

1. Compare the two masks with `ip addr`.
2. Which address is each side's own network? The laptop's is `192.168.1.0` to `.255`. What is the phone's?
3. Ask the phone how it would send to `.10`: `ip netns exec phone ip route get 192.168.1.10`. The exact error text is untested. Expect a message that says the network is unreachable.
4. When you are stuck: `ip netns list`, then `ip addr` in each namespace.

Do not change any other network setting. This part only needs the mask.

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `192.168.1.10` and `192.168.1.20` | The same two addresses as part 1 |
| `/24` | The laptop's mask, and both masks in the fixed state |
| `/28` | The wrong mask for the phone, on purpose. 28 bits for the network leaves 4 bits for hosts. 2 to the power 4 is 16 addresses |
| `192.168.1.16` to `192.168.1.31` | The block of 16 that holds `.20`. Blocks start at multiples of 16: 0, 16, 32. So `.20` is in the block that starts at 16 |
| `192.168.1.99` | We chose it because nobody owns it |
| `-c2 -W1` | 2 pings, wait 1 second for each |

## Results

Fill in [results.md](results.md). Commit `capture.txt` too.

## Draft status (remove before publishing)

Tested (course notes, 2026-10-24): with `192.168.1.10/24` and `192.168.1.20/28` on one cable, laptop to phone is silent loss (2 sent, 0 received) and the phone's capture shows the laptop's ARP request; phone to laptop prints `ping: connect: Network is unreachable` at once. A ping to `192.168.1.99` shows silent loss and unanswered ARP requests. The "Destination Host Unreachable" line was not seen with `-c2 -W1`, so this part does not promise it.
Untested: whether the phone sends an ARP reply, the `ip route` and `ip route get` output text, and the `arp or icmp` capture with `-v -e` in this setup.
