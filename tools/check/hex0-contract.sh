#!/usr/bin/env bash
# tools/check/hex0-contract.sh <hex0> <target-src> <tests> <sandbox>
# Rows 3-8, 12 and 13 for one target this host can execute.
# Syscall numbers, fds, and the trunc-mutant bytes come from the target.
set -u
export PYTHONDONTWRITEBYTECODE=1
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd) || exit 2
# shellcheck source=tools/check/gate-lib.sh
. "$root/tools/check/gate-lib.sh" || exit 2
cd "$root" || exit 2
umask 0022

[ $# -eq 4 ] || die "hex0-contract: want HEX0 SRC TESTS SANDBOX"
HEX0=$1
SRC=$2
TESTS=$3
SANDBOX=$4
case $HEX0 in
  /*) ;;
  *) HEX0=$root/$HEX0 ;;
esac
RUNG=$(dirname "$TESTS")
TARGET=$(dirname "$SRC")
mkdir -p "$SANDBOX" out
export SANDBOX
export HEX0_SCRATCH=$SANDBOX

seed_hash=$(sha256sum "$HEX0" | awk 'NR==1 {print $1}')

nr_of() {
  awk -v k="$1" '$1==k {print $2}' "$TARGET/syscalls.tsv"
}
fact() {
  awk -v k="$1" '$1==k {print $2}' "$TARGET/gate.tsv"
}
IN_FD=$(fact in_fd)
OUT_FD=$(fact out_fd)

expect_rc() {
  local label=$1 want=$2
  shift 2
  local rc=0
  run_status "$DUR_FAST" -- "$@" || rc=$?
  if timed_out "$rc"; then
    die "$label timed out"
  fi
  [ "$rc" -eq "$want" ] || die "$label rc $rc"
}

assert_out() {
  local label=$1 path=$2 exp=$3
  local mode
  if [ "$exp" = missing ]; then
    [ ! -e "$path" ] || die "$label exists"
    return
  fi
  [ -f "$path" ] || die "$label is not a file"
  mode=$(stat -c %a "$path")
  if [ "$exp" = same ]; then
    [ "$mode" = 640 ] || die "$label mode $mode"
    cmp -s "$path" "$SANDBOX/olddata" || die "$label bytes"
    return
  fi
  if [ "$exp" = "samebytes:755" ]; then
    [ "$mode" = 755 ] || die "$label mode $mode"
    cmp -s "$path" "$SANDBOX/olddata" || die "$label bytes"
    return
  fi
  [ "$mode" = 755 ] || die "$label mode $mode"
  if [ "$exp" = empty ]; then
    [ ! -s "$path" ] || die "$label not empty"
    return
  fi
  local want=${exp#file:}
  cmp -s "$path" "$want" || die "$label bytes"
}

pair() {
  local label=$1 want=$2 src=$3 abs_exp=$4 pre_exp=$5
  local abs=$SANDBOX/abs-$label
  local pre=$SANDBOX/pre-$label
  rm -f "$abs"
  cp "$SANDBOX/olddata" "$pre"
  chmod 640 "$pre"
  expect_rc "row 7 $label absent" "$want" "$HEX0" "$src" "$abs"
  assert_out "$label absent" "$abs" "$abs_exp"
  expect_rc "row 7 $label pre" "$want" "$HEX0" "$src" "$pre"
  assert_out "$label pre" "$pre" "$pre_exp"
  echo "row 7: $label exit $want"
}

check "row 3" "$DUR_FAST" -- "$HEX0" "$SRC" out/h1
cmp -s out/h1 "$HEX0" || die "row 3 cmp"
echo "row 3: cmp identical, exit 0"

check "row 8 strace" "$DUR_CMD" -- strace -f -o "$SANDBOX/trace" "$HEX0" "$SRC" out/h1str
cmp -s out/h1str "$HEX0" || die "row 8 cmp"
check "row 8 syscalls" "$DUR_CMD" -- python3 tools/check/syscalls-check.py "$SANDBOX/trace" "$TARGET/syscalls.tsv" >"$SANDBOX/sys.out"
cat "$SANDBOX/sys.out"
cp "$SANDBOX/trace" "$SANDBOX/trace-mut"
printf '0 socket(2, 1, 0) = 3\n' >> "$SANDBOX/trace-mut"
rc=0
run_status "$DUR_CMD" -- python3 tools/check/syscalls-check.py "$SANDBOX/trace-mut" "$TARGET/syscalls.tsv" >"$SANDBOX/sys-mut.out" 2>"$SANDBOX/sys-mut.err" || rc=$?
if timed_out "$rc"; then
  die "mutant row 8 timed out"
fi
[ "$rc" -ne 0 ] || die "mutant row 8 stayed green"
grep -q 'unexpected socket' "$SANDBOX/sys-mut.err" || die "mutant row 8 said $(cat "$SANDBOX/sys-mut.err")"
echo "mutant row 8 (extra syscall): red"

check "row 4 digits" "$DUR_CMD" -- python3 tools/check/hex-check.py --digits "$TESTS/exit42.hex0" >"$SANDBOX/probe.hex"
check "row 4 xxd" "$DUR_FAST" -- xxd -r -p "$SANDBOX/probe.hex" >"$SANDBOX/probe.bin"
check "row 4 build" "$DUR_FAST" -- "$HEX0" "$TESTS/exit42.hex0" out/exit42
cmp -s out/exit42 "$SANDBOX/probe.bin" || die "row 4 cmp"
expect_rc "row 4 run" 42 out/exit42
echo "row 4: cmp identical, exit 42"

mode=$(stat -c %a out/exit42)
[ "$mode" = "755" ] || die "row 5 mode $mode"
echo "row 5: $mode"
printf 'old-contents' > "$SANDBOX/old-contents"
cp "$SANDBOX/old-contents" "$SANDBOX/pre600"
chmod 600 "$SANDBOX/pre600"
check "row 5 preexist" "$DUR_FAST" -- "$HEX0" "$TESTS/exit42.hex0" "$SANDBOX/pre600"
mode=$(stat -c %a "$SANDBOX/pre600")
[ "$mode" = "755" ] || die "row 5 preexist mode $mode"
cmp -s "$SANDBOX/pre600" "$SANDBOX/probe.bin" || die "row 5 preexist bytes"
echo "row 5: preexist 600 is 755"

fix_ok() {
  local src=$1 exp=$2 name=$3
  rm -f "$SANDBOX/$name"
  check "row 6 $name" "$DUR_FAST" -- "$HEX0" "$src" "$SANDBOX/$name"
  cmp -s "$SANDBOX/$name" "$exp" || die "row 6 $name bytes"
  mode=$(stat -c %a "$SANDBOX/$name")
  [ "$mode" = "755" ] || die "row 6 $name mode $mode"
  echo "row 6: $name exit 0"
}

printf 'OLDDATA' > "$SANDBOX/olddata"
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

cat > "$SANDBOX/argc0.c" << 'EOF'
#include <unistd.h>
int main(int argc, char **argv) {
  char *av[] = {0};
  execv(argv[1], av);
  return 99;
}
EOF
cat > "$SANDBOX/argc1.c" << 'EOF'
#include <unistd.h>
int main(int argc, char **argv) {
  char *av[] = {argv[1], 0};
  execv(argv[1], av);
  return 99;
}
EOF
check "argc0 gcc" "$DUR_CMD" -- gcc -O2 -o "$SANDBOX/argc0" "$SANDBOX/argc0.c"
check "argc1 gcc" "$DUR_CMD" -- gcc -O2 -o "$SANDBOX/argc1" "$SANDBOX/argc1.c"
expect_rc "row 7 argc 0" 1 "$SANDBOX/argc0" "$HEX0"
echo "row 7: argc 0 exit 1"
expect_rc "row 7 argc 1" 1 "$SANDBOX/argc1" "$HEX0"
echo "row 7: argc 1 exit 1"

cp "$SANDBOX/olddata" "$SANDBOX/one-path"
chmod 640 "$SANDBOX/one-path"
expect_rc "row 7 one path" 1 "$HEX0" "$SANDBOX/one-path"
cmp -s "$SANDBOX/one-path" "$SANDBOX/olddata" || die "row 7 one path bytes"
mode=$(stat -c %a "$SANDBOX/one-path")
[ "$mode" = 640 ] || die "row 7 one path mode $mode"
echo "row 7: one path exit 1"

rm -f "$SANDBOX/abs-argc4"
cp "$SANDBOX/olddata" "$SANDBOX/pre-argc4"
chmod 640 "$SANDBOX/pre-argc4"
expect_rc "row 7 argc 4 absent" 1 "$HEX0" "$TESTS/lower.hex0" "$SANDBOX/abs-argc4" extra
assert_out "argc 4 absent" "$SANDBOX/abs-argc4" missing
expect_rc "row 7 argc 4 pre" 1 "$HEX0" "$TESTS/lower.hex0" "$SANDBOX/pre-argc4" extra
assert_out "argc 4 pre" "$SANDBOX/pre-argc4" same
echo "row 7: argc 4 exit 1"

pair "missing IN" 2 "$SANDBOX/missing-in" missing same
pair G 4 "$TESTS/bad-g.hex0" empty empty
pair vt 4 "$TESTS/vt.hex0" empty empty
pair ff 4 "$TESTS/ff.hex0" empty empty
pair reject-2f 4 "$TESTS/reject-2f.hex0" file:"$SANDBOX/exp-one" file:"$SANDBOX/exp-one"
pair reject-40 4 "$TESTS/reject-40.hex0" file:"$SANDBOX/exp-one" file:"$SANDBOX/exp-one"
pair reject-80 4 "$TESTS/reject-80.hex0" file:"$SANDBOX/exp-one" file:"$SANDBOX/exp-one"
pair reject-ff 4 "$TESTS/reject-ff.hex0" file:"$SANDBOX/exp-one" file:"$SANDBOX/exp-one"
pair odd 5 "$TESTS/odd.hex0" empty empty
pair odd-after 5 "$TESTS/odd-after.hex0" file:"$SANDBOX/exp-one" file:"$SANDBOX/exp-one"

rm -rf "$SANDBOX/absent-dir"
expect_rc "row 7 missing dir" 3 "$HEX0" "$TESTS/lower.hex0" "$SANDBOX/absent-dir/out"
[ ! -e "$SANDBOX/absent-dir/out" ] || die "row 7 missing dir created"
echo "row 7: missing OUT directory exit 3, absent stays absent"

dev_before=$(stat -c %a /dev/null)
expect_rc "row 7 non-regular" 3 "$HEX0" "$TESTS/lower.hex0" /dev/null
dev_after=$(stat -c %a /dev/null)
[ "$dev_before" = "$dev_after" ] || die "row 7 /dev/null mode $dev_before to $dev_after"
echo "row 7: non-regular exit 3, mode unchanged"

expect_rc "row 7 same device" 7 "$HEX0" /dev/null /dev/null
echo "row 7: same device exit 7"

mkfifo "$SANDBOX/fifo-none"
fifo_mode=$(stat -c %a "$SANDBOX/fifo-none")
expect_rc "row 7 fifo none" 3 "$HEX0" "$TESTS/lower.hex0" "$SANDBOX/fifo-none"
[ "$(stat -c %a "$SANDBOX/fifo-none")" = "$fifo_mode" ] || die "row 7 fifo none mode"
echo "row 7: fifo with no reader exit 3, mode unchanged"

mkfifo "$SANDBOX/fifo-reader"
fifo_mode=$(stat -c %a "$SANDBOX/fifo-reader")
sleep 30 < "$SANDBOX/fifo-reader" &
fifo_reader=$!
expect_rc "row 7 fifo reader" 3 "$HEX0" "$TESTS/lower.hex0" "$SANDBOX/fifo-reader"
kill "$fifo_reader" 2>/dev/null || true
wait "$fifo_reader" 2>/dev/null || true
[ "$(stat -c %a "$SANDBOX/fifo-reader")" = "$fifo_mode" ] || die "row 7 fifo reader mode"
echo "row 7: fifo with a reader exit 3, mode unchanged"

cp "$SANDBOX/olddata" "$SANDBOX/ro"
chmod 444 "$SANDBOX/ro"
expect_rc "row 7 read-only" 3 "$HEX0" "$SANDBOX/ro" "$SANDBOX/ro"
cmp -s "$SANDBOX/ro" "$SANDBOX/olddata" || die "row 7 read-only bytes"
mode=$(stat -c %a "$SANDBOX/ro")
[ "$mode" = 444 ] || die "row 7 read-only mode $mode"
echo "row 7: read-only same file exit 3, unchanged"

cp "$SANDBOX/olddata" "$SANDBOX/same"
chmod 640 "$SANDBOX/same"
expect_rc "row 7 same path" 7 "$HEX0" "$SANDBOX/same" "$SANDBOX/same"
assert_out "same path" "$SANDBOX/same" same
echo "row 7: same path exit 7"
printf '41 extra\n' > "$SANDBOX/hard"
chmod 640 "$SANDBOX/hard"
ln "$SANDBOX/hard" "$SANDBOX/hard.link"
expect_rc "row 7 hard link" 7 "$HEX0" "$SANDBOX/hard" "$SANDBOX/hard.link"
cmp -s "$SANDBOX/hard" <(printf '41 extra\n') || die "row 7 hard link bytes"
mode=$(stat -c %a "$SANDBOX/hard")
[ "$mode" = 640 ] || die "row 7 hard link mode $mode"
echo "row 7: hard link exit 7"
printf '41\n' > "$SANDBOX/sym.target"
chmod 640 "$SANDBOX/sym.target"
ln -s sym.target "$SANDBOX/sym.link"
expect_rc "row 7 symlink" 7 "$HEX0" "$SANDBOX/sym.target" "$SANDBOX/sym.link"
cmp -s "$SANDBOX/sym.target" <(printf '41\n') || die "row 7 symlink bytes"
mode=$(stat -c %a "$SANDBOX/sym.target")
[ "$mode" = 640 ] || die "row 7 symlink mode $mode"
echo "row 7: symlink exit 7"
rm -f "$SANDBOX/absent-same"
expect_rc "row 7 absent same" 2 "$HEX0" "$SANDBOX/absent-same" "$SANDBOX/absent-same"
[ ! -e "$SANDBOX/absent-same" ] || die "row 7 absent same created"
echo "row 7: absent same path exit 2"

pair "directory IN" 6 "$RUNG" empty empty

check "fault gcc" "$DUR_CMD" -- gcc -O2 -o "$SANDBOX/fault" tools/check/fault.c

fault_both() {
  local label=$1 nr=$2 fd=$3 nth=$4 want=$5 abs_exp=$6 pre_exp=$7
  local src=$SANDBOX/fin
  local abs=$SANDBOX/fabs-$label
  local pre=$SANDBOX/fpre-$label
  local ctl=$SANDBOX/fctl-$label
  printf '4142\n' > "$src"
  rm -f "$abs"
  cp "$SANDBOX/olddata" "$pre"
  chmod 640 "$pre"
  expect_rc "row 13 $label absent" "$want" "$SANDBOX/fault" "$nr" "$fd" 1 "$nth" "$HEX0" "$src" "$abs"
  assert_out "row 13 $label absent" "$abs" "$abs_exp"
  expect_rc "row 13 $label pre" "$want" "$SANDBOX/fault" "$nr" "$fd" 1 "$nth" "$HEX0" "$src" "$pre"
  assert_out "row 13 $label pre" "$pre" "$pre_exp"
  rm -f "$ctl"
  cp "$SANDBOX/olddata" "$ctl"
  chmod 640 "$ctl"
  check "row 13 $label control" "$DUR_FAST" -- "$HEX0" "$src" "$ctl"
  assert_out "row 13 $label control" "$ctl" file:"$SANDBOX/exp-two"
  echo "row 13: $label exit $want, control 0"
}

fault_both "fstat IN" "$(nr_of fstat)" "$IN_FD" 1 2 empty same
fault_both "fstat OUT" "$(nr_of fstat)" "$OUT_FD" 1 3 empty same
fault_both fchmod "$(nr_of fchmod)" "$OUT_FD" 1 3 empty same
fault_both read "$(nr_of read)" -1 1 6 empty empty
fault_both write "$(nr_of write)" -1 1 6 empty empty
fault_both close "$(nr_of close)" -1 1 6 file:"$SANDBOX/exp-two" file:"$SANDBOX/exp-two"
fault_both ftruncate "$(nr_of ftruncate)" -1 1 6 empty "samebytes:755"
printf 'A' > "$SANDBOX/exp-a"
fault_both "write after a byte" "$(nr_of write)" -1 2 6 file:"$SANDBOX/exp-a" file:"$SANDBOX/exp-a"
fault_both "read after bytes" "$(nr_of read)" -1 5 6 file:"$SANDBOX/exp-two" file:"$SANDBOX/exp-two"

python3 - "$HEX0" "$SANDBOX/trunc-first" "$(fact trunc_old)" "$(fact trunc_new)" << 'PY'
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
chmod 755 "$SANDBOX/trunc-first"
cp "$SANDBOX/olddata" "$SANDBOX/trunc-pre"
chmod 640 "$SANDBOX/trunc-pre"
printf '41\n' > "$SANDBOX/trunc-in"
rc=0
run_status "$DUR_FAST" -- "$SANDBOX/fault" "$(nr_of fchmod)" "$OUT_FD" 1 1 "$SANDBOX/trunc-first" "$SANDBOX/trunc-in" "$SANDBOX/trunc-pre" || rc=$?
if timed_out "$rc"; then
  die "mutant trunc-before-fchmod timed out"
fi
mode=$(stat -c %a "$SANDBOX/trunc-pre")
if [ "$rc" -ne 3 ] || [ "$mode" != 640 ] || cmp -s "$SANDBOX/trunc-pre" "$SANDBOX/olddata"; then
  die "mutant trunc-before-fchmod rc $rc mode $mode"
fi
echo "mutant trunc-before-fchmod: red (rc 3, mode 640, bytes truncated)"

python3 -c 'open("/dev/stdout","w").write("00\n"*2000)' > "$SANDBOX/big.hex0"
cat > "$SANDBOX/sigxfsz.c" << 'EOF'
#include <signal.h>
#include <unistd.h>
#include <sys/resource.h>
int main(int argc, char **argv) {
  struct rlimit lim;
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
check "sigxfsz gcc" "$DUR_CMD" -- gcc -O2 -o "$SANDBOX/sigxfsz" "$SANDBOX/sigxfsz.c"
rm -f "$SANDBOX/sig-dfl.out" "$SANDBOX/sig-ign.out"
rc=0
(
  ulimit -c 0
  cd "$SANDBOX" || exit 99
  run_status "$DUR_FAST" -- "$SANDBOX/sigxfsz" dfl "$HEX0" "$SANDBOX/big.hex0" "$SANDBOX/sig-dfl.out"
) >"$SANDBOX/sig-dfl.capture" 2>&1 || rc=$?
if timed_out "$rc"; then
  die "row 6 SIGXFSZ default timed out"
fi
[ "$rc" -eq 153 ] || die "row 6 SIGXFSZ default rc $rc $(cat "$SANDBOX/sig-dfl.capture")"
if [ -e "$SANDBOX/core" ] || [ -e core ]; then
  die "row 6 SIGXFSZ default left a core"
fi
grep -q -F 'File size limit exceeded' "$SANDBOX/sig-dfl.capture" \
  || die "row 6 SIGXFSZ default: bash note not captured"
echo "row 6: SIGXFSZ default exit 153, no core"
sed 's/^/row 6 SIGXFSZ note: /' "$SANDBOX/sig-dfl.capture"
rc=0
run_status "$DUR_FAST" -- "$SANDBOX/sigxfsz" ign "$HEX0" "$SANDBOX/big.hex0" "$SANDBOX/sig-ign.out" || rc=$?
if timed_out "$rc"; then
  die "row 6 SIGXFSZ ignored timed out"
fi
[ "$rc" -eq 6 ] || die "row 6 SIGXFSZ ignored rc $rc"
kept=$(wc -c < "$SANDBOX/sig-ign.out")
[ "$kept" -eq 1024 ] || die "row 6 SIGXFSZ ignored kept $kept"
echo "row 6: SIGXFSZ ignored exit 6, 1024 bytes kept"

check "row 12 fuzz" "$DUR_LONG" -- python3 tools/check/fuzz-hex0.py "$HEX0" 2000 "$SANDBOX"
check "row 12 status mutant" "$DUR_LONG" -- python3 tools/check/fuzz-hex0.py --expect-disagree "$HEX0" 2000 "$SANDBOX"
check "row 12 letter mutant" "$DUR_LONG" -- python3 tools/check/fuzz-hex0.py --expect-letter-offset "$HEX0" 2000 "$SANDBOX"
now_hash=$(sha256sum "$HEX0" | awk 'NR==1 {print $1}')
[ "$now_hash" = "$seed_hash" ] || die "row 12 seed changed"
echo "row 12: fuzz ok"
exit 0
