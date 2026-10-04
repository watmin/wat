# tools/check/gate-lib.sh -- one definition of how the gate fails and times out.
# Sourced by tools/verify.sh and the check modules. Not a check by itself.

die() {
  echo "verify: $*" >&2
  exit 1
}

# Failure and timeout are fatal. Callers that expect a status use run_status.
guard() {
  local secs=$1
  shift
  timeout --verbose -s KILL "$secs" "$@" || die "$* rc $?"
}

run_status() {
  local secs=$1
  shift
  timeout --verbose -s KILL "$secs" "$@"
}
