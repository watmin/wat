#!/usr/bin/env bash
# tools/check/seed-audit.sh <ladder/0-hex0/<arch>-<os>> <sandbox> [--size N]
# Rows 1, 2, 9, 10 and 11, and the row-9 comment mutant. It does not run the seed.
set -u
export PYTHONDONTWRITEBYTECODE=1
here=$(dirname "${BASH_SOURCE[0]}")
cd "$here/../.." || exit 2
# shellcheck disable=SC1091
. "$here/gate-lib.sh"

[ $# -ge 2 ] || die "seed-audit: want TARGET SANDBOX [--size N]"
TARGET=$1
SANDBOX=$2
shift 2
size=""
while [ $# -gt 0 ]; do
  case $1 in
    --size)
      [ $# -ge 2 ] || die "seed-audit: --size needs N"
      size=$2
      shift 2
      ;;
    *) die "seed-audit: bad arg $1" ;;
  esac
done

HEX0=$TARGET/hex0
SRC=$TARGET/hex0.hex0
name=$(basename "$TARGET")
arch=${name%%-*}
case $arch in
  x86_64) machine=i386:x86-64 ;;
  *) die "row 9: no disassembler mapped for $name" ;;
esac

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

dd if="$HEX0" of="$SANDBOX/code.bin" bs=1 skip=120 status=none
objdump -D -b binary -m "$machine" "$SANDBOX/code.bin" > "$SANDBOX/objdump.txt"
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

python3 - "$HEX0" "$size" << 'PY'
import struct, sys
data = open(sys.argv[1], "rb").read()
phoff = struct.unpack_from("<Q", data, 32)[0]
filesz = struct.unpack_from("<Q", data, phoff + 32)[0]
memsz = struct.unpack_from("<Q", data, phoff + 40)[0]
if filesz != len(data) or memsz != len(data):
    sys.stderr.write("row 10: filesz %d memsz %d len %d\n" % (filesz, memsz, len(data)))
    sys.exit(1)
want = sys.argv[2]
if want and len(data) != int(want):
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
exit 0
