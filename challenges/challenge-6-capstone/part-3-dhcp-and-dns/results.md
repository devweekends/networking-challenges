# Results: challenge 6, part 3

Fill this in after `bash test.sh` passes. Delete the lines in angle brackets.

## Prediction

Before I ran anything, I guessed that a guest's question to `192.168.50.1` <would or would not> match the isolation rule, because: <one sentence>

## The leases

The `lease applied` lines from the hook script:

```
<paste here>
```

| Device | Subnet | Address | Gateway | DNS server |
|---|---|---|---|---|
| `home1` | <subnet> | <address> | <gateway> | <dns> |
| `home2` | <subnet> | <address> | <gateway> | <dns> |
| `guest1` | <subnet> | <address> | <gateway> | <dns> |

How does one dnsmasq give two different gateways? <answer>

## The names

Output of `dig +short @ADDRESS web.test` from `home1` and from `guest1`:

```
<paste here>
```

Output of `curl http://web.test:8080/cgi-bin/whoami` from `home1` and from `guest1`:

```
<paste here>
```

## One lease on camera

The `tcpdump -n -v` of ports 67 and 68 during one lease:

```
<paste here>
```

| Packet | Who sent it | What it says |
|---|---|---|
| 1 | <who> | <meaning> |
| 2 | <who> | <meaning> |
| 3 | <who> | <meaning> |
| 4 | <who> | <meaning> |

## The things that must fail

| Check | What I saw | Why |
|---|---|---|
| `dig @192.168.1.1 nosuch.test` | <result> | <one sentence> |
| a new device with dnsmasq stopped | <result> | <one sentence> |

## Answers

1. Does the isolation rule match a guest's question to the router? Why or why not? <answer>
2. What happens to a third device if the home pool has only two addresses? <answer>

## Three questions about my home network that I cannot answer yet

1. <question>
2. <question>
3. <question>
