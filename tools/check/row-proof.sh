#!/usr/bin/env bash
# tools/check/row-proof.sh SCRATCH_DIR
# One row function is forced to return 0. Its module must go red.
# gate-lib is the step library. This file is the prover. Neither is a row module.
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

[ $# -eq 1 ] || die "row-proof: want SCRATCH_DIR"
WORK=$(under_tmp "$1")
step "row work" "$DUR_FAST" -- mkdir -p "$WORK"
proved=" "

step "row py" "$DUR_FAST" -- bash -c 'cat > "$1"' bash "$WORK/rows.py" << 'PY'
import re
import sys

FUNC = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{?")
RUNE = re.compile(r"rune:complectens\([^)]+\) — \S")
MODULES = (
    "tools/verify.sh",
    "tools/layout.sh",
    "tools/check/seed-audit.sh",
    "tools/check/hex0-contract.sh",
    "tools/check/layout-mutants.sh",
    "tools/check/driver-test.sh",
)


def functions(text):
    lines = text.splitlines()
    found = []
    for idx, line in enumerate(lines):
        match = FUNC.match(line)
        if not match:
            continue
        j = idx - 1
        while j >= 0 and lines[j].strip() == "":
            j -= 1
        exempt = 0
        if j >= 0:
            above = lines[j].strip()
            if above.startswith("#") and RUNE.search(above):
                exempt = 1
        found.append((match.group(1), exempt))
    return found


def read_text(path):
    try:
        return open(path, encoding="utf-8").read()
    except OSError as exc:
        sys.stderr.write("rows: %s\n" % exc)
        sys.exit(2)


def neuter(path, name):
    lines = open(path, encoding="utf-8").readlines()
    needle = name + "() {"
    out = []
    found = 0
    for line in lines:
        out.append(line)
        if line.rstrip("\n") == needle:
            out.append("  return 0\n")
            found += 1
    if found != 1:
        sys.stderr.write("neuter: %s found %d\n" % (name, found))
        sys.exit(1)
    open(path, "w", encoding="utf-8").writelines(out)


def timer(path):
    text = open(path, encoding="utf-8").read()
    old = "  if grep -q -F 'sending signal KILL' \"$err\"; then\n    timed=1\n  fi\n"
    new = "  if [ \"$rc\" == 137 ]; then\n    timed=1\n  fi\n"
    count = text.count(old)
    if count != 1:
        sys.stderr.write("timer decision found %d\n" % count)
        sys.exit(1)
    open(path, "w", encoding="utf-8").write(text.replace(old, new, 1))


def main(argv):
    if not argv:
        sys.stderr.write("rows: want a mode\n")
        return 2
    mode = argv[0]
    if mode == "list":
        root, dest = argv[1], argv[2]
        lines = []
        for rel in MODULES:
            for name, exempt in functions(read_text(root + "/" + rel)):
                lines.append("%s\t%s\t%s\n" % (rel, name, exempt))
        open(dest, "w", encoding="utf-8").writelines(lines)
        return 0
    if mode == "one":
        found = [name for name, exempt in functions(read_text(argv[1])) if not exempt]
        if len(found) != 1:
            sys.stderr.write("only: want one row, got %s\n" % ",".join(found))
            return 1
        sys.stdout.write(found[0] + "\n")
        return 0
    if mode == "neuter":
        neuter(argv[1], argv[2])
        return 0
    if mode == "timer":
        timer(argv[1])
        return 0
    sys.stderr.write("rows: unknown mode\n")
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except Exception as exc:
        sys.stderr.write("rows: %s\n" % exc)
        sys.exit(99)
PY

if [ -n "${HEX0_ROW_PROOF_ONLY:-}" ]; then
  src=$(abs_req "$HEX0_ROW_PROOF_ONLY")
  name=$(step "only name" "$DUR_FAST" -- python3 "$WORK/rows.py" one "$src")
  copy=$WORK/only-mod.sh
  step "only cp" "$DUR_FAST" -- cp "$src" "$copy"
  step "only neuter" "$DUR_FAST" -- python3 "$WORK/rows.py" neuter "$copy" "$name"
  blob=$(carry "only run" "$DUR_FAST" bash "$copy")
  rc=$(payload_rc "$blob")
  case $rc in
    ''|*[!0-9]*) die "$name rc $rc" ;;
  esac
  if [ "$rc" -eq 0 ]; then
    die "$name stayed green"
  fi
  echo "row-proof: $name red"
  exit 0
fi

needle_for() {
  case $1 in
    outer_sum) printf '%s\n' "outer sum length" ;;
    cr_check) printf '%s\n' "cr_check did not compare" ;;
    clone_layout) printf '%s\n' "clone layout did not compare" ;;
    scan_tools) printf '%s\n' "scan_tools did not compare" ;;
    line_has) printf '%s\n' "rule 8" ;;
    row1_same|row2_same|row3_same|row4_status|row8_check|row9_check|row10_check)
      printf '%s\n' "stayed green" ;;
    row11_lint) printf '%s\n' "row 11 text" ;;
    want_rc) printf '%s\n' "row 3: bytes differ" ;;
    file_mode) printf '%s\n' "row 5 mode" ;;
    same_file) printf '%s\n' "same_file did not compare" ;;
    assert_out) printf '%s\n' "assert_out did not compare" ;;
    pair) printf '%s\n' "pair did not compare" ;;
    row4_bytes) printf '%s\n' "row 4 bytes did not compare" ;;
    fix_ok) printf '%s\n' "row 6 lower did not compare" ;;
    fault_both) printf '%s\n' "fault_both did not compare" ;;
    mutant_expect) printf '%s\n' "mutant_expect did not compare" ;;
    *) printf '%s\n' "" ;;
  esac
}

accept_red() {
  local name=$1 blob=$2 rc=$3 needle
  case $rc in
    ''|*[!0-9]*) die "$name rc $rc" ;;
  esac
  if [ "$rc" -eq 0 ]; then
    die "$name stayed green"
  fi
  needle=$(needle_for "$name")
  if [ -n "$needle" ]; then
    case $blob in
      *"$needle"*) ;;
      *) die "$name went red without $needle: ${blob: -500}" ;;
    esac
  fi
  echo "row-proof: $name red ${SECONDS}s"
  proved="$proved$name "
}

prove_one() {
  local rel=$1 name=$2 kind dest work blob rc
  case $rel in
    tools/verify.sh|tools/layout.sh|tools/check/layout-mutants.sh) kind=git ;;
    *) kind=tar ;;
  esac
  dest=$WORK/copy-$name
  work=$WORK/w-$name
  step "rm $name" "$DUR_FAST" -- rm -rf "$dest" "$work"
  if [ "$kind" = git ]; then
    step "cp $name" "$DUR_LONG" -- cp -a "$gitbase" "$dest"
  else
    step "cp $name" "$DUR_LONG" -- cp -a "$tarbase" "$dest"
  fi
  step "neuter $name" "$DUR_FAST" -- python3 "$WORK/rows.py" neuter "$dest/$rel" "$name"
  step "work $name" "$DUR_FAST" -- mkdir -p "$work"
  case $rel in
    tools/check/seed-audit.sh|tools/check/hex0-contract.sh)
      blob=$(carry "proof $name" "$DUR_MODULE" env HEX0_ROW_PROOF=1 HEX0_SCRATCH="$work" "$dest/$rel" "$TARGET" "$work")
      ;;
    tools/check/layout-mutants.sh)
      blob=$(carry "proof $name" "$DUR_MODULE" env HEX0_ROW_PROOF=1 HEX0_SCRATCH="$work" "$dest/$rel" "$work")
      ;;
    tools/layout.sh)
      blob=$(carry "proof $name" "$DUR_MODULE" env HEX0_ROW_PROOF=1 HEX0_SCRATCH="$work" "$dest/$rel" "$dest")
      ;;
    tools/verify.sh)
      blob=$(carry "proof $name" "$DUR_MODULE" env HEX0_ROW_PROOF=1 HEX0_SCRATCH="$work" HEX0_SANDBOX="$work/sb" "$dest/$rel")
      ;;
    *) die "no runner for $rel" ;;
  esac
  rc=$(payload_rc "$blob")
  accept_red "$name" "$blob" "$rc"
}

machine=$(step "uname m" "$DUR_FAST" -- uname -m)
sysname=$(step "uname s" "$DUR_FAST" -- uname -s)
sysname=${sysname,,}
HOST=$machine-$sysname
TARGET=$(abs_req "$root/ladder/0-hex0/$HOST")
gitbase=$WORK/base-git
tarbase=$WORK/base-tar
sandbox_tree "$root" "$gitbase"
step "tar base" "$DUR_LONG" -- bash -c 'mkdir -p "$1" && tar -C "$2" --exclude=.git --exclude=out -cf - . | tar -C "$1" -xf -' bash "$tarbase" "$root"
step "list rows" "$DUR_FAST" -- python3 "$WORK/rows.py" list "$root" "$WORK/rows.tsv"

while IFS=$'\t' read -r rel name exempt; do
  [ -n "${name:-}" ] || continue
  if [ "$exempt" = 1 ]; then
    echo "row-proof: exempt $name"
    continue
  fi
  prove_one "$rel" "$name"
done < "$WORK/rows.tsv"

killcopy=$WORK/copy-kill
step "kill rm" "$DUR_FAST" -- rm -rf "$killcopy"
step "kill cp" "$DUR_LONG" -- cp -a "$tarbase" "$killcopy"
step "kill patch" "$DUR_FAST" -- python3 "$WORK/rows.py" timer "$killcopy/tools/check/gate-lib.sh"
killwork=$WORK/w-kill
step "kill work" "$DUR_FAST" -- mkdir -p "$killwork"
blob=$(carry "self-kill decision" "$DUR_CMD" "$killcopy/tools/check/driver-test.sh" "$killwork")
rc=$(payload_rc "$blob")
case $rc in
  ''|*[!0-9]*) die "self-kill decision rc $rc" ;;
esac
[ "$rc" != 0 ] || die "self-kill decision stayed green"
case $blob in
  *timed-out*|*timed\ out*) echo "row-proof: self-kill decision red" ;;
  *) die "self-kill decision said ${blob: -400}" ;;
esac

step "hollow write" "$DUR_FAST" -- bash -c 'cat > "$1"' bash "$WORK/hollow.sh" << 'EOF'
#!/usr/bin/env bash
set -u
hollow_row() {
  echo hollow-ran
  exit 1
}
hollow_row || true
exit 0
EOF
hwork=$WORK/hollow-run
step "hollow dir" "$DUR_FAST" -- mkdir -p "$hwork"
blob=$(carry "hollow row-proof" "$DUR_CMD" env HEX0_ROW_PROOF_ONLY="$WORK/hollow.sh" "$root/tools/check/row-proof.sh" "$hwork")
rc=$(payload_rc "$blob")
case $rc in
  ''|*[!0-9]*) die "unruned function rc $rc" ;;
esac
[ "$rc" != 0 ] || die "unruned function: row-proof stayed green"
case $blob in
  *stayed\ green*) echo "row-proof: unruned function red" ;;
  *) die "unruned function said ${blob: -400}" ;;
esac

for req in row4_bytes fix_ok assert_out clone_layout cr_check; do
  case $proved in
    *" $req "*) ;;
    *) die "not proved: $req" ;;
  esac
done
echo "row-proof: ok"
exit 0
