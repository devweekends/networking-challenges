# Challenge 9, part 7: curl, where the time goes

Your app takes two seconds to load. Is it DNS, the connection, or your server? curl can tell you how long each step of one visit took.

Goal: read a whole visit with `curl -v`, then time its steps with `curl -w`, on a fast page and on a slow one.

## 101: words you need

| Word | Plain meaning |
|---|---|
| `curl -v` | Verbose: curl prints what it does. Lines with `*` are notes, `>` lines it sent, `<` lines it received |
| `curl -w TEXT` | After the visit, print TEXT. Words like `%{time_total}` in it are filled in with numbers |
| `-o /dev/null` | Throw the page away. You only want the times |
| `time_namelookup` | Seconds from the start until the name had an address (DNS) |
| `time_connect` | Seconds from the start until the TCP handshake was done |
| `time_starttransfer` | Seconds from the start until the first byte of the answer arrived. The server was working until then |
| `time_total` | Seconds from the start until the whole answer had arrived |
| Time to first byte | Another name for `time_starttransfer` |

All four times count from the same start. So each one is at least as large as the one before it.

## What you build

```
  laptop: curl http://www.lab.test/cgi-bin/slow
    |-- name lookup (campus resolver) --|-- TCP handshake --|------- server works 4 seconds -------|-- answer --|
    0                            time_namelookup      time_connect                        time_starttransfer  time_total
```

The lab web page has a slow page, `/cgi-bin/slow`, that waits 4 seconds before it answers ([toolkit/lib.sh, www_make](../../../toolkit/lib.sh)).

## Steps

Run these **in the lab**:

```
cd /work/challenges/challenge-9-toolbox/part-7-curl
ip netns exec laptop curl -v http://www.lab.test/
```

| # | Type this | What it does | Script line |
|---|---|---|---|
| 1 | `ip netns exec laptop curl -v http://www.lab.test/` | The whole visit: the address curl tried, the request, the answer's headers | none |
| 2 | the `-w` command below, for `http://www.lab.test/` | The four times of a fast page | none |
| 3 | the same, for `http://www.lab.test/cgi-bin/slow` | The four times of a slow page. Which time is large? | [build.sh#L74-L77](../part-0-the-broken-network/build.sh#L74-L77) |
| 4 | Fill in `results.md` | Paste the outputs and answer the questions | none |
| 5 | `bash test.sh` | Checks that the fields are there and make sense | [test.sh#L15](test.sh#L15) |

The `-w` command, on one line:

```
ip netns exec laptop curl -sS -o /dev/null -w 'time_namelookup=%{time_namelookup} time_connect=%{time_connect} time_starttransfer=%{time_starttransfer} time_total=%{time_total}\n' http://www.lab.test/
```

### Reading curl -v

| Line starts with | Meaning |
|---|---|
| `*` | A note from curl: which address it tries, when it is connected |
| `>` | What curl sent: the request line `GET / HTTP/1.1` and the headers |
| `<` | What curl received: the status line `HTTP/1.1 200 OK` and the headers |

## On your own computer

Try the same `-w` command on your computer, against your own deployed app or any public page. Then open the same page in your browser, open the developer tools, and look at the **Network** tab. Its timing view shows the same steps.

On Windows, type `curl.exe`, not `curl`, in PowerShell. In PowerShell, `curl` can be a different command.

## Hints

| Step 1: a nudge | Step 2: the name | Step 3: the shape |
|---|---|---|
| The test says a field is missing | Copy the `-w` text exactly. The quotes keep it as one argument | `curl -sS -o /dev/null -w '...' URL` |

## Where each number comes from

| Number | Where it comes from |
|---|---|
| About 4 seconds | The slow page runs `sleep 4` before it answers |
| Very small times on the fast page | Every cable in the lab is virtual and short |

## Results

Fill in [results.md](results.md). Commit it.

## Draft status (remove before publishing)

Tested in the lab image (2026-10-27): `curl -v` and `curl -w` with the four fields against the lab web page and the slow page.
Untested: `curl.exe` on Windows and the browser's Network tab.
