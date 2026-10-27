# Results: challenge 7, part 3

Fill this in after `bash test.sh` passes. Delete the lines in angle brackets. Commit the four `.txt` files and the three `.conf` files the script wrote.

## Prediction

Before I filled the gaps, I guessed that with local preference 50 on the direct link, r1 would send traffic <through r2 or direct>.
I was <right or wrong>, because: <one sentence>

## Before the preference

Contents of `before-preference.txt`:

```
<paste here>
```

Which route has the `*`, and why did it win? <answer>

## After the preference

My Gap 2 lines:

```
<paste your R1_FROM_R3 and R3_FROM_R1 lines>
```

Contents of `after-preference.txt`:

```
<paste here>
```

| Question | My answer |
|---|---|
| Which route has the `*` now? | <answer> |
| The direct route still has the shorter AS path. Why did it lose? | <answer> |
| Did r3 receive the number 50 from r1? How do you know? | <answer> |

## The cut

Contents of `failover.txt`:

```
<paste here>
```

Contents of `restored.txt`:

```
<paste here>
```

| Question | My answer |
|---|---|
| Which next hop did r1 use during the cut? | <answer> |
| What was the `ttl` in the ping during the cut, and after? Why do they differ? | <answer> |
| What would happen if you left out R3_FROM_R1? Would the ping still work? | <answer> |

## The trace

Output of `ip netns exec r1 traceroute -n -s 198.51.100.1 203.0.113.1` with the main link up:

```
<paste here>
```

## A real network

A company has two providers: one fast and paid, one slow and cheap. Which one gets the higher local preference, and why is that a policy choice and not a fact about the network? <two sentences>

## Three questions about BGP that I cannot answer yet

1. <question>
2. <question>
3. <question>
