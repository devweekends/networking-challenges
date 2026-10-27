# Results: challenge 7, part 1

Fill this in after `bash test.sh` passes. Delete the lines in angle brackets. Commit `r1.conf`, `r2.conf` and `r3.conf` too.

## Prediction

Before I ran anything, I guessed r1's AS path to `203.0.113.0/24` would be <your guess>.
I was <right or wrong>, because: <one sentence>

## The sessions

Output of `birdc -s /tmp/bird-r1.ctl show protocols`:

```
<paste here>
```

Which line shows the BGP session, and what is its state? <answer>

## r1's routes

Output of `birdc -s /tmp/bird-r1.ctl show route`:

```
<paste here>
```

Output of `ip netns exec r1 ip route`:

```
<paste here>
```

| Question | My answer |
|---|---|
| Which route did BIRD give to Linux? How can you tell? | <answer> |
| What is the origin AS of `203.0.113.0/24`? | <answer> |
| Which router does r1 send that traffic to? | <answer> |

## The other direction

The AS path in `birdc -s /tmp/bird-r3.ctl show route all 198.51.100.0/24`: <paste the BGP.as_path line>

Why is it not the same as r1's path? <answer>

## Two pings

Output of `ip netns exec r1 ping -c2 -W1 -I 198.51.100.1 203.0.113.1`:

```
<paste here>
```

Output of `ip netns exec r1 ping -c2 -W1 203.0.113.1` (no `-I`):

```
<paste here>
```

Why does the second one get no answer? <answer>

## One line of my config

Pick one line of `r1.conf`. Change it in your head. What would break? <answer>

## Three questions about BGP that I cannot answer yet

1. <question>
2. <question>
3. <question>
