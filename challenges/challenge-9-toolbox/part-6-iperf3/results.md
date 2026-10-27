# Results: challenge 9, part 6

Fill this in as you go through the steps. Replace each part in angle brackets. Also fill in **Fault 4** in [faults.md](../part-0-the-broken-network/faults.md).

Clear fault 1 in part 3 first. With both faults in the network, the numbers mix.

## The slow direction

The whole output of `ip netns exec laptop iperf3 -c 203.0.113.80 -t 5`:

```
<paste here>
```

## The other direction

The whole output of `ip netns exec laptop iperf3 -c 203.0.113.80 -t 5 -R`:

```
<paste here>
```

## UDP

The whole output of `ip netns exec laptop iperf3 -c 203.0.113.80 -t 5 -u -b 2M`:

```
<paste here>
```

## Where the limit is

Output of `ip netns exec r2 tc qdisc show`:

```
<paste here>
```

## After the fix

The whole output of `ip netns exec laptop iperf3 -c 203.0.113.80 -t 5`, after you removed the limit:

```
<paste here>
```

## Questions

| Question | My answer |
|---|---|
| The sender line and the receiver line show different speeds. Which one is the real speed of the path, and why? | <answer> |
| `-R` was fast. Why does a limit on one cable slow only one direction? | <answer> |
| Fault 1 also made a copy slow. How did iperf3 look different with fault 1? (Look at the Retr column) | <answer> |
