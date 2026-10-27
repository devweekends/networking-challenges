# Results: challenge 8, part 4

Fill this in after `bash test.sh` passes. Delete the lines in angle brackets. Commit the `.txt` files the script wrote too.

## Prediction

Before I ran anything, I guessed that in the full tunnel the café <could or could not> see my name questions, and that in the split tunnel the website would see <address>.
I was <right or wrong>, because: <one sentence>

## What the website sees

Contents of `website-before.txt`, `website-full.txt` and `website-split.txt`:

```
<paste here>
```

| Tunnel | The website saw | Why |
|---|---|---|
| none | <address> | <one sentence> |
| full | <address> | <one sentence> |
| split | <address> | <one sentence> |

## The full tunnel's routes

Contents of `routes-full.txt`:

```
<paste here>
```

| Route | Why it is there |
|---|---|
| `default dev wg0` | <one sentence> |
| `203.0.113.2 via 192.168.50.1` | <one sentence> |
| `192.168.50.0/24 dev veth-laptop` | <one sentence, about DNS> |

## The DNS leak

The packet lines of `dns-cafe.txt`, then of `dns-tunnel.txt`:

```
<paste here>
```

| Question | My answer |
|---|---|
| In the full tunnel, before Gap 4, who saw the name `web.test`? | <answer> |
| After Gap 4, who saw it? | <answer> |
| Why could the café's name server not answer `intranet.test`? | <answer> |

## The split tunnel

The packet lines of `cafe-outside-split.txt`:

```
<paste here>
```

What can the café read in the split tunnel that it could not read in the full tunnel? <answer>

## Who sees what

| Set-up | The café sees | The office sees | The website sees |
|---|---|---|---|
| No tunnel | <answer> | <answer> | <answer> |
| Full tunnel, café DNS | <answer> | <answer> | <answer> |
| Full tunnel, office DNS | <answer> | <answer> | <answer> |
| Split tunnel | <answer> | <answer> | <answer> |
