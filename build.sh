#!/usr/bin/env bash
# Usage: ./build.sh [--jobs N] [--clean] [--static]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"
CLEAN=0
STATIC=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --jobs)
      JOBS="$2"
      shift 2
      ;;
    --clean)
      CLEAN=1
      shift
      ;;
    --static)
      STATIC=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

export JOBS
GLIBC_VER=2.17

OS="$(uname -s)"
ARCH="$(uname -m)"
[ "$ARCH" = arm64 ] && ARCH=aarch64

SUFFIX=""
[ "$STATIC" = 1 ] && SUFFIX="-static"
WORK="$ROOT_DIR/build$SUFFIX"
PREFIX="$WORK/deps"
DIST="$ROOT_DIR/dist$SUFFIX"

case "$OS-$ARCH" in
  Linux-x86_64 | Linux-aarch64)
    ZIG_TARGET=$ARCH-linux-gnu.$GLIBC_VER
    [ "$STATIC" = 1 ] && ZIG_TARGET=$ARCH-linux-musl
    ;;
  Darwin-aarch64 | Darwin-x86_64)
    ZIG_TARGET=native
    ;;
  *)
    echo "unsupported host $OS-$ARCH" >&2
    exit 1
    ;;
esac
if [ "$OS" != Linux ] && [ "$STATIC" = 1 ]; then
  echo "--static is only supported on Linux" >&2
  exit 1
fi

MAKE="${MAKE:-$(command -v gmake || command -v make)}"
"$MAKE" --version 2>/dev/null | grep -q 'GNU Make' || {
  echo "GNU make required" >&2
  exit 1
}

if [ "$ZIG_TARGET" = native ]; then
  export CC="zig cc" CXX="zig c++"
else
  export CC="zig cc -target $ZIG_TARGET" CXX="zig c++ -target $ZIG_TARGET"
fi
export AR="zig ar"
export RANLIB="zig ranlib"
[ "$OS" = Linux ] && export LD="zig ld.lld"
LDSTATIC=""
[ "$STATIC" = 1 ] && LDSTATIC="-static"

if [ "$CLEAN" = 1 ]; then
  echo ">>> cleaning $WORK and $DIST"
  rm -rf "$WORK" "$DIST"
fi
mkdir -p "$WORK/src" "$PREFIX/include" "$PREFIX/lib"

cd "$WORK/src"

# copies a submodule into the build dir
prepare() {
  [ -d "$1" ] && return
  if [ ! -f "$ROOT_DIR/vendor/$1/.git" ] && [ ! -d "$ROOT_DIR/vendor/$1/.git" ]; then
    echo "vendor/$1 is missing, run: git submodule update --init --depth 1" >&2
    exit 1
  fi
  echo ">>> preparing $1 ($(git -C "$ROOT_DIR/vendor/$1" describe --tags 2>/dev/null || echo unknown))"
  cp -R "$ROOT_DIR/vendor/$1" "$1"
  rm -rf "$1/.git"
}

prepare tree

echo ">>> tree"
(
  cd tree
  # CC has to be given to make, whose default for CC is set; the optimization flags of the Makefile
  # stay out, as they are for gcc only
  "$MAKE" -j"$JOBS" CC="$CC" CFLAGS="-Os -std=c11" LDFLAGS="$LDSTATIC -s" tree
  rm -rf "$DIST"
  mkdir -p "$DIST/bin" "$DIST/share/man/man1"
  cp tree "$DIST/bin/tree"
  cp doc/tree.1 "$DIST/share/man/man1/tree.1"
)

BIN="$DIST/bin/tree"
echo
echo ">>> done: $BIN"
"$BIN" --version
if [ "$OS" = Linux ]; then
  if [ "$STATIC" = 1 ]; then
    # static musl libc embeds the loader path as a string, so check for an interpreter header.
    if readelf -l "$BIN" | grep -q INTERP; then
      echo "WARNING: tree references a dynamic loader, not fully static" >&2
    else
      echo "fully static"
    fi
  else
    echo "only glibc is dynamic"
  fi
else
  otool -L "$BIN"
fi
