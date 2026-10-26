#!/usr/bin/env bash
# Test for challenge 6, part 4. Run it in the lab:  bash test.sh
# It runs the test sets of parts 1, 2 and 3 on the network that exists now, one after the other.
# Right after break.sh, at least one of them fails for each fault. After you fix every fault, all three pass.
# It prints every FAIL line from the three tests, so you can see which symptom belongs to which test.
# It does not rebuild anything and changes nothing, except that the part 3 test briefly stops dnsmasq
# and starts it again.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"
require_root

for part in part-1-addresses-and-routes part-2-nat-forwarding-isolation part-3-dhcp-and-dns; do
  TEST="$HERE/../$part/test.sh"
  if [ ! -f "$TEST" ]; then
    t_fail "$part: the test file is missing ($TEST)"
    continue
  fi
  RC=0
  OUT="$(bash "$TEST" 2>&1)" || RC=$?
  grep '^FAIL' <<< "$OUT" || true
  if [ "$RC" -eq 0 ]; then
    t_pass "$part: all checks passed"
  else
    t_fail "$part: some checks failed (the FAIL lines are above)"
  fi
done

# The write-up is read by a mentor. These are reminders, not failures.
if [ -s "$HERE/fault-seed.txt" ]; then
  echo "NOTE the seed in fault-seed.txt is: $(cat "$HERE/fault-seed.txt"). Put the same seed in fault-writeup.md."
else
  echo "NOTE fault-seed.txt is missing. Run break.sh with a seed first, so a mentor can repeat your run."
fi
if grep -q '<' "$HERE/fault-writeup.md" 2>/dev/null; then
  echo "NOTE fault-writeup.md still has lines in angle brackets. Fill them in before you hand it in."
fi

t_done
