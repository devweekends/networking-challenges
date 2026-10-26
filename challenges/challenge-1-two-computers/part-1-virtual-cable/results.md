# Results: challenge 1, part 1

Fill this in after `bash test.sh` passes and `capture.txt` is saved. Delete the lines in angle brackets.

## My ping to the phone

Output of `ip netns exec laptop ping -c2 -W1 192.168.1.20`:

```
<paste here>
```

## My ping to an address nobody owns

Output of `ip netns exec laptop ping -c2 -W1 192.168.1.99`:

```
<paste here>
```

What I saw: <Was there an error message, or only silence?>

## My capture

The full capture is in `capture.txt`. Copy the lines here and name them.

| Line | What it is |
|---|---|
| <paste the first line> | <for example: ARP request. Who is asking, and who for?> |
| <paste the next line> | <ARP reply> |
| <paste the echo request line> | <echo request> |
| <paste the echo reply line> | <echo reply> |

## Questions about my capture

1. Which line has the destination hardware address `ff:ff:ff:ff:ff:ff`, and what does that mean? <answer>
2. What is the TTL in the echo request? <answer>
3. Why did the second ping have no ARP lines? <answer>

## Three questions about my home network that I cannot answer yet

1. <question>
2. <question>
3. <question>
