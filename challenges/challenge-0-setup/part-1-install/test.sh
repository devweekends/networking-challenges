#!/usr/bin/env bash
# Test for challenge 0, part 1. Run it in the lab:  bash test.sh
# It runs the setup checker. Every line must say PASS.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The checker has its own exit code: 0 for all PASS, 1 for any FAIL.
exec bash "$HERE/../../../toolkit/check-setup.sh"
