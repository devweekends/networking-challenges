# Results: challenge 9, part 5

Fill this in as you go through the steps. Replace each part in angle brackets. Also fill in **Fault 3** in [faults.md](../part-0-the-broken-network/faults.md).

## Consent

Type the consent line from the README here, word for word, on one line, **before** you run your first scan:

<type the consent line here>

## The first scan

Output of `ip netns exec laptop nmap -n 203.0.113.80`:

```
<paste here>
```

Is the app's port in this list? Why, or why not? <answer>

## A wider scan

Output of `ip netns exec laptop nmap -n -p 1-10000 203.0.113.80`:

```
<paste here>
```

## Three states

Output of `ip netns exec laptop nmap -n -p 80,81,PORT 203.0.113.80`, with the app's port for PORT:

```
<paste here>
```

| State | What nmap saw | What it means |
|---|---|---|
| open | <answer> | <answer> |
| closed | <answer> | <answer> |
| filtered | <answer> | <answer> |

## The rule that made it filtered

Output of `ip netns exec r2 nft list ruleset`:

```
<paste here>
```

## After the fix

Output of the three-states scan again, after you removed the rule:

```
<paste here>
```
