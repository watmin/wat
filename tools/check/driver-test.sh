#!/usr/bin/env bash
# tools/check/driver-test.sh -- prove the driver dies when a module fails or hangs.
# Usage: tools/check/driver-test.sh SCRATCH_DIR
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2
# shellcheck disable=SC1091
. tools/check/gate-lib.sh

if [ "${HEX0_DRIVER_TEST:-}" = 1 ]; then
  die "driver-test must not run inside a driver test"
fi

ROOT=$PWD
WORK=${1:?}
mkdir -p "$WORK"

write_stub() {
  local path=$1
  local body=$2
  printf '%s\n' '#!/usr/bin/env bash' "$body" >"$path"
  chmod +x "$path"
}

prove() {
  local id=$1
  local label=$2
  local module=$3
  local mode=$4
  local copy="$WORK/$id"
  rm -rf "$copy" "$WORK/$id-sandbox"
  cp -a "$ROOT" "$copy"
  write_stub "$copy/tools/check/layout-mutants.sh" 'exit 0'
  write_stub "$copy/tools/check/seed-audit.sh" 'exit 0'
  write_stub "$copy/tools/check/hex0-contract.sh" 'exit 0'
  if [ "$mode" = hang ]; then
    write_stub "$copy/tools/check/$module.sh" 'sleep 300'
  else
    write_stub "$copy/tools/check/$module.sh" 'exit 1'
  fi
  local out="$WORK/$id.out"
  local err="$WORK/$id.err"
  local rc=0
  local bound=30
  local layout_guard=30
  if [ "$mode" = hang ]; then
    bound=20
    layout_guard=2
  fi
  HEX0_DRIVER_TEST=1 \
    HEX0_SANDBOX="$WORK/$id-sandbox" \
    LAYOUT_GUARD="$layout_guard" \
    SEED_GUARD=30 \
    CONTRACT_GUARD=30 \
    run_status "$bound" "$copy/tools/verify.sh" >"$out" 2>"$err" || rc=$?
  if [ "$rc" -eq 0 ]; then
    die "$label: driver exited 0"
  fi
  if ! grep -q -F "tools/check/$module.sh" "$err"; then
    die "$label: stderr did not name $module"
  fi
  echo "driver: $label"
}

prove fatal-layout "layout-mutants exit 1 is fatal" layout-mutants fail
prove fatal-seed "seed-audit exit 1 is fatal" seed-audit fail
prove fatal-contract "hex0-contract exit 1 is fatal" hex0-contract fail
prove hang-layout "layout-mutants hang is killed" layout-mutants hang
