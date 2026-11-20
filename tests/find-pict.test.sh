#!/bin/sh
# Tests for skills/pict-pairwise-testing/scripts/find-pict.sh
#
# Hermetic: every case runs with a PATH that holds only the few tools the
# script needs, plus whatever fake "pict" the case sets up. A real PICT
# installed on the machine cannot influence the result.
#
# Usage: sh tests/find-pict.test.sh
# Optional: REAL_PICT=/path/to/pict adds a case against a real binary.

here=$(cd "$(dirname "$0")" && pwd)
script="$here/../skills/pict-pairwise-testing/scripts/find-pict.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

pass=0
fail=0

# Minimal toolbox so PATH can exclude the rest of the system.
tools="$work/tools"
mkdir -p "$tools"
for t in sed tr uname cat; do
    ln -s "$(command -v "$t")" "$tools/$t"
done

# make_fake <path> <kind>   kind: v374 | newer | impostor
make_fake() {
    mkdir -p "$(dirname "$1")"
    case "$2" in
        v374)
            cat > "$1" <<'EOF'
#!/bin/sh
cat <<'USAGE'
Pairwise Independent Combinatorial Testing

Usage: pict model [options]

Options:
 /o:N|max - Order of combinations (default: 2)
 /d:C     - Separator for values  (default: ,)
 /a:C     - Separator for aliases (default: |)
 /n:C     - Negative value prefix (default: ~)
 /e:file  - File with seeding rows
 /r[:N]   - Randomize generation, N - seed
 /c       - Case-sensitive model evaluation
 /s       - Show model statistics
USAGE
exit 3
EOF
            ;;
        newer)
            cat > "$1" <<'EOF'
#!/bin/sh
cat <<'USAGE'
Pairwise Independent Combinatorial Testing

Usage: pict model [options]

Options:
 /o:N|max - Order of combinations (default: 2)
 /d:C     - Separator for values  (default: ,)
 /a:C     - Separator for aliases (default: |)
 /n:C     - Negative value prefix (default: ~)
 /e:file  - File with seeding rows
 /r[:N]   - Randomize generation, N - seed
 /b:N     - Try N seeds, keep the smallest suite
 /t:N     - Number of worker threads (default: auto)
 /c       - Case-sensitive model evaluation
 /s       - Show model statistics
USAGE
exit 3
EOF
            ;;
        impostor)
            cat > "$1" <<'EOF'
#!/bin/sh
echo "pict 1.0 - picture converter"
exit 0
EOF
            ;;
    esac
    chmod +x "$1"
}

# run_case <name> <expected exit> <expected line> [<expected line> ...]
# Uses $case_path, $case_bin and $case_cache set by the caller.
run_case() {
    name=$1
    want_exit=$2
    shift 2
    out=$(PATH="$case_path" PICT_BIN="$case_bin" XDG_CACHE_HOME="$case_cache" \
        /bin/sh "$script" 2>&1)
    got_exit=$?
    ok=1
    [ "$got_exit" -eq "$want_exit" ] || ok=0
    for line in "$@"; do
        printf '%s\n' "$out" | grep -qxF -- "$line" || ok=0
    done
    if [ "$ok" -eq 1 ]; then
        pass=$((pass + 1))
        echo "ok   - $name"
    else
        fail=$((fail + 1))
        echo "FAIL - $name (exit $got_exit, wanted $want_exit)"
        echo "       wanted lines: $*"
        printf '%s\n' "$out" | sed 's/^/       | /'
    fi
}

empty_cache="$work/empty-cache"
mkdir -p "$empty_cache"

# 1. Nothing anywhere.
case_path="$tools"; case_bin=""; case_cache="$empty_cache"
run_case "nothing found reports missing" 1 \
    "status=missing" "cache_dir=$empty_cache/pict-skill"

# 2. PICT_BIN points at a working binary.
make_fake "$work/custom/mypict" v374
case_path="$tools"; case_bin="$work/custom/mypict"; case_cache="$empty_cache"
run_case "PICT_BIN is used" 0 \
    "status=found" "path=$work/custom/mypict" "source=PICT_BIN" "flags=o d a n e r c s"

# 3. On PATH.
make_fake "$work/bin/pict" v374
case_path="$work/bin:$tools"; case_bin=""; case_cache="$empty_cache"
run_case "pict on PATH is found" 0 \
    "status=found" "path=$work/bin/pict" "source=PATH" "flags=o d a n e r c s"

# 4. In the cache dir only.
make_fake "$work/cache/pict-skill/pict" v374
case_path="$tools"; case_bin=""; case_cache="$work/cache"
run_case "cache dir is found" 0 \
    "status=found" "path=$work/cache/pict-skill/pict" "source=cache"

# 5. Order: PICT_BIN beats PATH, PATH beats cache.
case_path="$work/bin:$tools"; case_bin="$work/custom/mypict"; case_cache="$work/cache"
run_case "PICT_BIN wins over PATH and cache" 0 "source=PICT_BIN"
case_path="$work/bin:$tools"; case_bin=""; case_cache="$work/cache"
run_case "PATH wins over cache" 0 "source=PATH"

# 6. Broken PICT_BIN falls through to PATH and says why.
case_path="$work/bin:$tools"; case_bin="$work/does-not-exist"; case_cache="$empty_cache"
run_case "bad PICT_BIN falls through with a note" 0 \
    "source=PATH" \
    "note=PICT_BIN is set to '$work/does-not-exist' but that is not a working PICT executable"

# 7. A different program called pict is rejected.
make_fake "$work/impostor/pict" impostor
case_path="$work/impostor:$tools"; case_bin=""; case_cache="$empty_cache"
run_case "unrelated program named pict is rejected" 1 \
    "status=missing" \
    "note=found '$work/impostor/pict' on PATH but it does not identify itself as PICT"

# 8. Impostor on PATH, real one in cache.
case_path="$work/impostor:$tools"; case_bin=""; case_cache="$work/cache"
run_case "impostor on PATH still allows cache hit" 0 "source=cache"

# 9. Newer builds advertise extra options.
make_fake "$work/newer/pict" newer
case_path="$work/newer:$tools"; case_bin=""; case_cache="$empty_cache"
run_case "extra options of newer builds are reported" 0 "flags=o d a n e r b t c s"

# 10. Non-executable file is not accepted.
make_fake "$work/noexec/pict" v374
chmod -x "$work/noexec/pict"
case_path="$tools"; case_bin="$work/noexec/pict"; case_cache="$empty_cache"
run_case "non-executable file is rejected" 1 "status=missing"

# 11. Path with spaces.
make_fake "$work/with space/pict" v374
case_path="$tools"; case_bin="$work/with space/pict"; case_cache="$empty_cache"
run_case "path containing spaces works" 0 "path=$work/with space/pict"

# 12. Optional: a real binary.
if [ -n "${REAL_PICT:-}" ]; then
    case_path="$tools"; case_bin="$REAL_PICT"; case_cache="$empty_cache"
    run_case "real PICT binary" 0 "status=found" "path=$REAL_PICT" "flags=o d a n e r c s"
fi

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
