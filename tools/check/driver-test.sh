#!/usr/bin/env bash
# tools/check/driver-test.sh -- the driver dies when a module fails or hangs.
# Usage: tools/check/driver-test.sh SCRATCH_DIR
set -u
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd) || exit 2
# shellcheck source=tools/check/gate-lib.sh
. "$root/tools/check/gate-lib.sh" || exit 2
cd "$root" || exit 2

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

hang_body() {
  local module=$1
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -u' \
    'root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd) || exit 2' \
    '. "$root/tools/check/gate-lib.sh" || exit 2' \
    'rm -f "$SANDBOX/never-event"' \
    'mkfifo "$SANDBOX/never-event"' \
    "check \"$module hang\" 2 -- cat \"\$SANDBOX/never-event\""
}

prove_fail() {
  local id=$1
  local module=$2
  local copy="$WORK/$id"
  rm -rf "$copy" "$WORK/$id-sandbox"
  cp -a "$ROOT" "$copy"
  write_stub "$copy/tools/check/layout-mutants.sh" 'exit 0'
  write_stub "$copy/tools/check/seed-audit.sh" 'exit 0'
  write_stub "$copy/tools/check/hex0-contract.sh" 'exit 0'
  write_stub "$copy/tools/check/$module.sh" 'exit 1'
  local out="$WORK/$id.out"
  local err="$WORK/$id.err"
  local rc=0
  HEX0_DRIVER_TEST=1 \
    HEX0_SANDBOX="$WORK/$id-sandbox" \
    "$copy/tools/verify.sh" >"$out" 2>"$err" || rc=$?
  if [ "$rc" -eq 0 ]; then
    die "$module exit 1: driver exited 0"
  fi
  if ! grep -q -F "tools/check/$module.sh" "$err"; then
    die "$module exit 1: stderr did not name the module"
  fi
  echo "driver: $module exit 1 is fatal"
}

prove_hang() {
  local id=$1
  local module=$2
  local copy="$WORK/$id"
  rm -rf "$copy" "$WORK/$id-sandbox"
  cp -a "$ROOT" "$copy"
  write_stub "$copy/tools/check/layout-mutants.sh" 'exit 0'
  write_stub "$copy/tools/check/seed-audit.sh" 'exit 0'
  write_stub "$copy/tools/check/hex0-contract.sh" 'exit 0'
  hang_body "$module" > "$copy/tools/check/$module.sh"
  chmod +x "$copy/tools/check/$module.sh"
  local out="$WORK/$id.out"
  local err="$WORK/$id.err"
  local rc=0
  HEX0_DRIVER_TEST=1 \
    HEX0_SANDBOX="$WORK/$id-sandbox" \
    "$copy/tools/verify.sh" >"$out" 2>"$err" || rc=$?
  if [ "$rc" -eq 0 ]; then
    die "$module hang: driver exited 0"
  fi
  if ! grep -q -F "timed out" "$err"; then
    die "$module hang: stderr did not say timed out"
  fi
  if ! grep -q -F "$module" "$err"; then
    die "$module hang: stderr did not name the module"
  fi
  echo "driver: $module hang timed out"
}

prove_fail fatal-layout layout-mutants
prove_fail fatal-seed seed-audit
prove_fail fatal-contract hex0-contract
prove_hang hang-layout layout-mutants
prove_hang hang-seed seed-audit
prove_hang hang-contract hex0-contract

copy="$WORK/nonhost"
rm -rf "$copy" "$WORK/nonhost-sandbox"
cp -a "$ROOT" "$copy"
write_stub "$copy/tools/check/layout-mutants.sh" 'exit 0'
write_stub "$copy/tools/check/seed-audit.sh" 'exit 0'
write_stub "$copy/tools/check/hex0-contract.sh" 'exit 0'
mkdir -p "$copy/ladder/0-hex0/aarch64-linux"
printf '%s\n' '41 # one byte' > "$copy/ladder/0-hex0/aarch64-linux/hex0.hex0"
rc=0
HEX0_DRIVER_TEST=1 \
  HEX0_SANDBOX="$WORK/nonhost-sandbox" \
  "$copy/tools/verify.sh" >"$WORK/nonhost.out" 2>"$WORK/nonhost.err" || rc=$?
if [ "$rc" -ne 0 ]; then
  die "non-host target: driver rc $rc $(cat "$WORK/nonhost.err")"
fi
grep -q -F 'aarch64-linux: not executed on this host' "$WORK/nonhost.out" \
  || die "non-host target stayed silent"
grep -q -F 'driver-test: skipped' "$WORK/nonhost.out" \
  || die "driver-test skip was silent"
echo "driver: non-host target is not executed"
echo "driver-test: skipped on the nested run"
