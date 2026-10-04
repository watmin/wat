#!/usr/bin/env bash
# tools/check/layout-mutants.sh SCRATCH_DIR
# The layout rules, each mutant, and the check that the live tree was not touched.
# One reason to change: docs/LAYOUT.md, in the same commit.
set -u
export PYTHONDONTWRITEBYTECODE=1
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd) || exit 2
root=$(cd "$here/../.." && pwd) || exit 2
# shellcheck source=tools/check/gate-lib.sh
. "$here/gate-lib.sh" || exit 2
cd "$root" || exit 2
umask 0022

[ $# -eq 1 ] || die "layout-mutants: want SCRATCH_DIR"
SCRATCH=$1
TREE=$SCRATCH/tree
mkdir -p "$SCRATCH"

before=$(git status --porcelain=v1 | sort)

check "layout" "$DUR_CMD" -- tools/layout.sh >"$SCRATCH/layout.out"
grep -qx 'layout: ok' "$SCRATCH/layout.out" || die "layout text"

rm -rf "$TREE"
cp -a . "$TREE"

mutant_expect() {
  local needle=$1
  local label=$2
  run_status "$DUR_CMD" -- tools/layout.sh "$TREE" >"$SCRATCH/mut.out" 2>"$SCRATCH/mut.err"
  local rc=$?
  if timed_out "$rc"; then
    die "mutant $label timed out"
  fi
  [ "$rc" -ne 0 ] || die "mutant $label stayed green"
  if ! grep -q -F -e "$needle" "$SCRATCH/mut.out"; then
    die "mutant $label said $(cat "$SCRATCH/mut.out" "$SCRATCH/mut.err")"
  fi
  echo "mutant $label: red"
}

echo stray > "$TREE/STRAY"
mutant_expect "top-level name not in the layout: STRAY" "stray top-level file"
rm -f "$TREE/STRAY"

mkdir -p "$TREE/brand/subdir"
mutant_expect "brand/ holds a non-image: brand/subdir" "brand directory"
rmdir "$TREE/brand/subdir"

printf 'x\n' > "$TREE/brand/x.md"
mutant_expect "brand/ holds a non-image: brand/x.md" "brand non-image"
rm -f "$TREE/brand/x.md"

printf '\177ELF' > "$TREE/brand/evil.png"
mutant_expect "ELF magic outside the seed: brand/evil.png" "ELF in brand"
rm -f "$TREE/brand/evil.png"

mkdir -p "$TREE/out"
printf 'h\n' > "$TREE/out/h1"
git -C "$TREE" add -f -- out/h1
mutant_expect "tracked out/ path: out/h1" "tracked out"
git -C "$TREE" rm -f --cached -- out/h1 >/dev/null
rm -f "$TREE/out/h1"

printf '\177ELF' > "$TREE/ladder/0-hex0/tests/second.elf"
mutant_expect "ELF magic outside the seed: ladder/0-hex0/tests/second.elf" "second ELF"
rm -f "$TREE/ladder/0-hex0/tests/second.elf"

shopt -s nullglob
seeds=("$TREE"/ladder/0-hex0/*/hex0)
[ "${#seeds[@]}" -ge 1 ] || die "copied tree has no seed"
seed=${seeds[0]}

cp "$seed" "$TREE/ladder/0-hex0/hex0"
mutant_expect "ELF magic outside the seed: ladder/0-hex0/hex0" "seed outside a target"
rm -f "$TREE/ladder/0-hex0/hex0"

printf '\177ELF' > "$(dirname "$seed")/other"
mutant_expect "ELF magic outside the seed:" "second binary inside a target"
rm -f "$(dirname "$seed")/other"

printf 'A\0B' > "$TREE/ladder/0-hex0/tests/second.bin"
mutant_expect "binary outside the seed and brand/:" "NUL binary"
rm -f "$TREE/ladder/0-hex0/tests/second.bin"

printf 'x\n' > "$TREE/ladder/0-hex0/x86_64-linux/note.md"
mutant_expect "process document inside a rung:" "markdown inside a target"
rm -f "$TREE/ladder/0-hex0/x86_64-linux/note.md"

printf 'x\n' > "$TREE/ladder/0-hex0/x86_64-linux/note"
mutant_expect "process document inside a rung:" "note inside a target"
rm -f "$TREE/ladder/0-hex0/x86_64-linux/note"

echo brief > "$TREE/ladder/0-hex0/BRIEF.md"
mutant_expect "rung holds something other than README, tests/, and a target:" "brief inside a rung"
rm -f "$TREE/ladder/0-hex0/BRIEF.md"

mkdir -p "$TREE/ladder/0-hex0/aarch64-linux"
mutant_expect "target has no source:" "target with no source"
rmdir "$TREE/ladder/0-hex0/aarch64-linux"

mkdir -p "$TREE/ladder/0-hex0/X86-64"
mutant_expect "target name is not" "badly named target"
rmdir "$TREE/ladder/0-hex0/X86-64"

mkdir -p "$TREE/ladder/NotARung"
printf '%s\n' '# rung' > "$TREE/ladder/NotARung/README.md"
mutant_expect "rung directory is not" "rung name"
rm -rf "$TREE/ladder/NotARung"

month=""
for y in "$TREE"/docs/excursus/*/; do
  for m in "$y"*/; do
    month=${m%/}
  done
done
[ -n "$month" ] || die "copied tree has no excursus month"
max=0
for ex in "$month"/*/; do
  b=$(basename "$ex")
  if [[ $b =~ ^([0-9]{3})- ]]; then
    n=$((10#${BASH_REMATCH[1]}))
    if [ "$n" -gt "$max" ]; then
      max=$n
    fi
  fi
done
[ "$max" -ge 1 ] || die "copied tree has no excursus counter"
gap=$((max + 2))
gap_name=$(printf '%03d-counter-gap' "$gap")

mkdir -p "$TREE/ladder/${gap}-skip"
cat > "$TREE/ladder/${gap}-skip/README.md" << 'EOF'
# skip
| 0 | a |
| 1 | a |
| 2 | a |
| 3 | a |
| 4 | a |
| 5 | a |
| 6 | a |
| 7 | a |
EOF
mutant_expect "rung numbers skip" "rung number gap"
rm -rf "$TREE/ladder/${gap}-skip"

src="$TREE/ladder/0-hex0/x86_64-linux/hex0.hex0"
cp "$src" "$SCRATCH/src.bak"
cp ladder/0-hex0/README.md "$SCRATCH/readme.bak"

git -C "$TREE" rm -f -- ladder/0-hex0/README.md >/dev/null
mutant_expect "rung has no README.md" "rung without README"
git -C "$TREE" checkout HEAD -- ladder/0-hex0/README.md

printf 'no exit table\n' > "$TREE/ladder/0-hex0/README.md"
mutant_expect "readme has no exit statuses" "readme without an exit table"
cp "$SCRATCH/readme.bak" "$TREE/ladder/0-hex0/README.md"

{
  printf '%s\n' '# Exit status:'
  n=0
  while [ "$n" -le 7 ]; do
    if [ "$n" -ne 4 ]; then
      printf '# %s x\n' "$n"
    fi
    n=$((n + 1))
  done
} >> "$src"
mutant_expect "exit statuses differ" "source missing a status"
cp "$SCRATCH/src.bak" "$src"

{
  printf '%s\n' '# Exit status:'
  n=0
  while [ "$n" -le 8 ]; do
    printf '# %s x\n' "$n"
    n=$((n + 1))
  done
} >> "$src"
mutant_expect "exit statuses differ" "source extra status"
cp "$SCRATCH/src.bak" "$src"

printf x >> "$TREE/archived/README.md"
mutant_expect "archived/ bytes differ" "archived byte"
git -C "$TREE" checkout -- archived/README.md

printf 'x\n' > "$TREE/archived/untracked.txt"
mutant_expect "untracked file under archived/" "untracked archived file"
rm -f "$TREE/archived/untracked.txt"

redir='>'
printf '%s\n' "echo x ${redir} out/nope" > "$TREE/tools/check/writes-out.sh"
mutant_expect "a tools file redirects into out/" "redirect into out/"
rm -f "$TREE/tools/check/writes-out.sh"

verb=tee
printf '%s x out/nope\n' "$verb" > "$TREE/tools/check/tees-out.sh"
mutant_expect "a tools file tees into out/" "tee-out"
rm -f "$TREE/tools/check/tees-out.sh"

verb=cp
printf '%s a out/b\n' "$verb" > "$TREE/tools/check/copies-out.sh"
mutant_expect "a tools file copies into out/" "copy into out/"
rm -f "$TREE/tools/check/copies-out.sh"

verb=mv
printf '%s a out/b\n' "$verb" > "$TREE/tools/check/moves-out.sh"
mutant_expect "a tools file moves into out/" "move into out/"
rm -f "$TREE/tools/check/moves-out.sh"

dd_key='of='
printf 'dd if=/dev/zero %sout/nope\n' "$dd_key" > "$TREE/tools/check/dd-out.sh"
mutant_expect "a tools file writes out/ with dd" "dd into out/"
rm -f "$TREE/tools/check/dd-out.sh"

verb=install
printf '%s a out/b\n' "$verb" > "$TREE/tools/check/installs-out.sh"
mutant_expect "a tools file installs into out/" "install-out"
rm -f "$TREE/tools/check/installs-out.sh"

flag='-o'
printf 'gcc %s out/nope\n' "$flag" > "$TREE/tools/check/o-out.sh"
mutant_expect "a tools file names -o into out/" "dash-o into out/"
rm -f "$TREE/tools/check/o-out.sh"

left='cp x '
right='out/hex1 # fault.c out/fault'
printf '%s%s\n' "$left" "$right" > "$TREE/tools/check/copies-fault.sh"
mutant_expect "a tools file copies into out/" "fault allowance bypass"
rm -f "$TREE/tools/check/copies-fault.sh"

payload=$(printf '%s\n' ':wat:'':core:'':+')
printf '%s\n' "$payload" > "$TREE/ladder/0-hex0/tests/retired.wat"
git -C "$TREE" add -- ladder/0-hex0/tests/retired.wat
mutant_expect "colon-path token in" "colon path"
git -C "$TREE" rm -f --cached -- ladder/0-hex0/tests/retired.wat >/dev/null
rm -f "$TREE/ladder/0-hex0/tests/retired.wat"

tok='-'
tok+='>'
printf 'use %s Int\n' "$tok" > "$TREE/ladder/0-hex0/tests/arrow.wat"
git -C "$TREE" add -- ladder/0-hex0/tests/arrow.wat
mutant_expect "bare type arrow in" "tracked arrow"
git -C "$TREE" rm -f --cached -- ladder/0-hex0/tests/arrow.wat >/dev/null
rm -f "$TREE/ladder/0-hex0/tests/arrow.wat"

mkdir -p "$TREE/docs/stray-dir"
mutant_expect "stray directory under docs/" "stray directory under docs/"
rm -rf "$TREE/docs/stray-dir"

printf 'x\n' > "$TREE/docs/plain.txt"
mutant_expect "docs/ top level is not a standing document" "docs top-level non-document"
rm -f "$TREE/docs/plain.txt"

mkdir -p "$TREE/docs/excursus/notyear"
mutant_expect "excursus year is not YYYY" "year not YYYY"
rmdir "$TREE/docs/excursus/notyear"

year=$(dirname "$month")
mkdir -p "$year/13"
mutant_expect "excursus month is not MM" "month not MM"
rmdir "$year/13"

empty=""
i=1
while [ "$i" -le 12 ]; do
  mm=$(printf '%02d' "$i")
  if [ ! -e "$year/$mm" ]; then
    empty=$mm
    break
  fi
  i=$((i + 1))
done
[ -n "$empty" ] || die "no empty month to plant"
mkdir "$year/$empty"
mutant_expect "excursus month has no counter" "empty month"
rmdir "$year/$empty"

mkdir -p "$month/$gap_name"
mutant_expect "excursus counter gap" "counter gap"
rm -rf "$month/$gap_name"

exdir=""
for ex in "$month"/*/; do
  exdir=${ex%/}
done
[ -n "$exdir" ] || die "copied tree has no excursus"
mkdir "$exdir/nested"
mutant_expect "excursus holds a directory" "directory inside an excursus"
rmdir "$exdir/nested"

printf 'AA\n' > "$exdir/stray.hex0"
mutant_expect "excursus holds a non-document" "non-document in an excursus"
rm -f "$exdir/stray.hex0"

bad_n=$(printf '%03d' $((max + 1)))
mkdir -p "$month/${bad_n}-BadSlug"
mutant_expect "badly formed excursus slug" "bad slug"
rm -rf "$month/${bad_n}-BadSlug"

bare_line='see excursus'
bare_line+=' '
bare_line+='001'
printf '%s\n' "$bare_line" > "$TREE/docs/bare-ref.md"
git -C "$TREE" add -- docs/bare-ref.md
mutant_expect "bare numbered reference in" "bare numbered reference"
git -C "$TREE" rm -f --cached -- docs/bare-ref.md >/dev/null
rm -f "$TREE/docs/bare-ref.md"

mkdir -p "$TREE/ladder/0-hex0/aarch64-linux"
printf '%s\n' '41' '# Exit status: see the rung README' > "$TREE/ladder/0-hex0/aarch64-linux/hex0.hex0"
check "second target pointer" "$DUR_CMD" -- tools/layout.sh "$TREE" >"$SCRATCH/second.out"
grep -qx 'layout: ok' "$SCRATCH/second.out" || die "second target pointer stayed red"
echo "second target with a pointer: green"
rm -rf "$TREE/ladder/0-hex0/aarch64-linux"

rm -rf "$TREE"
check "layout after mutants" "$DUR_CMD" -- tools/layout.sh >"$SCRATCH/layout2.out"
grep -qx 'layout: ok' "$SCRATCH/layout2.out" || die "layout after mutants"
echo "layout: ok"

after=$(git status --porcelain=v1 | sort)
[ "$before" = "$after" ] || die "live tree changed during layout mutants"
git diff --quiet c45603e -- archived || die "archived not restored"
exit 0
