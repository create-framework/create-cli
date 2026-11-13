#!/bin/sh
# Offline tests: runs bin/create against a stub pixi on PATH that records how
# it is called, so argument handling, cleanup, finding the project and error
# paths are tested in a second, without the network. tests/e2e.sh tests
# against the real pixi.
set -eu

create="$(cd "$(dirname "$0")/.." && pwd)/bin/create"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
work=$(cd "$work" && pwd -P)

# The stub pixi. It appends each call to $STUB_LOG, one line with every
# argument in brackets, and fails the subcommand named by $STUB_FAIL.
mkdir "$work/bin"
cat >"$work/bin/pixi" <<'EOF'
#!/bin/sh
{
    for arg; do printf '[%s]' "$arg"; done
    printf '\n'
} >>"$STUB_LOG"
if [ "$1" = "${STUB_FAIL-}" ]; then
    echo "stub: $1 failed" >&2
    exit 1
fi
case $1 in
    --version) echo "pixi 0.78.0" ;;
    init)
        for path; do :; done
        mkdir -p -- "$path"
        printf '[workspace]\n' >"$path/pixi.toml"
        printf '.pixi/*\n' >"$path/.gitignore"
        ;;
    add) echo "stub: added" ;;
    run | exec) printf 'cwd=%s\n' "$(pwd -P)" >>"$STUB_LOG" ;;
    list) printf 'Name    Version\ncreate  0.1.1\nmojo    1.1.0\n' ;;
esac
EOF
chmod +x "$work/bin/pixi"

# A uname for a machine Create does not support.
mkdir "$work/freebsd"
cat >"$work/freebsd/uname" <<'EOF'
#!/bin/sh
case $1 in -s) echo FreeBSD ;; -m) echo amd64 ;; esac
EOF
chmod +x "$work/freebsd/uname"

PATH="$work/bin:$PATH"
STUB_LOG="$work/log"
export PATH STUB_LOG
unset STUB_FAIL NO_COLOR

# Failures are counted in a file, so ones in subshells count too.
fail() {
    printf 'FAIL: %s\n' "$1" >&2
    echo >>"$work/failures"
}

# A fresh directory to run a test in, with an empty log.
fresh() {
    dir="$work/t$1"
    mkdir "$dir"
    cd "$dir"
    : >"$STUB_LOG"
}

# Runs create, keeping its output in $out (stdout and stderr) and its exit
# status in $status.
run() {
    status=0
    out=$("$create" "$@" 2>&1) || status=$?
}

ok() { [ "$status" -eq 0 ] || fail "$1 (exit $status): $out"; }
fails() { [ "$status" -ne 0 ] || fail "$1 succeeded: $out"; }
says() { case $out in *"$1"*) ;; *) fail "$2: output lacks '$1': $out" ;; esac; }
logged() { grep -qF -- "$1" "$STUB_LOG" || fail "$2: pixi was not called with $1: $(cat "$STUB_LOG")"; }
not_logged() { ! grep -qF -- "$1" "$STUB_LOG" || fail "$2: pixi was called with $1"; }

# --- the top level

fresh top
run --version; ok "--version"; says "create 0.1.0" "--version"
run --help; ok "--help"; says "create run" "--help"
run; fails "no command"
run bogus; fails "an unknown command"; says "unknown command 'bogus'" "an unknown command"

# --- new

fresh new
run new demo; ok "new"
[ -f demo/main.mojo ] || fail "new: no main.mojo"
grep -qF 'run[MyApp]("demo")' demo/main.mojo || fail "new: the title is not the project's name"
logged '[--channel][https://conda.modular.com/max]' "new"
logged '[--platform][linux-64][--platform][osx-arm64]' "new"
logged '[add][--manifest-path][demo/pixi.toml][mojo][create]' "new"
says "cd demo" "new"

run new demo; fails "new over an existing project"
touch file; run new file; fails "new over a file"

fresh new-fail
STUB_FAIL=add run new demo; fails "new when pixi add fails"
says "stub: add failed" "the failing pixi's output is not shown"
[ ! -e demo ] || fail "a failed new left demo behind"
STUB_FAIL=init run new demo; fails "new when pixi init fails"
[ ! -e demo ] || fail "a failed init left demo behind"

if ! PATH=/usr/bin:/bin command -v pixi >/dev/null 2>&1; then
    fresh new-no-pixi
    PATH=/usr/bin:/bin run new demo; fails "new without pixi"; says "pixi is not installed" "new without pixi"
fi

# --- run

fresh run
"$create" new demo >/dev/null
mkdir -p demo/src/deep
: >"$STUB_LOG"
(cd demo/src/deep && run run gpu "two words" && ok "run" && logged '[run][mojo][run][main.mojo][gpu][two words]' "run")
logged "cwd=$dir/demo" "run does not run in the project's directory"

run run; fails "run outside a project"

if [ -s "$work/failures" ]; then
    printf '%s failure(s)\n' "$(wc -l <"$work/failures" | tr -d ' ')" >&2
    exit 1
fi
echo "ok"
