#!/bin/sh
# End to end: makes a project with `create new` in a temporary directory, then
# builds its main.mojo, which type-checks the template against the newest
# Create. Needs the network; the program itself is not run (no display).
set -eu

create="$(cd "$(dirname "$0")/.." && pwd)/bin/create"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

"$create" --version | grep -q '^create ' || fail "--version"
"$create" bogus 2>/dev/null && fail "an unknown command succeeded"
"$create" run 2>/dev/null && fail "run outside a project succeeded"

"$create" new demo
[ -f demo/pixi.toml ] || fail "no pixi.toml"
[ -f demo/main.mojo ] || fail "no main.mojo"
grep -q 'run\[MyApp\]("demo")' demo/main.mojo || fail "the title is not the project's name"
"$create" new demo 2>/dev/null && fail "new over an existing directory succeeded"

(cd demo && pixi run mojo build main.mojo -o app) || fail "main.mojo does not build"

echo "ok"
