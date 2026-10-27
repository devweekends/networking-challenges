# Results: challenge 9, setup

Fill this in right after `bash faults.sh`, while the four faults are in the network. Replace each part in angle brackets. Your best guesses go in [faults.md](faults.md).

## Ping

Output of `ip netns exec laptop ping -c 50 -i 0.2 203.0.113.80` (the last lines are enough, but keep the line with `packet loss`):

```
<paste here>
```

## Traceroute

Output of `ip netns exec laptop traceroute -n 203.0.113.80`:

```
<paste here>
```

## What ping and traceroute cannot tell

Ping says some packets are lost. Where are they lost? Is the path slow, or is one link slow? Does a name give the wrong address? Is a port closed or blocked? Which of these questions can ping and traceroute answer, and which can they not?

<answer in two or three sentences>
