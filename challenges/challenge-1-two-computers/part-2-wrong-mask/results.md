# Results: challenge 1, part 2

Fill this in after `bash test.sh` passes and `capture.txt` is saved. Delete the lines in angle brackets.

## Prediction

Before I ran anything, I guessed this computer thinks the other is NOT on its network: <laptop or phone>.
I was <right or wrong>, because: <one sentence>

## The two masks

Output of `ip netns exec laptop ip addr` and `ip netns exec phone ip addr` (the `inet` lines):

```
<paste here>
```

## Laptop to phone (laptop is /24, phone is /28)

Output of `ip netns exec laptop ping -c2 -W1 192.168.1.20`:

```
<paste here>
```

## Phone to laptop

Output of `ip netns exec phone ping -c2 -W1 192.168.1.10`:

```
<paste here>
```

## Why the two failures look different

<Write two or three short sentences. One failure is silent loss. The other stops at once with an error. Which computer has no route, and why?>

## The capture

What the phone's side of the cable showed when the laptop pinged `192.168.1.20`:

```
<paste the ARP and ICMP lines for .20>
```

Did the phone send an ARP reply? <yes or no, and which line shows it>

## An address nobody owns

The ARP lines for `192.168.1.99`:

```
<paste the ARP request lines for .99>
```

Did anyone answer? <yes or no>

## After the fix (both /24)

Output of the ping each way:

```
<paste both here>
```
