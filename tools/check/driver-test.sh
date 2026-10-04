#!/usr/bin/env bash
# tools/check/driver-test.sh SCRATCH_DIR
# One fail, one hang, the step proofs, and a stubbed non-host target.
# rune:peragrare(stub) — the non-host row runs with the modules stubbed; a real second seed is a later target.
set -u
here=${BASH_SOURCE[0]%/*}
case $here in
  /*) ;;
  *) here=$PWD/$here ;;
esac
root=${here%/*}
root=${root%/*}
cd "$root" || exit 2
# shellcheck source=tools/check/gate-lib.sh
. "$here/gate-lib.sh" || exit 2
umask 0022

[ $# -eq 1 ] || die "driver-test: want SCRATCH_DIR"
WORK=$(under_tmp "$1")
step "driver work" "$DUR_FAST" -- mkdir -p "$WORK"
MARK=$WORK/mark
printf '%s\n' hex0-driver-mark > "$MARK"
LIB=$root/tools/check/gate-lib.sh

if [ "${HEX0_DRIVER_TEST:-}" = 1 ] && [ -n "${HEX0_DRIVER_MARK:-}" ] && [ -f "$HEX0_DRIVER_MARK" ]; then
  if [ "$(<"$HEX0_DRIVER_MARK")" = hex0-driver-mark ]; then
    die "driver-test must not run inside a driver test"
  fi
fi

# rune:complectens(helper) — write_stub writes a stub file and is not a comparison.
write_stub() {
  local path=$1
  local body=$2
  step "stub $path" "$DUR_FAST" -- bash -c 'printf "%s\n" "$2" > "$1"; chmod 755 "$1"' bash "$path" "$body"
}

# The child's own SIGKILL is status 137. expect leaves that status in the step.
# A timer decision on rc 137 treats this line as timed out.
expect "self-kill" "$DUR_FAST" 137 -- bash -c 'kill -KILL $$'
echo "driver: self-kill is not timed out"

# timeout kills its direct child by pid, and bash execs a lone command.
# A background setsid grandchild keeps another pid and survives that kill.
blob=$(carry "setsid" "$DUR_CMD" bash -c '. "$1"; step "escape" 5 -- bash -c "setsid sleep 30 & wait"' bash "$LIB")
case $blob in
  *setsid\ escape*) ;;
  *) die "setsid was not an escape: $blob" ;;
esac
echo "driver: setsid escape"

for bad in 0 010 abc; do
  blob=$(carry "scale $bad" "$DUR_FAST" bash -c 'HEX0_TIME_SCALE="$1" . "$2"' bash "$bad" "$LIB")
  case $blob in
    *HEX0_TIME_SCALE*) ;;
    *) die "scale $bad stayed green: $blob" ;;
  esac
done
echo "driver: scale refusal"

step "int fifo" "$DUR_FAST" -- mkfifo "$WORK/int.fifo"
step "int out" "$DUR_FAST" -- bash -c ': > "$1"' bash "$WORK/int.out"
# A new session so SIGINT is delivered. The child closes the launch pipe.
int_pid=$(step "int launch" "$DUR_FAST" -- python3 - "$LIB" "$WORK/int.fifo" "$WORK/int.out" << 'PY'
import os, sys
lib, fifo, out = sys.argv[1:]
pid = os.fork()
if pid == 0:
    os.setsid()
    os.unsetenv("HEX0_STEP_MARK")
    null = os.open("/dev/null", os.O_RDWR)
    os.dup2(null, 1)
    os.dup2(null, 2)
    os.execv("/bin/bash", ["bash", "-c", ". \"$1\"; step \"int cat\" 30 -- cat \"$2\" >\"$3\" 2>&1", "bash", lib, fifo, out])
    os._exit(127)
print(pid)
PY
)
step "int pause" "$DUR_FAST" -- sleep 0.4
step "int signal" "$DUR_FAST" -- bash -c 'kill -INT "$1" 2>/dev/null || true' bash "$int_pid"
step "int settle" "$DUR_FAST" -- sleep 0.4
case $(<"$WORK/int.out") in
  *timed\ out*|*timed-out*) die "interrupt did not stop the step: $(<"$WORK/int.out")" ;;
esac
left=$(carry "int gone" "$DUR_FAST" bash -c 'ps -o args= -C cat; ps -o args= -C timeout; exit 0')
case $left in
  *"$WORK/int.fifo"*) die "interrupt left a step: $left" ;;
esac
echo "driver: interrupt stopped the step"

replay=$(expect "replay" "$DUR_FAST" "text:replay-token" -- bash -c 'echo replay-token; exit 1')
case $replay in
  *replay-token*) ;;
  *) die "replay lost the token: $replay" ;;
esac
echo "driver: replay kept the token"

# rune:complectens(helper) — prove_tree copies a sandbox tree and is not a comparison.
prove_tree() {
  local id=$1
  COPY=$WORK/$id
  step "prove rm $id" "$DUR_FAST" -- rm -rf "$COPY"
  sandbox_tree "$root" "$COPY"
}

prove_tree fatal
fail_copy=$COPY
write_stub "$fail_copy/tools/check/layout-mutants.sh" '#!/usr/bin/env bash
exit 1'
fail_sb=$WORK/fatal-sandbox
step "fail sb rm" "$DUR_FAST" -- rm -rf "$fail_sb"
blob=$(carry "driver fail" "$DUR_MODULE" env HEX0_DRIVER_TEST=1 HEX0_DRIVER_MARK="$MARK" HEX0_SANDBOX="$fail_sb" "$fail_copy/tools/verify.sh")
rc=$(payload_rc "$blob")
[ "$rc" != 0 ] || die "layout-mutants exit 1: driver exited 0"
case $blob in
  *tools/check/layout-mutants.sh*) ;;
  *) die "layout-mutants exit 1: stderr did not name the module: $blob" ;;
esac
echo "driver: layout-mutants exit 1 is fatal"

prove_tree hang
hang_copy=$COPY
step "hang stub" "$DUR_FAST" -- bash -c 'cat > "$1"; chmod 755 "$1"' bash "$hang_copy/tools/check/layout-mutants.sh" << 'EOF'
#!/usr/bin/env bash
set -u
here=${BASH_SOURCE[0]%/*}
case $here in
  /*) ;;
  *) here=$PWD/$here ;;
esac
. "$here/gate-lib.sh" || exit 2
step "hang fifo" "$DUR_FAST" -- mkfifo "$SANDBOX/never-event"
step "layout-mutants hang" 2 -- cat "$SANDBOX/never-event"
EOF
hang_sb=$WORK/hang-sandbox
step "hang sb rm" "$DUR_FAST" -- rm -rf "$hang_sb"
blob=$(carry "driver hang" "$DUR_MODULE" env HEX0_DRIVER_TEST=1 HEX0_DRIVER_MARK="$MARK" HEX0_SANDBOX="$hang_sb" "$hang_copy/tools/verify.sh")
rc=$(payload_rc "$blob")
[ "$rc" != 0 ] || die "hang: driver exited 0"
case $blob in
  *timed\ out*|*timed-out*) ;;
  *) die "hang: stderr did not say timed out: $blob" ;;
esac
case $blob in
  *layout-mutants*) ;;
  *) die "hang: stderr did not name the module: $blob" ;;
esac
echo "driver: layout-mutants hang timed out"

prove_tree nonhost
host_copy=$COPY
write_stub "$host_copy/tools/check/layout-mutants.sh" '#!/usr/bin/env bash
exit 0'
write_stub "$host_copy/tools/check/seed-audit.sh" '#!/usr/bin/env bash
exit 0'
write_stub "$host_copy/tools/check/hex0-contract.sh" '#!/usr/bin/env bash
exit 0'
step "aarch64 dir" "$DUR_FAST" -- mkdir -p "$host_copy/ladder/0-hex0/aarch64-linux"
step "aarch64 src" "$DUR_FAST" -- bash -c 'printf "%s\n" "41 # one byte" > "$1"' bash "$host_copy/ladder/0-hex0/aarch64-linux/hex0.hex0"
host_sb=$WORK/nonhost-sandbox
step "host sb rm" "$DUR_FAST" -- rm -rf "$host_sb"
blob=$(carry "driver nonhost" "$DUR_MODULE" env HEX0_DRIVER_TEST=1 HEX0_DRIVER_MARK="$MARK" HEX0_SANDBOX="$host_sb" "$host_copy/tools/verify.sh")
rc=$(payload_rc "$blob")
[ "$rc" = 0 ] || die "non-host target: driver rc $rc $blob"
case $blob in
  *'aarch64-linux: not executed on this host'*) ;;
  *) die "non-host target stayed silent: $blob" ;;
esac
case $blob in
  *'driver-test: skipped'*) ;;
  *) die "driver-test skip was silent: $blob" ;;
esac
echo "driver: non-host target is not executed"
echo "driver-test: skipped on the nested run"
exit 0
