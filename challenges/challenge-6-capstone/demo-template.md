# Demo template: five minutes

Record your screen with your voice. Any recorder is fine. Label every command **On your computer** or **In the lab**, out loud or on screen. The lab cannot show the real path to the internet, so never run a real-internet command in the lab and call it part of the demo.

Do not read this page out loud. Show your own network and say what you see.

| Time | Show | Say |
|---|---|---|
| 0:00 to 0:40 | The address plan table and `ip addr` for the home router | Each subnet, why that size, and where the pool sits |
| 0:40 to 1:30 | A device getting its lease (`udhcpc` output, the `lease applied` line) | What the lease contained, and where the name comes from |
| 1:30 to 3:30 | One `curl` from `home1` to `203.0.113.80:8080`, with a capture on both sides of the router and the `conntrack -L` line | The source address inside, the source address outside, whether the port changed, and why |
| 3:30 to 4:40 | One injected fault: the seed, the symptom, the command that found it, the fix | Which layer it was, and why you looked there first |
| 4:40 to 5:00 | Your answer to the course question | Why home devices reach the internet without public addresses |

## Be ready for three questions

A mentor will pick three of these. You answer in writing, a voice note or a short video.

1. Why does the server see only one address?
2. When does the source port change?
3. What breaks if the guest subnet is a `/30`?
4. Why can the server reach your forwarded port but not your laptop's other ports?
5. Which test would catch a missing default route on your router?
