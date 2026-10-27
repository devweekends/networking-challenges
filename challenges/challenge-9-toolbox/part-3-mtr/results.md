# Results: challenge 9, part 3

Fill this in as you go through the steps. Replace each part in angle brackets. Also fill in **Fault 1** in [faults.md](../part-0-the-broken-network/faults.md).

## Fault 1: a report with the loss

Output of `ip netns exec laptop mtr -rn -c 50 -i 0.2 203.0.113.80`, while the faults are planted:

```
<paste the whole report here>
```

## The lossy link

The loss starts at hop <number>. The lossy cable is between <address> and <address>.

What `tc qdisc show` printed on that cable:

```
<paste here>
```

## A router limiting itself

Output of the same mtr command, after you fixed fault 1 and switched r1's limit on with `ip netns exec r1 sysctl -w net.ipv4.icmp_ratelimit=1000`:

```
<paste the whole report here>
```

Hop 1 shows loss here. Is hop 1 broken? How do you know from the other rows? <answer>

## After the fix

Output of the same mtr command, after you switched r1's limit off again (`icmp_ratelimit=0`):

```
<paste the whole report here>
```
