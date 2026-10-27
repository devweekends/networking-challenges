# Faults

Seed: <the seed from fault-seed.txt>

Delete the lines in angle brackets when you fill this in. Every command here must be one you really ran, and every output line must be copied from your own screen.

Keep each output line on one line, inside backticks, as in the lines below. The tests read the text between the backticks.

## Best guesses

Write these right after `bash faults.sh`, before part 1. Use only `ping` and `traceroute`. A wrong guess is fine. You will compare it with what the tools show.

### Complaint A: copying a file to the server is slow

- Best guess: <one sentence>

### Complaint B: one name does not load, www.lab.test works

- Best guess: <one sentence>

### Complaint C: the app on its port does not answer

- Best guess: <one sentence>

## Round 1

Fill in one fault in each of parts 3 to 6.

### Fault 1

- Tool: <the tool>
- Command: `<the command you ran>`
- Output line: `<the one line that proves it>`
- Fix: `<the command that cleared it>`

### Fault 2

- Tool: <the tool>
- Command: `<the command you ran>`
- Output line: `<the one line that proves it>`
- Fix: `<the command that cleared it>`

### Fault 3

- Tool: <the tool>
- Command: `<the command you ran>`
- Output line: `<the one line that proves it>`
- Fix: `<the command that cleared it>`

### Fault 4

- Tool: <the tool>
- Command: `<the command you ran>`
- Output line: `<the one line that proves it>`
- Fix: `<the command that cleared it>`

## Round 2 (the blind round)

Run `bash faults.sh --round 2` only after parts 3 to 6 pass. Two of the four kinds of fault are planted, with new numbers. You do not know which two.

### Finding A

- What it is: <loss, a wrong DNS answer, a filtered port, or a speed limit>
- Tool: <the tool>
- Command: `<the command you ran>`
- Output line: `<the one line that proves it>`

### Finding B

- What it is: <loss, a wrong DNS answer, a filtered port, or a speed limit>
- Tool: <the tool>
- Command: `<the command you ran>`
- Output line: `<the one line that proves it>`
