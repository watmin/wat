#!/usr/bin/env bash
# tools/verify.sh -- the hex0 gate.
# Host detection and the loop over rungs and targets. Steps are timed
# inside the modules. This driver does not put a second timer around them.
# Scratch and instruments live under /var/tmp. Rung output goes to out/.
set -u
export PYTHONDONTWRITEBYTECODE=1
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
# shellcheck source=tools/check/gate-lib.sh
. tools/check/gate-lib.sh || exit 2
umask 0022

if [ -n "${HEX0_SANDBOX:-}" ]; then
  case $HEX0_SANDBOX in
    /var/tmp/*) ;;
    *) die "HEX0_SANDBOX must be under /var/tmp" ;;
  esac
  if [ -e "$HEX0_SANDBOX" ]; then
    die "HEX0_SANDBOX already exists"
  fi
  mkdir "$HEX0_SANDBOX" || die "HEX0_SANDBOX mkdir"
  SANDBOX=$HEX0_SANDBOX
else
  SANDBOX=$(mktemp -d /var/tmp/hex0-verify.XXXXXX)
fi
export SANDBOX
export HEX0_SCRATCH=$SANDBOX
HOST=$(uname -m)-$(uname -s | tr '[:upper:]' '[:lower:]')
trap 'rm -rf "$SANDBOX"' EXIT

is_host() {
  [ "$1" = "$HOST" ]
}

tools/check/layout-mutants.sh "$SANDBOX" || die "tools/check/layout-mutants.sh rc $?"

shopt -s nullglob
found_host=0
for rung in ladder/*/; do
  rname=$(basename "$rung")
  for dir in "$rung"*/; do
    tgt=$(basename "$dir")
    [ "$tgt" = tests ] && continue
    [[ $tgt =~ ^[a-z0-9_]+-[a-z0-9_]+$ ]] || die "not a target: $rname/$tgt"
    case $rname in
      0-hex0)
        if [ "$tgt" = x86_64-linux ]; then
          tools/check/seed-audit.sh "${rung}${tgt}" "$SANDBOX" --size 537 \
            || die "tools/check/seed-audit.sh rc $?"
        else
          tools/check/seed-audit.sh "${rung}${tgt}" "$SANDBOX" \
            || die "tools/check/seed-audit.sh rc $?"
        fi
        if is_host "$tgt"; then
          found_host=1
          tools/check/hex0-contract.sh \
            "${rung}${tgt}/hex0" "${rung}${tgt}/hex0.hex0" "${rung}tests" "$SANDBOX" \
            || die "tools/check/hex0-contract.sh rc $?"
        else
          echo "$tgt: not executed on this host"
        fi
        ;;
      *) die "no module for rung $rname" ;;
    esac
  done
done
[ "$found_host" -eq 1 ] || die "no target for this host: $HOST"

if [ "${HEX0_DRIVER_TEST:-}" = 1 ]; then
  echo "driver-test: skipped"
else
  tools/check/driver-test.sh "$SANDBOX" || die "tools/check/driver-test.sh rc $?"
fi

check "fresh clone" "$DUR_CMD" -- git clone --quiet "$PWD" "$SANDBOX/clone"
export HEX0_SCRATCH=$SANDBOX
check "fresh clone layout" "$DUR_CMD" -- tools/layout.sh "$SANDBOX/clone" >"$SANDBOX/clone.layout"
cat "$SANDBOX/clone.layout"
echo "fresh clone: layout ok"

check "autocrlf clone" "$DUR_CMD" -- git -c core.autocrlf=true clone --quiet "$PWD" "$SANDBOX/crlf-clone"
if grep -q $'\r' "$SANDBOX/crlf-clone/tools/verify.sh"; then
  die "autocrlf clone rewrote a tools script"
fi
echo "autocrlf clone: lf"

echo "verify: working tree and HEAD clone"
exit 0
