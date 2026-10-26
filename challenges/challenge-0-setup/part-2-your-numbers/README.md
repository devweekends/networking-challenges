# Challenge 0, part 2: your own numbers

Goal: find five numbers on your own computer, paste them into a file, and let a script check them. The script also tells you your mask as a short prefix like `/24`.

## 101: words you need

| Word | Plain meaning |
|---|---|
| Address | The number of your computer on the network. Four numbers with dots, like `192.168.1.23` |
| Mask | A second number that tells which addresses are on your own network. Like `255.255.255.0` |
| Prefix | The same idea written short. `255.255.255.0` is `/24` |
| Gateway | The router. Your computer sends everything for outside to it |
| DNS server | The computer that turns a name like `example.com` into an address |
| Public address | The address a website sees when you visit it. It can differ from your own address |
| Hex | A way to write numbers with 0 to 9 and a to f. `0x` at the start means hex. `ff` is 255 |
| Documentation range | Addresses made for examples, like `203.0.113.45`. No real computer uses them |

## What you build

A file called `my-numbers.txt` with five lines. A checker reads it and prints the prefix.

## Seven commands

You only need seven commands for the whole course. In the lab you are already root, so you do not need `sudo`. (On your own Linux or WSL 2, scripts run with `sudo`.)

| Command | What it does |
|---|---|
| `cd folder` | Go into a folder |
| `ls` | List what is in the folder |
| `cat file` | Show what is in a file |
| `nano file` | Edit a file. Save with Ctrl+O then Enter. Leave with Ctrl+X |
| `Ctrl+C` | Stop a command that is still running |
| `exit` | Leave the lab |
| `sudo` | Run a command as root. Not needed in the lab |

## Where each number comes from

Copy these from **your computer**, not from the lab. The lab has its own numbers, and they are not yours.

| Line | What to copy | Windows | macOS | Linux |
|---|---|---|---|---|
| `address` | Your IPv4 address | `ipconfig`, the line `IPv4 Address` | `ifconfig`, the line `inet` | `ip addr`, the line `inet` |
| `mask` | Your mask. Dotted or hex are both fine | `ipconfig`, `Subnet Mask` | `ifconfig`, `netmask` (it prints hex like `0xffffff00`) | `ip addr` shows a prefix like `/24`. Write the dotted mask instead, for example `255.255.255.0` |
| `gateway` | Your router | `ipconfig`, `Default Gateway` | `netstat -rn`, the `default` line | `ip route`, the `default via` line |
| `dns` | The IPv4 DNS server | `ipconfig /all`, `DNS Servers` (take the IPv4 one) | `scutil --dns` | `resolvectl status` |
| `public` | The IPv4 address a website sees | `curl.exe -4 ifconfig.me` | `curl -4 ifconfig.me` | `curl -4 ifconfig.me` |

Notes:

- On Windows PowerShell, type `curl.exe`, not `curl`. Plain `curl` in PowerShell is a different command.
- `ifconfig.me` is a website run by someone else. Using it is optional.
- On a phone, look at the Wi-Fi details screen. The numbers have the same names.
- Your public address is personal. If your repository is public, write `203.0.113.45` on the `public` line. The checker accepts it.
- If the public address starts with `100.` or is a private address, the checker prints a note. That is fine. It is a clue about your provider. Say so in `results.md`.
- The macOS commands are not yet checked on a Mac.

The checker works out the prefix itself. It counts the `1` bits in the mask. `255` is eight ones. So `255.255.255.0` has 8 + 8 + 8 = 24 ones, and prints `/24`. As hex, `0xffffff00` is `255.255.255.0`. And `0xfffff000` is `255.255.240.0`, which prints `/20`.

## Steps

| # | Where | Type this | What happens | Script line |
|---|---|---|---|---|
| 1 | On your computer | Run the commands in the table above. Write the five numbers somewhere | You have your numbers | none |
| 2 | In the lab | `cd challenges/challenge-0-setup/part-2-your-numbers` | You are in this folder | none |
| 3 | In the lab | `ls` | You see `check-numbers.sh`, `my-numbers.txt`, `README.md`, `results.md`, `test.sh` | none |
| 4 | In the lab | `nano my-numbers.txt` | Paste your numbers after each label. Save and leave | none |
| 5 | In the lab | `cat my-numbers.txt` | You see what the checker will read | [check-numbers.sh#L64](check-numbers.sh#L64) reads the five lines |
| 6 | In the lab | `bash check-numbers.sh` | Each line is checked. Then it prints your mask and prefix | [check-numbers.sh#L70](check-numbers.sh#L70) checks the addresses, [L76](check-numbers.sh#L76) reads the mask, [L94](check-numbers.sh#L94) counts the ones |
| 7 | In the lab | `ping 127.0.0.1` and press Ctrl+C after a few lines | You practise stopping a command. `127.0.0.1` is your own machine | none |
| 8 | In the lab | `bash test.sh` | Checks that the checker works, then checks your file | [test.sh#L24](test.sh#L24) is the first check |
| 9 | On your computer | Put your prefix line into `results.md`. Commit | Your proof | none |
| 10 | In the lab | `exit` | You leave the lab | none |

If your editor on your computer saves the file with Windows line endings, that is fine for this file. The checker ignores them.

## If the checker says FAIL

| It says | What to do |
|---|---|
| `mask needs four numbers` | You wrote fewer or more than four numbers. Write all four, like `255.255.255.0` |
| `address is empty` | The line has no number after the label. Paste it |
| `... is not a mask` | A mask is ones, then zeros. `255.0.255.0` is not one |
| `each number ... must be from 0 to 255` | One number is too big. Check that you copied it right |

When you are stuck, run `cat my-numbers.txt`. It shows what the checker read. Copy the numbers from your computer, not from the lab.

## Results

Fill in [results.md](results.md).
