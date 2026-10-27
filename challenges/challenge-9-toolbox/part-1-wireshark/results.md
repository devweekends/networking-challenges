# Results: challenge 9, part 1

Fill this in after you opened `capture.pcap` in Wireshark. Replace each part in angle brackets. Commit this file and `capture.pcap`.

## Three values from my capture

Read each value in Wireshark. Write the display filter you typed in the bar at the top.

| Question | Display filter I used | My answer |
|---|---|---|
| Source port of the laptop's first web connection | <filter> | <number> |
| TTL of the server's packets, as they reach the laptop | <filter> | <number> |
| Packets to 203.0.113.80 (how many) | <filter> | <number> |

## Follow the TCP stream

Right-click one web packet, then **Follow** and **TCP Stream**. Paste the first two lines the laptop sent:

```
<paste here>
```

## Display filter or capture filter?

| Question | My answer |
|---|---|
| Which kind did you type in Wireshark's bar? | <answer> |
| Which kind does `tcpdump` take at the end of its command? | <answer> |
| The server's packets left it with one TTL and reached the laptop with a smaller one. Why? | <answer> |
