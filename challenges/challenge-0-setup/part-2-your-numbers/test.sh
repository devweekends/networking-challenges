#!/usr/bin/env bash
# Test for challenge 0, part 2. Run it in the lab:  bash test.sh
# First it proves the checker itself works on made-up numbers. Then it checks YOUR my-numbers.txt.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../toolkit/lib.sh"

CHECK="$HERE/check-numbers.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# write_numbers ADDRESS MASK GATEWAY DNS PUBLIC: make a test file with the five lines
write_numbers() {
  printf 'address: %s\nmask: %s\ngateway: %s\ndns: %s\npublic: %s\n' "$@" > "$TMP/numbers.txt"
}

# run_check FILE: sets OUT and RC without stopping the test when the checker fails
run_check() {
  RC=0
  OUT="$(bash "$CHECK" "$1" 2>&1)" || RC=$?
}

# Must pass: dotted mask.
write_numbers 192.168.1.23 255.255.255.0 192.168.1.1 192.168.1.1 203.0.113.45
run_check "$TMP/numbers.txt"
if [ "$RC" -eq 0 ] && grep -q '/24' <<< "$OUT"; then
  t_pass "255.255.255.0 prints /24"
else
  t_fail "255.255.255.0 should print /24 and exit 0. Output was: $OUT"
fi

# Must pass: macOS hex mask.
write_numbers 192.168.1.23 0xffffff00 192.168.1.1 192.168.1.1 203.0.113.45
run_check "$TMP/numbers.txt"
if [ "$RC" -eq 0 ] && grep -q '/24' <<< "$OUT"; then
  t_pass "0xffffff00 prints /24"
else
  t_fail "0xffffff00 should print /24 and exit 0. Output was: $OUT"
fi

# Must pass: another hex mask.
write_numbers 10.1.2.3 0xfffff000 10.1.0.1 10.1.0.1 203.0.113.45
run_check "$TMP/numbers.txt"
if [ "$RC" -eq 0 ] && grep -q '/20' <<< "$OUT"; then
  t_pass "0xfffff000 prints /20"
else
  t_fail "0xfffff000 should print /20 and exit 0. Output was: $OUT"
fi

# Must pass: a file saved with Windows line endings.
write_numbers 192.168.1.23 255.255.255.0 192.168.1.1 192.168.1.1 203.0.113.45
sed -i 's/$/\r/' "$TMP/numbers.txt"
run_check "$TMP/numbers.txt"
if [ "$RC" -eq 0 ]; then
  t_pass "a file with Windows line endings is read correctly"
else
  t_fail "a file with Windows line endings should still pass. Output was: $OUT"
fi

# Must fail: a mask with three numbers.
write_numbers 192.168.1.23 255.255.255 192.168.1.1 192.168.1.1 203.0.113.45
run_check "$TMP/numbers.txt"
if [ "$RC" -ne 0 ] && grep -q 'mask needs four numbers' <<< "$OUT"; then
  t_pass "a mask with three numbers is refused: mask needs four numbers"
else
  t_fail "a mask with three numbers should print 'mask needs four numbers' and exit non-zero. Output was: $OUT"
fi

# Must fail: a mask that is not ones then zeros.
write_numbers 192.168.1.23 255.0.255.0 192.168.1.1 192.168.1.1 203.0.113.45
run_check "$TMP/numbers.txt"
if [ "$RC" -ne 0 ] && grep -q 'is not a mask' <<< "$OUT"; then
  t_pass "255.0.255.0 is refused: not a mask"
else
  t_fail "255.0.255.0 should be refused. Output was: $OUT"
fi

# Must fail: an address with three numbers.
write_numbers 192.168.1 255.255.255.0 192.168.1.1 192.168.1.1 203.0.113.45
run_check "$TMP/numbers.txt"
if [ "$RC" -ne 0 ] && grep -q 'address needs four numbers' <<< "$OUT"; then
  t_pass "an address with three numbers is refused"
else
  t_fail "an address with three numbers should print 'address needs four numbers'. Output was: $OUT"
fi

# Your own numbers. The shipped template is empty, so this fails until you fill it in.
run_check "$HERE/my-numbers.txt"
if [ "$RC" -eq 0 ]; then
  t_pass "your my-numbers.txt is correct"
else
  t_fail "your my-numbers.txt has a problem. Checker said: $OUT"
fi

t_done
