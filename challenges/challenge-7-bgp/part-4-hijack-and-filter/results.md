# Results: challenge 7, part 4

Fill this in after `bash test.sh` passes. Delete the lines in angle brackets. Commit the three `.txt` files and the three `.conf` files the script wrote.

## Prediction

Before I filled the gaps, I guessed that during the hijack <r1 or r2> would answer for `198.51.100.130`, and <r1 or r2> for `198.51.100.1`.
I was <right or wrong>, because: <one sentence>

## Before the hijack

The two visits in `before-hijack.txt`:

```
<paste the two "r3 visits" parts here>
```

## During the hijack

Contents of `hijack.txt`:

```
<paste here>
```

| Question | My answer |
|---|---|
| Which two routes in r3 cover `198.51.100.130`? | <answer> |
| Which one did Linux use, and why? | <answer> |
| What is the origin AS of the `/25`? Is it the owner? | <answer> |
| Why did `198.51.100.1` still reach r1? | <answer> |

## The filter

My Gap 2 and Gap 3 lines:

```
<paste them here>
```

Contents of `after-filter.txt`:

```
<paste here>
```

| Question | My answer |
|---|---|
| Where is the `/25` now? | <answer> |
| The `/24` through r2 has the path `64497 64496`. Why did the filter keep it? | <answer> |
| The test let r2 announce the whole `/24`. Which part of your filter stopped it? | <answer> |

## The real internet

Your filter is a list written by hand. RPKI does the same check with signed records. Name one kind of bad route it would catch, and one kind it would not. <two sentences>

## Three questions about BGP that I cannot answer yet

1. <question>
2. <question>
3. <question>
