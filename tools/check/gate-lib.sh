# shellcheck shell=bash
# tools/check/gate-lib.sh -- how the gate fails, and the one timer.
# Sourced by tools/verify.sh and the check modules. Not a check by itself.
#
# Durations measured on this host (12th Gen i7-1270P) on 2026-10-04:
# a full verify was about 34s, and layout.sh about 1.25s. A 2000-case fuzz
# finished inside 120s. HEX0_TIME_SCALE multiplies every duration (default 1).

die() {
  echo "verify: $*" >&2
  exit 1
}

secs_of() {
  local base=$1
  local scale=${HEX0_TIME_SCALE:-1}
  case $scale in
    ''|*[!0-9]*) die "HEX0_TIME_SCALE is not a whole number" ;;
  esac
  echo $((base * scale))
}

# Fast steps (cmp, stat, a single hex0) finish in well under a second.
DUR_FAST=10
# python, gcc, objdump, git, layout.
DUR_CMD=30
# one fuzz sample.
DUR_LONG=90

reap_group() {
  local pid=$1
  local i=0
  while kill -0 -- "-$pid" 2>/dev/null; do
    kill -KILL -- "-$pid" 2>/dev/null || true
    i=$((i + 1))
    if [ "$i" -gt 40 ]; then
      return 1
    fi
    sleep 0.05
  done
  return 0
}

# check LABEL SECS -- cmd...
# On success, the command's stdout is passed through.
# On failure, die with the label, the rc, whether the timer fired, and the output.
check() {
  local label=$1
  local base=$2
  shift 2
  if [ "${1:-}" = "--" ]; then
    shift
  fi
  local secs out err rc pid tmp
  secs=$(secs_of "$base")
  tmp=${HEX0_SCRATCH:-${SANDBOX:-/var/tmp}}
  mkdir -p "$tmp"
  out=$(mktemp "$tmp/check.XXXXXX")
  err=$(mktemp "$tmp/check.XXXXXX")
  rc=0
  set -m
  timeout --verbose -s KILL "$secs" "$@" >"$out" 2>"$err" &
  pid=$!
  wait "$pid" || rc=$?
  if ! reap_group "$pid"; then
    echo "verify: $label descendants still alive" >&2
    rm -f "$out" "$err"
    exit 1
  fi
  set +m
  if [ "$rc" -ne 0 ]; then
    local why=""
    if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
      why=" timed out"
    fi
    echo "verify: $label rc $rc$why" >&2
    cat "$out" >&2
    cat "$err" >&2
    rm -f "$out" "$err"
    exit 1
  fi
  cat "$out"
  rm -f "$out" "$err"
}

# Return the command's status. A timer is 124 or 137; the caller must not
# treat that as a successful refusal.
run_status() {
  local base=$1
  shift
  if [ "${1:-}" = "--" ]; then
    shift
  fi
  local secs rc pid
  secs=$(secs_of "$base")
  rc=0
  set -m
  timeout --verbose -s KILL "$secs" "$@" &
  pid=$!
  wait "$pid" || rc=$?
  if ! reap_group "$pid"; then
    die "run_status descendants still alive"
  fi
  set +m
  return "$rc"
}

timed_out() {
  [ "$1" -eq 124 ] || [ "$1" -eq 137 ]
}
