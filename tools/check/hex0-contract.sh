#!/usr/bin/env bash
# tools/check/hex0-contract.sh TARGET_DIR SANDBOX
# Rows 3-8, 12-15 for the host target. Both paths are absolute.
# rune:circumspicere(phantom) — since Linux 5.18 an empty argv is replaced by {""}, so this row cannot observe argc 0.
set -u
export PYTHONDONTWRITEBYTECODE=1
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

[ $# -eq 2 ] || die "hex0-contract: want TARGET_DIR SANDBOX"
TARGET=$(abs_req "$1")
SANDBOX=$(under_tmp "$2")
export SANDBOX HEX0_SCRATCH=$SANDBOX
HEX0=$TARGET/hex0
SRC=$TARGET/hex0.hex0
RUNG=${TARGET%/*}
TESTS=$RUNG/tests
GATE=$TARGET/gate.tsv
CALLS=$TARGET/syscalls.tsv
PY=$root/tools/check
product=$root/out
step "contract out" "$DUR_FAST" -- mkdir -p "$product"

IN_FD=$(fact "$GATE" in_fd)
OUT_FD=$(fact "$GATE" out_fd)
TRUNC_OLD=$(fact "$GATE" trunc_fchmod_then_ftruncate)
TRUNC_NEW=$(fact "$GATE" trunc_ftruncate_then_fchmod)

want_rc() {
  local label=$1 want=$2 blob rc
  shift 2
  blob=$(carry "$label" "$DUR_FAST" "$@")
  rc=$(payload_rc "$blob")
  if [ "$rc" != "$want" ]; then
    echo "$label rc $rc" >&2
    printf '%s\n' "$(payload_body "$blob")" >&2
    exit 1
  fi
}

file_mode() {
  step "mode $1" "$DUR_FAST" -- stat -c %a "$2"
}

same_file() {
  local blob rc
  blob=$(carry "cmp $1" "$DUR_FAST" cmp -s "$2" "$3")
  rc=$(payload_rc "$blob")
  [ "$rc" = 0 ]
}

assert_out() {
  local label=$1 path=$2 exp=$3 mode
  if [ "$exp" = missing ]; then
    if [ -e "$path" ]; then
      echo "$label exists" >&2
      exit 1
    fi
    return 0
  fi
  [ -f "$path" ] || die "$label is not a file"
  mode=$(file_mode "$label" "$path")
  if [ "$exp" = same ]; then
    [ "$mode" = 640 ] || die "$label mode $mode"
    same_file "$label" "$path" "$SANDBOX/olddata" || die "$label bytes"
    return 0
  fi
  if [ "$exp" = "samebytes:755" ]; then
    [ "$mode" = 755 ] || die "$label mode $mode"
    same_file "$label" "$path" "$SANDBOX/olddata" || die "$label bytes"
    return 0
  fi
  [ "$mode" = 755 ] || die "$label mode $mode"
  if [ "$exp" = empty ]; then
    [ ! -s "$path" ] || die "$label not empty"
    return 0
  fi
  local want=${exp#file:}
  same_file "$label" "$path" "$want" || die "$label bytes"
}

pair() {
  local label=$1 want=$2 src=$3 abs_exp=$4 pre_exp=$5
  local abs=$SANDBOX/abs-$label
  local pre=$SANDBOX/pre-$label
  step "pair rm $label" "$DUR_FAST" -- rm -f "$abs"
  step "pair cp $label" "$DUR_FAST" -- cp "$SANDBOX/olddata" "$pre"
  step "pair mode $label" "$DUR_FAST" -- chmod 640 "$pre"
  want_rc "row 7 $label absent" "$want" "$HEX0" "$src" "$abs"
  assert_out "$label absent" "$abs" "$abs_exp"
  want_rc "row 7 $label pre" "$want" "$HEX0" "$src" "$pre"
  assert_out "$label pre" "$pre" "$pre_exp"
  echo "row 7: $label exit $want"
}

row3_same() {
  local blob rc
  blob=$(carry "row 3 cmp" "$DUR_FAST" cmp -s "$1" "$2")
  rc=$(payload_rc "$blob")
  if [ "$rc" != 0 ]; then
    echo "row 3: bytes differ" >&2
    exit 1
  fi
  echo "row 3: cmp identical, exit 0"
}

row4_status() {
  local blob rc
  blob=$(carry "row 4 run" "$DUR_FAST" "$1")
  rc=$(payload_rc "$blob")
  if [ "$rc" != 42 ]; then
    echo "row 4: status $rc" >&2
    exit 1
  fi
  echo "row 4: cmp identical, exit 42"
}

row4_bytes() {
  local blob rc
  blob=$(carry "row 4 cmp" "$DUR_FAST" cmp -s "$1" "$2")
  rc=$(payload_rc "$blob")
  if [ "$rc" != 0 ]; then
    echo "row 4: bytes differ" >&2
    exit 1
  fi
}

row8_check() {
  local blob rc body
  blob=$(carry "row 8 syscalls" "$DUR_CMD" python3 "$PY/syscalls-check.py" "$1" "$2")
  rc=$(payload_rc "$blob")
  body=$(payload_body "$blob")
  if [ "$rc" != 0 ]; then
    printf '%s\n' "$body" >&2
    exit 1
  fi
  printf '%s\n' "$body"
}

seed_hash=$(step "seed hash" "$DUR_FAST" -- sha256sum "$HEX0")
seed_hash=${seed_hash%% *}
printf 'OLDDATA' > "$SANDBOX/olddata"

want_rc "row 3 run" 0 "$HEX0" "$SRC" "$product/h1"
row3_same "$product/h1" "$HEX0"
capture_red "mutant row 3 (bytes)" "row 3: bytes differ" row3_same "$HEX0" "$SANDBOX/olddata"

step "row 8 strace" "$DUR_CMD" -- strace -f -o "$SANDBOX/trace" "$HEX0" "$SRC" "$product/h1str"
same_file "row 8" "$product/h1str" "$HEX0" || die "row 8 cmp"
row8_check "$SANDBOX/trace" "$CALLS"
step "row 8 socket copy" "$DUR_FAST" -- cp "$SANDBOX/trace" "$SANDBOX/trace-socket"
step "row 8 socket append" "$DUR_FAST" -- bash -c 'printf "%s\n" "0 socket(2, 1, 0) = 3" >> "$1"' bash "$SANDBOX/trace-socket"
capture_red "mutant row 8 (extra syscall)" "row 8: unexpected" row8_check "$SANDBOX/trace-socket" "$CALLS"
step "row 8 exec copy" "$DUR_FAST" -- cp "$SANDBOX/trace" "$SANDBOX/trace-exec"
step "row 8 exec append" "$DUR_FAST" -- bash -c 'printf "%s\n" "execve(\"/bin/sh\", [\"sh\"], 0) = 0" >> "$1"' bash "$SANDBOX/trace-exec"
capture_red "mutant row 8 (second execve)" "row 8: execve count" row8_check "$SANDBOX/trace-exec" "$CALLS"

step "row 4 digits" "$DUR_CMD" -- python3 "$PY/hex-check.py" --digits "$TESTS/exit42.hex0" >"$SANDBOX/probe.hex"
step "row 4 xxd" "$DUR_FAST" -- xxd -r -p "$SANDBOX/probe.hex" >"$SANDBOX/probe.bin"
want_rc "row 4 build" 0 "$HEX0" "$TESTS/exit42.hex0" "$product/exit42"
row4_bytes "$product/exit42" "$SANDBOX/probe.bin"
row4_status "$product/exit42"
capture_red "mutant row 4 (status)" "row 4: status" row4_status /bin/true

mode=$(file_mode "row 5" "$product/exit42")
[ "$mode" = "755" ] || die "row 5 mode $mode"
echo "row 5: $mode"
printf 'old-contents' > "$SANDBOX/old-contents"
step "row 5 cp" "$DUR_FAST" -- cp "$SANDBOX/old-contents" "$SANDBOX/pre600"
step "row 5 mode" "$DUR_FAST" -- chmod 600 "$SANDBOX/pre600"
want_rc "row 5 preexist" 0 "$HEX0" "$TESTS/exit42.hex0" "$SANDBOX/pre600"
mode=$(file_mode "row 5 pre" "$SANDBOX/pre600")
[ "$mode" = "755" ] || die "row 5 preexist mode $mode"
same_file "row 5 preexist" "$SANDBOX/pre600" "$SANDBOX/probe.bin" || die "row 5 preexist bytes"
echo "row 5: preexist 600 is 755"

fix_ok() {
  local src=$1 exp=$2 name=$3 mode
  step "row 6 rm $name" "$DUR_FAST" -- rm -f "$SANDBOX/$name"
  want_rc "row 6 $name" 0 "$HEX0" "$src" "$SANDBOX/$name"
  same_file "row 6 $name" "$SANDBOX/$name" "$exp" || die "row 6 $name bytes"
  mode=$(file_mode "row 6 $name" "$SANDBOX/$name")
  [ "$mode" = "755" ] || die "row 6 $name mode $mode"
  echo "row 6: $name exit 0"
}

printf '\253' > "$SANDBOX/exp-lower"
printf 'J' > "$SANDBOX/exp-upper"
printf 'B' > "$SANDBOX/exp-comments"
printf 'A' > "$SANDBOX/exp-one"
printf 'AB' > "$SANDBOX/exp-two"
fix_ok "$TESTS/lower.hex0" "$SANDBOX/exp-lower" lower
fix_ok "$TESTS/upper.hex0" "$SANDBOX/exp-upper" upper
fix_ok "$TESTS/crlf.hex0" "$SANDBOX/exp-one" crlf
fix_ok "$TESTS/eof-comment.hex0" "$SANDBOX/exp-one" eof
fix_ok "$TESTS/comments.hex0" "$SANDBOX/exp-comments" comments
fix_ok "$TESTS/split.hex0" "$SANDBOX/exp-one" split
fix_ok "$TESTS/comment-nibble.hex0" "$SANDBOX/exp-one" comment-nibble
fix_ok "$TESTS/comment-cr.hex0" "$SANDBOX/exp-two" comment-cr
fix_ok "$TESTS/comment-tab.hex0" "$SANDBOX/exp-two" comment-tab
fix_ok "$TESTS/comment-high.hex0" "$SANDBOX/exp-two" comment-high
fix_ok "$TESTS/crlf-two.hex0" "$SANDBOX/exp-two" crlf-two

step "argc0 src" "$DUR_FAST" -- bash -c 'cat > "$1"' bash "$SANDBOX/argc0.c" << 'EOF'
#include <unistd.h>
int main(int argc, char **argv) {
  char *av[] = {0};
  (void)argc;
  execv(argv[1], av);
  return 99;
}
EOF
step "argc1 src" "$DUR_FAST" -- bash -c 'cat > "$1"' bash "$SANDBOX/argc1.c" << 'EOF'
#include <unistd.h>
int main(int argc, char **argv) {
  char *av[] = {argv[1], 0};
  (void)argc;
  execv(argv[1], av);
  return 99;
}
EOF
step "argc0 gcc" "$DUR_CMD" -- gcc -O2 -o "$SANDBOX/argc0" "$SANDBOX/argc0.c"
step "argc1 gcc" "$DUR_CMD" -- gcc -O2 -o "$SANDBOX/argc1" "$SANDBOX/argc1.c"
want_rc "row 7 empty argv" 1 "$SANDBOX/argc0" "$HEX0"
echo "row 7: empty argv exit 1"
want_rc "row 7 argc 1" 1 "$SANDBOX/argc1" "$HEX0"
echo "row 7: argc 1 exit 1"

step "one path cp" "$DUR_FAST" -- cp "$SANDBOX/olddata" "$SANDBOX/one-path"
step "one path mode" "$DUR_FAST" -- chmod 640 "$SANDBOX/one-path"
want_rc "row 7 one path" 1 "$HEX0" "$SANDBOX/one-path"
same_file "one path" "$SANDBOX/one-path" "$SANDBOX/olddata" || die "row 7 one path bytes"
mode=$(file_mode "one path" "$SANDBOX/one-path")
[ "$mode" = 640 ] || die "row 7 one path mode $mode"
echo "row 7: one path exit 1"

step "argc4 rm" "$DUR_FAST" -- rm -f "$SANDBOX/abs-argc4"
step "argc4 cp" "$DUR_FAST" -- cp "$SANDBOX/olddata" "$SANDBOX/pre-argc4"
step "argc4 mode" "$DUR_FAST" -- chmod 640 "$SANDBOX/pre-argc4"
want_rc "row 7 argc 4 absent" 1 "$HEX0" "$TESTS/lower.hex0" "$SANDBOX/abs-argc4" extra
assert_out "argc 4 absent" "$SANDBOX/abs-argc4" missing
want_rc "row 7 argc 4 pre" 1 "$HEX0" "$TESTS/lower.hex0" "$SANDBOX/pre-argc4" extra
assert_out "argc 4 pre" "$SANDBOX/pre-argc4" same
echo "row 7: argc 4 exit 1"

pair "missing IN" 2 "$SANDBOX/missing-in" missing same
pair G 4 "$TESTS/bad-g.hex0" empty empty
pair vt 4 "$TESTS/vt.hex0" empty empty
pair ff 4 "$TESTS/ff.hex0" empty empty
pair reject-2f 4 "$TESTS/reject-2f.hex0" "file:$SANDBOX/exp-one" "file:$SANDBOX/exp-one"
pair reject-40 4 "$TESTS/reject-40.hex0" "file:$SANDBOX/exp-one" "file:$SANDBOX/exp-one"
pair reject-80 4 "$TESTS/reject-80.hex0" "file:$SANDBOX/exp-one" "file:$SANDBOX/exp-one"
pair reject-ff 4 "$TESTS/reject-ff.hex0" "file:$SANDBOX/exp-one" "file:$SANDBOX/exp-one"
pair odd 5 "$TESTS/odd.hex0" empty empty
pair odd-after 5 "$TESTS/odd-after.hex0" "file:$SANDBOX/exp-one" "file:$SANDBOX/exp-one"

step "missing dir rm" "$DUR_FAST" -- rm -rf "$SANDBOX/absent-dir"
want_rc "row 7 missing dir" 3 "$HEX0" "$TESTS/lower.hex0" "$SANDBOX/absent-dir/out"
[ ! -e "$SANDBOX/absent-dir/out" ] || die "row 7 missing dir created"
echo "row 7: missing OUT directory exit 3, absent stays absent"

dev_before=$(file_mode "dev before" /dev/null)
want_rc "row 7 non-regular" 3 "$HEX0" "$TESTS/lower.hex0" /dev/null
dev_after=$(file_mode "dev after" /dev/null)
[ "$dev_before" = "$dev_after" ] || die "row 7 /dev/null mode $dev_before to $dev_after"
echo "row 7: non-regular exit 3, mode unchanged"

want_rc "row 7 same device" 7 "$HEX0" /dev/null /dev/null
echo "row 7: same device exit 7"

step "fifo none" "$DUR_FAST" -- mkfifo "$SANDBOX/fifo-none"
fifo_mode=$(file_mode "fifo none" "$SANDBOX/fifo-none")
want_rc "row 7 fifo none" 3 "$HEX0" "$TESTS/lower.hex0" "$SANDBOX/fifo-none"
mode=$(file_mode "fifo none after" "$SANDBOX/fifo-none")
[ "$mode" = "$fifo_mode" ] || die "row 7 fifo none mode"
echo "row 7: fifo with no reader exit 3, mode unchanged"

step "fifo reader mk" "$DUR_FAST" -- mkfifo "$SANDBOX/fifo-reader"
fifo_mode=$(file_mode "fifo reader" "$SANDBOX/fifo-reader")
blob=$(carry "row 7 fifo reader" "$DUR_FAST" bash -c 'exec 3<>"$1"; "$2" "$3" "$1"; printf "inner:%s\n" "$?"' bash "$SANDBOX/fifo-reader" "$HEX0" "$TESTS/lower.hex0")
case $blob in
  *inner:3*) ;;
  *) die "row 7 fifo reader $blob" ;;
esac
mode=$(file_mode "fifo reader after" "$SANDBOX/fifo-reader")
[ "$mode" = "$fifo_mode" ] || die "row 7 fifo reader mode"
echo "row 7: fifo with a reader exit 3, mode unchanged"

step "ro cp" "$DUR_FAST" -- cp "$SANDBOX/olddata" "$SANDBOX/ro"
step "ro mode" "$DUR_FAST" -- chmod 444 "$SANDBOX/ro"
want_rc "row 7 read-only" 3 "$HEX0" "$SANDBOX/ro" "$SANDBOX/ro"
same_file "read-only" "$SANDBOX/ro" "$SANDBOX/olddata" || die "row 7 read-only bytes"
mode=$(file_mode "read-only" "$SANDBOX/ro")
[ "$mode" = 444 ] || die "row 7 read-only mode $mode"
echo "row 7: read-only same file exit 3, unchanged"

step "same cp" "$DUR_FAST" -- cp "$SANDBOX/olddata" "$SANDBOX/same"
step "same mode" "$DUR_FAST" -- chmod 640 "$SANDBOX/same"
want_rc "row 7 same path" 7 "$HEX0" "$SANDBOX/same" "$SANDBOX/same"
assert_out "same path" "$SANDBOX/same" same
echo "row 7: same path exit 7"

printf '41 extra\n' > "$SANDBOX/hard.want"
step "hard cp" "$DUR_FAST" -- cp "$SANDBOX/hard.want" "$SANDBOX/hard"
step "hard mode" "$DUR_FAST" -- chmod 640 "$SANDBOX/hard"
step "hard link" "$DUR_FAST" -- ln "$SANDBOX/hard" "$SANDBOX/hard.link"
want_rc "row 7 hard link" 7 "$HEX0" "$SANDBOX/hard" "$SANDBOX/hard.link"
same_file "hard link" "$SANDBOX/hard" "$SANDBOX/hard.want" || die "row 7 hard link bytes"
mode=$(file_mode "hard link" "$SANDBOX/hard")
[ "$mode" = 640 ] || die "row 7 hard link mode $mode"
echo "row 7: hard link exit 7"

printf '41\n' > "$SANDBOX/sym.want"
step "sym cp" "$DUR_FAST" -- cp "$SANDBOX/sym.want" "$SANDBOX/sym.target"
step "sym mode" "$DUR_FAST" -- chmod 640 "$SANDBOX/sym.target"
step "sym link" "$DUR_FAST" -- ln -s sym.target "$SANDBOX/sym.link"
want_rc "row 7 symlink" 7 "$HEX0" "$SANDBOX/sym.target" "$SANDBOX/sym.link"
same_file "symlink" "$SANDBOX/sym.target" "$SANDBOX/sym.want" || die "row 7 symlink bytes"
mode=$(file_mode "symlink" "$SANDBOX/sym.target")
[ "$mode" = 640 ] || die "row 7 symlink mode $mode"
echo "row 7: symlink exit 7"

step "absent same rm" "$DUR_FAST" -- rm -f "$SANDBOX/absent-same"
want_rc "row 7 absent same" 2 "$HEX0" "$SANDBOX/absent-same" "$SANDBOX/absent-same"
[ ! -e "$SANDBOX/absent-same" ] || die "row 7 absent same created"
echo "row 7: absent same path exit 2"

pair "directory IN" 6 "$RUNG" empty empty

step "fault gcc" "$DUR_CMD" -- gcc -O2 -o "$SANDBOX/fault" "$PY/fault.c"
expect "fault nth range" "$DUR_FAST" 93 -- "$SANDBOX/fault" 1 3 1 4294967297 /bin/true
expect "fault nr range" "$DUR_FAST" 93 -- "$SANDBOX/fault" 4294967296 3 1 1 /bin/true
expect "fault errno range" "$DUR_FAST" 93 -- "$SANDBOX/fault" 0 3 65536 1 /bin/true
echo "fault: range checks exit 93"

step "fd300 src" "$DUR_FAST" -- bash -c 'cat > "$1"' bash "$SANDBOX/fd300.c" << 'EOF'
#include <fcntl.h>
int main(void) {
  if (fcntl(300, F_GETFD) != -1) {
    return 2;
  }
  return 0;
}
EOF
# Static so the NTH-1 read filter is not the dynamic linker's read of libc.
step "fd300 gcc" "$DUR_CMD" -- gcc -O2 -static -o "$SANDBOX/fd300" "$SANDBOX/fd300.c"
step "fd300 run" "$DUR_FAST" -- bash -c 'ulimit -n 524288 || exit 97; exec 300<>/dev/null; exec "$1" 0 -1 1 1 "$2"' bash "$SANDBOX/fault" "$SANDBOX/fd300"
echo "fault: close_range closed fd 300"

step "sigterm src" "$DUR_FAST" -- bash -c 'cat > "$1"' bash "$SANDBOX/sigterm.c" << 'EOF'
#include <signal.h>
#include <unistd.h>
int main(void) {
  signal(SIGTERM, SIG_DFL);
  raise(SIGTERM);
  return 0;
}
EOF
step "sigterm gcc" "$DUR_CMD" -- gcc -O2 -static -o "$SANDBOX/sigterm" "$SANDBOX/sigterm.c"
expect "fault signal" "$DUR_FAST" 143 -- "$SANDBOX/fault" 0 -1 1 2 "$SANDBOX/sigterm"
echo "fault: signal re-injected"

fault_both() {
  local label=$1 nr=$2 fd=$3 nth=$4 want=$5 abs_exp=$6 pre_exp=$7
  local src=$SANDBOX/fin
  local abs=$SANDBOX/fabs-$label
  local pre=$SANDBOX/fpre-$label
  local ctl=$SANDBOX/fctl-$label
  printf '4142\n' > "$src"
  step "fault rm $label" "$DUR_FAST" -- rm -f "$abs"
  step "fault cp $label" "$DUR_FAST" -- cp "$SANDBOX/olddata" "$pre"
  step "fault mode $label" "$DUR_FAST" -- chmod 640 "$pre"
  want_rc "row 13 $label absent" "$want" "$SANDBOX/fault" "$nr" "$fd" 1 "$nth" "$HEX0" "$src" "$abs"
  assert_out "row 13 $label absent" "$abs" "$abs_exp"
  want_rc "row 13 $label pre" "$want" "$SANDBOX/fault" "$nr" "$fd" 1 "$nth" "$HEX0" "$src" "$pre"
  assert_out "row 13 $label pre" "$pre" "$pre_exp"
  step "fault ctl rm $label" "$DUR_FAST" -- rm -f "$ctl"
  step "fault ctl cp $label" "$DUR_FAST" -- cp "$SANDBOX/olddata" "$ctl"
  step "fault ctl mode $label" "$DUR_FAST" -- chmod 640 "$ctl"
  want_rc "row 13 $label control" 0 "$HEX0" "$src" "$ctl"
  assert_out "row 13 $label control" "$ctl" "file:$SANDBOX/exp-two"
  echo "row 13: $label exit $want, control 0"
}

fault_both "fstat IN" "$(nr_of "$CALLS" fstat)" "$IN_FD" 1 2 empty same
fault_both "fstat OUT" "$(nr_of "$CALLS" fstat)" "$OUT_FD" 1 3 empty same
fault_both fchmod "$(nr_of "$CALLS" fchmod)" "$OUT_FD" 1 3 empty same
fault_both read "$(nr_of "$CALLS" read)" -1 1 6 empty empty
fault_both write "$(nr_of "$CALLS" write)" -1 1 6 empty empty
fault_both close "$(nr_of "$CALLS" close)" -1 1 6 "file:$SANDBOX/exp-two" "file:$SANDBOX/exp-two"
fault_both ftruncate "$(nr_of "$CALLS" ftruncate)" -1 1 6 empty "samebytes:755"
printf 'A' > "$SANDBOX/exp-a"
fault_both "write after a byte" "$(nr_of "$CALLS" write)" -1 2 6 "file:$SANDBOX/exp-a" "file:$SANDBOX/exp-a"
fault_both "read after bytes" "$(nr_of "$CALLS" read)" -1 5 6 "file:$SANDBOX/exp-two" "file:$SANDBOX/exp-two"

step "trunc build" "$DUR_FAST" -- python3 - "$HEX0" "$SANDBOX/trunc-first" "$TRUNC_OLD" "$TRUNC_NEW" << 'PY'
import sys
old = bytes.fromhex(sys.argv[3])
new = bytes.fromhex(sys.argv[4])
data = open(sys.argv[1], "rb").read()
found = data.count(old)
if found != 1:
    sys.stderr.write("trunc mutant: pattern found %d times\n" % found)
    sys.exit(2)
open(sys.argv[2], "wb").write(data.replace(old, new, 1))
PY
step "trunc mode" "$DUR_FAST" -- chmod 755 "$SANDBOX/trunc-first"
step "trunc cp" "$DUR_FAST" -- cp "$SANDBOX/olddata" "$SANDBOX/trunc-pre"
step "trunc chmod" "$DUR_FAST" -- chmod 640 "$SANDBOX/trunc-pre"
printf '41\n' > "$SANDBOX/trunc-in"
blob=$(carry "trunc mutant" "$DUR_FAST" "$SANDBOX/fault" "$(nr_of "$CALLS" fchmod)" "$OUT_FD" 1 1 "$SANDBOX/trunc-first" "$SANDBOX/trunc-in" "$SANDBOX/trunc-pre")
rc=$(payload_rc "$blob")
mode=$(file_mode "trunc" "$SANDBOX/trunc-pre")
if [ "$rc" -ne 3 ] || [ "$mode" != 640 ] || same_file "trunc" "$SANDBOX/trunc-pre" "$SANDBOX/olddata"; then
  die "mutant trunc-before-fchmod rc $rc mode $mode"
fi
echo "mutant trunc-before-fchmod: red (rc 3, mode 640, bytes truncated)"

step "sig big" "$DUR_FAST" -- python3 -c 'import sys; sys.stdout.buffer.write(b"00\n"*2000)' >"$SANDBOX/big.hex0"
step "sig src" "$DUR_FAST" -- bash -c 'cat > "$1"' bash "$SANDBOX/sigxfsz.c" << 'EOF'
#include <signal.h>
#include <unistd.h>
#include <sys/resource.h>
int main(int argc, char **argv) {
  struct rlimit lim;
  (void)argc;
  if (argv[1][0] == 'd') {
    signal(SIGXFSZ, SIG_DFL);
  } else {
    signal(SIGXFSZ, SIG_IGN);
  }
  lim.rlim_cur = 1024;
  lim.rlim_max = 1024;
  setrlimit(RLIMIT_FSIZE, &lim);
  execv(argv[2], argv + 2);
  return 99;
}
EOF
step "sig gcc" "$DUR_CMD" -- gcc -O2 -o "$SANDBOX/sigxfsz" "$SANDBOX/sigxfsz.c"
step "sig rm" "$DUR_FAST" -- rm -f "$SANDBOX/sig-dfl.out" "$SANDBOX/sig-ign.out"
blob=$(carry "row 14 sigxfsz" "$DUR_CMD" bash -c 'ulimit -c 0; printf "core:%s\n" "$(ulimit -c)"; "$1" dfl "$2" "$3" "$4"; printf "inner:%s\n" "$?"' bash "$SANDBOX/sigxfsz" "$HEX0" "$SANDBOX/big.hex0" "$SANDBOX/sig-dfl.out")
case $blob in
  *core:0*inner:153*) echo "row 14: SIGXFSZ default exit 153, RLIMIT_CORE 0" ;;
  *) die "row 14 SIGXFSZ $blob" ;;
esac
blob=$(carry "row 15 sigxfsz" "$DUR_FAST" bash -c '"$1" ign "$2" "$3" "$4"; printf "inner:%s\n" "$?"' bash "$SANDBOX/sigxfsz" "$HEX0" "$SANDBOX/big.hex0" "$SANDBOX/sig-ign.out")
case $blob in
  *inner:6*) ;;
  *) die "row 15 SIGXFSZ $blob" ;;
esac
kept=$(step "row 15 bytes" "$DUR_FAST" -- wc -c "$SANDBOX/sig-ign.out")
kept=${kept%% *}
[ "$kept" = 1024 ] || die "row 15 SIGXFSZ kept $kept"
echo "row 15: SIGXFSZ ignored exit 6, 1024 bytes kept"

fuzz=$(step "row 12 fuzz" "$DUR_LONG" -- python3 "$PY/fuzz-hex0.py" "$HEX0" 2000 "$SANDBOX" "$GATE")
echo "$fuzz"
status_mut=$(step "row 12 status mutant" "$DUR_LONG" -- python3 "$PY/fuzz-hex0.py" --expect-disagree "$HEX0" 2000 "$SANDBOX" "$GATE")
echo "$status_mut"
letter_mut=$(step "row 12 letter mutant" "$DUR_LONG" -- python3 "$PY/fuzz-hex0.py" --expect-letter-offset "$HEX0" 2000 "$SANDBOX" "$GATE")
echo "$letter_mut"
now_hash=$(step "seed hash after" "$DUR_FAST" -- sha256sum "$HEX0")
now_hash=${now_hash%% *}
[ "$now_hash" = "$seed_hash" ] || die "row 12 seed changed"
echo "row 12: fuzz ok"
exit 0
