# Challenge 7: three networks that talk BGP

This challenge belongs to module 10 of the course, "How networks reach each other". You run three small networks inside the lab. Each one is its own autonomous system with its own number, and they tell each other which address blocks they can reach with BGP.

| Part | Folder | Help | You will |
|---|---|---|---|
| 1 | `part-1-three-networks` | Guided | Start three networks, AS64496, AS64497 and AS64498, and see a block travel from one end to the other |
| 2 | `part-2-read-and-withdraw` | Guided | Read the AS path, withdraw a block and watch the ping fail, then bring it back |
| 3 | `part-3-backup-link` | Gapped | Add a direct link, then use your own preference to make it a backup |
| 4 | `part-4-hijack-and-filter` | Gapped | See a wrong, more specific announcement pull traffic away, then write the filter that stops it |

Do the parts in order. Each part's README explains every new word and every line of the script.

The addresses and AS numbers in the lab are made for examples and documentation: `198.51.100.0/24`, `203.0.113.0/24` and AS64496 to AS64511. They are never used on the real internet.

## A sample trace, for chapter 10.1 and the gate in 10.12

If your own trace shows only `* * *` or only private hops (common on a mobile hotspot or behind carrier-grade NAT), practise on this one. It is real and public.

Where it comes from: RIPE Atlas measurement 18399116, a traceroute run by the RIPE NCC's measurement network. This run started from probe 6307, an "anchor" in Amsterdam inside the RIPE NCC's own network, and went to an anchor in Tokyo, on 27 August 2026 at 13:18 UTC. Anyone can read it at https://atlas.ripe.net/measurements/18399116.

```
 1  *
 2  193.0.3.5          1.0 ms
 3  80.249.209.139     6.1 ms
 4  91.129.14.30      23.2 ms
 5  91.129.14.248     23.1 ms
 6  91.129.12.116     23.8 ms
 7  91.129.12.45      24.0 ms
 8  91.129.14.68      39.9 ms
 9  62.115.171.212    20.0 ms
10  62.115.138.112    31.9 ms
11  62.115.114.95     39.7 ms
12  62.115.143.23     34.4 ms
13  62.115.134.229   248.2 ms
14  62.115.116.203   264.6 ms
15  62.115.41.151    259.4 ms
16  *
17  *
18  45.76.201.211    254.8 ms
19  104.238.161.230  261.8 ms
```

Each line shows the first answer time for that hop. Here is what the lookups said on 27 October 2026, with RIPEstat's `prefix-overview` (for example https://stat.ripe.net/data/prefix-overview/data.json?resource=62.115.171.212) and PeeringDB:

| Hops | Block | Network that announces it |
|---|---|---|
| start, 2 | `193.0.0.0/21` | AS3333, RIPE NCC |
| 3 | `80.249.208.0/21` | Announced by nobody. PeeringDB lists this block as the peering network of AMS-IX, an exchange point in Amsterdam |
| 4 to 8 | `91.128.0.0/14` | AS1257, Tele2 Sverige |
| 9 to 15 | `62.115.0.0/16` | AS1299, Arelion |
| 18, 19 | `45.76.192.0/19` and `104.238.160.0/23` | AS20473, The Constant Company (Vultr) |

Things to notice:

- Hop 3 belongs to no network on its own. It is an address on an exchange point's shared switch, where the networks meet.
- The jump from about 35 ms at hop 12 to about 250 ms at hop 13 is where the path crosses a long distance. Hop 13 alone cannot tell you which cable it used.
- A hop's address can belong to the network on either side of a link, so "this hop is in AS1299" is a good guess, not proof.
- Lookups change over time. If you look these addresses up today and get a different answer, write down both answers and the dates.
