# Results: challenge 9, part 4

Fill this in as you go through the steps. Replace each part in angle brackets. Also fill in **Fault 2** in [faults.md](../part-0-the-broken-network/faults.md).

The broken name is the one in complaint B, from `bash faults.sh`.

## Two resolvers

The whole output of `ip netns exec laptop dig @192.0.2.1 NAME` (the campus resolver):

```
<paste here>
```

The whole output of `ip netns exec laptop dig @203.0.113.53 NAME` (the public resolver):

```
<paste here>
```

| Question | My answer |
|---|---|
| Which resolver gives the wrong address? | <answer> |
| What is in the `flags:` line of each answer? | <answer> |
| The TTL of the wrong answer is 0. What does that mean for a computer that stores answers? | <answer> |

## Following a name from the root

Output of `dig +trace @1.1.1.1 example.com`, run in the lab itself (not in the laptop). The first lines and the last lines are enough:

```
<paste here>
```

Which servers answered, in order? <answer>

## After the fix

Output of `ip netns exec laptop dig +short NAME` and of `ip netns exec laptop curl -sS -m 5 http://NAME/`:

```
<paste here>
```
