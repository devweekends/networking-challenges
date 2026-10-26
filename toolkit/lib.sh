#!/usr/bin/env bash
# toolkit/lib.sh: small helpers shared by every challenge script.
# Source it. Do not run it. From a part folder:
#   source "$HERE/../../../toolkit/lib.sh"
#
# What is inside:
#   require_root       stop unless you are root (in the lab you always are)
#   ns_add NAME        make a fresh network namespace (loopback switched on) and write its name in a list
#   cable A B          join namespaces A and B with a virtual cable (a veth pair), both ends up
#   cable_if A IFA B IFB   the same, but you choose the name of each end (names must start with veth-)
#   in_ns NAME CMD...  run CMD inside namespace NAME
#   bg_start NAME NS CMD...   run CMD inside namespace NS in the background, and remember it as NAME
#   stop_proc NAME     stop a program started with bg_start
#   www_make DIR TITLE make a tiny web folder: a page, and two small programs that tell a visitor its address
#   udhcpc_hook_path   print the path of the script that applies a DHCP lease (see toolkit/udhcpc-hook.sh)
#   teardown_all       stop every bg_start program, delete every namespace made with ns_add, and any leftover veth- link
#   try_ping, try_curl, if_with_addr, first_if, mac_of, ns_exists   helpers for test.sh files
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
  # A resolver file left over from an earlier run would give this new computer a DNS server it never asked for.
  rm -rf "/etc/netns/$name"
  ip netns add "$name"
  # Every real computer has a loopback (127.0.0.1). A new namespace has it switched off.
  ip netns exec "$name" ip link set lo up
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

# cable_if A IFA B IFB: one veth pair. The end in A is called IFA. The end in B is called IFB.
# Both ends are brought up. Names must start with veth- so that teardown_all can clean up after a stop half way.
cable_if() {
  local a="${1:?cable_if needs NS_A IF_A NS_B IF_B}" ifa="${2:?}" b="${3:?}" ifb="${4:?}"
  case "$ifa$ifb" in
    veth-*veth-*) ;;
    *) die "cable_if: both interface names must start with veth-" ;;
  esac
  if [ "${#ifa}" -gt 15 ] || [ "${#ifb}" -gt 15 ]; then
    die "cable_if: interface names can have 15 characters at most"
  fi
  ip link del "$ifa" 2>/dev/null || true
  ip link add "$ifa" type veth peer name "$ifb"
  ip link set "$ifa" netns "$a"
  ip link set "$ifb" netns "$b"
  ip netns exec "$a" ip link set "$ifa" up
  ip netns exec "$b" ip link set "$ifb" up
}

NET_PID_DIR="${NET_PID_DIR:-/tmp/networking-course-pids}"

# bg_start NAME NS CMD...: run CMD inside namespace NS, in the background. Its output goes to
# $NET_PID_DIR/NAME.log. The process id is saved, so stop_proc NAME and teardown_all can stop it.
# Starting a program with a name that is already in use stops the old one first.
bg_start() {
  local name="${1:?bg_start needs a name}" ns="${2:?bg_start needs a namespace}"
  shift 2
  stop_proc "$name"
  mkdir -p "$NET_PID_DIR"
  ip netns exec "$ns" "$@" > "$NET_PID_DIR/$name.log" 2>&1 < /dev/null &
  echo "$!" > "$NET_PID_DIR/$name.pid"
}

stop_proc() {
  local name="${1:?stop_proc needs a name}" file pid
  file="$NET_PID_DIR/$name.pid"
  [ -f "$file" ] || return 0
  pid="$(cat "$file")"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    { wait "$pid"; } 2>/dev/null || true
    sleep 0.3
  fi
  rm -f "$file"
}

stop_all_procs() {
  local file
  [ -d "$NET_PID_DIR" ] || return 0
  for file in "$NET_PID_DIR"/*.pid; do
    [ -e "$file" ] || continue
    stop_proc "$(basename "$file" .pid)"
  done
}

# www_make DIR TITLE: make a web folder for busybox httpd.
#   DIR/index.html          a page that says TITLE
#   DIR/cgi-bin/whoami      answers at once: "the server sees you as ADDRESS:PORT"
#   DIR/cgi-bin/slow        the same answer, after 4 seconds (it keeps a conversation open)
www_make() {
  local dir="${1:?www_make needs a folder}" title="${2:?www_make needs a title}"
  mkdir -p "$dir/cgi-bin"
  echo "$title" > "$dir/index.html"
  cat > "$dir/cgi-bin/whoami" <<'CGI'
#!/bin/sh
echo "Content-Type: text/plain"
echo
echo "the server sees you as ${REMOTE_ADDR}:${REMOTE_PORT}"
CGI
  cat > "$dir/cgi-bin/slow" <<'CGI'
#!/bin/sh
sleep 4
echo "Content-Type: text/plain"
echo
echo "the server sees you as ${REMOTE_ADDR}:${REMOTE_PORT}"
CGI
  chmod 755 "$dir/cgi-bin/whoami" "$dir/cgi-bin/slow"
}

# udhcpc_hook_path: copy toolkit/udhcpc-hook.sh to /tmp, make it runnable, and print where it is.
# (A file from a Windows folder may not be runnable, so we use a copy.)
udhcpc_hook_path() {
  local dst=/tmp/networking-course-udhcpc-hook
  cp "$NET_ROOT/toolkit/udhcpc-hook.sh" "$dst"
  chmod 755 "$dst"
  echo "$dst"
}

teardown_all() {
  local name link
  stop_all_procs
  if [ -f "$NET_STATE_FILE" ]; then
    while IFS= read -r name; do
      if [ -n "$name" ]; then
        ip netns del "$name" 2>/dev/null || true
        rm -rf "/etc/netns/$name"
      fi
    done < "$NET_STATE_FILE"
    rm -f "$NET_STATE_FILE"
  fi
  # A cable can be left in the main namespace if a script stopped half way.
  for link in $(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | cut -d@ -f1 | grep '^veth-' || true); do
    ip link del "$link" 2>/dev/null || true
  done
}

# ---- helpers for test.sh files ----

# try_ping NS ADDRESS [COUNT]: sets OUT and RC without stopping the test when ping fails
try_ping() {
  RC=0
  OUT="$(ip netns exec "$1" ping -c"${3:-2}" -W1 "$2" 2>&1)" || RC=$?
}

# try_curl NS CURL_ARGS...: sets OUT (body and errors), RC (curl's exit code) and ELAPSED (whole seconds)
try_curl() {
  local ns="${1:?try_curl needs a namespace}" started="$SECONDS"
  shift
  RC=0
  OUT="$(ip netns exec "$ns" curl -sS -m 3 "$@" 2>&1)" || RC=$?
  ELAPSED=$((SECONDS - started))
}

# ns_exists NAME: true if the namespace exists
ns_exists() {
  local list
  list="$(ip netns list 2>/dev/null || true)"
  grep -qw -- "$1" <<< "$list"
}

# if_with_addr NS ADDRESS: print the name of the interface that holds ADDRESS (empty if none)
if_with_addr() {
  local out
  out="$(ip netns exec "$1" ip -o -4 addr show 2>/dev/null || true)"
  awk -v a="$2/" '!done && index($4, a) == 1 { print $2; done = 1 }' <<< "$out"
}

# first_if NS: print the name of the first interface in NS that is not the loopback
first_if() {
  local out
  out="$(ip netns exec "$1" ip -o link show 2>/dev/null || true)"
  awk -F': ' '$2 != "lo" && !done { n = $2; sub(/@.*/, "", n); print n; done = 1 }' <<< "$out"
}

# mac_of NS INTERFACE: print the hardware address of an interface
mac_of() {
  ip netns exec "$1" cat "/sys/class/net/$2/address"
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
