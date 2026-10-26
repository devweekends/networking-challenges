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

More challenges are added as the course goes on.

Each part is a folder with the same files:

| File | What it is |
|---|---|
| `README.md` | Words to know, what you build, the steps, and where each number comes from |
| One script | The commands, with comments. You can run it, or type its lines one by one |
| `results.md` | Your own output. You fill this in and commit it |
| `test.sh` | Run it in the lab. It says `PASS` or `FAIL` for each check |

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

## What is in each folder

| Folder | Contents |
|---|---|
| `lab/` | The lab image recipe (`Dockerfile`) and the start scripts |
| `toolkit/` | Shared helpers (`lib.sh`) and the setup checker (`check-setup.sh`) |
| `challenges/` | One folder per challenge, one subfolder per part |

## Line endings

Windows saves a new line as two characters. Linux wants one. A script with the Windows kind stops with strange errors. This repository has a `.gitattributes` and an `.editorconfig` that keep scripts in the Linux kind. If a script still has the Windows kind, the checker tells you the command that fixes it.
