#!/bin/sh
# find-pict.sh - locate the PICT executable and report which options it supports.
#
# Read-only and offline: this script does not download, install, build or
# write anything. It only checks a few locations and runs a candidate once
# with no arguments to read its usage text.
#
# Search order:
#   1. $PICT_BIN            (explicit path chosen by the user)
#   2. pict / pict.exe      (on PATH)
#   3. the skill cache dir  (${XDG_CACHE_HOME:-$HOME/.cache}/pict-skill)
#
# Output: key=value lines on stdout.
# Exit:   0 when a working PICT was found, 1 otherwise.

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/pict-skill"
usage=""

# Succeeds when "$1" is an executable that identifies itself as PICT.
probe() {
    [ -n "$1" ] || return 1
    [ -f "$1" ] || return 1
    [ -x "$1" ] || return 1
    usage=$("$1" </dev/null 2>&1)
    case "$usage" in
        *"Pairwise Independent Combinatorial"*) return 0 ;;
    esac
    return 1
}

report_found() {
    # Option letters come from usage lines such as " /o:N|max - Order of ...".
    flags=$(printf '%s\n' "$usage" |
        sed -n 's|^[[:space:]]*/\([A-Za-z]\).*|\1|p' | tr '\n' ' ' | sed 's/ $//')
    echo "status=found"
    echo "path=$1"
    echo "source=$2"
    echo "flags=$flags"
    exit 0
}

if [ -n "${PICT_BIN:-}" ]; then
    if probe "$PICT_BIN"; then
        report_found "$PICT_BIN" "PICT_BIN"
    fi
    echo "note=PICT_BIN is set to '$PICT_BIN' but that is not a working PICT executable"
fi

for name in pict pict.exe; do
    candidate=$(command -v "$name" 2>/dev/null) || continue
    if probe "$candidate"; then
        report_found "$candidate" "PATH"
    fi
    echo "note=found '$candidate' on PATH but it does not identify itself as PICT"
done

for name in pict pict.exe; do
    if probe "$cache_dir/$name"; then
        report_found "$cache_dir/$name" "cache"
    fi
done

echo "status=missing"
echo "cache_dir=$cache_dir"
echo "os=$(uname -s 2>/dev/null || echo unknown)"
exit 1
