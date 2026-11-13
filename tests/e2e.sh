#!/bin/sh
# End to end, against the real pixi: makes a project with `create new` in a
# temporary directory, builds it with `create build`, updates it with
# `create update` and checks it with `create doctor`. Needs the network; the program itself is not run (no
# display).
#
# With --latest, the project is moved to the newest Create before building, so
# CI finds out when a Create release breaks the main.mojo template and
# CREATE_SPEC in bin/create needs updating with it.
set -eu

latest=
case ${1-} in
    --latest) latest=1 ;;
    '') ;;
    *) echo "usage: tests/e2e.sh [--latest]" >&2; exit 2 ;;
esac

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

if [ -n "$latest" ]; then
    pixi add --manifest-path demo/pixi.toml create || fail "moving to the newest create"
fi

mkdir demo/src
(cd demo/src && "$create" build) || fail "main.mojo does not build"
[ -x demo/build/demo ] || fail "create build made no demo/build/demo"

(cd demo && "$create" update) || fail "create update"
(cd demo && "$create" doctor) || fail "create doctor found problems"

echo "ok"
