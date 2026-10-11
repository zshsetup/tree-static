# tree-static

Portable builds of [tree](https://oldmanprogrammer.net/source.php?dir=projects/tree), which lists the
contents of directories as a tree, built with [zig](https://ziglang.org) as the C toolchain.

- Linux glibc: only glibc is linked dynamically, and only symbols up to glibc 2.17, so the
  binaries run on anything from CentOS 7 onwards
- Linux musl (`--static`): fully static, no runtime dependencies at all (e.g. Alpine)
- macOS: only libSystem is dynamic (it ships with macOS, which has no fully static binaries)

## Prerequisites

- `zig`, GNU make (the `make` 3.81 of macOS is enough), `git`

## Installation

Clone the repo with submodules (shallow, the history of the vendored projects is not needed):

```shell
git clone --recurse-submodules --shallow-submodules https://github.com/zshsetup/tree-static
cd tree-static
```

## Usage

```shell
./build.sh
```

Output is installed under `dist/`:

- `dist/bin/tree`: the binary; copy it anywhere on your `PATH`
- `dist/share/man/man1/tree.1`: the man page

Pass `--static` for the fully static musl build on Linux (output in `dist-static/`), `--clean` to
remove previous build output first, and `--jobs N` to control parallelism.

To run the smoke tests against the build:

```shell
./tests/run_smoke_tests.sh            # dist/
./tests/run_smoke_tests.sh --static   # dist-static/
```

## Releases

Publishing a GitHub release tagged like the contents of `VERSION`, the tag checked out in
`vendor/tree`, builds and attaches `tree-static-<platform>.tar.gz` for `macos-arm64`,
`linux-amd64`, `linux-arm64`, `linux-musl-amd64`, and `linux-musl-arm64`, together with the sources
they were built from (`tree-static-sources.tar.gz`).

To update a vendored project, check out a new release tag in its submodule, commit it, and update
`VERSION` if it is the main one, e.g.
`git -C vendor/tree fetch --depth 1 origin tag 2.3.2 && git -C vendor/tree checkout 2.3.2`.

## Acknowledgments

This repository builds and vendors the following upstream projects, unmodified, as git
submodules under `vendor/`. Credit goes to their respective authors:

- [tree](https://github.com/Old-Man-Programmer/tree) by Steve Baker and contributors

## License

MIT for the code in this repository. See `NOTICE` for the licenses of the upstream projects and the
resulting binaries, which are GPL-2.0-or-later.
