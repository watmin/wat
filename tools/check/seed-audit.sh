#!/usr/bin/env bash
# tools/check/seed-audit.sh TARGET_DIR SANDBOX
# Rows 1, 2, 9, 10 and 11. Both paths are absolute. Facts come from gate.tsv.
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

[ $# -eq 2 ] || die "seed-audit: want TARGET_DIR SANDBOX"
TARGET=$(abs_req "$1")
SANDBOX=$(under_tmp "$2")
export SANDBOX HEX0_SCRATCH=$SANDBOX

HEX0=$TARGET/hex0
SRC=$TARGET/hex0.hex0
GATE=$TARGET/gate.tsv
size=$(fact "$GATE" size)
machine=$(fact "$GATE" objdump_machine)
width=$(fact "$GATE" insn_width)
code_base=$(fact "$GATE" code_base)
row9_from=$(fact "$GATE" row9_from)
row9_to=$(fact "$GATE" row9_to)
PY=$root/tools/check

row1_same() {
  local blob rc
  blob=$(carry "row 1 cmp" "$DUR_FAST" cmp -s "$1" "$2")
  rc=$(payload_rc "$blob")
  if [ "$rc" != 0 ]; then
    echo "row 1: seed differs" >&2
    exit 1
  fi
  echo "row 1: cmp identical"
}

row2_same() {
  local blob rc
  step "row 2 sed" "$DUR_FAST" -- sed 's/[#;].*//' "$1" >"$SANDBOX/stripped.hex"
  step "row 2 xxd" "$DUR_FAST" -- xxd -r -p "$SANDBOX/stripped.hex" >"$SANDBOX/xxd.bin"
  blob=$(carry "row 2 cmp" "$DUR_FAST" cmp -s "$SANDBOX/xxd.bin" "$2")
  rc=$(payload_rc "$blob")
  if [ "$rc" != 0 ]; then
    echo "row 2: bytes differ" >&2
    exit 1
  fi
  echo "row 2: cmp identical"
}

row9_check() {
  local blob rc body
  blob=$(carry "row 9 disasm" "$DUR_CMD" python3 "$PY/disasm-check.py" "$1" "$2" "$3")
  rc=$(payload_rc "$blob")
  body=$(payload_body "$blob")
  if [ "$rc" != 0 ]; then
    printf '%s\n' "$body" >&2
    exit 1
  fi
  printf '%s\n' "$body"
}

row10_check() {
  local blob rc body
  blob=$(carry "row 10" "$DUR_FAST" python3 - "$1" "$2" << 'PY'
import struct
import sys
data = open(sys.argv[1], "rb").read()
phoff = struct.unpack_from("<Q", data, 32)[0]
filesz = struct.unpack_from("<Q", data, phoff + 32)[0]
memsz = struct.unpack_from("<Q", data, phoff + 40)[0]
want = int(sys.argv[2])
if filesz != len(data) or memsz != len(data):
    sys.stderr.write("row 10: filesz %d memsz %d len %d\n" % (filesz, memsz, len(data)))
    sys.exit(1)
if len(data) != want:
    sys.stderr.write("row 10 size %d\n" % len(data))
    sys.exit(1)
sys.stdout.write("row 10: %d bytes\n" % len(data))
PY
)
  rc=$(payload_rc "$blob")
  body=$(payload_body "$blob")
  if [ "$rc" != 0 ]; then
    printf '%s\n' "$body" >&2
    exit 1
  fi
  printf '%s\n' "$body"
}

row11_lint() {
  local blob rc body
  blob=$(carry "row 11 lint" "$DUR_CMD" python3 "$PY/hex-check.py" --lint "$1")
  rc=$(payload_rc "$blob")
  body=$(payload_body "$blob")
  if [ "$rc" != 0 ]; then
    printf '%s\n' "$body" >&2
    exit 1
  fi
  printf '%s\n' "$body"
}

step "row 1 hex-check" "$DUR_CMD" -- python3 "$PY/hex-check.py" "$SRC" >"$SANDBOX/decoded.bin"
row1_same "$SANDBOX/decoded.bin" "$HEX0"

step "row 1 flip" "$DUR_FAST" -- python3 - "$HEX0" "$SANDBOX/flipped.bin" << 'PY'
import sys
data = bytearray(open(sys.argv[1], "rb").read())
data[300] ^= 1
open(sys.argv[2], "wb").write(data)
PY
capture_red "mutant row 1 (byte)" "row 1: seed differs" row1_same "$SANDBOX/flipped.bin" "$HEX0"

row2_same "$SRC" "$HEX0"
step "row 2 mutant" "$DUR_FAST" -- python3 - "$SANDBOX/bad-hex.hex0" "$SRC" << 'PY'
import sys
text = open(sys.argv[2], encoding="utf-8").read()
out = []
done = False
for line in text.splitlines(keepends=True):
    body = line.split("#", 1)[0].split(";", 1)[0]
    if not done and any(ch in "0123456789abcdefABCDEF" for ch in body):
        chars = list(line)
        for i, ch in enumerate(chars):
            if ch in "0123456789abcdefABCDEF":
                chars[i] = "0" if ch != "0" else "1"
                done = True
                break
        line = "".join(chars)
    out.append(line)
if not done:
    sys.stderr.write("row 2 mutant found nothing\n")
    sys.exit(1)
open(sys.argv[1], "w", encoding="utf-8").write("".join(out))
PY
capture_red "mutant row 2 (byte)" "row 2: bytes differ" row2_same "$SANDBOX/bad-hex.hex0" "$HEX0"

step "row 9 dd" "$DUR_FAST" -- dd if="$HEX0" of="$SANDBOX/code.bin" bs=1 skip="$code_base" status=none
step "row 9 objdump" "$DUR_CMD" -- objdump -D -b binary -m "$machine" --adjust-vma="$code_base" --insn-width="$width" "$SANDBOX/code.bin" >"$SANDBOX/objdump.txt"
row9_check "$SRC" "$SANDBOX/code.bin" "$SANDBOX/objdump.txt"

step "row 9 comment mutant" "$DUR_FAST" -- python3 - "$SANDBOX/bad-comment.hex0" "$SRC" "$row9_from" "$row9_to" << 'PY'
import sys
text = open(sys.argv[2], encoding="utf-8").read()
text2 = text.replace(sys.argv[3], sys.argv[4], 1)
if text2 == text:
    sys.stderr.write("comment mutant found nothing\n")
    sys.exit(1)
open(sys.argv[1], "w", encoding="utf-8").write(text2)
PY
capture_red "mutant row 9 (comment)" "row 9 mismatch" row9_check "$SANDBOX/bad-comment.hex0" "$SANDBOX/code.bin" "$SANDBOX/objdump.txt"

step "row 9 offset mutant" "$DUR_FAST" -- python3 - "$SANDBOX/bad-offset.hex0" "$SRC" << 'PY'
import sys
text = open(sys.argv[2], encoding="utf-8").read()
text2 = text.replace("+0078 ", "+0079 ", 1)
if text2 == text:
    sys.stderr.write("offset mutant found nothing\n")
    sys.exit(1)
open(sys.argv[1], "w", encoding="utf-8").write(text2)
PY
capture_red "mutant row 9 (offset)" "row 9: offset" row9_check "$SANDBOX/bad-offset.hex0" "$SANDBOX/code.bin" "$SANDBOX/objdump.txt"

step "row 9 count mutant" "$DUR_FAST" -- python3 - "$SANDBOX/bad-count.hex0" "$SRC" << 'PY'
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
capture_red "mutant row 9 (count)" "comments vs" row9_check "$SANDBOX/bad-count.hex0" "$SANDBOX/code.bin" "$SANDBOX/objdump.txt"

row10_check "$HEX0" "$size"
capture_red "mutant row 10 (size)" "row 10 size" row10_check "$HEX0" 999

lint=$(row11_lint "$SRC") || die "row 11 lint failed"
[ "$lint" = "lint: ok" ] || die "row 11 text $lint"
echo "row 11: lint ok"

step "row 11 bare mutant" "$DUR_FAST" -- python3 - "$SANDBOX/bare.hex0" "$SRC" << 'PY'
import sys
text = open(sys.argv[2], encoding="utf-8").read()
open(sys.argv[1], "w", encoding="utf-8").write(text + "\n41\n")
PY
capture_red "mutant row 11 (bare)" "lint: bare" row11_lint "$SANDBOX/bare.hex0"

step "row 11 ascii mutant" "$DUR_FAST" -- python3 - "$SANDBOX/latin.hex0" "$SRC" << 'PY'
import sys
data = open(sys.argv[2], "rb").read()
open(sys.argv[1], "wb").write(data + b"\n# \xff\n")
PY
capture_red "mutant row 11 (ascii)" "lint: not ascii" row11_lint "$SANDBOX/latin.hex0"
exit 0
