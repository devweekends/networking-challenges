# Results: challenge 8, part 3

Fill this in after `bash test.sh` passes. Delete the lines in angle brackets. Commit `cafe-outside.txt`, `wg0.txt`, `size.txt` and `size-capture.txt` too.

## Prediction

Before I ran anything, I guessed the café would see <protocols>, and the outer packet would be <number> bytes.
I was <right or wrong>, because: <one sentence>

## What the café sees

The packet lines of `cafe-outside.txt`:

```
<paste here>
```

| Question | My answer |
|---|---|
| Which protocols are there? | <answer> |
| Can the café tell you talk to the office? How? | <answer> |
| Can the café tell you visited `10.20.0.5`? | <answer> |
| Which lines are the 3 pings? How can you tell? | <answer> |

## What the office sees

The packet lines of `wg0.txt`:

```
<paste here>
```

Why can the VPN box read the ping when the café cannot? <answer>

## The outer size

Contents of `size.txt` and `size-capture.txt`:

```
<paste here>
```

| Layer | Bytes | Running total |
|---|---|---|
| Inner IP packet | 84 | 84 |
| Padding | <bytes> | <total> |
| WireGuard | <bytes> | <total> |
| UDP header | <bytes> | <total> |
| Outer IPv4 header | <bytes> | <total> |

Which number in `size-capture.txt` matches which row? <answer>

## Optional: keepalive

If you did the optional extra, paste the two `conntrack -L` outputs and the two `ping` results from the VPN box:

```
<paste here>
```

Why does keepalive go on the laptop and not on the VPN box? <answer>
