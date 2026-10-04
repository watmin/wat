# shellcheck shell=bash
# tools/check/gate-lib.sh -- the two step helpers, and nothing else that runs a command.
# Sourced by tools/verify.sh and the check modules. Not a check by itself.
#
# Measured on this host (12th Gen i7-1270P) on 2026-10-04:
# a 2000-case fuzz finished in about 5s. HEX0_CASE_SECS is 2, times the scale,
# and that is the per-case limit the fuzz reads. DUR_LONG (90) is the outer
# bound of one fuzz step. DUR_FAST (10) covers cmp, stat, and one hex0.
# DUR_CMD (30) covers python, gcc, objdump, git, and one layout.
# DUR_MODULE (1800) is the driver's backstop around one whole module
# (layout-mutants is one layout per mutant). It is not a measured duration.
# HEX0_TIME_SCALE multiplies every duration. It is checked once, here.

die() {
  echo "verify: $*" >&2
  exit 1
}

if [ "$EUID" -eq 0 ]; then
  die "refuses to run as root: a read-only same file is status 3 unless CAP_DAC_OVERRIDE lets the open succeed, and as root that row is red on a correct seed"
fi

HEX0_TIME_SCALE=${HEX0_TIME_SCALE:-1}
if [[ ! $HEX0_TIME_SCALE =~ ^[1-9][0-9]*$ ]]; then
  die "HEX0_TIME_SCALE must match ^[1-9][0-9]*\$"
fi
export HEX0_TIME_SCALE
export HEX0_CASE_SECS=$((2 * HEX0_TIME_SCALE))
export LC_ALL=C
export LANG=C
export PYTHONDONTWRITEBYTECODE=1

DUR_FAST=10
DUR_CMD=30
DUR_LONG=90
DUR_MODULE=1800

STEP_PIDS=()

_drop_pid() {
  local gone=$1
  local left=()
  local pid
  for pid in "${STEP_PIDS[@]+"${STEP_PIDS[@]}"}"; do
    if [ "$pid" != "$gone" ]; then
      left+=("$pid")
    fi
  done
  STEP_PIDS=("${left[@]+"${left[@]}"}")
}

_kill_live() {
  local pid
  for pid in "${STEP_PIDS[@]+"${STEP_PIDS[@]}"}"; do
    kill -KILL -- "-$pid" 2>/dev/null || true
  done
}

_on_signal() {
  local sig=$1
  _kill_live
  trap - INT TERM
  kill -s "$sig" $$
}

trap '_on_signal INT' INT
trap '_on_signal TERM' TERM

_marks_alive() {
  local mark=$1
  local envf pid
  local found=""
  for envf in /proc/[0-9]*/environ; do
    [ -r "$envf" ] || continue
    pid=${envf#/proc/}
    pid=${pid%/environ}
    if { tr '\0' '\n' <"$envf" | grep -qx "HEX0_STEP_MARK=$mark"; } 2>/dev/null; then
      found="$found $pid"
    fi
  done
  printf '%s' "$found"
}

_kill_mark() {
  local mark=$1
  local pid
  for pid in $(_marks_alive "$mark"); do
    kill -KILL "$pid" 2>/dev/null || true
  done
}

# Step temp files. A SANDBOX that does not exist yet is not created here.
scratch_tmp() {
  if [ -n "${HEX0_SCRATCH:-}" ]; then
    printf '%s\n' "$HEX0_SCRATCH"
  elif [ -n "${SANDBOX:-}" ] && [ -d "$SANDBOX" ]; then
    printf '%s\n' "$SANDBOX"
  else
    printf '%s\n' /var/tmp
  fi
}

# step LABEL SECS -- cmd    must exit 0. Stdout is passed through.
# expect LABEL SECS WANT -- cmd
#   WANT is a status (digits) or text:NEEDLE. A timeout is never a match.
# Both replay the command's output on failure and print got and want.
# "timed out" is timeout's own "sending signal KILL" line, never the rc.
_run() {
  local label=$1 base=$2 mode=$3 want=$4
  shift 4
  local secs out err rc pid mark timed escaped was
  secs=$((base * HEX0_TIME_SCALE))
  local tmp
  tmp=$(scratch_tmp)
  mkdir -p "$tmp"
  out=$(mktemp "$tmp/step.XXXXXX")
  err=$(mktemp "$tmp/step.XXXXXX")
  mark="hex0step-$$-${RANDOM}"
  rc=0
  was=0
  case $- in *m*) was=1 ;; esac
  set -m
  # A background job must keep the caller's stdin. Heredocs are how modules
  # hand a Python program to step, and bash would otherwise point that job at /dev/null.
  exec 9<&0
  HEX0_STEP_MARK=$mark timeout --verbose -s KILL "$secs" "$@" >"$out" 2>"$err" <&9 &
  pid=$!
  STEP_PIDS+=("$pid")
  wait "$pid" || rc=$?
  _drop_pid "$pid"
  if [ "$was" -eq 0 ]; then
    set +m
  fi
  timed=0
  if grep -q -F 'sending signal KILL' "$err"; then
    timed=1
  fi
  escaped=$(_marks_alive "$mark")
  if [ -n "$escaped" ]; then
    echo "verify: $label setsid escape:${escaped}" >&2
    echo "verify: $label got escape want none" >&2
    cat "$out" >&2
    cat "$err" >&2
    _kill_mark "$mark"
    rm -f "$out" "$err"
    exit 1
  fi
  if [ "$timed" -eq 1 ]; then
    echo "verify: $label rc $rc got timed-out want ${want:-0} timed out" >&2
    cat "$out" >&2
    cat "$err" >&2
    rm -f "$out" "$err"
    exit 1
  fi
  if [ "$mode" = step ]; then
    if [ "$rc" -ne 0 ]; then
      echo "verify: $label rc $rc got $rc want 0" >&2
      cat "$out" >&2
      cat "$err" >&2
      rm -f "$out" "$err"
      exit 1
    fi
    cat "$out"
    rm -f "$out" "$err"
    return 0
  fi
  if [[ $want =~ ^[0-9]+$ ]]; then
    if [ "$rc" -ne "$want" ]; then
      echo "verify: $label rc $rc got $rc want $want" >&2
      cat "$out" >&2
      cat "$err" >&2
      rm -f "$out" "$err"
      exit 1
    fi
    cat "$out"
    rm -f "$out" "$err"
    return 0
  fi
  local text=${want#text:}
  if ! grep -q -F -e "$text" "$out" "$err"; then
    echo "verify: $label rc $rc got missing want $text" >&2
    cat "$out" >&2
    cat "$err" >&2
    rm -f "$out" "$err"
    exit 1
  fi
  cat "$out"
  rm -f "$out" "$err"
  return 0
}

step() {
  local label=$1 base=$2
  shift 2
  if [ "${1:-}" != "--" ]; then
    die "step $label: missing --"
  fi
  shift
  _run "$label" "$base" step 0 "$@"
}

expect() {
  local label=$1 base=$2 want=$3
  shift 3
  if [ "${1:-}" != "--" ]; then
    die "expect $label: missing --"
  fi
  shift
  _run "$label" "$base" expect "$want" "$@"
}

# Run a shell function that must refuse, and require its own text.
capture_red() {
  local label=$1 needle=$2
  shift 2
  local tmp out err rc blob
  tmp=$(scratch_tmp)
  mkdir -p "$tmp"
  out=$(mktemp "$tmp/red.XXXXXX")
  err=$(mktemp "$tmp/red.XXXXXX")
  rc=0
  ("$@") >"$out" 2>"$err" || rc=$?
  blob=$(<"$out")
  blob+=$(<"$err")
  rm -f "$out" "$err"
  if [ "$rc" -eq 0 ]; then
    die "$label stayed green"
  fi
  case $blob in
    *"$needle"*) echo "$label: red" ;;
    *) die "$label said $blob" ;;
  esac
}

abs_req() {
  local canon
  case $1 in
    /*) ;;
    *) die "relative path refused: $1" ;;
  esac
  canon=$(readlink -f -- "$1") || die "cannot resolve $1"
  printf '%s\n' "$canon"
}

# A scratch directory is a canonical path under /var/tmp, and not /var/tmp itself.
under_tmp() {
  local canon
  canon=$(abs_req "$1")
  case $canon in
    /var/tmp|/var/tmp/) die "path is /var/tmp: $1" ;;
    /var/tmp/*) ;;
    *) die "path must be under /var/tmp: $canon" ;;
  esac
  printf '%s\n' "$canon"
}

payload_rc() {
  printf '%s\n' "${1##*$'\n'rc:}"
}

payload_body() {
  local blob=$1
  printf '%s\n' "${blob%$'\n'rc:*}"
}

# Run a command and return its combined output plus a final rc:N line.
# The command's own status stays in that line. step still refuses a timeout.
carry() {
  local label=$1 base=$2
  shift 2
  step "$label" "$base" -- bash -c '"$@" 2>&1; printf "\nrc:%s\n" "$?"' bash "$@"
}

fact() {
  local file=$1 key=$2 line
  line=$(awk -F '\t' -v k="$key" '$1 == k { print $2; found = 1 } END { if (!found) exit 3 }' "$file") || die "missing fact $key in $file"
  if [ -z "$line" ]; then
    die "empty fact $key in $file"
  fi
  printf '%s\n' "$line"
}

nr_of() {
  local file=$1 key=$2 line
  line=$(awk -F '\t' -v k="$key" '$1 == k { print $2; found = 1 } END { if (!found) exit 3 }' "$file") || die "missing syscall $key in $file"
  if [ -z "$line" ]; then
    die "empty syscall $key in $file"
  fi
  printf '%s\n' "$line"
}

# sandbox_tree SRC DEST -- git init, visible files, and the archive commit object.
# Never copies a .git directory. git bundle packs refs, so a raw commit id is an
# empty bundle. A temporary bare repo (sibling of DEST) holds refs/gate/archive
# and reads the source objects through alternates. The source refs are not written.
sandbox_tree() {
  local src=$1 dest=$2
  local git
  git=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/git-sandbox
  step "tree init" "$DUR_CMD" -- "$git" init -q "$dest"
  step "tree fill" "$DUR_LONG" -- bash -c 'tar -C "$1" --exclude=.git --exclude=out -cf - . | tar -C "$2" -xf -' bash "$src" "$dest"
  step "tree bundle" "$DUR_LONG" -- bash -c '
    git=$1
    src=$2
    dest=$3
    bare=$dest.archive.git
    trap "rm -rf \"\$bare\" \"\$dest/archive.bundle\"" EXIT
    common=$("$git" -C "$src" rev-parse --path-format=absolute --git-common-dir)
    objects=$common/objects
    "$git" init -q --bare "$bare"
    printf "%s\n" "$objects" > "$bare/objects/info/alternates"
    "$git" -C "$bare" update-ref refs/gate/archive c45603e
    "$git" -C "$bare" bundle create "$dest/archive.bundle" refs/gate/archive
    "$git" -C "$dest" fetch --no-tags "$dest/archive.bundle" "refs/gate/archive:refs/gate/archive"
  ' bash "$git" "$src" "$dest"
  step "tree add" "$DUR_CMD" -- "$git" -C "$dest" add -A
  # The archive commit is a parent, so a clone of HEAD still contains that object.
  step "tree commit" "$DUR_CMD" -- bash -c '
    git=$1
    dest=$2
    tree=$("$git" -C "$dest" write-tree)
    commit=$("$git" -C "$dest" commit-tree "$tree" -p refs/gate/archive -m "hex0 gate sandbox tree")
    "$git" -C "$dest" update-ref HEAD "$commit"
  ' bash "$git" "$dest"
}
