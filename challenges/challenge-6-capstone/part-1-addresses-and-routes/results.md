# Results: challenge 6, part 1

Fill this in after `bash test.sh` passes. Delete the lines in angle brackets.

## Prediction

Before I ran anything, I guessed that `home1` pinging `203.0.113.80` would <get a reply or not>.
I was <right or wrong>, because: <one sentence>

## My address plan

| Link | Subnet | Addresses |
|---|---|---|
| Home LAN | <subnet> | <which address each plug has> |
| Guest LAN | <subnet> | <...> |
| Home router to provider | <subnet> | <...> |
| Public side | <subnet> | <...> |

Why did I choose a `/30` for the link between the two routers? <answer>

## The routers

Output of `ip addr` and `ip route` in `hrouter`:

```
<paste here>
```

Output of `ip addr` and `ip route` in `prouter`:

```
<paste here>
```

Why does `prouter` not need a default route? <answer>

## The route a packet takes

Output of `ip route get 203.0.113.80` in `home1`, and in `hrouter`:

```
<paste here>
```

Output of `traceroute -n 203.0.113.80` in `hrouter`:

```
<paste here>
```

## The public server sees the home router

Output of `curl http://203.0.113.80:8080/cgi-bin/whoami` from `hrouter`:

```
<paste here>
```

## The failing ping

Output of `ip netns exec home1 ping -c2 -W1 203.0.113.80`:

```
<paste here>
```

The capture on the home router's outside interface during that ping:

```
<paste here>
```

What source address is leaving, and why can no answer come back? <answer>

## Three questions about my home network that I cannot answer yet

1. <question>
2. <question>
3. <question>
