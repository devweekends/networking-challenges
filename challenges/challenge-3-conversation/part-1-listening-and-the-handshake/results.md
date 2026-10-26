# Results: challenge 3, part 1

Fill this in after `bash test.sh` passes. Delete the lines in angle brackets. Commit the five `.txt` files too.

## Prediction

Before I ran anything, I guessed: with the server on `127.0.0.1`, curl from the laptop <hangs or fails at once>.
I was <right or wrong>, because: <one sentence>

## The server on 127.0.0.1

Contents of `listen-loopback.txt`:

```
<paste here>
```

What `curl` printed, and the exit code:

```
<paste here>
```

## The server on 0.0.0.0

Contents of `listen-all.txt`:

```
<paste here>
```

## The handshake

Contents of `handshake.txt`:

```
<paste here>
```

| Line | What it is |
|---|---|
| <paste the first Flags line> | <which packet, who sent it, what it means> |
| <paste the second Flags line> | <which packet, who sent it, what it means> |
| <paste the third Flags line> | <which packet, who sent it, what it means> |

## One open conversation, from both sides

Contents of `connected-laptop.txt` and `connected-server.txt` (the `ESTAB` lines):

```
<paste here>
```

## Answers

1. What changed between `listen-loopback.txt` and `listen-all.txt`? <answer>
2. Why was the first curl refused and not stuck? <answer>
3. In the `ss` output, which numbers are the same on both sides, and why do they appear in a different order? <answer>
4. Which number in the capture is the laptop's port, and who chose it? <answer>

## Three questions about my home network that I cannot answer yet

1. <question>
2. <question>
3. <question>
