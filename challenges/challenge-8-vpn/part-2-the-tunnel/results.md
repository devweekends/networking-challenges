# Results: challenge 8, part 2

Fill this in after `bash test.sh` passes. Delete the lines in angle brackets. Commit `before-tunnel.txt`, `with-tunnel.txt`, `wg-show.txt`, `spoof.txt` and `spoof-capture.txt` too. Never commit a key file.

## Prediction

Before I ran anything, I guessed that without Gap 4 the server would send its answer to <where>.
I was <right or wrong>, because: <one sentence>

## Before and with the tunnel

Contents of `before-tunnel.txt`:

```
<paste here>
```

Contents of `with-tunnel.txt`:

```
<paste here>
```

The answer says `ttl=63`. The server started at 64. Which computer lowered it, and why not the routers on the internet? <answer>

## What each end knows

Contents of `wg-show.txt`:

```
<paste here>
```

| Question | My answer |
|---|---|
| The VPN box shows the laptop's endpoint. You never typed it. Where did it come from? | <answer> |
| Why does the café router need no port forward? | <answer> |
| Someone copies the laptop's public key. What can they do with it? What can they not do? | <answer> |

## The two routes

| Route | In which computer | What breaks without it |
|---|---|---|
| `10.20.0.0/24 dev wg0` | <computer> | <one sentence> |
| `10.99.0.0/24 via 10.20.0.2` | <computer> | <one sentence> |

AllowedIPs already says `10.20.0.0/24`. Why is the route still needed? <answer>

## The false source

Contents of `spoof.txt` (the first line is enough) and `spoof-capture.txt`:

```
<paste here>
```

Why did the VPN box drop the packet? Which setting decided it? <answer>

## One question I still have

1. <question>
