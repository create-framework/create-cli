#!/bin/sh
# End to end, against the real pixi: makes a project with `create new` in a
# temporary directory, then builds it with `create build`, which type-checks
# the template against the newest Create. Needs the network; the program
# itself is not run (no display).
set -eu

create="$(cd "$(dirname "$0")/.." && pwd)/bin/create"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

"$create" new demo || fail "create new"
[ -f demo/pixi.toml ] || fail "no pixi.toml"
[ -f demo/main.mojo ] || fail "no main.mojo"

mkdir demo/src
(cd demo/src && "$create" build) || fail "main.mojo does not build"
[ -x demo/build/demo ] || fail "create build made no demo/build/demo"

echo "ok"
