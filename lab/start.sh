#!/usr/bin/env bash
# Start the lab. Run it on your computer (not inside the lab):
#   bash lab/start.sh                 normal start
#   bash lab/start.sh --no-privilege  start WITHOUT --privileged, to see the checker fail on purpose
set -euo pipefail

# Git Bash on Windows rewrites paths like /work. This stops it.
export MSYS_NO_PATHCONV=1

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"

PRIVILEGED=1
if [ "${1:-}" = "--no-privilege" ]; then
  PRIVILEGED=0
fi

# Git Bash can print the Windows form of a path (D:/Projects/...). Docker Desktop wants that form.
# In Linux and macOS bash, "pwd -W" is not an option, so we keep the normal path.
if MOUNT_PATH="$(cd "$REPO" && pwd -W 2>/dev/null)"; then
  :
else
  MOUNT_PATH="$REPO"
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker is not running. Start Docker Desktop, wait until it says it is running, then run this again."
  exit 1
fi

# Build the image once. It stays on your computer after that.
if ! docker image inspect networking-lab >/dev/null 2>&1; then
  echo "Building the lab image. This happens once."
  (cd "$REPO" && docker build -t networking-lab lab/)
fi

RUN_ARGS=(run --rm -it)
if [ "$PRIVILEGED" -eq 1 ]; then
  RUN_ARGS+=(--privileged)
fi
RUN_ARGS+=(--hostname lab -v "$MOUNT_PATH:/work" networking-lab bash)

# mintty (the default Git Bash window) needs winpty to give Docker a terminal. Untested here.
DOCKER=(docker)
case "$(uname -s)" in
  MINGW*|MSYS*)
    if command -v winpty >/dev/null 2>&1; then
      DOCKER=(winpty docker)
    fi
    ;;
esac

exec "${DOCKER[@]}" "${RUN_ARGS[@]}"
