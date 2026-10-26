#!/usr/bin/env bash
# toolkit/lib.sh: small helpers shared by every challenge script.
# Source it. Do not run it. From a part folder:
#   source "$HERE/../../../toolkit/lib.sh"
#
# What is inside:
#   require_root       stop unless you are root (in the lab you always are)
#   ns_add NAME        make a fresh network namespace and write its name in a list
#   cable A B          join namespaces A and B with a virtual cable (a veth pair), both ends up
#   in_ns NAME CMD...  run CMD inside namespace NAME
#   teardown_all       delete every namespace made with ns_add, and any leftover veth- link
#   t_pass, t_fail, t_done   helpers for test.sh files

NET_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NET_STATE_FILE="${NET_STATE_FILE:-/tmp/networking-course-namespaces}"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

# Stop with a plain message if any script in the repository has Windows line endings.
guard_line_endings() {
  local bad cr
  cr="$(printf '\r')"
  bad="$(grep -rlI --include='*.sh' --exclude-dir=.git -e "$cr" "$NET_ROOT" 2>/dev/null || true)"
  if [ -n "$bad" ]; then
    printf 'STOP: these files have Windows line endings:\n' >&2
    printf '  %s\n' $bad >&2
    printf '%s\n' "Fix: find $NET_ROOT -name '*.sh' -exec sed -i 's/\\r\$//' {} +" >&2
    printf 'Then run your script again.\n' >&2
    exit 1
  fi
}

guard_line_endings

require_root() {
  [ "$(id -u)" -eq 0 ] || die "run this as root. In the lab you are root already. Are you inside the lab?"
}

ns_add() {
  local name="${1:?ns_add needs a name}"
  ip netns del "$name" 2>/dev/null || true
  ip netns add "$name"
  mkdir -p "$(dirname "$NET_STATE_FILE")"
  if ! grep -qx "$name" "$NET_STATE_FILE" 2>/dev/null; then
    echo "$name" >> "$NET_STATE_FILE"
  fi
}

# cable A B: one veth pair. The end in A is veth-A. The end in B is veth-B. Both ends are brought up.
# Interface names can have 15 characters, so a namespace name can have 10.
cable() {
  local a="${1:?cable needs two namespace names}" b="${2:?cable needs two namespace names}"
  if [ "${#a}" -gt 10 ] || [ "${#b}" -gt 10 ]; then
    die "namespace names for cable must be 10 characters or less"
  fi
  ip link del "veth-$a" 2>/dev/null || true
  ip link add "veth-$a" type veth peer name "veth-$b"
  ip link set "veth-$a" netns "$a"
  ip link set "veth-$b" netns "$b"
  ip netns exec "$a" ip link set "veth-$a" up
  ip netns exec "$b" ip link set "veth-$b" up
}

in_ns() {
  local name="${1:?in_ns needs a namespace name}"
  shift
  ip netns exec "$name" "$@"
}

teardown_all() {
  local name link
  if [ -f "$NET_STATE_FILE" ]; then
    while IFS= read -r name; do
      if [ -n "$name" ]; then
        ip netns del "$name" 2>/dev/null || true
      fi
    done < "$NET_STATE_FILE"
    rm -f "$NET_STATE_FILE"
  fi
  # A cable can be left in the main namespace if a script stopped half way.
  for link in $(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | cut -d@ -f1 | grep '^veth-' || true); do
    ip link del "$link" 2>/dev/null || true
  done
}

T_FAILS=0

t_pass() {
  printf 'PASS %s\n' "$*"
}

t_fail() {
  printf 'FAIL %s\n' "$*"
  T_FAILS=$((T_FAILS + 1))
}

t_done() {
  if [ "$T_FAILS" -eq 0 ]; then
    echo "RESULT: all checks passed"
    exit 0
  fi
  echo "RESULT: $T_FAILS check(s) failed"
  exit 1
}
