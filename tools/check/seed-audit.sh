#!/usr/bin/env bash
# tools/check/seed-audit.sh <ladder/0-hex0/<arch>-<os>> <sandbox> [--size N]
# Rows 1, 2, 9, 10 and 11, and the mutants that show those rows going red.
# It does not run the seed.
set -u
export PYTHONDONTWRITEBYTECODE=1
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd) || exit 2
# shellcheck source=tools/check/gate-lib.sh
. "$root/tools/check/gate-lib.sh" || exit 2
cd "$root" || exit 2
umask 0022

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
mkdir -p "$SANDBOX"
export SANDBOX
export HEX0_SCRATCH=$SANDBOX

HEX0=$TARGET/hex0
SRC=$TARGET/hex0.hex0
name=$(basename "$TARGET")
arch=${name%%-*}
case $arch in
  x86_64) machine=i386:x86-64 ;;
  *) die "row 9: no disassembler mapped for $name" ;;
esac
code_base=$(awk '$1=="code_base" {print $2}' "$TARGET/gate.tsv")
[ -n "$code_base" ] || die "seed-audit: no code_base"

show_red() {
  local label=$1 needle=$2
  shift 2
  local rc=0
  run_status "$DUR_CMD" -- "$@" >"$SANDBOX/mut.out" 2>"$SANDBOX/mut.err" || rc=$?
  if timed_out "$rc"; then
    die "$label timed out"
  fi
  if [ "$rc" -eq 0 ]; then
    die "$label stayed green"
  fi
  grep -q -F "$needle" "$SANDBOX/mut.out" "$SANDBOX/mut.err" || die "$label said $(cat "$SANDBOX/mut.out" "$SANDBOX/mut.err")"
  echo "$label: red"
}

check "row 1 hex-check" "$DUR_CMD" -- python3 tools/check/hex-check.py "$SRC" >"$SANDBOX/decoded.bin"
cmp -s "$SANDBOX/decoded.bin" "$HEX0" || die "row 1 cmp"
echo "row 1: cmp identical"

python3 - "$HEX0" "$SANDBOX/flipped.bin" << 'PY'
import sys
data = bytearray(open(sys.argv[1], "rb").read())
data[300] ^= 0x01
open(sys.argv[2], "wb").write(data)
PY
cat > "$SANDBOX/row1-diff.py" << 'PY'
import sys
a = open(sys.argv[1], "rb").read()
b = open(sys.argv[2], "rb").read()
if a == b:
    sys.stderr.write("row 1: stayed identical\n")
    sys.exit(0)
sys.stderr.write("row 1: seed differs\n")
sys.exit(1)
PY
show_red "mutant row 1 (byte)" "row 1: seed differs" \
  python3 "$SANDBOX/row1-diff.py" "$SANDBOX/flipped.bin" "$HEX0"

check "row 2 sed" "$DUR_FAST" -- sed 's/[#;].*//' "$SRC" >"$SANDBOX/stripped.hex"
check "row 2 xxd" "$DUR_FAST" -- xxd -r -p "$SANDBOX/stripped.hex" >"$SANDBOX/xxd.bin"
cmp -s "$SANDBOX/xxd.bin" "$HEX0" || die "row 2 cmp"
echo "row 2: cmp identical"

check "row 9 dd" "$DUR_FAST" -- dd if="$HEX0" of="$SANDBOX/code.bin" bs=1 skip="$code_base" status=none
check "row 9 objdump" "$DUR_CMD" -- objdump -D -b binary -m "$machine" --adjust-vma="$code_base" "$SANDBOX/code.bin" >"$SANDBOX/objdump.txt"
check "row 9 disasm" "$DUR_CMD" -- python3 tools/check/disasm-check.py "$SRC" "$SANDBOX/code.bin" "$SANDBOX/objdump.txt" >"$SANDBOX/row9.out"
cat "$SANDBOX/row9.out"

python3 - "$SANDBOX/bad-comment.hex0" "$SRC" << 'PY'
import sys
text = open(sys.argv[2], encoding="utf-8").read()
text2 = text.replace("cmpq $0x3,(%rsp)", "addq $0x3,(%rsp)", 1)
if text2 == text:
    sys.stderr.write("comment mutant found nothing\n")
    sys.exit(1)
open(sys.argv[1], "w", encoding="utf-8").write(text2)
PY
show_red "mutant row 9 (comment)" "row 9 mismatch" \
  python3 tools/check/disasm-check.py "$SANDBOX/bad-comment.hex0" "$SANDBOX/code.bin" "$SANDBOX/objdump.txt"

python3 - "$SANDBOX/bad-offset.hex0" "$SRC" << 'PY'
import sys
text = open(sys.argv[2], encoding="utf-8").read()
text2 = text.replace("+0078 ", "+0079 ", 1)
if text2 == text:
    sys.stderr.write("offset mutant found nothing\n")
    sys.exit(1)
open(sys.argv[1], "w", encoding="utf-8").write(text2)
PY
show_red "mutant row 9 (offset)" "row 9: offset" \
  python3 tools/check/disasm-check.py "$SANDBOX/bad-offset.hex0" "$SANDBOX/code.bin" "$SANDBOX/objdump.txt"

python3 - "$SANDBOX/bad-count.hex0" "$SRC" << 'PY'
import sys
lines = open(sys.argv[2], encoding="utf-8").read().splitlines(keepends=True)
seen = False
out = []
dropped = False
for line in lines:
    if line.startswith("# ## Code"):
        seen = True
    if seen and not dropped and line[:1] not in ("", "#") and any(ch.isalnum() for ch in line.split("#", 1)[0]):
        dropped = True
        continue
    out.append(line)
if not dropped:
    sys.stderr.write("count mutant found nothing\n")
    sys.exit(1)
open(sys.argv[1], "w", encoding="utf-8").write("".join(out))
PY
show_red "mutant row 9 (count)" "comments vs" \
  python3 tools/check/disasm-check.py "$SANDBOX/bad-count.hex0" "$SANDBOX/code.bin" "$SANDBOX/objdump.txt"

check "row 10" "$DUR_FAST" -- python3 - "$HEX0" "$size" << 'PY'
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

check "row 11 lint" "$DUR_CMD" -- python3 tools/check/hex-check.py --lint "$SRC" >"$SANDBOX/lint.out"
grep -qx 'lint: ok' "$SANDBOX/lint.out" || die "row 11 text $(cat "$SANDBOX/lint.out")"
echo "row 11: lint ok"

python3 - "$SANDBOX/bare.hex0" "$SRC" << 'PY'
import sys
text = open(sys.argv[2], encoding="utf-8").read()
open(sys.argv[1], "w", encoding="utf-8").write(text + "\n41\n")
PY
show_red "mutant row 11 (bare)" "lint: bare" \
  python3 tools/check/hex-check.py --lint "$SANDBOX/bare.hex0"
exit 0
