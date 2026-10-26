#!/usr/bin/env bash
# The setup checker. Run it IN THE LAB:  bash toolkit/check-setup.sh
# One line per check: "PASS name" or "FAIL name: how to fix it".
# Exit code 0 means every check passed. Safe to run again and again.
#   bash toolkit/check-setup.sh --versions    also print the version of each tool
set -euo pipefail

WORK=/work
TOOLS=(ip nft tcpdump dnsmasq dig traceroute ping nc curl conntrack busybox nano dhclient)
TEST_NS=check-setup-ns
TEST_LINK=chk-setup-a
FAILS=0

pass() { printf 'PASS %s\n' "$1"; }
fail() { printf 'FAIL %s: %s\n' "$1" "$2"; FAILS=$((FAILS + 1)); }

cleanup() {
  ip netns del "$TEST_NS" 2>/dev/null || true
  ip link del "$TEST_LINK" 2>/dev/null || true
}
trap cleanup EXIT

finish() {
  if [ "$FAILS" -eq 0 ]; then
    echo "RESULT: all checks passed"
    exit 0
  fi
  echo "RESULT: $FAILS check(s) failed. Read the first FAIL line. Its name tells you which check."
  exit 1
}

# Check 1, not-in-lab: are we inside the lab container? The image has a marker file.
if [ ! -f /etc/networking-lab-image ]; then
  fail not-in-lab "this is not the lab. On your computer run: bash lab/start.sh (Windows PowerShell: .\\lab\\start.ps1). Then run this checker again inside the lab. If you did that, rebuild the image: docker build -t networking-lab lab/"
  finish
fi
pass in-lab

# Check 2, repo-not-visible: is the repository folder mounted at /work?
if [ -f "$WORK/toolkit/check-setup.sh" ] && [ -d "$WORK/challenges" ]; then
  pass repo-visible
else
  fail repo-not-visible "your repository folder is not at /work. Type exit, then start the lab again from inside your repository folder: bash lab/start.sh"
fi

# Check 3, wrong-image: is every tool there?
for tool in "${TOOLS[@]}"; do
  if command -v "$tool" >/dev/null 2>&1; then
    pass "tool-$tool"
  else
    fail wrong-image "the tool $tool is missing, so this is an old or wrong image. On your computer run: docker rmi networking-lab, then bash lab/start.sh"
  fi
done

# Check 4, no-privilege: can we make a namespace and a virtual cable? Needs docker run --privileged.
if command -v ip >/dev/null 2>&1; then
  cleanup
  if ip netns add "$TEST_NS" 2>/dev/null; then
    pass namespace-create
    if ip link add "$TEST_LINK" type veth peer name chk-setup-b 2>/dev/null; then
      pass veth-create
    else
      fail no-privilege "a virtual cable could not be made. The lab needs --privileged. Type exit, then start it with: bash lab/start.sh"
    fi
  else
    fail no-privilege "a namespace could not be made. The lab needs --privileged. Type exit, then start it with: bash lab/start.sh"
  fi
  cleanup
fi

# Check 5, crlf-line-endings: do any scripts or your numbers file have Windows line endings?
if [ -d "$WORK" ]; then
  CR="$(printf '\r')"
  BAD="$(grep -rlI --include='*.sh' --include='my-numbers.txt' --exclude-dir=.git -e "$CR" "$WORK" 2>/dev/null || true)"
  if [ -n "$BAD" ]; then
    FIRST="$(printf '%s\n' "$BAD" | head -n 1)"
    fail crlf-line-endings "Windows line endings found, for example in $FIRST. Fix: find $WORK -name '*.sh' -exec sed -i 's/\\r\$//' {} + then run this checker again"
  else
    pass line-endings
  fi
fi

if [ "${1:-}" = "--versions" ]; then
  echo "--- tool versions"
  for cmd in "ip -V" "nft --version" "tcpdump --version" "dnsmasq --version" "dig -v" \
             "traceroute --version" "ping -V" "curl --version" "conntrack --version" \
             "nano --version"; do
    # Each tool prints its version in its own way, so we show only the first line.
    printf '%s: ' "${cmd%% *}"
    ($cmd 2>&1 || true) | head -n 1 || true
  done
  grep PRETTY_NAME /etc/os-release || true
fi

finish
