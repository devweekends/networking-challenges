# Results: challenge 6, part 2

Fill this in after `bash test.sh` passes. Delete the lines in angle brackets.

## Prediction

Before I ran anything, I guessed that a visit to `198.51.100.2:22` would <be refused or time out>.
I was <right or wrong>, because: <one sentence>

## The router's rules

Output of `ip netns exec hrouter nft list ruleset`:

```
<paste here>
```

Which line is NAT that rewrites the source? Which rewrites the destination? Which one is a filter? <answer>

## What the public server sees

Output of `curl http://203.0.113.80:8080/cgi-bin/whoami` from `home1` and from `guest1`:

```
<paste here>
```

## The forwarded port

Output of `curl http://198.51.100.2:8080/` from `server`:

```
<paste here>
```

## The NAT table

The lines of `conntrack -L` in `hrouter` for the connections above:

```
<paste here>
```

| Question | My answer |
|---|---|
| Did the port change for either device? Why or why not? | <answer> |
| Which part of a line is what the device sent, and which part is the answer? | <answer> |

## The capture, one `home1` curl

Inside (the home side of `hrouter`):

```
<paste here>
```

Outside (the plug towards `prouter`):

```
<paste here>
```

Which field changed between the two? <answer>

## The things that must fail

| Check | What I saw (exit code and message) | Why |
|---|---|---|
| `guest1` to `http://192.168.1.20/` | <result> | <one sentence> |
| `server` to `http://192.168.1.20/` | <result> | <one sentence> |
| `server` to `http://198.51.100.2:22/` | <result> | <one sentence> |

## Three questions about my home network that I cannot answer yet

1. <question>
2. <question>
3. <question>
