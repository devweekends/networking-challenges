# Results: challenge 5, part 1

Fill this in after `bash test.sh` passes. Delete the lines in angle brackets. Commit `dhcp-capture.txt` too.

## Prediction

Before I ran anything, I guessed that a new device asking for a lease with dnsmasq stopped would <get an address or get none>, after about <seconds>.
I was <right or wrong>, because: <one sentence>

## The leases

The client's output for the laptop (the `udhcpc` lines and the `lease applied` line):

```
<paste here>
```

The laptop after its lease (address, route, resolver file):

```
<paste here>
```

| Part of the lease | Value | Where it ended up on the laptop |
|---|---|---|
| address and mask | <value> | <where> |
| gateway | <value> | <where> |
| DNS server | <value> | <where> |
| lease time | <value> | <what happens when it ends> |

## The names

Output of `dig +short @192.168.1.1 web.test`:

```
<paste here>
```

The status line of `dig @192.168.1.1 nosuch.test`:

```
<paste here>
```

Output of `curl -sS http://web.test:8080/cgi-bin/whoami` from the laptop:

```
<paste here>
```

Which of these two commands asks the DNS server I name, and which asks the servers in the resolver file? <answer>

## The lease on camera

Contents of `dhcp-capture.txt`:

```
<paste here>
```

| Packet | Who sent it | What it says |
|---|---|---|
| 1 | <who> | <meaning> |
| 2 | <who> | <meaning> |
| 3 | <who> | <meaning> |
| 4 | <who> | <meaning> |

Why does the first packet come from `0.0.0.0`? <answer>

## With dnsmasq stopped

What the client printed, how long it took, and what address the interface had at the end:

```
<paste here>
```

## Three questions about my home network that I cannot answer yet

1. <question>
2. <question>
3. <question>
