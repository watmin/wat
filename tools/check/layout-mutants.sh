#!/usr/bin/env bash
# tools/check/layout-mutants.sh SCRATCH_DIR
# Each layout rule, broken on a sandbox tree, calling layout.sh itself.
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
cd "$root" || exit 2
umask 0022
GIT=$here/git-sandbox

[ $# -eq 1 ] || die "layout-mutants: want SCRATCH_DIR"
SCRATCH=$(under_tmp "$1")
TREE=$SCRATCH/tree
export SANDBOX=$SCRATCH
export HEX0_SCRATCH=$SCRATCH

layout_ok=$(step "layout" "$DUR_LONG" -- "$root/tools/layout.sh")
[ "$layout_ok" = "layout: ok" ] || die "layout text $layout_ok"
echo "layout: ok"

step "tree reset" "$DUR_FAST" -- rm -rf "$TREE"
sandbox_tree "$root" "$TREE"

mutant_expect() {
  local needle=$1
  local label=$2
  expect "mutant $label" "$DUR_LONG" "text:$needle" -- "$root/tools/layout.sh" "$TREE"
  echo "mutant $label: red"
  row_did=mutant_expect
}

step "stray" "$DUR_FAST" -- bash -c 'printf stray > "$1/STRAY"' bash "$TREE"
row_did=""
mutant_expect "top-level name not in the layout: STRAY" "stray top-level file"
[ "$row_did" = mutant_expect ] || die "mutant_expect did not compare"
step "unstray" "$DUR_FAST" -- rm -f "$TREE/STRAY"

step "brand dir" "$DUR_FAST" -- mkdir -p "$TREE/brand/subdir"
mutant_expect "brand/ holds a non-image: brand/subdir" "brand directory"
step "brand dir rm" "$DUR_FAST" -- rm -rf "$TREE/brand/subdir"

step "brand md" "$DUR_FAST" -- bash -c 'printf "x\n" > "$1/brand/x.md"' bash "$TREE"
mutant_expect "brand/ holds a non-image: brand/x.md" "brand non-image"
step "brand md rm" "$DUR_FAST" -- rm -f "$TREE/brand/x.md"

step "brand elf" "$DUR_FAST" -- bash -c 'printf "\177ELF" > "$1/brand/evil.png"' bash "$TREE"
mutant_expect "ELF magic outside the seed: brand/evil.png" "ELF in brand"
step "brand elf rm" "$DUR_FAST" -- rm -f "$TREE/brand/evil.png"

# A PNG header with ELF magic later in the file.
step "brand append" "$DUR_FAST" -- python3 -c 'import sys; open(sys.argv[1],"wb").write(b"\x89PNG\r\n\x1a\n"+b"\x7fELF")' "$TREE/brand/marked.png"
mutant_expect "ELF magic outside the seed: brand/marked.png" "ELF appended to a PNG"
step "brand append rm" "$DUR_FAST" -- rm -f "$TREE/brand/marked.png"

product='out'
step "tracked out mkdir" "$DUR_FAST" -- mkdir -p "$TREE/$product"
step "tracked out file" "$DUR_FAST" -- bash -c 'printf "h\n" > "$1/$2/h1"' bash "$TREE" "$product"
step "tracked out add" "$DUR_CMD" -- "$GIT" -C "$TREE" add -f -- "$product/h1"
mutant_expect "tracked out/ path:" "tracked out"
step "tracked out unstage" "$DUR_CMD" -- "$GIT" -C "$TREE" rm -f --cached -- "$product/h1"
step "tracked out rm" "$DUR_FAST" -- rm -f "$TREE/$product/h1"

step "second elf" "$DUR_FAST" -- bash -c 'printf "\177ELF" > "$1/ladder/0-hex0/tests/second.elf"' bash "$TREE"
mutant_expect "ELF magic outside the seed: ladder/0-hex0/tests/second.elf" "second ELF"
step "second elf rm" "$DUR_FAST" -- rm -f "$TREE/ladder/0-hex0/tests/second.elf"

leaf=hex0
step "seed copy" "$DUR_FAST" -- bash -c 'cp "$1/$2" "$3/$2"' bash "$TREE/ladder/0-hex0/x86_64-linux" "$leaf" "$TREE/ladder/0-hex0"
mutant_expect "ELF magic outside the seed: ladder/0-hex0/hex0" "seed outside a target"
step "seed copy rm" "$DUR_FAST" -- rm -f "$TREE/ladder/0-hex0/hex0"

step "other bin" "$DUR_FAST" -- bash -c 'printf "\177ELF" > "$1/ladder/0-hex0/x86_64-linux/other"' bash "$TREE"
mutant_expect "ELF magic outside the seed:" "second binary inside a target"
step "other bin rm" "$DUR_FAST" -- rm -f "$TREE/ladder/0-hex0/x86_64-linux/other"

step "nul bin" "$DUR_FAST" -- python3 -c 'import sys; open(sys.argv[1],"wb").write(b"A\0B")' "$TREE/ladder/0-hex0/tests/second.bin"
mutant_expect "binary outside the seed and brand/:" "NUL binary"
step "nul bin rm" "$DUR_FAST" -- rm -f "$TREE/ladder/0-hex0/tests/second.bin"

step "note md" "$DUR_FAST" -- bash -c 'printf "x\n" > "$1/ladder/0-hex0/x86_64-linux/note.md"' bash "$TREE"
mutant_expect "process document inside a rung:" "markdown inside a target"
step "note md rm" "$DUR_FAST" -- rm -f "$TREE/ladder/0-hex0/x86_64-linux/note.md"

step "plan md" "$DUR_FAST" -- bash -c 'printf "x\n" > "$1/ladder/0-hex0/x86_64-linux/plan.md"' bash "$TREE"
mutant_expect "process document inside a rung:" "plan inside a target"
step "plan md rm" "$DUR_FAST" -- rm -f "$TREE/ladder/0-hex0/x86_64-linux/plan.md"

step "hidden brief" "$DUR_FAST" -- bash -c 'printf "x\n" > "$1/ladder/0-hex0/.BRIEF.md"' bash "$TREE"
mutant_expect "rung holds something other than README, tests/, and a target:" "hidden brief"
step "hidden brief rm" "$DUR_FAST" -- rm -f "$TREE/ladder/0-hex0/.BRIEF.md"

step "tests brief" "$DUR_FAST" -- bash -c 'printf "x\n" > "$1/ladder/0-hex0/tests/BRIEF-hex1.md"' bash "$TREE"
mutant_expect "process document inside a rung:" "brief inside tests"
step "tests brief rm" "$DUR_FAST" -- rm -f "$TREE/ladder/0-hex0/tests/BRIEF-hex1.md"

step "tests nest" "$DUR_FAST" -- mkdir -p "$TREE/ladder/0-hex0/tests/nested"
mutant_expect "tests/ holds a directory:" "nested tests directory"
step "tests nest rm" "$DUR_FAST" -- rm -rf "$TREE/ladder/0-hex0/tests/nested"

step "rung brief" "$DUR_FAST" -- bash -c 'printf brief > "$1/ladder/0-hex0/BRIEF.md"' bash "$TREE"
mutant_expect "rung holds something other than README, tests/, and a target:" "brief inside a rung"
step "rung brief rm" "$DUR_FAST" -- rm -f "$TREE/ladder/0-hex0/BRIEF.md"

step "empty target" "$DUR_FAST" -- mkdir -p "$TREE/ladder/0-hex0/aarch64-linux"
mutant_expect "target has no source:" "target with no source"
step "only tsv" "$DUR_FAST" -- cp "$TREE/ladder/0-hex0/x86_64-linux/gate.tsv" "$TREE/ladder/0-hex0/aarch64-linux/gate.tsv"
mutant_expect "target has no source:" "target with only a table"
step "empty target rm" "$DUR_FAST" -- rm -rf "$TREE/ladder/0-hex0/aarch64-linux"

step "freebsd target" "$DUR_FAST" -- mkdir -p "$TREE/ladder/0-hex0/x86_64-freebsd"
step "freebsd source" "$DUR_FAST" -- bash -c 'printf "41\n" > "$1/ladder/0-hex0/x86_64-freebsd/hex0.hex0"' bash "$TREE"
mutant_expect "target not named in the design table:" "target not in the design table"
step "freebsd rm" "$DUR_FAST" -- rm -rf "$TREE/ladder/0-hex0/x86_64-freebsd"

step "bad target" "$DUR_FAST" -- mkdir -p "$TREE/ladder/0-hex0/X86-64"
mutant_expect "target name is not" "badly named target"
step "bad target rm" "$DUR_FAST" -- rmdir "$TREE/ladder/0-hex0/X86-64"

step "bad rung" "$DUR_FAST" -- mkdir -p "$TREE/ladder/NotARung"
step "bad rung readme" "$DUR_FAST" -- bash -c 'printf "%s\n" "# rung" > "$1/ladder/NotARung/README.md"' bash "$TREE"
mutant_expect "rung directory is not" "rung name"
step "bad rung rm" "$DUR_FAST" -- rm -rf "$TREE/ladder/NotARung"

step "hidden rung" "$DUR_FAST" -- mkdir -p "$TREE/ladder/.1-hex1"
mutant_expect "rung directory is not" "hidden rung"
step "hidden rung rm" "$DUR_FAST" -- rm -rf "$TREE/ladder/.1-hex1"

month=""
for y in "$TREE"/docs/excursus/*/; do
  for m in "$y"*/; do
    month=${m%/}
  done
done
[ -n "$month" ] || die "copied tree has no excursus month"
max=0
for ex in "$month"/*/; do
  b=${ex%/}
  b=${b##*/}
  if [[ $b =~ ^([0-9]{3})- ]]; then
    n=$((10#${BASH_REMATCH[1]}))
    if [ "$n" -gt "$max" ]; then
      max=$n
    fi
  fi
done
[ "$max" -ge 1 ] || die "copied tree has no excursus counter"
gap=$((max + 2))
step "gap rung" "$DUR_FAST" -- mkdir -p "$TREE/ladder/${gap}-skip"
step "gap readme" "$DUR_CMD" -- bash -c 'cat > "$1/README.md"' bash "$TREE/ladder/${gap}-skip" << 'EOF'
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
step "gap rm" "$DUR_FAST" -- rm -rf "$TREE/ladder/${gap}-skip"

src="$TREE/ladder/0-hex0/x86_64-linux/hex0.hex0"
step "src bak" "$DUR_FAST" -- cp "$src" "$SCRATCH/src.bak"
step "readme bak" "$DUR_FAST" -- cp "$root/ladder/0-hex0/README.md" "$SCRATCH/readme.bak"

step "rm readme" "$DUR_CMD" -- "$GIT" -C "$TREE" rm -f -- ladder/0-hex0/README.md
mutant_expect "rung has no README.md" "rung without README"
step "restore readme" "$DUR_CMD" -- "$GIT" -C "$TREE" checkout HEAD -- ladder/0-hex0/README.md

step "blank readme" "$DUR_FAST" -- bash -c 'printf "no exit table\n" > "$1/ladder/0-hex0/README.md"' bash "$TREE"
mutant_expect "readme has no exit statuses" "readme without an exit table"
step "readme restore copy" "$DUR_FAST" -- cp "$SCRATCH/readme.bak" "$TREE/ladder/0-hex0/README.md"

step "status word" "$DUR_FAST" -- bash -c 'printf "\n# status 9 means a refusal that is not in the contract\n" >> "$1"' bash "$src"
mutant_expect "target source states a status meaning:" "status word"
step "src restore 1" "$DUR_FAST" -- cp "$SCRATCH/src.bak" "$src"

step "status block" "$DUR_FAST" -- bash -c 'printf "\n# Exit status:\n# 9 nope\n" >> "$1"' bash "$src"
mutant_expect "target source states a status meaning:" "status block"
step "src restore 2" "$DUR_FAST" -- cp "$SCRATCH/src.bak" "$src"

step "archived byte" "$DUR_FAST" -- bash -c 'printf x >> "$1/archived/README.md"' bash "$TREE"
mutant_expect "archived/ bytes differ" "archived byte"
step "archived restore" "$DUR_CMD" -- "$GIT" -C "$TREE" checkout -- archived/README.md

step "archived untracked" "$DUR_FAST" -- bash -c 'printf "x\n" > "$1/archived/untracked.txt"' bash "$TREE"
mutant_expect "untracked file under archived/" "untracked archived file"
step "archived untracked rm" "$DUR_FAST" -- rm -f "$TREE/archived/untracked.txt"

# rune:complectens(helper) — write_tool writes a mutant file and is not a comparison.
write_tool() {
  local name=$1
  local body=$2
  step "write $name" "$DUR_FAST" -- bash -c 'printf "%s\n" "$2" > "$1"' bash "$TREE/tools/check/$name" "$body"
}

redir='>'
write_tool writes-out.sh "echo x ${redir} out/nope"
mutant_expect "a tools file redirects into out/" "redirect into out/"
step "rm writes-out" "$DUR_FAST" -- rm -f "$TREE/tools/check/writes-out.sh"

quote='"'
write_tool writes-quoted.sh "echo x ${redir} ${quote}out/nope${quote}"
mutant_expect "a tools file redirects into out/" "quoted redirect"
step "rm writes-quoted" "$DUR_FAST" -- rm -f "$TREE/tools/check/writes-quoted.sh"

write_tool writes-var.sh "echo x ${redir}${quote}\$ROOT/out/nope${quote}"
mutant_expect "a tools file redirects into out/" "variable redirect"
step "rm writes-var" "$DUR_FAST" -- rm -f "$TREE/tools/check/writes-var.sh"

verb='tee'
write_tool tees-out.sh "$verb x out/nope"
mutant_expect "a tools file tees into out/" "tee-out"
step "rm tees" "$DUR_FAST" -- rm -f "$TREE/tools/check/tees-out.sh"

verb='cp'
write_tool copies-out.sh "$verb a out/b"
mutant_expect "a tools file copies into out/" "copy into out/"
step "rm copies" "$DUR_FAST" -- rm -f "$TREE/tools/check/copies-out.sh"

verb='mv'
write_tool moves-out.sh "$verb a out/b"
mutant_expect "a tools file moves into out/" "move into out/"
step "rm moves" "$DUR_FAST" -- rm -f "$TREE/tools/check/moves-out.sh"

dd_key='of='
write_tool dd-out.sh "dd if=/dev/zero ${dd_key}out/nope"
mutant_expect "a tools file writes out/ with dd" "dd into out/"
step "rm dd" "$DUR_FAST" -- rm -f "$TREE/tools/check/dd-out.sh"

verb='install'
write_tool installs-out.sh "$verb a out/b"
mutant_expect "a tools file installs into out/" "install-out"
step "rm install" "$DUR_FAST" -- rm -f "$TREE/tools/check/installs-out.sh"

flag='-o'
write_tool o-out.sh "gcc ${flag} out/nope"
mutant_expect "a tools file names -o into out/" "dash-o into out/"
step "rm o" "$DUR_FAST" -- rm -f "$TREE/tools/check/o-out.sh"

seed_line='cp seed '
seed_line+='ladder/'
seed_line+='0-hex0/x86_64-linux/'
seed_line+='hex0'
write_tool writes-seed.sh "$seed_line"
mutant_expect "a tools file writes a target seed:" "tools write a seed"
step "rm seed write" "$DUR_FAST" -- rm -f "$TREE/tools/check/writes-seed.sh"

step "colon file" "$DUR_FAST" -- bash -c 'printf "%s\n" "x" > "$1/tools/check/colon.wat"' bash "$TREE"
# The rejected token is assembled in the mutant file only.
step "colon body" "$DUR_FAST" -- python3 -c 'import sys; open(sys.argv[1],"w").write(":"+":"+"path\n")' "$TREE/tools/check/colon.wat"
step "colon add" "$DUR_CMD" -- "$GIT" -C "$TREE" add -- tools/check/colon.wat
mutant_expect "colon-path token in" "colon path"
step "colon rm" "$DUR_CMD" -- "$GIT" -C "$TREE" rm -f -- tools/check/colon.wat

step "arrow file" "$DUR_FAST" -- python3 -c 'import sys; open(sys.argv[1],"w").write("a "+"<"+"-"+" b\n")' "$TREE/tools/check/arrow.wat"
step "arrow add" "$DUR_CMD" -- "$GIT" -C "$TREE" add -- tools/check/arrow.wat
mutant_expect "bare type arrow in" "tracked arrow"
step "arrow rm" "$DUR_CMD" -- "$GIT" -C "$TREE" rm -f -- tools/check/arrow.wat

step "stray docs" "$DUR_FAST" -- mkdir -p "$TREE/docs/stray-dir"
mutant_expect "stray directory under docs/" "stray directory under docs/"
step "stray docs rm" "$DUR_FAST" -- rm -rf "$TREE/docs/stray-dir"

step "docs bin" "$DUR_FAST" -- bash -c 'printf x > "$1/docs/stray.bin"' bash "$TREE"
mutant_expect "docs/ top level is not a standing document" "docs top-level non-document"
step "docs bin rm" "$DUR_FAST" -- rm -f "$TREE/docs/stray.bin"

step "bad year" "$DUR_FAST" -- mkdir -p "$TREE/docs/excursus/YYYY"
mutant_expect "excursus year is not YYYY" "year not YYYY"
step "bad year rm" "$DUR_FAST" -- rm -rf "$TREE/docs/excursus/YYYY"

step "bad month" "$DUR_FAST" -- mkdir -p "$TREE/docs/excursus/2026/13"
mutant_expect "excursus month is not MM" "month not MM"
step "bad month rm" "$DUR_FAST" -- rm -rf "$TREE/docs/excursus/2026/13"

empty=""
for y in "$TREE"/docs/excursus/*/; do
  for m in "$y"*/; do
    n=0
    for ex in "$m"*/; do
      [ -d "$ex" ] && n=$((n + 1))
    done
    if [ "$n" -eq 0 ]; then
      empty=${m%/}
    fi
  done
done
if [ -z "$empty" ]; then
  step "empty month" "$DUR_FAST" -- mkdir -p "$TREE/docs/excursus/2026/02"
  empty=$TREE/docs/excursus/2026/02
fi
mutant_expect "excursus month has no counter" "empty month"
step "empty month rm" "$DUR_FAST" -- rm -rf "$TREE/docs/excursus/2026/02"

step "counter gap dir" "$DUR_FAST" -- mkdir -p "$month/$(printf '%03d' $((max + 2)))-gap"
mutant_expect "excursus counter gap" "counter gap"
step "counter gap rm" "$DUR_FAST" -- rm -rf "$month/$(printf '%03d' $((max + 2)))-gap"

exdir=""
for ex in "$month"/*/; do
  exdir=${ex%/}
done
[ -n "$exdir" ] || die "copied tree has no excursus"
step "ex dir" "$DUR_FAST" -- mkdir -p "$exdir/nested"
mutant_expect "excursus holds a directory" "directory inside an excursus"
step "ex dir rm" "$DUR_FAST" -- rmdir "$exdir/nested"

step "ex bin" "$DUR_FAST" -- bash -c 'printf "AA\n" > "$1/stray.hex0"' bash "$exdir"
mutant_expect "excursus holds a non-document" "non-document in an excursus"
step "ex bin rm" "$DUR_FAST" -- rm -f "$exdir/stray.hex0"

bad_n=$(printf '%03d' $((max + 1)))
step "bad slug" "$DUR_FAST" -- mkdir -p "$month/${bad_n}-BadSlug"
mutant_expect "badly formed excursus slug" "bad slug"
step "bad slug rm" "$DUR_FAST" -- rm -rf "$month/${bad_n}-BadSlug"

step "bare ref" "$DUR_FAST" -- python3 -c 'import sys; open(sys.argv[1],"w").write("see excursus"+" "+"001\n")' "$TREE/docs/bare-ref.md"
step "bare add" "$DUR_CMD" -- "$GIT" -C "$TREE" add -- docs/bare-ref.md
mutant_expect "bare numbered reference in" "bare numbered reference"
step "bare unstage" "$DUR_CMD" -- "$GIT" -C "$TREE" rm -f --cached -- docs/bare-ref.md
step "bare rm" "$DUR_FAST" -- rm -f "$TREE/docs/bare-ref.md"

step "case ref" "$DUR_FAST" -- python3 -c 'import sys; open(sys.argv[1],"w").write("See Excursus"+" "+"001\n")' "$TREE/docs/case-ref.md"
step "case add" "$DUR_CMD" -- "$GIT" -C "$TREE" add -- docs/case-ref.md
mutant_expect "bare numbered reference in" "case-insensitive bare reference"
step "case unstage" "$DUR_CMD" -- "$GIT" -C "$TREE" rm -f --cached -- docs/case-ref.md
step "case rm" "$DUR_FAST" -- rm -f "$TREE/docs/case-ref.md"

step "second target" "$DUR_FAST" -- mkdir -p "$TREE/ladder/0-hex0/aarch64-linux"
step "second pointer" "$DUR_FAST" -- bash -c 'printf "%s\n" "# This target points at the rung README for the input language and the refusals." "41" > "$1/ladder/0-hex0/aarch64-linux/hex0.hex0"' bash "$TREE"
second=$(step "second target layout" "$DUR_LONG" -- "$root/tools/layout.sh" "$TREE")
[ "$second" = "layout: ok" ] || die "second target pointer stayed red: $second"
echo "second target with a pointer: green"
step "second rm" "$DUR_FAST" -- rm -rf "$TREE/ladder/0-hex0/aarch64-linux"

step "bad path" "$DUR_FAST" -- python3 -c 'import os,sys; root=os.fsencode(sys.argv[1]); os.close(os.open(os.path.join(root,b"docs",bytes([255])), os.O_CREAT|os.O_WRONLY, 0o644))' "$TREE"
step "bad path add" "$DUR_CMD" -- "$GIT" -C "$TREE" add -A -- docs
mutant_expect "scan crashed" "rule 2 crash"
step "tree rm" "$DUR_FAST" -- rm -rf "$TREE"
exit 0
