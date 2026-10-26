# Results: challenge 4, part 1

Fill this in after `bash test.sh` passes. Delete the lines in angle brackets. Commit `inside.txt`, `outside.txt` and the three `.txt` files the script wrote.

## Prediction

Before I ran anything, I guessed the server would see <192.168.1.23 or 203.0.113.1>.
I was <right or wrong>, because: <one sentence>

## Before masquerade

Output of `ip netns exec laptop ping -c1 -W1 203.0.113.80` with forwarding on and no masquerade rule:

```
<paste here>
```

Why is there no answer? <answer>

## After masquerade: what the server sees

Output of `curl` from the laptop and from the phone to `http://203.0.113.80:8080/cgi-bin/whoami`:

```
<paste both here>
```

## The same source port

Contents of `same-port-laptop.txt` and `same-port-phone.txt`:

```
<paste here>
```

Contents of `conntrack.txt`:

```
<paste here>
```

| Device | Sent from | Server saw | Why |
|---|---|---|---|
| laptop | 41000 | <port> | <one sentence> |
| phone | 41000 | <port> | <one sentence> |

Which number in `conntrack.txt` is the new port? <answer>

## The capture

Contents of `inside.txt` and `outside.txt`:

```
<paste the inside lines>
```

```
<paste the outside lines>
```

| Question | My answer |
|---|---|
| Which field changed between the two sides? | <answer> |
| Which field did not change, and why? | <answer> |

## A private address, from the outside

Output of `ip netns exec server curl -sS -m 3 http://192.168.1.23/`:

```
<paste here>
```

Why does it fail at once, and not after a timeout? <answer>

## Three questions about my home network that I cannot answer yet

1. <question>
2. <question>
3. <question>
