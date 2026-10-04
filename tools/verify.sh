#!/usr/bin/env bash
# tools/verify.sh -- the hex0 gate.
# Host detection and the loop over rungs and targets.
# Scratch and instruments live under /var/tmp. Rung output goes to out/.
# rune:solvere(scratch) — out/ is the rung product directory and one gate owns it per run; two concurrent gates on one tree still share it.
set -u
export PYTHONDONTWRITEBYTECODE=1
here=${BASH_SOURCE[0]%/*}
case $here in
  /*) ;;
  *) here=$PWD/$here ;;
esac
root=${here%/*}
cd "$root" || exit 2
# shellcheck source=tools/check/gate-lib.sh
. tools/check/gate-lib.sh || exit 2
umask 0022

if [ -n "${HEX0_SANDBOX:-}" ]; then
  SANDBOX=$(under_tmp "$HEX0_SANDBOX")
  if [ -e "$SANDBOX" ]; then
    die "HEX0_SANDBOX already exists"
  fi
  step "sandbox mkdir" "$DUR_FAST" -- mkdir "$SANDBOX"
else
  SANDBOX=$(step "sandbox temp" "$DUR_FAST" -- mktemp -d /var/tmp/hex0-verify.XXXXXX)
  SANDBOX=$(under_tmp "$SANDBOX")
fi
export SANDBOX HEX0_SCRATCH=$SANDBOX
trap 'rm -rf "$SANDBOX"' EXIT

machine=$(step "uname m" "$DUR_FAST" -- uname -m)
sysname=$(step "uname s" "$DUR_FAST" -- uname -s)
sysname=${sysname,,}
HOST=$machine-$sysname
GIT=$root/tools/check/git-sandbox

outer_sum() {
  step "outer sum" "$DUR_FAST" -- bash -c 'tar -C "$1" -cf - HEAD index config refs | sha256sum' bash "$root/.git"
}

outer_before=$(outer_sum) || die "outer sum failed"
outer_before=${outer_before%% *}
[ "${#outer_before}" -eq 64 ] || die "outer sum length ${#outer_before}"

product=out
step "empty out" "$DUR_FAST" -- bash -c 'rm -rf -- "$1/$2" && mkdir -- "$1/$2"' bash "$root" "$product"

for rel in tools/verify.sh tools/layout.sh tools/check/*.sh; do
  case $rel in
    tools/check/gate-lib.sh) continue ;;
  esac
  step "step-lint $rel" "$DUR_FAST" -- python3 tools/check/step-lint.py "$rel"
done
echo "row 18: step-lint ok"
printf '%s\n' '#!/usr/bin/env bash' 'cmp /dev/null /dev/null' > "$SANDBOX/bare-module.sh"
expect "step-lint mutant" "$DUR_FAST" "text:bare command:" -- python3 tools/check/step-lint.py "$SANDBOX/bare-module.sh"
echo "mutant step-lint: red"

step "tools/check/layout-mutants.sh" "$DUR_MODULE" -- tools/check/layout-mutants.sh "$SANDBOX/layout"

shopt -s nullglob
found_host=0
for rung in ladder/*/; do
  rname=${rung%/}
  rname=${rname##*/}
  for dir in "$rung"*/; do
    tgt=${dir%/}
    tgt=${tgt##*/}
    [ "$tgt" = tests ] && continue
    [[ $tgt =~ ^[a-z0-9_]+-[a-z0-9_]+$ ]] || die "not a target: $rname/$tgt"
    case $rname in
      0-hex0)
        target=$(abs_req "$root/$rung$tgt")
        step "tools/check/seed-audit.sh $tgt" "$DUR_MODULE" -- tools/check/seed-audit.sh "$target" "$SANDBOX"
        if [ "$tgt" = "$HOST" ]; then
          found_host=1
          step "tools/check/hex0-contract.sh" "$DUR_MODULE" -- tools/check/hex0-contract.sh "$target" "$SANDBOX"
        else
          echo "$tgt: not executed on this host"
        fi
        ;;
      *) die "no module for rung $rname" ;;
    esac
  done
done
[ "$found_host" -eq 1 ] || die "no target for this host: $HOST"

skip_driver=0
if [ "${HEX0_DRIVER_TEST:-}" = 1 ] && [ -n "${HEX0_DRIVER_MARK:-}" ]; then
  case $HEX0_DRIVER_MARK in
    /*) ;;
    *) die "relative path refused: HEX0_DRIVER_MARK" ;;
  esac
  if [ -f "$HEX0_DRIVER_MARK" ] && [ "$(<"$HEX0_DRIVER_MARK")" = hex0-driver-mark ]; then
    skip_driver=1
  fi
fi
if [ "$skip_driver" -eq 1 ]; then
  echo "driver-test: skipped"
else
  step "driver-test" "$DUR_MODULE" -- tools/check/driver-test.sh "$SANDBOX/driver"
fi

cr_check() {
  local blob rc body
  blob=$(carry "text cr" "$DUR_LONG" python3 "$1/tools/check/text-cr.py" "$1")
  rc=$(payload_rc "$blob")
  body=$(payload_body "$blob")
  if [ "$rc" != 0 ]; then
    printf '%s\n' "$body" >&2
    exit 1
  fi
  printf '%s\n' "$body"
}

clone_layout() {
  local text
  text=$(step "clone layout" "$DUR_LONG" -- "$1/tools/layout.sh" "$1")
  [ "$text" = "layout: ok" ] || die "clone layout $text"
  row_did=clone_layout
}

candidate=$SANDBOX/candidate
sandbox_tree "$root" "$candidate"

step "hostile dir" "$DUR_CMD" -- bash -c 'GIT_DIR=/var/tmp/hex0-no-such-git GIT_INDEX_FILE=/var/tmp/hex0-no-such-index "$1" -C "$2" status --porcelain >/dev/null' bash "$GIT" "$candidate"
echo "git: caller GIT_DIR ignored"

step "hook dir" "$DUR_FAST" -- mkdir -p "$SANDBOX/hostile-hooks"
printf '%s\n' '#!/bin/sh' 'exit 1' > "$SANDBOX/hostile-hooks/pre-commit"
step "hook mode" "$DUR_FAST" -- chmod 755 "$SANDBOX/hostile-hooks/pre-commit"
step "hook install" "$DUR_FAST" -- cp "$SANDBOX/hostile-hooks/pre-commit" "$candidate/.git/hooks/pre-commit"
printf '[core]\n\thooksPath = %s\n' "$SANDBOX/hostile-hooks" > "$SANDBOX/hostile.gitconfig"
step "hook commit" "$DUR_CMD" -- bash -c 'GIT_CONFIG_GLOBAL="$3" "$1" -C "$2" commit --allow-empty -q -m "hooks stay off"' bash "$GIT" "$candidate" "$SANDBOX/hostile.gitconfig"
echo "git: hooks ignored"

step "empty home" "$DUR_FAST" -- mkdir -p "$SANDBOX/empty-home"
step "identity commit" "$DUR_CMD" -- bash -c 'HOME="$3" XDG_CONFIG_HOME="$3" "$1" -C "$2" commit --allow-empty -q -m "fixed identity"' bash "$GIT" "$candidate" "$SANDBOX/empty-home"
echo "git: fixed identity"

step "worktree add" "$DUR_CMD" -- "$GIT" -C "$candidate" worktree add --detach "$SANDBOX/linked" HEAD
step "worktree file" "$DUR_FAST" -- bash -c '[ -f "$1/.git" ]' bash "$SANDBOX/linked"
sandbox_tree "$SANDBOX/linked" "$SANDBOX/from-worktree"
step "worktree gitdir" "$DUR_FAST" -- bash -c '[ -d "$1/.git" ]' bash "$SANDBOX/from-worktree"
echo "git: linked worktree did not copy the gitdir"

step "plain clone" "$DUR_CMD" -- "$GIT" clone --quiet "$candidate" "$SANDBOX/clone"
row_did=""
clone_layout "$SANDBOX/clone"
[ "$row_did" = clone_layout ] || die "clone layout did not compare"
plain=$(cr_check "$SANDBOX/clone") || die "plain clone cr"
[ "$plain" = "text files: lf" ] || die "cr_check did not compare: $plain"
echo "plain clone: layout ok"

step "crlf clone" "$DUR_CMD" -- "$GIT" -c core.autocrlf=true clone --quiet "$candidate" "$SANDBOX/crlf-clone"
row_did=""
clone_layout "$SANDBOX/crlf-clone"
[ "$row_did" = clone_layout ] || die "clone layout did not compare"
crlf=$(cr_check "$SANDBOX/crlf-clone") || die "autocrlf clone cr"
[ "$crlf" = "text files: lf" ] || die "cr_check did not compare: $crlf"
echo "autocrlf clone: lf"

step "noattr clone" "$DUR_CMD" -- "$GIT" clone --quiet "$candidate" "$SANDBOX/noattr"
step "noattr edit" "$DUR_FAST" -- bash -c 'printf "%s\n" "$2" >> "$1/.gitattributes"' bash "$SANDBOX/noattr" 'tools/check/*.sh text eol=crlf'
step "noattr add" "$DUR_CMD" -- "$GIT" -C "$SANDBOX/noattr" add -A -- .gitattributes
step "noattr commit" "$DUR_CMD" -- "$GIT" -C "$SANDBOX/noattr" commit -q -m "attribute forces crlf on tools"
step "noattr autocrlf" "$DUR_CMD" -- "$GIT" -c core.autocrlf=true clone --quiet "$SANDBOX/noattr" "$SANDBOX/crlf-noattr"
capture_red "mutant autocrlf attribute" "text file contains CR" cr_check "$SANDBOX/crlf-noattr"
echo "mutant autocrlf without lf: red"

# A nested gate proves one function. It must not start this proof again.
if [ "${HEX0_ROW_PROOF:-}" = 1 ] || [ "${HEX0_DRIVER_TEST:-}" = 1 ]; then
  echo "row-proof: skipped"
else
  step "row-proof" "$DUR_MODULE" -- tools/check/row-proof.sh "$SANDBOX/rows"
fi

outer_after=$(outer_sum) || die "outer sum failed"
outer_after=${outer_after%% *}
[ "${#outer_after}" -eq 64 ] || die "outer sum length ${#outer_after}"
[ "$outer_before" = "$outer_after" ] || die "outer repository changed"
echo "verify: sandbox candidate, clone layout, outer repository unchanged"
exit 0
