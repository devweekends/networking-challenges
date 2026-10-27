# Networking challenges

These are the hands-on challenges for the Networking course. You build small networks inside your own laptop, break them, and read what happens.

You do not need a second computer. You do not need a router. The lab is a Linux machine that runs inside Docker on your laptop. Everything you build lives inside it. When you type `exit`, it is gone, and your real network is untouched.

This repository is a template. Copy it to your own GitHub account first (the green **Use this template** button), then clone your copy.

## Two places to type commands

You will type commands in two places. Every command block in a README says which one.

| Label | Where | How you know |
|---|---|---|
| **On your computer** | Your normal terminal (Git Bash, PowerShell, Terminal) | Your usual prompt |
| **In the lab** | The Linux machine inside Docker | The prompt starts with `(lab)` |

Your real addresses, your router and the internet path are on **your computer**. The networks you build are **in the lab**.

## Start the lab

1. Install Docker Desktop and start it. Read Docker's own page for what your computer needs: https://docs.docker.com/desktop/
2. **On your computer**, open a terminal inside this repository folder.
3. Start the lab:

   | Your computer | Command |
   |---|---|
   | Windows with Git Bash, macOS, Linux | `bash lab/start.sh` |
   | Windows with PowerShell | `.\lab\start.ps1` |

4. The first time, it builds the lab image. After that it starts fast.
5. You should see a prompt that starts with `(lab)`. Your repository folder is there as `/work`.
6. Leave the lab with `exit`.

The lab uses `docker run --privileged`. That gives the lab container wide power over Docker's own virtual machine. We need it so you can make virtual networks. Use it only for this lab image.

## Challenges

| # | Folder | Parts | You will |
|---|---|---|---|
| 0 | `challenges/challenge-0-setup` | 1 install, 2 your numbers | Start the lab, pass the setup checker, and read your own network numbers |
| 1 | `challenges/challenge-1-two-computers` | 1 virtual cable, 2 wrong mask | Make two computers talk, capture it, then make them disagree |
| 2 | `challenges/challenge-2-router` | 1 two subnets and a router | Build a router between two networks, make a ping cross it, and see which addresses change |
| 3 | `challenges/challenge-3-conversation` | 1 listening and the handshake | Run a server on two listening addresses, capture the handshake, and read both sides with `ss` |
| 4 | `challenges/challenge-4-home-router` | 1 masquerade, 2 forwarding and a guest network | Put devices behind a router with NAT, read the NAT table, forward a port, and keep a guest away from home |
| 5 | `challenges/challenge-5-dhcp-dns` | 1 leases and names | Make the router hand out addresses and names with dnsmasq |
| 6 | `challenges/challenge-6-capstone` | 1 addresses and routes, 2 NAT, forwarding and isolation, 3 DHCP and DNS, 4 break and fix | Build a whole small internet from your own scripts, then find three faults that a script injects |

Part 2 of the course, "Beyond your home network":

| # | Folder | Parts | You will |
|---|---|---|---|
| 7 | `challenges/challenge-7-bgp` | 1 three networks, 2 read and withdraw, 3 backup link, 4 hijack and filter | Run three networks that talk BGP, watch a route appear and disappear, add a backup link with your own preference, then steal a block and stop it |
| 8 | `challenges/challenge-8-vpn` | 1 office and café, 2 the tunnel, 3 what each side sees, 4 full and split tunnel | Build a WireGuard VPN between two networks behind NAT and prove with captures what each network sees |
| 9 | `challenges/challenge-9-toolbox` | 0 the broken network, 1 Wireshark, 2 tcpdump, 3 mtr, 4 dig, 5 nmap, 6 iperf3, 7 curl | Find four hidden faults in a broken network, one tool at a time, and save the evidence |

More challenges are added as the course goes on.

How much help you get changes as the course goes on:

| Challenges | Help |
|---|---|
| 0 and 1 | **Guided.** Every command is typed by you, one at a time, and every line is explained |
| 2, 3, 4 and 5 | **Gapped.** The script is nearly complete. A few lines are missing and marked `TODO`. The test tells you which gap is wrong |
| 6 | **Open with hints.** You get the goal, the tests and a ladder of hints. You write the scripts, starting from your own earlier ones |
| 7, 8 and 9 | **Guided, then gapped.** The first part of each is guided; the later parts have `TODO` gaps. Challenge 9 asks you to choose the tool yourself in its last round |

Each part is a folder with the same files:

| File | What it is |
|---|---|
| `README.md` | Words to know, what you build, the steps, and where each number comes from |
| One script | The commands, with comments. You can run it, or type its lines one by one. In challenges 2 to 5, some lines are gaps for you to fill. In challenge 6 you write it |
| `results.md` | Your own output. You fill this in and commit it |
| `test.sh` | Run it in the lab. It says `PASS` or `FAIL` for each check. When a check fails, read its message: it names the gap or the thing to look at |

Run a test from the lab like this:

```
bash challenges/challenge-0-setup/part-1-install/test.sh
```

Scripts are safe to run again. Each one deletes what it built before it starts.

## If something is wrong

Run the setup checker **in the lab**:

```
bash toolkit/check-setup.sh
```

It prints one line per check. Read the first `FAIL` line. The word after `FAIL` is the name of the problem, and the rest of the line is the fix.

| Name | Meaning |
|---|---|
| `not-in-lab` | You are not inside the lab. Start it with `lab/start.sh` |
| `no-privilege` | The lab was started without `--privileged`. Start it with `lab/start.sh` |
| `wrong-image` | A tool is missing. Your lab image is old or wrong |
| `crlf-line-endings` | A script has Windows line endings. The checker prints the fix |
| `repo-not-visible` | Your repository folder is not at `/work`. Start the lab from inside the repository |

## If you are stuck on a part

Some parts build on the part before. If you are stuck, you can build the network from the end of an earlier part and keep going. Run this **in the lab**:

```
bash /work/toolkit/restore.sh --list
bash /work/toolkit/restore.sh 4.1
```

The first line lists the parts you can restore (2.1, 4.1, 4.2, 6.1, 6.2 and 6.3) and what each one builds. The second builds the network from the end of challenge 4, part 1. A restore changes only the lab network. It never changes your own files.

The restore builds in `toolkit/restore/` are the course's own answers. Read them after you have tried, not before. If you used one, say so in your capstone demo.

## What is in each folder

| Folder | Contents |
|---|---|
| `lab/` | The lab image recipe (`Dockerfile`) and the start scripts |
| `toolkit/` | Shared helpers (`lib.sh`), the DHCP lease script (`udhcpc-hook.sh`), the setup checker (`check-setup.sh`) and the restore script (`restore.sh`, which runs the builds in `toolkit/restore/`) |
| `challenges/` | One folder per challenge, one subfolder per part |

## Line endings

Windows saves a new line as two characters. Linux wants one. A script with the Windows kind stops with strange errors. This repository has a `.gitattributes` and an `.editorconfig` that keep scripts in the Linux kind. If a script still has the Windows kind, the checker tells you the command that fixes it.
