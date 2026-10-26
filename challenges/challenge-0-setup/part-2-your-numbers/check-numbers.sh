#!/usr/bin/env bash
# Challenge 0, part 2: check the numbers you pasted into my-numbers.txt.
# Run it in the lab:  bash check-numbers.sh
# It reads my-numbers.txt, checks each number, and prints your mask as a prefix.
# You can give another file:  bash check-numbers.sh other-file.txt
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="${1:-$HERE/my-numbers.txt}"
ERRORS=0

bad() {
  printf 'FAIL %s: %s\n' "$1" "$2"
  ERRORS=$((ERRORS + 1))
}

# get_value LABEL: print what comes after "LABEL:" or "LABEL=". Windows line endings are ignored.
get_value() {
  tr -d '\r' < "$FILE" \
    | sed -n "/^[[:space:]]*$1[[:space:]]*[:=]/I{s/^[^:=]*[:=][[:space:]]*//;s/[[:space:]]*\$//;p;q}" \
    || true
}

is_ipv4() {
  local value="$1" IFS=. octet
  [[ "$value" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || return 1
  for octet in $value; do
    (( 10#$octet <= 255 )) || return 1
  done
}

# Say what is wrong with a value that is not four numbers. LABEL VALUE EXAMPLE
explain_ipv4() {
  local label="$1" value="$2" example="$3" count
  if [ -z "$value" ]; then
    bad "$label" "$label is empty. Paste the number from your computer, for example $example"
  elif [[ "$value" =~ ^[0-9.]+$ ]]; then
    count="$(printf '%s' "$value" | tr '.' '\n' | grep -c . || true)"
    if [ "$count" -ne 4 ]; then
      bad "$label" "$label needs four numbers, like $example. You wrote $count."
    else
      bad "$label" "each number in $label must be from 0 to 255. You wrote $value"
    fi
  else
    bad "$label" "$label must be four numbers with dots, like $example. You wrote $value"
  fi
}

ipv4_to_int() {
  local a b c d
  IFS=. read -r a b c d <<< "$1"
  echo $(( (10#$a << 24) | (10#$b << 16) | (10#$c << 8) | 10#$d ))
}

int_to_ipv4() {
  printf '%d.%d.%d.%d' $(( ($1 >> 24) & 255 )) $(( ($1 >> 16) & 255 )) $(( ($1 >> 8) & 255 )) $(( $1 & 255 ))
}

if [ ! -f "$FILE" ]; then
  echo "FAIL file: $FILE was not found. Run this from the part-2-your-numbers folder."
  exit 1
fi

ADDRESS="$(get_value address)"
MASK="$(get_value mask)"
GATEWAY="$(get_value gateway)"
DNS="$(get_value dns)"
PUBLIC="$(get_value public)"

is_ipv4 "$ADDRESS" || explain_ipv4 address "$ADDRESS" 192.168.1.23
is_ipv4 "$GATEWAY" || explain_ipv4 gateway "$GATEWAY" 192.168.1.1
is_ipv4 "$DNS"     || explain_ipv4 dns "$DNS" 192.168.1.1
is_ipv4 "$PUBLIC"  || explain_ipv4 public "$PUBLIC" 203.0.113.45

# The mask can be dotted (255.255.255.0) or hex like macOS prints it (0xffffff00).
MASK_INT=""
if [[ "$MASK" =~ ^0[xX]([0-9a-fA-F]{8})$ ]]; then
  MASK_INT=$(( 16#${BASH_REMATCH[1]} ))
elif is_ipv4 "$MASK"; then
  MASK_INT="$(ipv4_to_int "$MASK")"
elif [[ "$MASK" =~ ^0[xX] ]]; then
  bad mask "a hex mask has eight digits after 0x, like 0xffffff00. You wrote $MASK"
else
  explain_ipv4 mask "$MASK" 255.255.255.0
fi

PREFIX=""
if [ -n "$MASK_INT" ]; then
  INVERSE=$(( ~MASK_INT & 0xFFFFFFFF ))
  if (( (INVERSE & (INVERSE + 1)) != 0 )) || [ "$MASK_INT" -eq 0 ]; then
    bad mask "$MASK is not a mask. A mask is ones, then zeros, like 255.255.255.0"
  else
    PREFIX=0
    for (( bit = 31; bit >= 0; bit-- )); do
      if (( (MASK_INT >> bit) & 1 )); then
        PREFIX=$((PREFIX + 1))
      else
        break
      fi
    done
  fi
fi

if [ "$ERRORS" -ne 0 ]; then
  echo "RESULT: $ERRORS problem(s). Run cat my-numbers.txt to see what the checker read."
  exit 1
fi

printf 'address   %s\n' "$ADDRESS"
DOTTED="$(int_to_ipv4 "$MASK_INT")"
if [ "$MASK" = "$DOTTED" ]; then
  printf 'mask      %s = /%s\n' "$DOTTED" "$PREFIX"
else
  printf 'mask      %s = %s = /%s\n' "$MASK" "$DOTTED" "$PREFIX"
fi
printf 'prefix    %s/%s\n' "$ADDRESS" "$PREFIX"
printf 'gateway   %s\n' "$GATEWAY"
printf 'dns       %s\n' "$DNS"
printf 'public    %s\n' "$PUBLIC"

# These are notes. They do not fail the check.
if (( ( $(ipv4_to_int "$GATEWAY") & MASK_INT ) != ( $(ipv4_to_int "$ADDRESS") & MASK_INT ) )); then
  echo "NOTE gateway: the gateway is not on your network. Check that you copied the right line."
fi
case "$PUBLIC" in
  10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*|100.6[4-9].*|100.[7-9][0-9].*|100.1[01][0-9].*|100.12[0-7].*)
    echo "NOTE public: this address is private or shared. A website normally sees a different one. Write it anyway and say so in results.md."
    ;;
esac

echo "PASS my-numbers.txt looks right"
