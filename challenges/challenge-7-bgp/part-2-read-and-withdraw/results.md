# Results: challenge 7, part 2

Fill this in after `bash test.sh` passes. Delete the lines in angle brackets. Commit `route-all.txt`, `withdrawn.txt` and `back.txt` too.

## Prediction

Before I ran anything, I guessed the ping would fail <at once or after a while>.
I was <right or wrong>, because: <one sentence>

## The whole route

Contents of `route-all.txt`:

```
<paste here>
```

| Question | My answer |
|---|---|
| Which network first announced `203.0.113.0/24`? Which line tells you? | <answer> |
| Which network passed it on to r1? | <answer> |
| Where does r1 send the traffic? | <answer> |
| r1 did not receive `BGP.local_pref: 100`. Where does it come from? | <answer> |

The AS path for the same block in r2 is: <paste r2's BGP.as_path line>. Why is it shorter? <answer>

## The withdrawal

Contents of `withdrawn.txt`:

```
<paste here>
```

| Question | My answer |
|---|---|
| What did BIRD say about `203.0.113.0/24`? | <answer> |
| Which line is missing from `ip route`? | <answer> |
| How many withdrawals did r1 receive? | <answer> |
| r3 still has the address `203.0.113.1`. Why can nobody reach it? | <answer> |

## The return

Contents of `back.txt`:

```
<paste here>
```

## A real outage

In module 7 you met an outage where a big network's computers were fine, but nobody could reach them. How is that like what you did in this part? <two sentences>

## Three questions about BGP that I cannot answer yet

1. <question>
2. <question>
3. <question>
