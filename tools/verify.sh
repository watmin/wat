#!/usr/bin/env bash
# tools/verify.sh -- the hex0 gate.
# Sandbox, host detection, and the loop over rungs and targets.
# Layout mutants, the seed audit, and the hex0 contract are modules
# under tools/check/. Scratch and instruments live under /var/tmp.
# Rung output goes to out/. This script does not modify the live tree
# or the git index.
set -u
export PYTHONDONTWRITEBYTECODE=1
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
# shellcheck disable=SC1091
. tools/check/gate-lib.sh
umask 0022

SANDBOX=/var/tmp/hex0-verify
HOST=$(uname -m)-$(uname -s | tr '[:upper:]' '[:lower:]')
rm -rf "$SANDBOX"
mkdir -p "$SANDBOX" out
trap 'rm -rf "$SANDBOX"' EXIT

skip_execution() {
  local tgt=$1
  if [ "$tgt" = "$HOST" ]; then
    return 1
  fi
  echo "$tgt: not executed on this host"
  return 0
}

guard 180 tools/check/layout-mutants.sh "$SANDBOX"

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
          guard 60 tools/check/seed-audit.sh "${rung}${tgt}" "$SANDBOX" --size 537
        else
          guard 60 tools/check/seed-audit.sh "${rung}${tgt}" "$SANDBOX"
        fi
        if [ "$tgt" = "$HOST" ]; then
          found_host=1
          guard 180 tools/check/hex0-contract.sh \
            "${rung}${tgt}/hex0" "${rung}${tgt}/hex0.hex0" "${rung}tests" "$SANDBOX"
        else
          skip_execution "$tgt" || die "non-host target $tgt fell through to execution"
        fi
        ;;
      *) die "no module for rung $rname" ;;
    esac
  done
done
[ "$found_host" -eq 1 ] || die "no target for this host: $HOST"
if skip_execution "$HOST"; then
  die "host target was not executed"
fi
skip_execution aarch64-linux || die "aarch64-linux stayed silent"

echo "verify: ok"
exit 0
