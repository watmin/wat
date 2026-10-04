# tools/check/gate-lib.sh -- one definition of how the gate fails and times out.
# Sourced by tools/verify.sh and the check modules. Not a check by itself.

die() {
  echo "verify: $*" >&2
  exit 1
}

guard() {
  local secs=$1
  shift
  timeout --verbose -s KILL "$secs" "$@"
}
