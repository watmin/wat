#!/usr/bin/env bash
# tools/verify.sh -- the hex0 gate.
# Layout mutants run against a scratch copy under /var/tmp. This script does
# not modify the live tree or the git index. It builds by running the seed
# into out/, and it builds the fault injector with gcc into the sandbox.
# A check's fixture outputs live in the sandbox.
# The host target is uname -m and uname -s. Other targets are decoded and
# reported as not executed on this host.
set -u
export PYTHONDONTWRITEBYTECODE=1
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
umask 0022

SANDBOX=/var/tmp/hex0-verify
TREE=/var/tmp/hex0-verify-tree
HOST=$(uname -m)-$(uname -s | tr '[:upper:]' '[:lower:]')
TGT=ladder/0-hex0/$HOST
HEX0=$TGT/hex0
SRC=$TGT/hex0.hex0

skip_execution() {
  local tgt=$1
  if [ "$tgt" = "$HOST" ]; then
    return 1
  fi
  echo "$tgt: not executed on this host"
  return 0
}

static_target() {
  local tgt=$1
  local dir=ladder/0-hex0/$tgt
  local bin=$dir/hex0
  local src=$dir/hex0.hex0
  local arch=${tgt%%-*}
  local machine=""
  guard 30 python3 tools/check/hex-check.py "$src" >"$SANDBOX/py-$tgt.bin"
  rc=$?
  [ "$rc" -eq 0 ] || die "row 1 $tgt hex-check rc $rc"
  cmp "$SANDBOX/py-$tgt.bin" "$bin" || die "row 1 $tgt cmp"
  echo "row 1: cmp identical ($tgt)"
  guard 30 python3 tools/check/hex-check.py --digits "$src" >"$SANDBOX/stripped-$tgt.hex"
  rc=$?
  [ "$rc" -eq 0 ] || die "row 2 $tgt digits rc $rc"
  xxd -r -p "$SANDBOX/stripped-$tgt.hex" > "$SANDBOX/xxd-$tgt.bin"
  rc=$?
  [ "$rc" -eq 0 ] || die "row 2 $tgt xxd rc $rc"
  cmp "$SANDBOX/xxd-$tgt.bin" "$bin" || die "row 2 $tgt cmp"
  echo "row 2: cmp identical ($tgt)"
  guard 30 python3 tools/check/hex-check.py --lint "$src" >"$SANDBOX/lint-$tgt.out"
  rc=$?
  [ "$rc" -eq 0 ] || die "row 11 $tgt rc $rc"
  grep -qx 'lint: ok' "$SANDBOX/lint-$tgt.out" || die "row 11 $tgt text"
  echo "row 11: lint ok ($tgt)"
  case $arch in
    x86_64) machine=i386:x86-64 ;;
    *) die "row 9: no disassembler mapped for $tgt" ;;
  esac
  dd if="$bin" of="$SANDBOX/code-$tgt.bin" bs=1 skip=120 status=none
  objdump -D -b binary -m "$machine" "$SANDBOX/code-$tgt.bin" > "$SANDBOX/objdump-$tgt.txt"
  rc=$?
  [ "$rc" -eq 0 ] || die "objdump $tgt rc $rc"
  guard 30 python3 tools/check/disasm-check.py "$src" "$SANDBOX/code-$tgt.bin" "$SANDBOX/objdump-$tgt.txt" >"$SANDBOX/row9-$tgt.out"
  rc=$?
  [ "$rc" -eq 0 ] || die "row 9 $tgt"
  cat "$SANDBOX/row9-$tgt.out"
  python3 - "$bin" << 'PY'
import struct, sys
data = open(sys.argv[1], "rb").read()
phoff = struct.unpack_from("<Q", data, 32)[0]
filesz = struct.unpack_from("<Q", data, phoff + 32)[0]
memsz = struct.unpack_from("<Q", data, phoff + 40)[0]
if filesz != len(data) or memsz != len(data):
    sys.stderr.write("row 10: filesz %d memsz %d len %d\n" % (filesz, memsz, len(data)))
    sys.exit(1)
sys.stdout.write("row 10: %d bytes (%s)\n" % (len(data), sys.argv[2] if len(sys.argv) > 2 else ""))
PY
  rc=$?
  [ "$rc" -eq 0 ] || die "row 10 $tgt"
}
rm -rf "$SANDBOX" "$TREE"
mkdir -p "$SANDBOX" out

restore() {
  rm -rf "$SANDBOX" "$TREE"
}
trap restore EXIT

die() {
  echo "verify: $*" >&2
  exit 1
}

guard() {
  local secs=$1
  shift
  timeout --verbose -s KILL "$secs" "$@"
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

guard 60 tools/layout.sh >"$SANDBOX/layout.out" 2>"$SANDBOX/layout.err"
rc=$?
[ "$rc" -eq 0 ] || die "layout rc $rc ($(cat "$SANDBOX/layout.out" "$SANDBOX/layout.err"))"
grep -qx 'layout: ok' "$SANDBOX/layout.out" || die "layout text"

cp -a . "$TREE"

mutant_expect() {
  local rule=$1 label=$2
  guard 60 tools/layout.sh "$TREE" >"$SANDBOX/mut.out" 2>"$SANDBOX/mut.err"
  rc=$?
  [ "$rc" -ne 0 ] || die "mutant rule $rule ($label) stayed green"
  grep -q "layout: rule ${rule}:" "$SANDBOX/mut.out" || die "mutant rule $rule ($label) said $(cat "$SANDBOX/mut.out" "$SANDBOX/mut.err")"
  echo "mutant rule $rule ($label): red"
}

echo stray > "$TREE/STRAY"
mutant_expect 1 "stray top-level file"
rm -f "$TREE/STRAY"

printf 'x\n' > "$TREE/brand/x.md"
mutant_expect 1 "brand non-image"
rm -f "$TREE/brand/x.md"

printf '\177ELF' > "$TREE/ladder/0-hex0/tests/second.elf"
mutant_expect 2 "second ELF"
rm -f "$TREE/ladder/0-hex0/tests/second.elf"

cp "$TREE/$HEX0" "$TREE/ladder/0-hex0/hex0"
mutant_expect 2 "seed outside a target"
rm -f "$TREE/ladder/0-hex0/hex0"

printf '\177ELF' > "$TREE/$TGT/other"
mutant_expect 2 "second binary inside a target"
rm -f "$TREE/$TGT/other"

printf 'A\0B' > "$TREE/ladder/0-hex0/tests/second.bin"
mutant_expect 2 "NUL binary"
rm -f "$TREE/ladder/0-hex0/tests/second.bin"

echo brief > "$TREE/ladder/0-hex0/BRIEF.md"
mutant_expect 3 "brief inside a rung"
rm -f "$TREE/ladder/0-hex0/BRIEF.md"

mkdir -p "$TREE/ladder/0-hex0/aarch64-linux"
mutant_expect 3 "target with no source"
rmdir "$TREE/ladder/0-hex0/aarch64-linux"

mkdir -p "$TREE/ladder/0-hex0/X86-64"
mutant_expect 3 "badly named target"
rmdir "$TREE/ladder/0-hex0/X86-64"

mkdir -p "$TREE/ladder/2-skip"
cat > "$TREE/ladder/2-skip/README.md" << 'EOF'
# skip
| 0 | a |
| 1 | a |
| 2 | a |
| 3 | a |
| 4 | a |
| 5 | a |
| 6 | a |
EOF
mutant_expect 4 "rung number gap"
rm -rf "$TREE/ladder/2-skip"

cp ladder/0-hex0/README.md "$SANDBOX/readme.bak"
printf 'no exit table\n' > "$TREE/ladder/0-hex0/README.md"
mutant_expect 5 "readme without an exit table"
cp "$SANDBOX/readme.bak" "$TREE/ladder/0-hex0/README.md"

grep -v '^| 4 |' "$SANDBOX/readme.bak" > "$TREE/ladder/0-hex0/README.md"
mutant_expect 5 "readme missing a status"
cp "$SANDBOX/readme.bak" "$TREE/ladder/0-hex0/README.md"

cp "$SANDBOX/readme.bak" "$TREE/ladder/0-hex0/README.md"
printf '| 8 | not a status of this rung |\n' >> "$TREE/ladder/0-hex0/README.md"
mutant_expect 5 "readme extra status"
cp "$SANDBOX/readme.bak" "$TREE/ladder/0-hex0/README.md"

printf x >> "$TREE/archived/README.md"
mutant_expect 6 "archived byte"
git -C "$TREE" checkout -- archived/README.md

redir='>'
printf '%s\n' "echo x ${redir} out/nope" > "$TREE/tools/check/writes-out.sh"
mutant_expect 7 "redirect into out/"
rm -f "$TREE/tools/check/writes-out.sh"

verb=cp
printf '%s a out/b\n' "$verb" > "$TREE/tools/check/copies-out.sh"
mutant_expect 7 "copy into out/"
rm -f "$TREE/tools/check/copies-out.sh"

payload=$(printf '%s\n' ':wat:'':core:'':+')
printf '%s\n' "$payload" > "$TREE/ladder/0-hex0/tests/retired.wat"
git -C "$TREE" add -- ladder/0-hex0/tests/retired.wat
mutant_expect 8 "colon path"
git -C "$TREE" rm -f --cached -- ladder/0-hex0/tests/retired.wat >/dev/null
rm -f "$TREE/ladder/0-hex0/tests/retired.wat"

mkdir -p "$TREE/docs/stray-dir"
mutant_expect 9 "stray directory under docs/"
rm -rf "$TREE/docs/stray-dir"

mkdir -p "$TREE/docs/excursus/2026/10/003-counter-gap"
mutant_expect 9 "counter gap"
rm -rf "$TREE/docs/excursus/2026/10/003-counter-gap"

printf 'AA\n' > "$TREE/docs/excursus/2026/10/001-the-ladder/stray.hex0"
mutant_expect 9 "non-document in an excursus"
rm -f "$TREE/docs/excursus/2026/10/001-the-ladder/stray.hex0"

mkdir -p "$TREE/docs/excursus/2026/10/002-BadSlug"
mutant_expect 9 "bad slug"
rm -rf "$TREE/docs/excursus/2026/10/002-BadSlug"

bare_line='see excursus'
bare_line+=' '
bare_line+='001'
printf '%s\n' "$bare_line" > "$TREE/docs/bare-ref.md"
git -C "$TREE" add -- docs/bare-ref.md
mutant_expect 9 "bare numbered reference"
git -C "$TREE" rm -f --cached -- docs/bare-ref.md >/dev/null
rm -f "$TREE/docs/bare-ref.md"

rm -rf "$TREE"
guard 60 tools/layout.sh >"$SANDBOX/layout2.out" 2>"$SANDBOX/layout2.err"
rc=$?
[ "$rc" -eq 0 ] || die "layout after mutants rc $rc ($(cat "$SANDBOX/layout2.out"))"
grep -qx 'layout: ok' "$SANDBOX/layout2.out" || die "layout after mutants"
echo "layout: ok"

found_host=0
for dir in ladder/0-hex0/*/; do
  tgt=$(basename "$dir")
  [ "$tgt" = tests ] && continue
  if [ "$tgt" = "$HOST" ]; then
    found_host=1
    continue
  fi
  static_target "$tgt"
  skip_execution "$tgt" || die "non-host target $tgt fell through to execution"
done
[ "$found_host" -eq 1 ] || die "no target for this host: $HOST"
if skip_execution "$HOST"; then
  die "host target was not executed"
fi

guard 30 python3 tools/check/hex-check.py "$SRC" >"$SANDBOX/py.bin"
rc=$?
[ "$rc" -eq 0 ] || die "row 1 hex-check rc $rc"
cmp "$SANDBOX/py.bin" "$HEX0" || die "row 1 cmp"
echo "row 1: cmp identical"

guard 30 python3 tools/check/hex-check.py --digits "$SRC" >"$SANDBOX/stripped.hex"
rc=$?
[ "$rc" -eq 0 ] || die "row 2 digits rc $rc"
xxd -r -p "$SANDBOX/stripped.hex" > "$SANDBOX/xxd.bin"
rc=$?
[ "$rc" -eq 0 ] || die "row 2 xxd rc $rc"
cmp "$SANDBOX/xxd.bin" "$HEX0" || die "row 2 cmp"
echo "row 2: cmp identical"

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

guard 30 python3 tools/check/hex-check.py --digits ladder/0-hex0/tests/exit42.hex0 >"$SANDBOX/probe.hex"
rc=$?
[ "$rc" -eq 0 ] || die "probe digits rc $rc"
xxd -r -p "$SANDBOX/probe.hex" > "$SANDBOX/probe.bin"
rc=$?
[ "$rc" -eq 0 ] || die "probe xxd rc $rc"
rm -f out/exit42
guard 30 "$HEX0" ladder/0-hex0/tests/exit42.hex0 out/exit42
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
guard 30 "$HEX0" ladder/0-hex0/tests/exit42.hex0 "$SANDBOX/pre600"
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
fix_ok ladder/0-hex0/tests/lower.hex0 "$SANDBOX/exp-lower" lower
fix_ok ladder/0-hex0/tests/upper.hex0 "$SANDBOX/exp-upper" upper
fix_ok ladder/0-hex0/tests/crlf.hex0 "$SANDBOX/exp-one" crlf
fix_ok ladder/0-hex0/tests/eof-comment.hex0 "$SANDBOX/exp-one" eof
fix_ok ladder/0-hex0/tests/comments.hex0 "$SANDBOX/exp-comments" comments
fix_ok ladder/0-hex0/tests/split.hex0 "$SANDBOX/exp-one" split
fix_ok ladder/0-hex0/tests/comment-nibble.hex0 "$SANDBOX/exp-one" comment-nibble
fix_ok ladder/0-hex0/tests/comment-cr.hex0 "$SANDBOX/exp-two" comment-cr
fix_ok ladder/0-hex0/tests/comment-tab.hex0 "$SANDBOX/exp-two" comment-tab
fix_ok ladder/0-hex0/tests/comment-high.hex0 "$SANDBOX/exp-two" comment-high
fix_ok ladder/0-hex0/tests/crlf-two.hex0 "$SANDBOX/exp-two" crlf-two

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
guard 30 "$HEX0" ladder/0-hex0/tests/lower.hex0 "$SANDBOX/abs-argc4" extra
rc=$?
[ "$rc" -eq 1 ] || die "row 7 argc 4 absent rc $rc"
assert_out "argc 4 absent" "$SANDBOX/abs-argc4" missing
guard 30 "$HEX0" ladder/0-hex0/tests/lower.hex0 "$SANDBOX/pre-argc4" extra
rc=$?
[ "$rc" -eq 1 ] || die "row 7 argc 4 pre rc $rc"
assert_out "argc 4 pre" "$SANDBOX/pre-argc4" same
echo "row 7: argc 4 exit 1"

pair "missing IN" 2 "$SANDBOX/missing-in" missing same

pair G 4 ladder/0-hex0/tests/bad-g.hex0 empty empty
pair vt 4 ladder/0-hex0/tests/vt.hex0 empty empty
pair ff 4 ladder/0-hex0/tests/ff.hex0 empty empty
pair reject-2f 4 ladder/0-hex0/tests/reject-2f.hex0 file:"$SANDBOX/exp-one" file:"$SANDBOX/exp-one"
pair reject-40 4 ladder/0-hex0/tests/reject-40.hex0 file:"$SANDBOX/exp-one" file:"$SANDBOX/exp-one"
pair reject-80 4 ladder/0-hex0/tests/reject-80.hex0 file:"$SANDBOX/exp-one" file:"$SANDBOX/exp-one"
pair reject-ff 4 ladder/0-hex0/tests/reject-ff.hex0 file:"$SANDBOX/exp-one" file:"$SANDBOX/exp-one"
pair odd 5 ladder/0-hex0/tests/odd.hex0 empty empty
pair odd-after 5 ladder/0-hex0/tests/odd-after.hex0 file:"$SANDBOX/exp-one" file:"$SANDBOX/exp-one"

rm -rf "$SANDBOX/absent-dir"
guard 30 "$HEX0" ladder/0-hex0/tests/lower.hex0 "$SANDBOX/absent-dir/out"
rc=$?
[ "$rc" -eq 3 ] || die "row 7 missing dir rc $rc"
[ ! -e "$SANDBOX/absent-dir/out" ] || die "row 7 missing dir created"
echo "row 7: missing OUT directory exit 3, absent stays absent"

dev_before=$(stat -c %a /dev/null)
guard 30 "$HEX0" ladder/0-hex0/tests/lower.hex0 /dev/null
rc=$?
dev_after=$(stat -c %a /dev/null)
[ "$rc" -eq 3 ] || die "row 7 non-regular rc $rc"
[ "$dev_before" = "$dev_after" ] || die "row 7 /dev/null mode $dev_before -> $dev_after"
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

pair "directory IN" 6 ladder/0-hex0 empty empty

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

[ -x /var/tmp/vigilia-hex0/peragrare/mutant-trunc-first ] || die "trunc-first mutant missing"
cp "$SANDBOX/olddata" "$SANDBOX/trunc-pre"
chmod 640 "$SANDBOX/trunc-pre"
printf '41\n' > "$SANDBOX/trunc-in"
guard 30 "$SANDBOX/fault" 91 4 1 /var/tmp/vigilia-hex0/peragrare/mutant-trunc-first "$SANDBOX/trunc-in" "$SANDBOX/trunc-pre"
rc=$?
mode=$(stat -c %a "$SANDBOX/trunc-pre")
if [ "$rc" -eq 3 ] && [ "$mode" = 640 ] && cmp -s "$SANDBOX/trunc-pre" "$SANDBOX/olddata"; then
  die "trunc-before-fchmod mutant stayed green"
fi
echo "mutant trunc-before-fchmod: red (rc $rc)"

dd if="$HEX0" of="$SANDBOX/code.bin" bs=1 skip=120 status=none
objdump -D -b binary -m i386:x86-64 "$SANDBOX/code.bin" > "$SANDBOX/objdump.txt"
rc=$?
[ "$rc" -eq 0 ] || die "objdump rc $rc"
guard 30 python3 tools/check/disasm-check.py "$SRC" "$SANDBOX/code.bin" "$SANDBOX/objdump.txt" >"$SANDBOX/row9.out"
rc=$?
[ "$rc" -eq 0 ] || die "row 9"
cat "$SANDBOX/row9.out"
python3 - "$SANDBOX/bad-comment.hex0" "$SRC" << 'PY'
import sys
text = open(sys.argv[2], encoding="utf-8").read()
old = "cmpq   $0x3,(%rsp)"
# the stored comment collapses spaces; replace the mnemonic
text2 = text.replace("cmpq $0x3,(%rsp)", "addq $0x3,(%rsp)", 1)
if text2 == text:
    sys.stderr.write("comment mutant found nothing\n")
    sys.exit(1)
open(sys.argv[1], "w", encoding="utf-8").write(text2)
PY
rc=$?
[ "$rc" -eq 0 ] || die "row 9 mutant build rc $rc"
guard 30 python3 tools/check/disasm-check.py "$SANDBOX/bad-comment.hex0" "$SANDBOX/code.bin" "$SANDBOX/objdump.txt" >"$SANDBOX/row9m.out" 2>"$SANDBOX/row9m.err"
rc=$?
[ "$rc" -ne 0 ] || die "row 9 mutant stayed green"
echo "mutant row 9 (comment): red"

python3 - "$HEX0" << 'PY'
import struct, sys
data = open(sys.argv[1], "rb").read()
phoff = struct.unpack_from("<Q", data, 32)[0]
filesz = struct.unpack_from("<Q", data, phoff + 32)[0]
memsz = struct.unpack_from("<Q", data, phoff + 40)[0]
if filesz != len(data) or memsz != len(data):
    sys.stderr.write("row 10: filesz %d memsz %d len %d\n" % (filesz, memsz, len(data)))
    sys.exit(1)
if len(data) != 537:
    sys.stderr.write("row 10 size %d\n" % len(data))
    sys.exit(1)
sys.stdout.write("row 10: %d bytes\n" % len(data))
PY
rc=$?
[ "$rc" -eq 0 ] || die "row 10"

guard 30 python3 tools/check/hex-check.py --lint "$SRC" >"$SANDBOX/lint.out"
rc=$?
[ "$rc" -eq 0 ] || die "row 11 rc $rc"
grep -qx 'lint: ok' "$SANDBOX/lint.out" || die "row 11 text $(cat "$SANDBOX/lint.out")"
echo "row 11: lint ok"

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

git diff --quiet c45603e -- archived || die "archived not restored"
[ ! -e STRAY ] || die "STRAY left behind"
[ ! -e ladder/2-skip ] || die "gap rung left behind"
[ ! -e brand/x.md ] || die "brand mutant left behind"
[ ! -e docs/bare-ref.md ] || die "bare ref left behind"

skip_execution aarch64-linux || die "aarch64-linux stayed silent"

echo "verify: ok"
exit 0
