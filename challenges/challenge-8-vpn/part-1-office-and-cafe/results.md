# Results: challenge 8, part 1

Fill this in after `bash test.sh` passes. Delete the lines in angle brackets. Commit `forward-test.txt` too.

## Prediction

Before I ran anything, I guessed the website would see the laptop as <192.168.50.23 or 198.51.100.2>.
I guessed that with the rule deleted, one more packet would <still arrive or not arrive>.
I was <right or wrong>, because: <one sentence>

## What the website sees

The two `curl` lines from step 9:

```
<paste here>
```

| Computer | Its own address | The website saw | Why |
|---|---|---|---|
| laptop | 192.168.50.23 | <address> | <one sentence> |
| officesrv | 10.20.0.5 | <address> | <one sentence> |

## No way in

The laptop's `ping 10.20.0.5` from step 9:

```
<paste here>
```

Which computer answered "Destination Net Unreachable", and why? <answer>

## The forward experiment

Contents of `forward-test.txt`:

```
<paste here>
```

The conntrack line that step 10 printed:

```
<paste here>
```

| Line | Did it arrive? | Why |
|---|---|---|
| 2 rule off, old state kept | <yes or no> | <one sentence> |
| 4 rule back, old state kept | <yes or no> | <one sentence> |

You change a NAT rule and nothing changes. What is the first thing you check now? <answer>

## Two questions I still have

1. <question>
2. <question>
