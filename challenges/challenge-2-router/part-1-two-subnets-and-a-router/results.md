# Results: challenge 2, part 1

Fill this in after `bash test.sh` passes. Delete the lines in angle brackets.

## Prediction

Before I ran anything, I guessed: if only the server's route back is missing, the laptop's ping <gets through or does not>.
I was <right or wrong>, because: <one sentence>

## The mid-point

Output of `ip netns exec laptop ping -c2 -W1 192.168.1.1`:

```
<paste here>
```

What is the TTL in the reply, and why? <answer>

## The ping across the router

Output of `ip netns exec laptop ping -c2 -W1 203.0.113.80`:

```
<paste here>
```

What is the TTL in the reply now, and why is it different? <answer>

## The routes

Output of `ip route` in each computer:

```
<paste the laptop's routes>
<paste the router's routes>
<paste the server's routes>
```

The router has no default route. Why does it not need one for this part? <answer>

## traceroute

Output of `ip netns exec laptop traceroute -n 203.0.113.80`:

```
<paste here>
```

Which line is the router, and which is the server? <answer>

## An address the router has no route for

Output of `ip netns exec laptop ping -c1 -W1 198.51.100.7`:

```
<paste here>
```

Who answered, and what is the difference from silent loss? <answer>

## My capture

Paste the lines from `inside.txt` and `outside.txt`.

```
<paste the inside lines>
```

```
<paste the outside lines>
```

| Question | My answer |
|---|---|
| Which MAC addresses are on the inside cable? | <answer> |
| Which MAC addresses are on the outside cable? | <answer> |
| Which of these changed at the router: source IP, destination IP, source MAC, destination MAC, TTL? | <answer> |
| Which did not change? | <answer> |

## What each gap does

| Gap | What I saw when it was missing |
|---|---|
| 1 default route on the laptop | <what the ping said> |
| 2 forwarding in the router | <what the ping said> |
| 3 route on the server | <what the ping said> |

## Three questions about my home network that I cannot answer yet

1. <question>
2. <question>
3. <question>
