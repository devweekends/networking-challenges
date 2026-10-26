# Challenge 1, part 1: a virtual cable

Goal: make two computers inside the lab, join them with a virtual cable, ping one from the other, and capture the ping.

The addresses here (`192.168.1.10` and `192.168.1.20`) belong to the lab only. They are separate from your real home network, even if they look alike.

## 101: words you need

| Word | Plain meaning |
|---|---|
| Namespace | A separate set of network settings inside one machine. Here, each namespace plays one computer |
| Virtual cable (veth pair) | Two network ends joined together. What goes in one end comes out of the other |
| Interface | One network connection on a computer. Like a plug. Ours are `veth-laptop` and `veth-phone` |
| Up | Switched on. An interface that is not up cannot send |
| `/24` | "The first three numbers name the network." `192.168.1.x` is one network |
| Ping | Sends a small message and waits for an answer. It tells you if another computer is reachable |
| Packet loss | Messages that got no answer. `100% packet loss` means none came back |
| ARP | A question sent to everyone on the cable: "Who has this address?" The owner answers with its hardware address |
| MAC address | The hardware address of one interface. Six pairs of letters and numbers |
| tcpdump | A tool that shows the messages crossing an interface. This is called a capture |
| TTL | "Time to live." A counter in each packet. Every router lowers it by one. Linux starts it at 64 |

## What you build

```
  laptop                              phone
  192.168.1.10/24 --- one cable ---   192.168.1.20/24
  veth-laptop                         veth-phone
```

No real cable. No Wi-Fi. Both computers are inside the lab.

## Steps

Run these **in the lab**. First:

```
cd challenges/challenge-1-two-computers/part-1-virtual-cable
```

You can run the whole script with `bash cable.sh`. Or you can type its lines one by one. Typing them teaches more. The table shows each line.

| # | Type this | What it does | Script line |
|---|---|---|---|
| 1 | `bash cable.sh` | Builds everything below. Safe to run again | whole file |
| 2 | (delete the old network) | Removes what the course built before, so you start clean | [cable.sh#L12](cable.sh#L12) |
| 3 | `ip netns add laptop` | Makes the first computer | [cable.sh#L15](cable.sh#L15) (`ns_add` runs this command and writes the name in a list, see [lib.sh#L42](../../../toolkit/lib.sh#L42)) |
| 4 | `ip netns add phone` | Makes the second computer | [cable.sh#L16](cable.sh#L16) |
| 5 | `ip link add veth-laptop type veth peer name veth-phone` | Makes one cable with two ends | [cable.sh#L19](cable.sh#L19) |
| 6 | `ip link set veth-laptop netns laptop` | Plugs one end into the laptop | [cable.sh#L22](cable.sh#L22) |
| 7 | `ip link set veth-phone netns phone` | Plugs the other end into the phone | [cable.sh#L23](cable.sh#L23) |
| 8 | `ip netns exec laptop ip addr add 192.168.1.10/24 dev veth-laptop` | Gives the laptop its address. `ip netns exec laptop` means "run this inside the laptop" | [cable.sh#L26](cable.sh#L26) |
| 9 | `ip netns exec phone ip addr add 192.168.1.20/24 dev veth-phone` | Gives the phone its address | [cable.sh#L27](cable.sh#L27) |
| 10 | `ip netns exec laptop ip link set veth-laptop up` | Switches the laptop end on | [cable.sh#L30](cable.sh#L30) |
| 11 | `ip netns exec phone ip link set veth-phone up` | Switches the phone end on | [cable.sh#L31](cable.sh#L31) |
| 12 | `ip netns exec laptop ip addr show dev veth-laptop` | Shows the laptop's address. Look for `192.168.1.10/24` and `UP` | [cable.sh#L34](cable.sh#L34) |
| 13 | `ip netns exec laptop ping -c2 -W1 192.168.1.20` | Sends 2 pings and waits 1 second for each answer. You should see `2 received, 0% packet loss` | none |
| 14 | `ip netns exec laptop ping -c2 -W1 192.168.1.99` | Pings an address nobody owns. You should see `0 received, 100% packet loss`. No error message comes. Silence is the answer | none |
| 15 | the capture, below | You watch the ping cross the cable | none |
| 16 | `bash test.sh` | Checks all of the above | [test.sh#L41](test.sh#L41) and [test.sh#L57](test.sh#L57) |

### The capture

You want to watch the ping cross the cable. You have one terminal, so run the capture in the background with `&`.

```
cd /work/challenges/challenge-1-two-computers/part-1-virtual-cable
ip netns exec laptop ip neigh flush dev veth-laptop
timeout 10 ip netns exec phone tcpdump -n -v -e -i veth-phone -c 6 arp or icmp > capture.txt 2>&1 &
sleep 1
ip netns exec laptop ping -c2 -W1 192.168.1.20
wait
cat capture.txt
```

Line by line:

- `ip neigh flush` makes the laptop forget who it knows. Without it, the ARP lines may not appear.
- `tcpdump -n -v -e -i veth-phone` watches the phone's end. `-n` shows numbers, not names. `-v` shows more detail, such as TTL. `-e` shows hardware addresses.
- `arp or icmp` shows only ARP and ping messages.
- `-c 6` stops after 6 messages. `timeout 10` stops it after 10 seconds, whatever happens.
- `> capture.txt 2>&1 &` saves the output in `capture.txt` and runs in the background.
- `sleep 1` gives tcpdump a second to start. `wait` waits until it is done.

What you should see, in this order (the shape, not exact text):

1. An ARP request. The laptop asks everyone: "Who has `192.168.1.20`? Tell `192.168.1.10`." Its destination hardware address is `ff:ff:ff:ff:ff:ff`, which means everyone.
2. An ARP reply. The phone says: "`192.168.1.20` is at (its hardware address)."
3. An ICMP echo request from `192.168.1.10` to `192.168.1.20`. The `-v` detail shows `ttl 64`.
4. An ICMP echo reply back.
5. The second ping: another request and reply. No ARP this time, because the laptop now remembers.

So one ping is more than one packet: that is 6 lines for 2 pings. Chapter 1.5 explains each field.

## Hints

1. A ping reaches the other end of the cable. Does that end have an address, and is it up?
2. Both ends need `ip link set ... up`.
3. When you are stuck, run `ip netns list`. Then run `ip netns exec laptop ip addr` and `ip netns exec phone ip addr`.

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `192.168.1.10`, `192.168.1.20` | We chose them. They are from a private range that real home networks use too. In the lab they are only names for two made-up computers |
| `/24` | We chose it. It means the first three numbers name the network, so `.10` and `.20` are on the same network |
| `192.168.1.99` | We chose it because nobody owns it. It is the negative control: a ping that must fail |
| `-c2` | Send 2 pings |
| `-W1` | Wait 1 second for each answer |
| `ttl 64` | Linux starts every packet at 64. The same number is in `/proc/sys/net/ipv4/ip_default_ttl` |
| 6 lines in the capture | 2 ARP lines, then 2 pings with a request and a reply each (4 lines) |

## Results

Fill in [results.md](results.md). Commit `capture.txt` and `results.md`.

## Draft status (remove before publishing)

Tested (course notes, 2026-10-24): namespaces, virtual cables, and `ping -c2 -W1`, including 2 sent and 0 received for an address nobody owns.
Untested: the exact `tcpdump -n -v -e` output and the TTL display, the `arp or icmp` filter, whether exactly 6 lines appear, `ip neigh flush`, and `ttl=64` in the ping replies.
