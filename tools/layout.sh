#!/usr/bin/env bash
# tools/layout.sh -- the nine rules in docs/LAYOUT.md. Prints "layout: ok" or
# "layout: rule N: ..." and exits nonzero. The first broken rule wins, so a
# mutant aimed at one rule is not hidden behind another.
# Usage: tools/layout.sh [ROOT]. ROOT defaults to the repository.
set -uo pipefail

if [ $# -ge 1 ]; then
  cd "$1" || exit 2
else
  cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
fi
ROOT=$PWD
shopt -s nullglob
if [ -n "${HEX0_SCRATCH:-}" ]; then
  LTMP=$HEX0_SCRATCH/layout-tmp
  mkdir -p "$LTMP"
else
  LTMP=$(mktemp -d /var/tmp/hex0-layout.XXXXXX)
fi
trap 'rm -rf "$LTMP"' EXIT

fail() {
  echo "layout: rule $1: $2"
  exit 1
}

fill_find() {
  local rule=$1
  shift
  FIND_LIST=$(mktemp "$LTMP/find.XXXXXX")
  find "$@" -print0 >"$FIND_LIST"
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    rm -f "$FIND_LIST"
    fail "$rule" "find failed"
  fi
}

# Files a commit could carry: tracked, plus untracked that are not git-ignored.
visible_list() {
  local rule=$1
  VISIBLE=$(mktemp "$LTMP/visible.XXXXXX")
  git ls-files -co --exclude-standard -z >"$VISIBLE"
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    rm -f "$VISIBLE"
    fail "$rule" "git ls-files failed"
  fi
}

# One grep over a NUL list. kind 8 skips archived/ and docs/. kind 9 skips archived/.
# Exit 0 a hit, 1 no hit, 2 grep failed. Hit paths are written to out.
grep_list() {
  local re=$1
  local list=$2
  local out=$3
  local kind=$4
  local -a files=()
  local rel
  while IFS= read -r -d '' rel; do
    [ -n "$rel" ] || continue
    case $kind in
      8)
        case $rel in
          archived/*|docs/*) continue ;;
        esac
        ;;
      9)
        case $rel in
          archived/*) continue ;;
        esac
        ;;
    esac
    files+=("$rel")
  done <"$list"
  if [ "${#files[@]}" -eq 0 ]; then
    return 1
  fi
  grep -I -l -E -e "$re" -- "${files[@]}" >"$out"
}

# 1. Top level is exactly the allowed names. out/ may exist, and is never tracked.
# brand/ image files are part of this rule.
allowed=" README.md LICENSE NOTICE .gitignore .gitattributes ladder watc tools docs brand archived out "
for name in "$ROOT"/* "$ROOT"/.[!.]*; do
  base=$(basename "$name")
  [ "$base" = ".git" ] && continue
  case $allowed in
    *" $base "*) ;;
    *) fail 1 "top-level name not in the layout: $base" ;;
  esac
done

if [ -d "$ROOT/brand" ]; then
  fill_find 1 "$ROOT/brand" -mindepth 1
  while IFS= read -r -d '' f; do
    rel=${f#"$ROOT"/}
    base=$(basename "$f")
    if [ -d "$f" ]; then
      fail 1 "brand/ holds a non-image: $rel"
    fi
    case $base in
      *.png|*.ico|*.svg) ;;
      *) fail 1 "brand/ holds a non-image: $rel" ;;
    esac
  done <"$FIND_LIST"
  rm -f "$FIND_LIST"
fi

tracked_out=$(git ls-files -- out) || fail 1 "git ls-files failed"
if [ -n "$tracked_out" ]; then
  first=${tracked_out%%$'\n'*}
  fail 1 "tracked out/ path: $first"
fi

# 2. One committed binary per target: ladder/0-hex0/<arch>-<os>/hex0.
# ELF magic is refused everywhere, including brand/. A NUL is refused
# everywhere except brand/, whose images are binaries on purpose.
# Ignored build output is not a commit, so it is not in this list.
visible_list 2
bin_msg=$(python3 - "$ROOT" "$VISIBLE" << 'PY'
import os, re, sys
root, vis = sys.argv[1], sys.argv[2]
seed = re.compile(r"^ladder/0-hex0/[a-z0-9_]+-[a-z0-9_]+/hex0$")
with open(vis, "rb") as handle:
    blob = handle.read()
for relb in blob.split(b"\0"):
    if not relb:
        continue
    rel = relb.decode()
    if seed.match(rel):
        continue
    path = os.path.join(root, rel)
    try:
        with open(path, "rb") as handle:
            head = handle.read(4)
            if head.startswith(b"\x7fELF"):
                sys.stdout.write("ELF magic outside the seed: %s\n" % rel)
                sys.exit(1)
            if rel == "brand" or rel.startswith("brand/"):
                continue
            if b"\0" in head or b"\0" in handle.read():
                sys.stdout.write("binary outside the seed and brand/: %s\n" % rel)
                sys.exit(1)
    except OSError:
        sys.stdout.write("unreadable file: %s\n" % rel)
        sys.exit(2)
sys.exit(0)
PY
)
bin_rc=$?
rm -f "$VISIBLE"
if [ "$bin_rc" -eq 1 ] || [ "$bin_rc" -eq 2 ]; then
  fail 2 "$bin_msg"
elif [ "$bin_rc" -ne 0 ]; then
  fail 2 "scan failed"
fi

# 3. A rung holds README.md, tests/, and <arch>-<os>/ directories.
# A target holds its source, and may hold *.tsv tables the gate reads.
# Process documents stay in docs/.
for rung in "$ROOT"/ladder/*/; do
  rung_rel=${rung#"$ROOT"/}
  for child in "$rung"*; do
    [ -e "$child" ] || continue
    base=$(basename "$child")
    if [ "$base" = README.md ]; then
      continue
    fi
    if [ "$base" = tests ] && [ -d "$child" ]; then
      continue
    fi
    if [ -d "$child" ] && [[ $base =~ ^[a-z0-9_]+-[a-z0-9_]+$ ]]; then
      found=0
      fill_find 3 "$child" -type f
      while IFS= read -r -d '' f; do
        b=$(basename "$f")
        if [ "$b" != hex0 ]; then
          found=1
        fi
        if [[ $b == *.md ]]; then
          fail 3 "process document inside a rung: ${rung_rel}$base/$b"
        fi
        printf '%s\n' "$b" | grep -qiE 'brief|expect|score|note|design|weigh'
        prc=${PIPESTATUS[1]}
        if [ "$prc" -eq 0 ]; then
          fail 3 "process document inside a rung: ${rung_rel}$base/$b"
        elif [ "$prc" -gt 1 ]; then
          fail 3 "grep failed on $b"
        fi
      done <"$FIND_LIST"
      rm -f "$FIND_LIST"
      [ "$found" -eq 1 ] || fail 3 "target has no source: ${rung_rel}$base"
      continue
    fi
    if [ -d "$child" ]; then
      fail 3 "target name is not <arch>-<os>: ${rung_rel}$base"
    fi
    fail 3 "rung holds something other than README, tests/, and a target: ${rung_rel}$base"
  done
done

# 4. Rung directories are <n>-<name>, from 0, with no gaps.
nums=()
for rung in "$ROOT"/ladder/*/; do
  base=$(basename "$rung")
  if [[ ! $base =~ ^([0-9]+)-(.+)$ ]]; then
    fail 4 "rung directory is not <n>-<name>: $base"
  fi
  nums+=("$((10#${BASH_REMATCH[1]}))")
done
if [ "${#nums[@]}" -eq 0 ]; then
  fail 4 "no rungs under ladder/"
fi
IFS=$'\n' sorted=($(printf '%s\n' "${nums[@]}" | sort -n))
unset IFS
expect=0
for n in "${sorted[@]}"; do
  [ "$n" -eq "$expect" ] || fail 4 "rung numbers skip $expect (found $n)"
  expect=$((expect + 1))
done

# 5. The README's status numbers are the contract. A target block that lists
# numbers must equal that set. A pointer with no numbers adds nothing.
status_numbers() {
  awk '
    index($0, "Exit status:") { inb = 1; next }
    inb {
      line = $0
      sub(/^[[:space:]]*[#;]+[[:space:]]*/, "", line)
      if (match(line, /^[0-9]+/)) { print substr(line, RSTART, RLENGTH); next }
      inb = 0
    }
  ' "$1" | sort -n | uniq
}

for rung in "$ROOT"/ladder/*/; do
  name=$(basename "$rung")
  readme=$rung/README.md
  [ -f "$readme" ] || fail 5 "rung has no README.md: $name"
  readme_set=$(awk '
    /^[[:space:]]*\|[[:space:]]*[0-9]+[[:space:]]*\|/ {
      line = $0
      sub(/^[[:space:]]*\|[[:space:]]*/, "", line)
      if (match(line, /^[0-9]+/)) print substr(line, RSTART, RLENGTH)
    }
  ' "$readme" | sort -n | uniq)
  if [ -z "$readme_set" ]; then
    fail 5 "readme has no exit statuses: $name"
  fi
  fill_find 5 "$rung" -type f
  while IFS= read -r -d '' f; do
    rel=${f#"$rung"}
    case $rel in
      README.md|tests|tests/*) continue ;;
    esac
    grep -I -q . "$f"
    grc=$?
    if [ "$grc" -eq 1 ]; then
      continue
    elif [ "$grc" -gt 1 ]; then
      fail 5 "grep failed on $f"
    fi
    src_set=$(status_numbers "$f")
    if [ -n "$src_set" ] && [ "$src_set" != "$readme_set" ]; then
      fail 5 "exit statuses differ for $name (source: $(printf '%s' "$src_set" | tr '\n' ' ') readme: $(printf '%s' "$readme_set" | tr '\n' ' '))"
    fi
  done <"$FIND_LIST"
  rm -f "$FIND_LIST"
done

# 6. archived/ is the tree at c45603e, byte for byte, and nothing else.
git diff --quiet c45603e -- archived
drc=$?
if [ "$drc" -gt 1 ]; then
  fail 6 "git diff failed"
fi
if [ "$drc" -ne 0 ]; then
  fail 6 "archived/ bytes differ from c45603e"
fi
por=$(git status --porcelain -- archived) || fail 6 "git status failed"
if [ -n "$por" ]; then
  first=${por%%$'\n'*}
  case $first in
    '??'*) fail 6 "untracked file under archived/: $first" ;;
    *) fail 6 "archived/ porcelain: $first" ;;
  esac
fi
lista=$(git ls-tree -r --name-only c45603e -- archived | sort) || fail 6 "git ls-tree failed"
listb=$(git ls-files -- archived | sort) || fail 6 "git ls-files failed"
if [ "$lista" != "$listb" ]; then
  fail 6 "archived/ file list differs from c45603e"
fi

# 7. tools/ checks. It does not write a rung's output into out/.
scan_out() {
  local re=$1 why=$2 list rc line
  list=$(mktemp "$LTMP/scan.XXXXXX")
  grep -R -n -E -e "$re" tools >"$list"
  rc=$?
  if [ "$rc" -gt 1 ]; then
    rm -f "$list"
    fail 7 "grep failed"
  fi
  if [ "$rc" -eq 0 ]; then
    IFS= read -r line <"$list" || line=""
    rm -f "$list"
    fail 7 "$why: $line"
  fi
  rm -f "$list"
}
redir_re='>>?'
redir_re+='[[:space:]]*out/'
scan_out "$redir_re" "a tools file redirects into out/"
tee_re='tee'
tee_re+='[[:space:]]+.*out/'
scan_out "$tee_re" "a tools file tees into out/"
cp_re='(^|[^A-Za-z0-9_])cp[[:space:]]+.*out/'
scan_out "$cp_re" "a tools file copies into out/"
mv_re='(^|[^A-Za-z0-9_])mv[[:space:]]+.*out/'
scan_out "$mv_re" "a tools file moves into out/"
dd_re='of='
dd_re+='out/'
scan_out "$dd_re" "a tools file writes out/ with dd"
install_re='(^|[^A-Za-z0-9_])install[[:space:]]+.*out/'
scan_out "$install_re" "a tools file installs into out/"
o_re='-o'
o_re+='[[:space:]]+out/'
scan_out "$o_re" "a tools file names -o into out/"

# 8. Files outside archived/ and docs/ use Clojure/EDN syntax.
# Every file a commit could carry, tracked or not. brand/ is not excluded.
# The patterns are built so this script does not contain the tokens it rejects.
colon_re=':{2}'
arrow_re='(^|[^A-Za-z0-9_])('
arrow_re+='<'
arrow_re+='-'
arrow_re+='|'
arrow_re+='-'
arrow_re+='>'
arrow_re+=')([^A-Za-z0-9_]|$)'
visible_list 8
hit=$(mktemp "$LTMP/hit.XXXXXX")
grep_list "$colon_re" "$VISIBLE" "$hit" 8
grc=$?
if [ "$grc" -eq 0 ]; then
  IFS= read -r hit_path <"$hit" || hit_path=""
  rm -f "$hit" "$VISIBLE"
  fail 8 "colon-path token in $hit_path"
elif [ "$grc" -gt 1 ]; then
  rm -f "$hit" "$VISIBLE"
  fail 8 "grep failed"
fi
grep_list "$arrow_re" "$VISIBLE" "$hit" 8
grc=$?
if [ "$grc" -eq 0 ]; then
  IFS= read -r hit_path <"$hit" || hit_path=""
  rm -f "$hit" "$VISIBLE"
  fail 8 "bare type arrow in $hit_path"
elif [ "$grc" -gt 1 ]; then
  rm -f "$hit" "$VISIBLE"
  fail 8 "grep failed"
fi
rm -f "$hit" "$VISIBLE"

# 9. docs/ is standing markdown plus excursus/YYYY/MM/NNN-slug/.
for entry in "$ROOT"/docs/* "$ROOT"/docs/.[!.]*; do
  base=$(basename "$entry")
  if [ -d "$entry" ]; then
    [ "$base" = "excursus" ] || fail 9 "stray directory under docs/: $base"
  elif [[ $base == *.md ]]; then
    :
  else
    fail 9 "docs/ top level is not a standing document: $base"
  fi
done
if [ -d "$ROOT/docs/excursus" ]; then
  for year in "$ROOT"/docs/excursus/*; do
    ybase=$(basename "$year")
    if [[ ! -d $year || ! $ybase =~ ^[0-9]{4}$ ]]; then
      fail 9 "excursus year is not YYYY: $ybase"
    fi
    for month in "$year"/*; do
      mbase=$(basename "$month")
      if [[ ! -d $month || ! $mbase =~ ^(0[1-9]|1[0-2])$ ]]; then
        fail 9 "excursus month is not MM: $ybase/$mbase"
      fi
      nums=()
      for ex in "$month"/*; do
        ebase=$(basename "$ex")
        if [[ ! -d $ex || ! $ebase =~ ^([0-9]{3})-([a-z][a-z0-9]*(-[a-z][a-z0-9]*)*)$ ]]; then
          fail 9 "badly formed excursus slug: $ybase/$mbase/$ebase"
        fi
        nums+=("$((10#${BASH_REMATCH[1]}))")
        fill_find 9 "$ex" -mindepth 1
        while IFS= read -r -d '' f; do
          rel=${f#"$ex"/}
          if [ -d "$f" ]; then
            fail 9 "excursus holds a directory: $ybase/$mbase/$ebase/$rel"
          fi
          b=$(basename "$f")
          [[ $b == *.md ]] || fail 9 "excursus holds a non-document: $ybase/$mbase/$ebase/$b"
        done <"$FIND_LIST"
        rm -f "$FIND_LIST"
      done
      if [ "${#nums[@]}" -eq 0 ]; then
        fail 9 "excursus month has no counter: $ybase/$mbase"
      fi
      IFS=$'\n' sorted=($(printf '%s\n' "${nums[@]}" | sort -n))
      unset IFS
      expect=1
      for n in "${sorted[@]}"; do
        if [ "$n" -ne "$expect" ]; then
          fail 9 "excursus counter gap: $ybase/$mbase missing $(printf '%03d' "$expect")"
        fi
        expect=$((expect + 1))
      done
    done
  done
fi

bare_re='(^|[^A-Za-z0-9_])('
bare_re+='excursus|arc'
bare_re+=')[[:space:]]+[0-9]+([^0-9-]|$)'
visible_list 9
hit=$(mktemp "$LTMP/hit.XXXXXX")
grep_list "$bare_re" "$VISIBLE" "$hit" 9
grc=$?
if [ "$grc" -eq 0 ]; then
  IFS= read -r hit_path <"$hit" || hit_path=""
  rm -f "$hit" "$VISIBLE"
  fail 9 "bare numbered reference in $hit_path"
elif [ "$grc" -gt 1 ]; then
  rm -f "$hit" "$VISIBLE"
  fail 9 "grep failed"
fi
rm -f "$hit" "$VISIBLE"

echo "layout: ok"
exit 0
