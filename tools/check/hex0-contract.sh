#!/usr/bin/env bash
# tools/check/hex0-contract.sh <hex0> <target-src> <tests> <sandbox>
# Rows 3-8, 12 and 13 for one target this host can execute.
# A later rung gets its own contract script. This one stays hex0's.
set -u
export PYTHONDONTWRITEBYTECODE=1
here=$(dirname "${BASH_SOURCE[0]}")
cd "$here/../.." || exit 2
# shellcheck disable=SC1091
. "$here/gate-lib.sh"
umask 0022

[ $# -eq 4 ] || die "hex0-contract: want HEX0 SRC TESTS SANDBOX"
HEX0=$1
SRC=$2
TESTS=$3
SANDBOX=$4
RUNG=$(dirname "$TESTS")

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
    cmp "$path" "$SANDBOX/olddata" || die "$label bytes"
    return
  fi
  if [ "$exp" = "samebytes:755" ]; then
    [ "$mode" = 755 ] || die "$label mode $mode"
    cmp "$path" "$SANDBOX/olddata" || die "$label bytes"
    return
  fi
  [ "$mode" = 755 ] || die "$label mode $mode"
  if [ "$exp" = empty ]; then
    [ ! -s "$path" ] || die "$label not empty"
    return
  fi
  local want=${exp#file:}
  cmp "$path" "$want" || die "$label bytes"
}

pair() {
  local label=$1 want=$2 src=$3 abs_exp=$4 pre_exp=$5
  local abs=$SANDBOX/abs-$label
  local pre=$SANDBOX/pre-$label
  rm -f "$abs"
  cp "$SANDBOX/olddata" "$pre"
  chmod 640 "$pre"
  guard 30 "$HEX0" "$src" "$abs"
  local rc=$?
  [ "$rc" -eq "$want" ] || die "$label absent rc $rc"
  assert_out "$label absent" "$abs" "$abs_exp"
  guard 30 "$HEX0" "$src" "$pre"
  rc=$?
  [ "$rc" -eq "$want" ] || die "$label pre rc $rc"
  assert_out "$label pre" "$pre" "$pre_exp"
  echo "row 7: $label exit $want"
}

rm -f out/h1
guard 30 "$HEX0" "$SRC" out/h1
rc=$?
[ "$rc" -eq 0 ] || die "row 3 rc $rc"
cmp out/h1 "$HEX0" || die "row 3 cmp"
echo "row 3: cmp identical, exit 0"

rm -f out/h1str
guard 30 strace -f -o "$SANDBOX/trace" "$HEX0" "$SRC" out/h1str
rc=$?
[ "$rc" -eq 0 ] || die "row 8 rc $rc"
cmp out/h1str "$HEX0" || die "row 8 cmp"
guard 30 python3 tools/check/syscalls-check.py "$SANDBOX/trace" >"$SANDBOX/sys.out"
rc=$?
[ "$rc" -eq 0 ] || die "row 8 syscalls"
cat "$SANDBOX/sys.out"
cp "$SANDBOX/trace" "$SANDBOX/trace-mut"
printf '0 socket(2, 1, 0) = 3\n' >> "$SANDBOX/trace-mut"
guard 30 python3 tools/check/syscalls-check.py "$SANDBOX/trace-mut" >"$SANDBOX/sys-mut.out" 2>"$SANDBOX/sys-mut.err"
rc=$?
[ "$rc" -ne 0 ] || die "row 8 mutant stayed green"
grep -q 'unexpected socket' "$SANDBOX/sys-mut.err" || die "row 8 mutant said $(cat "$SANDBOX/sys-mut.err")"
echo "mutant row 8 (extra syscall): red"

guard 30 python3 tools/check/hex-check.py --digits "$TESTS/exit42.hex0" >"$SANDBOX/probe.hex"
rc=$?
[ "$rc" -eq 0 ] || die "probe digits rc $rc"
xxd -r -p "$SANDBOX/probe.hex" > "$SANDBOX/probe.bin"
rc=$?
[ "$rc" -eq 0 ] || die "probe xxd rc $rc"
rm -f out/exit42
guard 30 "$HEX0" "$TESTS/exit42.hex0" out/exit42
rc=$?
[ "$rc" -eq 0 ] || die "row 4 build rc $rc"
cmp out/exit42 "$SANDBOX/probe.bin" || die "row 4 cmp"
guard 30 out/exit42
rc=$?
[ "$rc" -eq 42 ] || die "row 4 run rc $rc"
echo "row 4: cmp identical, exit 42"

mode=$(stat -c %a out/exit42)
[ "$mode" = "755" ] || die "row 5 mode $mode"
echo "row 5: $mode"
printf 'old-contents' > "$SANDBOX/old-contents"
cp "$SANDBOX/old-contents" "$SANDBOX/pre600"
chmod 600 "$SANDBOX/pre600"
guard 30 "$HEX0" "$TESTS/exit42.hex0" "$SANDBOX/pre600"
rc=$?
[ "$rc" -eq 0 ] || die "row 5 preexist rc $rc"
mode=$(stat -c %a "$SANDBOX/pre600")
[ "$mode" = "755" ] || die "row 5 preexist mode $mode"
cmp "$SANDBOX/pre600" "$SANDBOX/probe.bin" || die "row 5 preexist bytes"
echo "row 5: preexist 600 is 755"

fix_ok() {
  local src=$1 exp=$2 name=$3
  rm -f "$SANDBOX/$name"
  guard 30 "$HEX0" "$src" "$SANDBOX/$name"
  rc=$?
  [ "$rc" -eq 0 ] || die "row 6 $name rc $rc"
  cmp "$SANDBOX/$name" "$exp" || die "row 6 $name bytes"
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

rm -f "$SANDBOX/abs-argc-one"
cp "$SANDBOX/olddata" "$SANDBOX/pre-argc-one"
chmod 640 "$SANDBOX/pre-argc-one"
guard 30 "$HEX0" "$SANDBOX/pre-argc-one"
rc=$?
[ "$rc" -eq 1 ] || die "argc-one pre rc $rc"
assert_out "argc-one pre" "$SANDBOX/pre-argc-one" same
[ ! -e "$SANDBOX/abs-argc-one" ] || die "argc-one absent exists"
echo "row 7: argc 1 exit 1"
cat > "$SANDBOX/argc0.c" << 'EOF'
#include <unistd.h>
int main(int argc, char **argv) {
  char *av[] = {0};
  execv(argv[1], av);
  return 99;
}
EOF
guard 30 gcc -O2 -o "$SANDBOX/argc0" "$SANDBOX/argc0.c"
rc=$?
[ "$rc" -eq 0 ] || die "argc0 gcc rc $rc"
rm -f "$SANDBOX/abs-argc0"
cp "$SANDBOX/olddata" "$SANDBOX/pre-argc0"
chmod 640 "$SANDBOX/pre-argc0"
guard 30 "$SANDBOX/argc0" "$HEX0"
rc=$?
[ "$rc" -eq 1 ] || die "row 7 argc 0 rc $rc"
assert_out "argc 0 absent" "$SANDBOX/abs-argc0" missing
assert_out "argc 0 pre" "$SANDBOX/pre-argc0" same
echo "row 7: argc 0 exit 1"
rm -f "$SANDBOX/abs-argc4"
cp "$SANDBOX/olddata" "$SANDBOX/pre-argc4"
chmod 640 "$SANDBOX/pre-argc4"
guard 30 "$HEX0" "$TESTS/lower.hex0" "$SANDBOX/abs-argc4" extra
rc=$?
[ "$rc" -eq 1 ] || die "row 7 argc 4 absent rc $rc"
assert_out "argc 4 absent" "$SANDBOX/abs-argc4" missing
guard 30 "$HEX0" "$TESTS/lower.hex0" "$SANDBOX/pre-argc4" extra
rc=$?
[ "$rc" -eq 1 ] || die "row 7 argc 4 pre rc $rc"
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
guard 30 "$HEX0" "$TESTS/lower.hex0" "$SANDBOX/absent-dir/out"
rc=$?
[ "$rc" -eq 3 ] || die "row 7 missing dir rc $rc"
[ ! -e "$SANDBOX/absent-dir/out" ] || die "row 7 missing dir created"
echo "row 7: missing OUT directory exit 3, absent stays absent"

dev_before=$(stat -c %a /dev/null)
guard 30 "$HEX0" "$TESTS/lower.hex0" /dev/null
rc=$?
dev_after=$(stat -c %a /dev/null)
[ "$rc" -eq 3 ] || die "row 7 non-regular rc $rc"
[ "$dev_before" = "$dev_after" ] || die "row 7 /dev/null mode $dev_before to $dev_after"
echo "row 7: non-regular exit 3, mode unchanged"

cp "$SANDBOX/olddata" "$SANDBOX/ro"
chmod 444 "$SANDBOX/ro"
guard 30 "$HEX0" "$SANDBOX/ro" "$SANDBOX/ro"
rc=$?
[ "$rc" -eq 3 ] || die "row 7 read-only rc $rc"
cmp "$SANDBOX/ro" "$SANDBOX/olddata" || die "row 7 read-only bytes"
mode=$(stat -c %a "$SANDBOX/ro")
[ "$mode" = 444 ] || die "row 7 read-only mode $mode"
echo "row 7: read-only same file exit 3, unchanged"

cp "$SANDBOX/olddata" "$SANDBOX/same"
chmod 640 "$SANDBOX/same"
guard 30 "$HEX0" "$SANDBOX/same" "$SANDBOX/same"
rc=$?
[ "$rc" -eq 7 ] || die "row 7 same path rc $rc"
assert_out "same path" "$SANDBOX/same" same
echo "row 7: same path exit 7"
printf '41 extra\n' > "$SANDBOX/hard"
chmod 640 "$SANDBOX/hard"
ln "$SANDBOX/hard" "$SANDBOX/hard.link"
guard 30 "$HEX0" "$SANDBOX/hard" "$SANDBOX/hard.link"
rc=$?
[ "$rc" -eq 7 ] || die "row 7 hard link rc $rc"
cmp "$SANDBOX/hard" <(printf '41 extra\n') || die "row 7 hard link bytes"
mode=$(stat -c %a "$SANDBOX/hard")
[ "$mode" = 640 ] || die "row 7 hard link mode $mode"
echo "row 7: hard link exit 7"
printf '41\n' > "$SANDBOX/sym.target"
chmod 640 "$SANDBOX/sym.target"
ln -s sym.target "$SANDBOX/sym.link"
guard 30 "$HEX0" "$SANDBOX/sym.target" "$SANDBOX/sym.link"
rc=$?
[ "$rc" -eq 7 ] || die "row 7 symlink rc $rc"
cmp "$SANDBOX/sym.target" <(printf '41\n') || die "row 7 symlink bytes"
mode=$(stat -c %a "$SANDBOX/sym.target")
[ "$mode" = 640 ] || die "row 7 symlink mode $mode"
echo "row 7: symlink exit 7"
rm -f "$SANDBOX/absent-same"
guard 30 "$HEX0" "$SANDBOX/absent-same" "$SANDBOX/absent-same"
rc=$?
[ "$rc" -eq 2 ] || die "row 7 absent same rc $rc"
[ ! -e "$SANDBOX/absent-same" ] || die "row 7 absent same created"
echo "row 7: absent same path exit 2"

pair "directory IN" 6 "$RUNG" empty empty

guard 30 gcc -O2 -o "$SANDBOX/fault" tools/check/fault.c
rc=$?
[ "$rc" -eq 0 ] || die "fault gcc rc $rc"

fault_both() {
  local label=$1 nr=$2 fd=$3 want=$4 abs_exp=$5 pre_exp=$6
  local src=$SANDBOX/fin
  local abs=$SANDBOX/fabs-$label
  local pre=$SANDBOX/fpre-$label
  local ctl=$SANDBOX/fctl-$label
  printf '41\n' > "$src"
  rm -f "$abs"
  cp "$SANDBOX/olddata" "$pre"
  chmod 640 "$pre"
  guard 30 "$SANDBOX/fault" "$nr" "$fd" 1 "$HEX0" "$src" "$abs"
  rc=$?
  [ "$rc" -eq "$want" ] || die "row 13 $label absent rc $rc"
  assert_out "row 13 $label absent" "$abs" "$abs_exp"
  guard 30 "$SANDBOX/fault" "$nr" "$fd" 1 "$HEX0" "$src" "$pre"
  rc=$?
  [ "$rc" -eq "$want" ] || die "row 13 $label pre rc $rc"
  assert_out "row 13 $label pre" "$pre" "$pre_exp"
  rm -f "$ctl"
  cp "$SANDBOX/olddata" "$ctl"
  chmod 640 "$ctl"
  guard 30 "$HEX0" "$src" "$ctl"
  rc=$?
  [ "$rc" -eq 0 ] || die "row 13 $label control rc $rc"
  assert_out "row 13 $label control" "$ctl" file:"$SANDBOX/exp-one"
  echo "row 13: $label exit $want, control 0"
}
fault_both "fstat IN" 5 3 2 empty same
fault_both "fstat OUT" 5 4 3 empty same
fault_both fchmod 91 4 3 empty same
fault_both read 0 -1 6 empty empty
fault_both write 1 -1 6 empty empty
fault_both close 3 -1 6 file:"$SANDBOX/exp-one" file:"$SANDBOX/exp-one"
fault_both ftruncate 77 -1 6 empty "samebytes:755"

python3 - "$HEX0" "$SANDBOX/trunc-first" << 'PY'
import sys
old = bytes.fromhex(
    "6a5b584489efbeed0100000f0585c079076a03e9d5000000"
    "6a4d584489ef31f60f0585c079076a06e9c0000000"
)
new = bytes.fromhex(
    "6a4d584489ef31f60f0585c079076a06e9d8000000"
    "6a5b584489efbeed0100000f0585c079076a03e9c0000000"
)
data = open(sys.argv[1], "rb").read()
found = data.count(old)
if found != 1:
    sys.stderr.write("trunc mutant: pattern found %d times\n" % found)
    sys.exit(2)
open(sys.argv[2], "wb").write(data.replace(old, new, 1))
PY
rc=$?
[ "$rc" -eq 0 ] || die "trunc mutant build rc $rc"
chmod 755 "$SANDBOX/trunc-first"
cp "$SANDBOX/olddata" "$SANDBOX/trunc-pre"
chmod 640 "$SANDBOX/trunc-pre"
printf '41\n' > "$SANDBOX/trunc-in"
guard 30 "$SANDBOX/fault" 91 4 1 "$SANDBOX/trunc-first" "$SANDBOX/trunc-in" "$SANDBOX/trunc-pre"
rc=$?
mode=$(stat -c %a "$SANDBOX/trunc-pre")
if [ "$rc" -eq 3 ] && [ "$mode" = 640 ] && cmp -s "$SANDBOX/trunc-pre" "$SANDBOX/olddata"; then
  die "trunc-before-fchmod mutant stayed green"
fi
echo "mutant trunc-before-fchmod: red (rc $rc)"

guard 120 python3 tools/check/fuzz-hex0.py "$HEX0" 2000
rc=$?
[ "$rc" -eq 0 ] || die "row 12 fuzz rc $rc"
guard 120 python3 tools/check/fuzz-hex0.py --expect-disagree "$HEX0" 2000
rc=$?
[ "$rc" -eq 0 ] || die "row 12 mutant rc $rc"
guard 120 python3 tools/check/fuzz-hex0.py --expect-letter-offset "$HEX0" 2000
rc=$?
[ "$rc" -eq 0 ] || die "row 12 letter mutant rc $rc"
cmp "$HEX0" "$SANDBOX/py.bin" || die "row 12 seed changed"
echo "row 12: fuzz ok"
exit 0
