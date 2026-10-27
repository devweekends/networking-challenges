# Challenge 9, part 4: dig, ask DNS yourself

The site loads on your phone's mobile data, but not on the campus Wi-Fi. Same name. Why? The two networks ask two different resolvers. If they give two different answers, one of them is wrong. `dig` lets you ask a resolver you choose, and shows the whole answer.

Goal: find fault 2 by asking two resolvers the same question. Then follow a real name from the root of DNS, with `+trace`.

## 101: words you need

| Word | Plain meaning |
|---|---|
| dig | A tool that asks one DNS question and prints the whole answer |
| `@SERVER` | Ask this server, not the one in `/etc/resolv.conf` |
| `+short` | Print only the answer, nothing else |
| A record | The answer "this name has this IPv4 address" |
| ANSWER SECTION | The part of dig's output with the answer lines: name, TTL, `IN`, type, value |
| TTL (in DNS) | How many seconds a computer may keep the answer before it asks again. 0 means: do not keep it |
| `SERVER:` line | Near the end of dig's output: which server really answered |
| Root servers | The top of DNS. They know who answers for `.com`, `.org` and the other endings |
| `+trace` | Start at the root and follow each step down to the answer, like a resolver does |
| `/etc/resolv.conf` | The file that says which resolver a Linux computer asks. Each lab computer can have its own |

## What you build

```
  laptop ---- r1 (campus resolver, 192.0.2.1) ---- r2 ---- dns (public resolver, 203.0.113.53)
    |              asks the public resolver, but
    |              has its own wrong answer for one name (fault 2)
    |
    +-- dig @192.0.2.1 NAME      and      dig @203.0.113.53 NAME      Same question, two resolvers
```

The broken name is the one in complaint B, from `faults.sh`. Below it is called NAME.

## Steps

Run these **in the lab**:

```
cd /work/challenges/challenge-9-toolbox/part-4-dig
ip netns exec laptop dig @192.0.2.1 NAME
```

| # | Type this | What it does | Script line |
|---|---|---|---|
| 1 | `ip netns exec laptop dig @192.0.2.1 NAME` | Asks the campus resolver. Read the ANSWER SECTION and the `SERVER:` line | none |
| 2 | `ip netns exec laptop dig @203.0.113.53 NAME` | Asks the public resolver the same question | none |
| 3 | (compare) | Two answers for one name. Which address is the server, `203.0.113.80`? | none |
| 4 | `ip netns exec laptop dig +short www.lab.test` | No `@`: the laptop's own resolver, from `/etc/netns/laptop/resolv.conf` | [build.sh#L119](../part-0-the-broken-network/build.sh#L119) |
| 5 | `dig +trace @1.1.1.1 example.com` | **In the lab itself, not in the laptop.** Follows a real name from the root. The lab needs `@1.1.1.1` to find the root servers | none |
| 6 | `echo "nameserver 203.0.113.53" > /etc/netns/laptop/resolv.conf` | The fix you can make as a user: ask the resolver that gives the right answer. Write it in `faults.md` | none |
| 7 | `ip netns exec laptop dig +short NAME` and `ip netns exec laptop curl -sS -m 5 http://NAME/` | The right address now, and the page loads | none |
| 8 | Fill in `results.md` and **Fault 2** in `faults.md` | The output line is the wrong answer line from step 1 | none |
| 9 | `bash test.sh` | Checks both answers, the trace, your Fault 2 entry, and that the laptop gets the right address | [test.sh#L28](test.sh#L28) |
| 10 | (read the script) | How fault 2 was planted | [faults.sh#L90-L95](../part-0-the-broken-network/faults.sh#L90-L95) |

### Reading a dig answer

```
;; ANSWER SECTION:
docs.lab.test.		0	IN	A	203.0.113.153

;; Query time: 4 msec
;; SERVER: 192.0.2.1#53(192.0.2.1) (UDP)
```

| Part | Meaning |
|---|---|
| `docs.lab.test.` | The name. The dot at the end is the root |
| `0` | The TTL in seconds |
| `IN A 203.0.113.153` | Internet, an A record, the address |
| `SERVER: 192.0.2.1#53` | The campus resolver answered, on port 53 |

Your name and address will differ.

## On your own computer

| Computer | Command |
|---|---|
| macOS, Linux | `dig example.com`, `dig @1.1.1.1 example.com`, `dig +trace example.com` |
| Windows | `Resolve-DnsName example.com` and `Resolve-DnsName example.com -Server 1.1.1.1` in PowerShell. `dig` is not built in, so use the lab for `+trace` |

## Hints

| Step 1: a nudge | Step 2: the name | Step 3: the shape |
|---|---|---|
| The web page works by address. Does the name give that address? | `dig` to each resolver, with `@` | `ip netns exec laptop dig @RESOLVER NAME`. Then compare the two A records |

The real fix is in the campus resolver, and only its owner can make it. In real life you tell them, and use another resolver until then.

## Where each number comes from

| Number | Where it comes from |
|---|---|
| `192.0.2.1` | The campus resolver in r1. The laptop's `/etc/resolv.conf` points to it |
| `203.0.113.53` | The public resolver |
| `1.1.1.1` | A real public resolver on the internet. The lab asks it for the list of root servers |
| The broken name and its wrong address | Your seed |

## Results

Fill in [results.md](results.md) and Fault 2 in [faults.md](../part-0-the-broken-network/faults.md). Commit both.

## Draft status (remove before publishing)

Tested in the lab image (2026-10-27): two dnsmasq resolvers giving two answers; `dig @`, `+short`; the laptop's own `resolv.conf`; `dig +trace @1.1.1.1 example.com` from the lab (it needs the internet; without `@1.1.1.1` it fails in the lab).
Untested: `Resolve-DnsName` on Windows; a network that blocks DNS to 1.1.1.1 (the test accepts the word `blocked` with the error).
