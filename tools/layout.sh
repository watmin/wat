#!/usr/bin/env bash
# tools/layout.sh -- the nine rules in docs/LAYOUT.md.
# Usage: tools/layout.sh [ROOT]. ROOT is absolute. The default is this repository.
# Prints "layout: ok" or "layout: rule N: ..." and exits nonzero.
set -uo pipefail
here=${BASH_SOURCE[0]%/*}
case $here in
  /*) ;;
  *) here=$PWD/$here ;;
esac
# shellcheck source=tools/check/gate-lib.sh
. "$here/check/gate-lib.sh" || exit 2
GIT=$here/check/git-sandbox

if [ $# -ge 1 ]; then
  case $1 in
    /*) ;;
    *) die "relative path refused: $1" ;;
  esac
  cd "$1" || exit 2
else
  cd "$here/.." || exit 2
fi
ROOT=$PWD
shopt -s nullglob dotglob

if [ -n "${HEX0_SCRATCH:-}" ]; then
  scratch=$(under_tmp "$HEX0_SCRATCH")
  LTMP=$(step "layout temp" "$DUR_FAST" -- mktemp -d "$scratch/layout.XXXXXX")
else
  LTMP=$(step "layout temp" "$DUR_FAST" -- mktemp -d /var/tmp/hex0-layout.XXXXXX)
fi
trap 'rm -rf "$LTMP"' EXIT

# rune:complectens(helper) — fail reports a decision the caller already made.
fail() {
  echo "layout: rule $1: $2"
  exit 1
}

step "layout find" "$DUR_CMD" -- find "$ROOT" \( -name .git -prune \) -o -print0 >"$LTMP/all"
step "layout visible" "$DUR_CMD" -- "$GIT" -C "$ROOT" ls-files -co --exclude-standard -z >"$LTMP/visible"

mapfile -d '' ALL <"$LTMP/all"
mapfile -d '' VISIBLE <"$LTMP/visible"
step "layout text list" "$DUR_CMD" -- python3 - "$ROOT" "$LTMP/visible" "$LTMP/text" << 'PY'
import sys
root, vis, outp = sys.argv[1:]
names = []
for relb in open(vis, "rb").read().split(b"\0"):
    if not relb:
        continue
    try:
        rel = relb.decode("utf-8")
    except UnicodeDecodeError:
        continue
    path = root + "/" + rel
    try:
        data = open(path, "rb").read()
    except OSError:
        continue
    if b"\0" in data:
        continue
    names.append(rel)
open(outp, "w", encoding="utf-8").write("\n".join(names) + "\n")
PY
TEXT_SET=" "
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  TEXT_SET="$TEXT_SET$rel "
done <"$LTMP/text"

design=$ROOT/docs/excursus/2026/10/001-the-ladder/DESIGN-the-ladder.md
[ -f "$design" ] || fail 3 "design has no targets table"
TARGET_NAMES=" "
in_table=0
while IFS= read -r line; do
  if [ "$in_table" -eq 0 ]; then
    if [ "$line" = "| target | the machine | ISA baseline it may assume |" ]; then
      in_table=1
    fi
    continue
  fi
  case $line in
    '## '*) break ;;
  esac
  if [[ $line =~ \`([a-z0-9_]+-[a-z0-9_]+)\` ]]; then
    TARGET_NAMES="$TARGET_NAMES${BASH_REMATCH[1]} "
  fi
done <"$design"
case $TARGET_NAMES in
  *' x86_64-linux '*) ;;
  *) fail 3 "design targets table was not read" ;;
esac

# 1. Every top-level name on disk, except .git. out/ may exist and is never tracked.
allowed=" README.md LICENSE NOTICE .gitignore .gitattributes ladder tools docs brand archived out "
for path in "${ALL[@]}"; do
  rel=${path#"$ROOT"/}
  [ "$path" = "$ROOT" ] && continue
  case $rel in
    */*) continue ;;
  esac
  case $allowed in
    *" $rel "*) ;;
    *) fail 1 "top-level name not in the layout: $rel" ;;
  esac
done

brand_msg=$(step "layout brand" "$DUR_CMD" -- python3 - "$ROOT" << 'PY'
import os, sys
root = sys.argv[1]
brand = os.path.join(root, "brand")
if not os.path.isdir(brand):
    sys.stdout.write("ok\n")
    raise SystemExit(0)
for dirpath, dirnames, filenames in os.walk(brand):
    rel_dir = os.path.relpath(dirpath, root)
    if rel_dir != "brand" and dirnames:
        pass
    for name in dirnames:
        sys.stdout.write("brand/ holds a non-image: %s/%s\n" % (rel_dir, name))
        raise SystemExit(0)
    for name in filenames:
        path = os.path.join(dirpath, name)
        rel = os.path.relpath(path, root)
        data = open(path, "rb").read()
        if b"\x7fELF" in data:
            sys.stdout.write("ELF magic outside the seed: %s\n" % rel)
            raise SystemExit(0)
        png = data.startswith(b"\x89PNG\r\n\x1a\n")
        ico = data.startswith(b"\x00\x00\x01\x00")
        svg = (b"\x00" not in data) and (b"<svg" in data or b"<SVG" in data) and data.lstrip().startswith(b"<")
        if not (png or ico or svg):
            sys.stdout.write("brand/ holds a non-image: %s\n" % rel)
            raise SystemExit(0)
sys.stdout.write("ok\n")
PY
)
case $brand_msg in
  ok) ;;
  'ELF magic'*) fail 2 "$brand_msg" ;;
  *) fail 1 "$brand_msg" ;;
esac

tracked_out=$(step "layout tracked out" "$DUR_CMD" -- "$GIT" -C "$ROOT" ls-files -- out)
# step already exits on failure. An empty index prints nothing.
if [ -n "$tracked_out" ]; then
  first=${tracked_out%%$'\n'*}
  fail 1 "tracked out/ path: $first"
fi

# 2. One committed binary per target. ELF anywhere else is red. NUL is red
# outside brand/. A scanner crash is a crash.
blob=$(carry "rule 2 scan" "$DUR_LONG" python3 - "$ROOT" "$LTMP/visible" << 'PY'
import sys
root, vis = sys.argv[1], sys.argv[2]
try:
    blob = open(vis, "rb").read()
except OSError as exc:
    sys.stderr.write("scan crashed: %s\n" % exc)
    sys.exit(99)
seed_at = "ladder/0-hex0/"
for relb in blob.split(b"\0"):
    if not relb:
        continue
    try:
        rel = relb.decode("utf-8")
    except UnicodeDecodeError:
        sys.stderr.write("scan crashed: path encoding\n")
        sys.exit(99)
    parts = rel.split("/")
    is_seed = (
        len(parts) == 4
        and parts[0] == "ladder"
        and parts[1] == "0-hex0"
        and parts[3] == "hex0"
        and "-" in parts[2]
    )
    path = root + "/" + rel
    try:
        handle = open(path, "rb")
    except OSError as exc:
        sys.stderr.write("scan crashed: %s\n" % exc)
        sys.exit(99)
    with handle:
        data = handle.read()
    if is_seed:
        continue
    if b"\x7fELF" in data:
        sys.stdout.write("ELF magic outside the seed: %s\n" % rel)
        sys.exit(0)
    if rel == "brand" or rel.startswith("brand/"):
        continue
    if b"\0" in data:
        sys.stdout.write("binary outside the seed and brand/: %s\n" % rel)
        sys.exit(0)
sys.stdout.write("ok\n")
PY
)
rc=$(payload_rc "$blob")
body=$(payload_body "$blob")
line=${body%%$'\n'*}
case $line in
  *'scan crashed'*) fail 2 "scan crashed" ;;
esac
if [ "$rc" != 0 ]; then
  fail 2 "scan crashed"
fi
case $line in
  ok) ;;
  *) fail 2 "$line" ;;
esac

# 3. A rung holds README.md, tests/, and target directories named in the design table.
# A target's source is <rung's program>.hex0. Hidden names are examined.
proc_re='brief|expect|score|note|design|weigh|plan'
for path in "${ALL[@]}"; do
  rel=${path#"$ROOT"/}
  case $rel in
    ladder/*) ;;
    *) continue ;;
  esac
done

rung_names=()
for path in "${ALL[@]}"; do
  rel=${path#"$ROOT"/}
  case $rel in
    ladder/*/*) continue ;;
    ladder/*) ;;
    *) continue ;;
  esac
  [ -d "$path" ] || continue
  rung_names+=("${path##*/}")
done

for rung in "${rung_names[@]}"; do
  if [[ ! $rung =~ ^([0-9]+)-(.+)$ ]]; then
    fail 4 "rung directory is not <n>-<name>: $rung"
  fi
  prog=${BASH_REMATCH[2]}
  source_name="$prog.hex0"
  for path in "${ALL[@]}"; do
    rel=${path#"$ROOT"/}
    case $rel in
      ladder/"$rung"/*) ;;
      *) continue ;;
    esac
    rest=${rel#ladder/"$rung"/}
    base=${rest%%/*}
    [ -e "$ROOT/ladder/$rung/$base" ] || continue
    if [ "$base" = README.md ]; then
      continue
    fi
    if [ "$base" = tests ]; then
      if [ "$rest" = tests ]; then
        [ -d "$ROOT/ladder/$rung/tests" ] || fail 3 "rung holds something other than README, tests/, and a target: ladder/$rung/$base"
        continue
      fi
      child=${rest#tests/}
      child_base=${child%%/*}
      full=$ROOT/ladder/$rung/tests/$child
      if [ -d "$ROOT/ladder/$rung/tests/$child_base" ] && [ "$child" != "$child_base" ]; then
        fail 3 "tests/ holds a directory: ladder/$rung/tests/$child_base"
      fi
      if [ -d "$full" ]; then
        fail 3 "tests/ holds a directory: ladder/$rung/tests/$child"
      fi
      shopt -s nocasematch
      if [[ $child_base =~ (^|[^A-Za-z0-9])($proc_re)([^A-Za-z0-9]|$) ]]; then
        shopt -u nocasematch
        fail 3 "process document inside a rung: ladder/$rung/tests/$child_base"
      fi
      shopt -u nocasematch
      continue
    fi
    if [[ $base =~ ^[a-z0-9_]+-[a-z0-9_]+$ ]] && [ -d "$ROOT/ladder/$rung/$base" ]; then
      case $TARGET_NAMES in
        *" $base "*) ;;
        *) fail 3 "target not named in the design table: ladder/$rung/$base" ;;
      esac
      if [ "$rest" = "$base" ]; then
        continue
      fi
      inner=${rest#"$base"/}
      ibase=${inner##*/}
      if [[ $inner == */* ]]; then
        fail 3 "process document inside a rung: ladder/$rung/$rest"
      fi
      if [ -d "$ROOT/ladder/$rung/$base/$ibase" ]; then
        fail 3 "process document inside a rung: ladder/$rung/$base/$ibase"
      fi
      shopt -s nocasematch
      if [[ $ibase =~ ($proc_re) ]]; then
        shopt -u nocasematch
        fail 3 "process document inside a rung: ladder/$rung/$base/$ibase"
      fi
      shopt -u nocasematch
      case $ibase in
        "$source_name"|"$prog"|*.tsv) ;;
        *) fail 3 "process document inside a rung: ladder/$rung/$base/$ibase" ;;
      esac
      continue
    fi
    if [ -d "$ROOT/ladder/$rung/$base" ]; then
      fail 3 "target name is not <arch>-<os>: ladder/$rung/$base"
    fi
    fail 3 "rung holds something other than README, tests/, and a target: ladder/$rung/$base"
  done
  # The directory entry itself, including a target that holds no files.
  for path in "${ALL[@]}"; do
    rel=${path#"$ROOT"/}
    case $rel in
      ladder/"$rung"/*) ;;
      *) continue ;;
    esac
    rest=${rel#ladder/"$rung"/}
    case $rest in
      */*) continue ;;
    esac
    base=$rest
    [[ $base =~ ^[a-z0-9_]+-[a-z0-9_]+$ ]] || continue
    [ -d "$ROOT/ladder/$rung/$base" ] || continue
    case $TARGET_NAMES in
      *" $base "*) ;;
      *) continue ;;
    esac
    found=0
    for inner in "${ALL[@]}"; do
      irel=${inner#"$ROOT"/}
      if [ "$irel" = "ladder/$rung/$base/$source_name" ] && [ -f "$inner" ]; then
        found=1
      fi
    done
    [ "$found" -eq 1 ] || fail 3 "target has no source: ladder/$rung/$base"
  done
done

# 4. Rung numbers from 0, no gaps. Every name on disk under ladder/.
nums=()
for rung in "${rung_names[@]}"; do
  if [[ ! $rung =~ ^([0-9]+)-(.+)$ ]]; then
    fail 4 "rung directory is not <n>-<name>: $rung"
  fi
  nums+=("$((10#${BASH_REMATCH[1]}))")
done
if [ "${#nums[@]}" -eq 0 ]; then
  fail 4 "no rungs under ladder/"
fi
sorted_text=$(step "layout rung sort" "$DUR_FAST" -- bash -c 'printf "%s\n" "$@" | sort -n' bash "${nums[@]}")
sorted=()
while IFS= read -r n; do
  [ -n "$n" ] || continue
  sorted+=("$n")
done <<<"$sorted_text"
expect_n=0
for n in "${sorted[@]}"; do
  [ "$n" -eq "$expect_n" ] || fail 4 "rung numbers skip $expect_n (found $n)"
  expect_n=$((expect_n + 1))
done

# 5. A target source that states a status meaning is red.
# The README's table is the contract. The source points at it.
for rung in "${rung_names[@]}"; do
  readme=$ROOT/ladder/$rung/README.md
  [ -f "$readme" ] || fail 5 "rung has no README.md: $rung"
  readme_set=$(step "layout readme statuses" "$DUR_FAST" -- bash -c 'awk -f /dev/stdin "$1" | sort -n | uniq' bash "$readme" << 'AWK'
/^[[:space:]]*\|[[:space:]]*[0-9]+[[:space:]]*\|/ {
  line = $0
  sub(/^[[:space:]]*\|[[:space:]]*/, "", line)
  if (match(line, /^[0-9]+/)) print substr(line, RSTART, RLENGTH)
}
AWK
)
  if [ -z "$readme_set" ]; then
    fail 5 "readme has no exit statuses: $rung"
  fi
  for path in "${ALL[@]}"; do
    rel=${path#"$ROOT"/}
    case $rel in
      ladder/"$rung"/*/*) ;;
      *) continue ;;
    esac
    [ -f "$path" ] || continue
    case $rel in
      */tests/*) continue ;;
    esac
    while IFS= read -r line || [ -n "$line" ]; do
      if [[ $line == *'Exit status:'* ]]; then
        fail 5 "target source states a status meaning: $rel"
      fi
      if [[ $line =~ status[[:space:]][0-9] ]]; then
        fail 5 "target source states a status meaning: $rel"
      fi
    done <"$path"
  done
done

# 6. archived/ is the tree at c45603e. Every tracked name, and every untracked name.
diff_line=$(step "layout archived diff" "$DUR_CMD" -- bash -c '"$1" -C "$2" diff --quiet c45603e -- archived; printf "rc:%s\n" "$?"' bash "$GIT" "$ROOT")
case $diff_line in
  rc:0) ;;
  rc:1) fail 6 "archived/ bytes differ from c45603e" ;;
  *) fail 6 "git diff failed" ;;
esac
por=$(step "layout archived status" "$DUR_CMD" -- "$GIT" -C "$ROOT" status --porcelain -- archived)
if [ -n "$por" ]; then
  first=${por%%$'\n'*}
  case $first in
    '??'*) fail 6 "untracked file under archived/: $first" ;;
    *) fail 6 "archived/ porcelain: $first" ;;
  esac
fi
lista=$(step "layout ls-tree" "$DUR_CMD" -- bash -c '"$1" -C "$2" ls-tree -r --name-only c45603e -- archived | sort' bash "$GIT" "$ROOT")
listb=$(step "layout ls-files archived" "$DUR_CMD" -- bash -c '"$1" -C "$2" ls-files -- archived | sort' bash "$GIT" "$ROOT")
if [ "$lista" != "$listb" ]; then
  fail 6 "archived/ file list differs from c45603e"
fi

# 7. tools/ does not write a rung product. Quoted and variable out/ paths count.
# Scope: every file under tools/ that is not git-ignored (the visible list).
seed_re='(cp|mv|tee|install|dd)[[:space:]]+[^;#]*[[:space:]]ladder/'
seed_re+='[^[:space:]]+'
seed_re+='/hex0([^A-Za-z0-9_./]|$)'
scan_tools() {
  local why=$1
  local rel line
  for rel in "${VISIBLE[@]}"; do
    case $rel in
      tools/*) ;;
      *) continue ;;
    esac
    [ -f "$ROOT/$rel" ] || continue
    while IFS= read -r line || [ -n "$line" ]; do
      case $line in
        '#'*) continue ;;
      esac
      if [[ $line =~ \>\>?[[:space:]]*[\"\']?out/ ]]; then
        fail 7 "$why: $rel"
      fi
      if [[ $line =~ \>\>?[[:space:]]*[\"\']?\$[A-Za-z_][A-Za-z0-9_]*/out/ ]]; then
        fail 7 "$why: $rel"
      fi
      if [[ $line =~ (^|[^A-Za-z0-9_])tee[[:space:]]+.*out/ ]]; then
        fail 7 "a tools file tees into out/: $rel"
      fi
      if [[ $line =~ (^|[^A-Za-z0-9_])cp[[:space:]]+.*out/ ]]; then
        fail 7 "a tools file copies into out/: $rel"
      fi
      if [[ $line =~ (^|[^A-Za-z0-9_])mv[[:space:]]+.*out/ ]]; then
        fail 7 "a tools file moves into out/: $rel"
      fi
      if [[ $line =~ of=[[:space:]]*[\"\']?out/ ]]; then
        fail 7 "a tools file writes out/ with dd: $rel"
      fi
      if [[ $line =~ (^|[^A-Za-z0-9_])install[[:space:]]+.*out/ ]]; then
        fail 7 "a tools file installs into out/: $rel"
      fi
      if [[ $line =~ -o[[:space:]]+[\"\']?out/ ]]; then
        fail 7 "a tools file names -o into out/: $rel"
      fi
      if [[ $line =~ -o[[:space:]]*[\"\']out/ ]]; then
        fail 7 "a tools file names -o into out/: $rel"
      fi
      case $rel in
        *.sh|tools/check/git-sandbox)
          if [[ $line =~ $seed_re ]]; then
            fail 7 "a tools file writes a target seed: $rel"
          fi
          ;;
      esac
    done <"$ROOT/$rel"
  done
  scan_did=1
}
scan_did=0
scan_tools "a tools file redirects into out/"
[ "$scan_did" -eq 1 ] || die "scan_tools did not compare"

# 8 and 9. Token scans over the one visible list. Built so this file does not contain the tokens.
colon_re=':'
colon_re+='{2}'
arrow_re='(^|[^A-Za-z0-9_])('
arrow_re+='<'
arrow_re+='-'
arrow_re+='|'
arrow_re+='-'
arrow_re+='>'
arrow_re+=')([^A-Za-z0-9_]|$)'
bare_re='(^|[^A-Za-z0-9_])('
bare_re+='excursus|arc'
bare_re+=')[[:space:]]+[0-9]+([^0-9-]|$)'

line_has() {
  local rel=$1 re=$2
  local line
  [ -f "$ROOT/$rel" ] || return 1
  case $TEXT_SET in
    *" $rel "*) ;;
    *) return 1 ;;
  esac
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ $line =~ $re ]]; then
      return 0
    fi
  done <"$ROOT/$rel"
  return 1
}

for rel in "${VISIBLE[@]}"; do
  case $rel in
    archived/*|docs/*) continue ;;
  esac
  if line_has "$rel" "$colon_re"; then
    fail 8 "colon-path token in $rel"
  fi
  if line_has "$rel" "$arrow_re"; then
    fail 8 "bare type arrow in $rel"
  fi
done

# 9. docs/ shape. Every name on disk under docs/.
for path in "${ALL[@]}"; do
  rel=${path#"$ROOT"/}
  case $rel in
    docs/*) ;;
    *) continue ;;
  esac
  rest=${rel#docs/}
  base=${rest%%/*}
  if [ "$rest" = "$base" ]; then
    if [ -d "$path" ]; then
      [ "$base" = excursus ] || fail 9 "stray directory under docs/: $base"
    elif [[ $base == *.md ]]; then
      :
    else
      fail 9 "docs/ top level is not a standing document: $base"
    fi
  fi
done

if [ -d "$ROOT/docs/excursus" ]; then
  for year_path in "$ROOT"/docs/excursus/*; do
    [ -e "$year_path" ] || continue
    ybase=${year_path##*/}
    if [[ ! -d $year_path || ! $ybase =~ ^[0-9]{4}$ ]]; then
      fail 9 "excursus year is not YYYY: $ybase"
    fi
    for month_path in "$year_path"/*; do
      [ -e "$month_path" ] || continue
      mbase=${month_path##*/}
      if [[ ! -d $month_path || ! $mbase =~ ^(0[1-9]|1[0-2])$ ]]; then
        fail 9 "excursus month is not MM: $ybase/$mbase"
      fi
      nums=()
      saw=0
      for ex_path in "$month_path"/*; do
        [ -e "$ex_path" ] || continue
        saw=1
        ebase=${ex_path##*/}
        if [[ ! -d $ex_path || ! $ebase =~ ^([0-9]{3})-([a-z][a-z0-9]*(-[a-z][a-z0-9]*)*)$ ]]; then
          fail 9 "badly formed excursus slug: $ybase/$mbase/$ebase"
        fi
        nums+=("$((10#${BASH_REMATCH[1]}))")
        for path in "${ALL[@]}"; do
          prel=${path#"$ex_path"/}
          [ "$path" = "$ex_path" ] && continue
          case $path in
            "$ex_path"/*) ;;
            *) continue ;;
          esac
          if [ -d "$path" ]; then
            fail 9 "excursus holds a directory: $ybase/$mbase/$ebase/$prel"
          fi
          b=${path##*/}
          [[ $b == *.md ]] || fail 9 "excursus holds a non-document: $ybase/$mbase/$ebase/$b"
        done
      done
      if [ "$saw" -eq 0 ]; then
        fail 9 "excursus month has no counter: $ybase/$mbase"
      fi
      sorted_text=$(step "layout counter sort" "$DUR_FAST" -- bash -c 'printf "%s\n" "$@" | sort -n' bash "${nums[@]}")
      sorted=()
      while IFS= read -r n; do
        [ -n "$n" ] || continue
        sorted+=("$n")
      done <<<"$sorted_text"
      expect_n=1
      for n in "${sorted[@]}"; do
        if [ "$n" -ne "$expect_n" ]; then
          fail 9 "excursus counter gap: $ybase/$mbase missing $(printf '%03d' "$expect_n")"
        fi
        expect_n=$((expect_n + 1))
      done
    done
  done
fi

# A double-quoted span may name the forbidden form. The weigh stone quotes it, and
# that file is not edited here. An unquoted use is still the reference rule 9 rejects.
shopt -s nocasematch
for rel in "${VISIBLE[@]}"; do
  case $rel in
    archived/*) continue ;;
  esac
  [ -f "$ROOT/$rel" ] || continue
  case $TEXT_SET in
    *" $rel "*) ;;
    *) continue ;;
  esac
  while IFS= read -r line || [ -n "$line" ]; do
    stripped=${line//\"*\"/}
    if [[ $stripped =~ $bare_re ]]; then
      shopt -u nocasematch
      fail 9 "bare numbered reference in $rel"
    fi
  done <"$ROOT/$rel"
done
shopt -u nocasematch

echo "layout: ok"
exit 0
