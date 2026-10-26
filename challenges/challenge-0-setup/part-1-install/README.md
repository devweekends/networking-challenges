# Challenge 0, part 1: install the lab

Goal: start the lab and pass the setup checker. After this, every other challenge can run.

## 101: words you need

| Word | Plain meaning |
|---|---|
| Docker | A program that runs other programs in small sealed boxes |
| Image | The recipe and files for one box. Ours is called `networking-lab` |
| Container | A box that is running. When you type `exit`, it is deleted |
| The lab | Our container. A Linux machine inside your laptop, with the networking tools installed |
| Privileged | A setting that lets the container make virtual networks. Without it, the lab cannot work |
| Mounted folder | Your repository folder, shown inside the lab as `/work`. Edit it on either side |
| Line ending | The hidden character at the end of each line. Windows and Linux use different ones |
| Checker | A script that tests your setup and prints `PASS` or `FAIL` |

## What you build

A working lab. Nothing else. You know it works when the checker prints `PASS` on every line and `RESULT: all checks passed`.

## Start the download first

Docker Desktop is a big download. Start it now, and read this page while it runs. Read Docker's page on what your computer needs: https://docs.docker.com/desktop/. Whether Windows Home works: check Docker's page. This course does not promise it.

## Steps

| # | Where | Type this | What happens | Script line |
|---|---|---|---|---|
| 1 | On your computer | Install Docker Desktop. Start it. Wait until it says it is running | Docker is ready | none |
| 2 | On your computer | Open a terminal in this repository folder | You are in the right place | none |
| 3 | On your computer | `bash lab/start.sh` (PowerShell: `.\lab\start.ps1`) | The first time, the image is built. Then the lab starts and your prompt starts with `(lab)` | [start.sh#L34](../../../lab/start.sh#L34) builds, [start.sh#L41](../../../lab/start.sh#L41) mounts your folder at `/work` |
| 4 | In the lab | `bash toolkit/check-setup.sh` | One line per check | [check-setup.sh#L32](../../../toolkit/check-setup.sh#L32) is the first check |
| 5 | In the lab | `bash toolkit/check-setup.sh --versions` | The same checks, then the version of each tool | [check-setup.sh#L83](../../../toolkit/check-setup.sh#L83) |
| 6 | In the lab | `bash challenges/challenge-0-setup/part-1-install/test.sh` | The test runs the checker. Every line must be `PASS` | [test.sh#L9](test.sh#L9) |
| 7 | On your computer | Copy the output of steps 4 and 5 into `results.md`. Then commit it | Your proof | none |
| 8 | In the lab | `exit` | You leave the lab | none |

To commit, **on your computer**:

```
git add challenges/challenge-0-setup/part-1-install/results.md
git commit -m "Challenge 0 part 1: setup checker passes"
```

### See a failure on purpose (optional)

A checker that never fails proves nothing. Start the lab without `--privileged` and watch it fail:

1. **In the lab:** `exit`
2. **On your computer:** `bash lab/start.sh --no-privilege` (PowerShell: `.\lab\start.ps1 -NoPrivilege`)
3. **In the lab:** `bash toolkit/check-setup.sh`

You should see `FAIL no-privilege` with its fix, and the exit code is not 0 (`echo $?` prints 1). Then `exit` and start the lab the normal way.

## The five named failures

The checker names each problem. The first `FAIL` line is the one to fix.

| Name | What it means | Fix | Checker line |
|---|---|---|---|
| `not-in-lab` | You ran the checker on your computer, not in the lab | Run `bash lab/start.sh`, then run the checker in the lab | [L32](../../../toolkit/check-setup.sh#L32) |
| `no-privilege` | The lab cannot make a namespace or a cable. It was started without `--privileged` | Type `exit`, then start with `bash lab/start.sh` | [L55](../../../toolkit/check-setup.sh#L55) |
| `wrong-image` | A tool is missing. The image is old or wrong | On your computer: `docker rmi networking-lab`, then `bash lab/start.sh` | [L46](../../../toolkit/check-setup.sh#L46) |
| `crlf-line-endings` | A script has Windows line endings | Run the `sed` command the checker prints, then run the checker again | [L71](../../../toolkit/check-setup.sh#L71) |
| `repo-not-visible` | Your repository folder is not at `/work`, so the lab sees an empty folder | Type `exit`. Start the lab again from inside your repository folder | [L39](../../../toolkit/check-setup.sh#L39) |

If the checker itself will not run and you see `invalid option name` or `command not found` with strange characters, the checker has Windows line endings. In the lab, run this once, then try again:

```
find /work -name '*.sh' -exec sed -i 's/\r$//' {} +
```

If Docker is not running, `bash lab/start.sh` says so. Start Docker Desktop and run it again. Also useful when you are stuck: `docker version` and `docker info` on your computer (not tested in this course yet).

## Where each number comes from

| Number or name | Where it comes from |
|---|---|
| `ubuntu:24.04` and the long `sha256:...` code | The base image. The code pins one exact build, so everyone gets the same tools. See [Dockerfile#L1](../../../lab/Dockerfile#L1) |
| The tool list | [Dockerfile#L8](../../../lab/Dockerfile#L8) |
| `/work` | The place where Docker shows your folder. See [start.sh#L41](../../../lab/start.sh#L41) |
| 13 tools checked | The list in [check-setup.sh#L9](../../../toolkit/check-setup.sh#L9) |

## Safety note

`--privileged` gives the container all Linux powers and access to devices on Docker's virtual machine. Use it only for this lab image. Do not use it for images you do not know.

## Results

Fill in [results.md](results.md).

## Draft status (remove before publishing)

Untested: the Windows bind-mount flow end to end, `winpty` in Git Bash, the exact output of `--versions`, the exact error text when `--privileged` is missing, `docker version` and `docker info` as stuck diagnostics, Docker Desktop on macOS.
