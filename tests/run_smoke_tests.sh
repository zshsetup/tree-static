#!/usr/bin/env bash
# Usage: ./tests/run_smoke_tests.sh [--static] [--dist DIR]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT_DIR/dist"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --static)
      DIST="$ROOT_DIR/dist-static"
      shift
      ;;
    --dist)
      DIST="$(cd "$2" && pwd)"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

BIN="$DIST/bin/tree"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass() { echo "ok: $*"; }
fail() {
  echo "FAIL: $*" >&2
  exit 1
}

version="$("$BIN" --version)"
echo "$version" | grep -q '^tree v' || fail "tree --version: $version"
pass "$version"

mkdir -p "$TMP/top/sub/deeper"
touch "$TMP/top/file.txt" "$TMP/top/sub/inner.txt"
out="$("$BIN" -n "$TMP/top")"
for name in file.txt sub inner.txt deeper; do
  echo "$out" | grep -q "$name" || fail "$name missing from the listing: $out"
done
echo "$out" | grep -q '3 directories, 2 files' || fail "summary line: $out"
pass "lists a directory tree"

json="$("$BIN" -J "$TMP/top")"
echo "$json" | grep -q '"name":"file.txt"' || fail "JSON output: $json"
pass "JSON output"

if [ "$(uname -s)" = Linux ] && ! LC_ALL=C grep -a -q 'ld-musl' "$BIN"; then
  max="$(LC_ALL=C grep -aoh 'GLIBC_2\.[0-9]*' "$BIN" | sort -uV | tail -n 1)" || true
  if [ -n "$max" ]; then
    [ "$(printf '%s\n' "$max" GLIBC_2.17 | sort -V | tail -n 1)" = GLIBC_2.17 ] \
      || fail "needs $max, newer than GLIBC_2.17"
    pass "glibc floor ($max)"
  fi
fi

echo "all smoke tests passed"
