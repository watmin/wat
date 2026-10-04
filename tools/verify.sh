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

# The clone rows test this working tree, not HEAD. The commit is in the
# sandbox copy. The live index is never touched.
candidate=$SANDBOX/candidate
check "candidate copy" "$DUR_LONG" -- cp -a . "$candidate"
git -C "$candidate" config commit.gpgsign false
check "candidate add" "$DUR_CMD" -- git -C "$candidate" add -A
if git -C "$candidate" diff --cached --quiet; then
  echo "candidate: worktree matches HEAD"
else
  check "candidate commit" "$DUR_CMD" -- git -C "$candidate" commit -q -m "hex0 gate candidate"
fi
export HEX0_SCRATCH=$SANDBOX
check "plain clone" "$DUR_CMD" -- git clone --quiet "$candidate" "$SANDBOX/clone"
check "plain clone layout" "$DUR_CMD" -- tools/layout.sh "$SANDBOX/clone" >"$SANDBOX/clone.layout"
cat "$SANDBOX/clone.layout"
echo "plain clone: layout ok"
check "autocrlf clone" "$DUR_CMD" -- git -c core.autocrlf=true clone --quiet "$candidate" "$SANDBOX/crlf-clone"
if grep -q $'\r' "$SANDBOX/crlf-clone/tools/verify.sh"; then
  die "autocrlf clone rewrote a tools script"
fi
check "autocrlf clone layout" "$DUR_CMD" -- tools/layout.sh "$SANDBOX/crlf-clone" >"$SANDBOX/crlf.layout"
cat "$SANDBOX/crlf.layout"
echo "autocrlf clone: lf"

noattr=$SANDBOX/candidate-noattr
check "noattr copy" "$DUR_LONG" -- cp -a "$candidate" "$noattr"
grep -v -x -F '* text=auto eol=lf' "$noattr/.gitattributes" > "$noattr/.gitattributes.tmp"
mv "$noattr/.gitattributes.tmp" "$noattr/.gitattributes"
check "noattr add" "$DUR_CMD" -- git -C "$noattr" add -A -- .gitattributes
check "noattr commit" "$DUR_CMD" -- git -C "$noattr" commit -q -m "hex0 gate candidate without the attribute line"
check "noattr autocrlf clone" "$DUR_CMD" -- git -c core.autocrlf=true clone --quiet "$noattr" "$SANDBOX/crlf-noattr"
if ! grep -q $'\r' "$SANDBOX/crlf-noattr/tools/verify.sh"; then
  die "reverted attribute stayed lf"
fi
echo "mutant autocrlf without the attribute: red"

echo "verify: working tree, committed in the sandbox and cloned"
exit 0
