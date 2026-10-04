#!/usr/bin/env bash
# tools/check/layout-mutants.sh SCRATCH_DIR
# The layout rules, each mutant, and the check that the live tree was not touched.
# One reason to change: docs/LAYOUT.md, in the same commit.
set -u
export PYTHONDONTWRITEBYTECODE=1
here=$(dirname "${BASH_SOURCE[0]}")
cd "$here/../.." || exit 2
# shellcheck disable=SC1091
. "$here/gate-lib.sh"
umask 0022

[ $# -eq 1 ] || die "layout-mutants: want SCRATCH_DIR"
SCRATCH=$1
TREE=$SCRATCH/tree
mkdir -p "$SCRATCH"

before=$(git status --porcelain=v1 | sort)

guard 60 tools/layout.sh >"$SCRATCH/layout.out" 2>"$SCRATCH/layout.err"
rc=$?
[ "$rc" -eq 0 ] || die "layout rc $rc ($(cat "$SCRATCH/layout.out" "$SCRATCH/layout.err"))"
grep -qx 'layout: ok' "$SCRATCH/layout.out" || die "layout text"

rm -rf "$TREE"
cp -a . "$TREE"

mutant_expect() {
  local rule=$1 label=$2
  guard 60 tools/layout.sh "$TREE" >"$SCRATCH/mut.out" 2>"$SCRATCH/mut.err"
  rc=$?
  [ "$rc" -ne 0 ] || die "mutant rule $rule ($label) stayed green"
  grep -q "layout: rule ${rule}:" "$SCRATCH/mut.out" || die "mutant rule $rule ($label) said $(cat "$SCRATCH/mut.out" "$SCRATCH/mut.err")"
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

shopt -s nullglob
seeds=("$TREE"/ladder/0-hex0/*/hex0)
[ "${#seeds[@]}" -ge 1 ] || die "copied tree has no seed"
seed=${seeds[0]}

cp "$seed" "$TREE/ladder/0-hex0/hex0"
mutant_expect 2 "seed outside a target"
rm -f "$TREE/ladder/0-hex0/hex0"

printf '\177ELF' > "$(dirname "$seed")/other"
mutant_expect 2 "second binary inside a target"
rm -f "$(dirname "$seed")/other"

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

max=0
found=0
for rung in ladder/*/; do
  base=$(basename "$rung")
  n=${base%%-*}
  if [[ $n =~ ^[0-9]+$ ]]; then
    n=$((10#$n))
    found=1
    if [ "$n" -gt "$max" ]; then
      max=$n
    fi
  fi
done
[ "$found" -eq 1 ] || die "no rungs under ladder/"
gap=$((max + 2))

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
EOF
mutant_expect 4 "rung number gap"
rm -rf "$TREE/ladder/${gap}-skip"

cp ladder/0-hex0/README.md "$SCRATCH/readme.bak"
printf 'no exit table\n' > "$TREE/ladder/0-hex0/README.md"
mutant_expect 5 "readme without an exit table"
cp "$SCRATCH/readme.bak" "$TREE/ladder/0-hex0/README.md"

grep -v '^| 4 |' "$SCRATCH/readme.bak" > "$TREE/ladder/0-hex0/README.md"
mutant_expect 5 "readme missing a status"
cp "$SCRATCH/readme.bak" "$TREE/ladder/0-hex0/README.md"

cp "$SCRATCH/readme.bak" "$TREE/ladder/0-hex0/README.md"
printf '| 8 | not a status of this rung |\n' >> "$TREE/ladder/0-hex0/README.md"
mutant_expect 5 "readme extra status"
cp "$SCRATCH/readme.bak" "$TREE/ladder/0-hex0/README.md"

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

printf '%s\n' "$payload" > "$TREE/tools/check/untracked-colon.wat"
mutant_expect 8 "untracked colon path"
rm -f "$TREE/tools/check/untracked-colon.wat"

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
guard 60 tools/layout.sh >"$SCRATCH/layout2.out" 2>"$SCRATCH/layout2.err"
rc=$?
[ "$rc" -eq 0 ] || die "layout after mutants rc $rc ($(cat "$SCRATCH/layout2.out"))"
grep -qx 'layout: ok' "$SCRATCH/layout2.out" || die "layout after mutants"
echo "layout: ok"

after=$(git status --porcelain=v1 | sort)
[ "$before" = "$after" ] || die "live tree changed during layout mutants"
git diff --quiet c45603e -- archived || die "archived not restored"
[ ! -e STRAY ] || die "STRAY left behind"
[ ! -e "ladder/${gap}-skip" ] || die "gap rung left behind"
[ ! -e brand/x.md ] || die "brand mutant left behind"
[ ! -e docs/bare-ref.md ] || die "bare ref left behind"
[ ! -e tools/check/untracked-colon.wat ] || die "untracked colon left behind"
exit 0
