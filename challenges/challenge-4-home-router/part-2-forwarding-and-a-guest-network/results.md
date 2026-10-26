# Results: challenge 4, part 2

Fill this in after `bash test.sh` passes. Delete the lines in angle brackets. Commit `ruleset.txt`, `outside.txt`, `inside.txt` and `outside-tests.txt`.

## Prediction

Before I ran anything, I guessed that a visit to `203.0.113.1:22` would <hang or fail at once>.
I was <right or wrong>, because: <one sentence>

## The router's rules

Contents of `ruleset.txt`:

```
<paste here>
```

Which line forwards the port, and which line isolates the guest? <answer>

## The three outside tests

Contents of `outside-tests.txt`:

```
<paste here>
```

| Test | Exit code | What it tells me |
|---|---|---|
| forwarded | <code> | <one sentence> |
| unforwarded | <code> | <one sentence> |
| direct | <code> | <one sentence> |

## The forwarded request, on both sides

Contents of `outside.txt` and `inside.txt`:

```
<paste the outside lines>
```

```
<paste the inside lines>
```

| Question | My answer |
|---|---|
| Which field was rewritten between the two sides? | <answer> |
| Which field was not rewritten? | <answer> |

## The guest

Output of the guest's `curl` to the server, and of its `curl` to `http://192.168.1.23/`:

```
<paste here>
```

What is the difference between a refused connection and a timeout? Which one did the guest get, and why? <answer>

## Three questions about my home network that I cannot answer yet

1. <question>
2. <question>
3. <question>
