#!/bin/sh
# End to end, against the real pixi and the newest Create: makes a project with
# `create new` in a temporary directory, builds it with `create build`, then
# runs `create update`, `create upgrade` and `create doctor` on it. Needs the
# network; the program itself is not run (no display).
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
[ -f demo/assets/logo.png ] || fail "no assets/logo.png"
grep -qF 'run[MyApp]("demo")' demo/main.mojo || fail "main.mojo does not have the project's name"

mkdir demo/src
(cd demo/src && "$create" build) || fail "main.mojo does not build"
[ -x demo/build/demo ] || fail "create build made no demo/build/demo"

(cd demo && "$create" update) || fail "create update"
(cd demo && "$create" upgrade) || fail "create upgrade"
(cd demo && "$create" doctor) || fail "create doctor found problems"

echo "ok"
