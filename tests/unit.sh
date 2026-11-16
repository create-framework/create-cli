#!/bin/sh
# Offline tests: runs bin/create against a stub pixi on PATH that records how
# it is called, so argument handling, cleanup, finding the project and error
# paths are tested in a second, without the network. tests/e2e.sh tests
# against the real pixi.
#
# Tests that change the environment do it in a subshell, so the change ends
# with it, which is what SC2030 and SC2031 warn about.
# shellcheck disable=SC2030,SC2031
set -eu

create="$(cd "$(dirname "$0")/.." && pwd)/bin/create"
nl='
'
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
work=$(cd "$work" && pwd -P)

# The environment the stub pixi reports for a project, $STUB_PREFIX, with
# the project template a Create package installs.
template="$work/prefix/share/create/template"
mkdir -p "$template/assets"
printf '# A template\nrun[MyApp]("{{name}}")\n' >"$template/main.mojo"
printf 'not really a png\n' >"$template/assets/logo.png"
logo="$template/assets/logo.png"
mkdir "$work/old-create"

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
    run | exec)
        printf 'cwd=%s\n' "$(pwd -P)" >>"$STUB_LOG"
        case "$*" in *"printenv CONDA_PREFIX") printf '%s\n' "$STUB_PREFIX" ;; esac
        ;;
    update) : >"$(dirname "$STUB_LOG")/updated" ;;
    upgrade)
        case "$*" in
            *--dry-run*)
                # Until the project is upgraded, create 0.2.0 is beyond
                # what it allows, as pixi upgrade --json reports it.
                if [ -e "$(dirname "$STUB_LOG")/upgraded" ]; then
                    printf '{\n  "version": 1,\n  "environment": {}\n}\n'
                else
                    cat <<'JSON'
{
  "version": 1,
  "environment": {
    "default": {
      "linux-64": [
        {
          "name": "create",
          "before": {
            "conda": "https://prefix.dev/create-framework/create/linux-64/create-0.1.2-hb0f4dca_0.conda",
            "size": 4663743
          },
          "after": {
            "conda": "https://prefix.dev/create-framework/create/linux-64/create-0.2.0-hb0f4dca_0.conda",
            "size": 4698441
          },
          "type": "conda",
          "explicit": true
        }
JSON
                    if [ -n "${STUB_NEWER_MOJO-}" ]; then
                        cat <<'JSON'
        ,{
          "name": "mojo",
          "before": {
            "conda": "https://conda.modular.com/max/linux-64/mojo-1.1.0-release.conda"
          },
          "after": {
            "conda": "https://conda.modular.com/max/linux-64/mojo-1.3.0-release.conda"
          },
          "type": "conda",
          "explicit": true
        }
JSON
                    fi
                    cat <<'JSON'
      ]
    }
  }
}
JSON
                fi
                ;;
            *) : >"$(dirname "$STUB_LOG")/upgraded" ;;
        esac
        ;;
    list)
        # create moves to 0.1.2 once the project is updated, and to 0.2.0
        # once it is upgraded.
        create=0.1.1
        if [ -e "$(dirname "$STUB_LOG")/updated" ]; then create=0.1.2; fi
        if [ -e "$(dirname "$STUB_LOG")/upgraded" ]; then create=0.2.0; fi
        printf 'Name    Version\ncreate  %s\nmojo    1.1.0\n' "$create"
        ;;
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
STUB_PREFIX="$work/prefix"
export PATH STUB_LOG STUB_PREFIX
unset STUB_FAIL STUB_NEWER_MOJO NO_COLOR FORCE_COLOR

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
# status in $status. To change the environment for a call, export in a
# subshell: an assignment before a function call, like `VAR=x run`, stays set
# after it in some shells, such as macOS's /bin/sh (bash 3.2).
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
run --version; ok "--version"; says "create-cli dev" "--version"
run --help; ok "--help"; says "create watch" "--help"
run; fails "no command"
run bogus; fails "an unknown command"; says "unknown command 'bogus'" "an unknown command"

# --- new

fresh new
run new demo; ok "new"
[ -f demo/main.mojo ] || fail "new: no main.mojo"
grep -qF 'run[MyApp]("demo")' demo/main.mojo || fail "new: the title is not the project's name"
grep -qxF '/build/' demo/.gitignore || fail "new: build/ is not ignored"
cmp -s demo/assets/logo.png "$logo" || fail "new: no assets/logo.png"
logged '[--channel][https://conda.modular.com/max]' "new"
logged '[--platform][linux-64][--platform][osx-arm64]' "new"
logged '[add][--manifest-path][demo/pixi.toml][mojo][create]' "new"
logged '[run][--manifest-path][demo/pixi.toml][printenv][CONDA_PREFIX]' "new"
says "Creating new project 'demo'" "new"
says "Adding the Mojo and Create pixi packages" "new"
case $out in *"stub: added"*) fail "new: pixi's output is shown without --verbose" ;; esac
case $out in *"$(printf '\033')"*) fail "new: colour when not on a terminal" ;; esac

run new demo; fails "new over an existing project"; says "not empty" "new over an existing project"
touch file; run new file; fails "new over a file"

fresh new-verbose
run new --verbose demo; ok "new --verbose"; says "stub: added" "new --verbose"
fresh new-verbose-after
run new demo -v; ok "new with -v after the path"; says "stub: added" "new -v after the path"

fresh new-help
run new --help; ok "new --help"; says "Usage: create new" "new --help"
[ -z "$(ls -A)" ] || fail "new --help made something: $(ls -A)"
[ ! -s "$STUB_LOG" ] || fail "new --help called pixi"

fresh new-bad-args
run new --frobnicate demo; fails "new with an unknown option"; says "unknown option '--frobnicate'" "an unknown option"
run new; fails "new without a path"
run new a b; fails "new with two paths"
run new ''; fails "new with an empty path"
[ -z "$(ls -A)" ] || fail "a bad new made something: $(ls -A)"

fresh new-dash
run new -- -odd; ok "new -- -odd"
[ -f ./-odd/main.mojo ] || fail "new -- -odd: no project"

fresh new-slashes
run new demo///; ok "new with trailing slashes"
grep -qF 'run[MyApp]("demo")' demo/main.mojo || fail "trailing slashes: wrong title"

fresh new-quoting
run new 'my "odd\ project'; ok "new with quotes, a backslash and a space"
grep -qF 'run[MyApp]("my \"odd\\ project")' "my \"odd\\ project/main.mojo" \
    || fail "quotes are not escaped in main.mojo: $(grep 'run\[' "my \"odd\\ project/main.mojo")"

fresh new-empty-dir
mkdir empty
run new empty; ok "new in an empty directory"; [ -f empty/main.mojo ] || fail "new empty: no main.mojo"

fresh new-dot
mkdir here && cd here
run new .; ok "new ."
[ -f main.mojo ] || fail "new .: no main.mojo"
grep -qF 'run[MyApp]("here")' main.mojo || fail "new .: the title is not the directory's name"
[ -f assets/logo.png ] || fail "new .: no assets/logo.png"

fresh new-old-create
(export STUB_PREFIX="$work/old-create"; run new demo; fails "new with a Create without a template"
    says "the Create package has no project template; create new needs Create 0.3.1 or later" \
        "new with a Create without a template")
[ ! -e demo ] || fail "new with a Create without a template left demo behind"
(export STUB_FAIL=run; run new demo; fails "new when pixi run fails"
    says "could not find the Create package: pixi run failed" "new when pixi run fails")
[ ! -e demo ] || fail "new when pixi run fails left demo behind"

fresh new-fail
(export STUB_FAIL=add; run new demo; fails "new when pixi add fails"
    says "stub: add failed" "the failing pixi's output is not shown")
[ ! -e demo ] || fail "a failed new left demo behind"
mkdir empty
(export STUB_FAIL=add; run new empty; fails "new in a directory when pixi add fails")
[ -d empty ] || fail "a failed new removed a directory it did not make"
[ -z "$(ls -A empty)" ] || fail "a failed new left files in empty: $(ls -A empty)"
(export STUB_FAIL=init; run new demo; fails "new when pixi init fails")
[ ! -e demo ] || fail "a failed init left demo behind"

fresh new-platform
(PATH="$work/freebsd:$PATH"; run new demo; fails "new on FreeBSD"
    says "not on FreeBSD amd64" "the unsupported platform")
[ ! -e demo ] || fail "new on an unsupported platform made demo"

if ! PATH=/usr/bin:/bin command -v pixi >/dev/null 2>&1; then
    fresh new-no-pixi
    (PATH=/usr/bin:/bin; run new demo; fails "new without pixi"; says "pixi is not installed" "new without pixi")
fi

# --- run

fresh run
"$create" new demo >/dev/null
mkdir -p demo/src/deep
: >"$STUB_LOG"
(cd demo/src/deep && run run gpu "two words" && ok "run" && logged '[run][mojo][run][main.mojo][gpu][two words]' "run")
logged "cwd=$dir/demo" "run does not run in the project's directory"

: >"$STUB_LOG"
(cd demo && run run -- --help && ok "run -- --help" && logged '[main.mojo][--help]' "run -- --help")
(cd demo && run run --help && ok "run --help" && says "Usage: create run" "run --help")

run run; fails "run outside a project"; says "not in a Create project" "run outside a project"

# A pixi.toml without a main.mojo, like a nested workspace, is passed over.
mkdir -p demo/nested && : >demo/nested/pixi.toml
: >"$STUB_LOG"
(cd demo/nested && run run && ok "run in a nested workspace")
logged "cwd=$dir/demo" "run in a nested workspace"

# --- watch

fresh watch
"$create" new demo >/dev/null
: >"$STUB_LOG"
(cd demo && run watch arg && ok "watch")
logged '[exec][--spec][watchexec>=' "watch"
logged '[--restart][--exts][mojo]' "watch"
logged '[--][pixi][run][mojo][run][main.mojo][arg]' "watch"
(cd demo && run watch --help && ok "watch --help" && says "Usage: create watch" "watch --help")

# --- build

fresh build
"$create" new demo >/dev/null
mkdir demo/src
: >"$STUB_LOG"
(cd demo/src && run build && ok "build" && says "Building project 'demo'" "build" \
    && says "Built $dir/demo/build/demo" "build")
logged "[run][--manifest-path][$dir/demo/pixi.toml][mojo][build][$dir/demo/main.mojo][-o][$dir/demo/build/demo]" "build"
logged "cwd=$dir/demo/src" "build does not stay in the current directory"
[ -d demo/build ] || fail "build: no build directory"

: >"$STUB_LOG"
(cd demo && run build -o app && ok "build -o app")
logged 'main.mojo][-o][app]' "build -o app"
not_logged '/build/demo]' "build -o app also gave the default output"

# --- update

fresh update
"$create" new demo >/dev/null
mkdir demo/src
: >"$STUB_LOG"
(cd demo/src && run update
    ok "update"
    says "Updating project 'demo'" "update"
    says "create 0.1.1 -> 0.1.2" "update"
    says "mojo 1.1.0 (unchanged)" "update"
    says "create 0.2.0 (release notes: https://github.com/create-framework/create/releases/tag/v0.2.0)" "update's note of a newer create"
    says "New package version available:" "update's note of a newer create"
    says "releases/tag/v0.2.0)$nl${nl}It is outside the versions pixi.toml allows." "update's note of a newer create"
    says "See its release notes for any breaking changes." "update's note of a newer create"
    says "To upgrade anyway, use: create upgrade" "update's note of a newer create"
    if printf '%s\n' "$out" | grep -q '^  mojo .*release notes'; then
        fail "update notes a newer mojo that is not out: $out"
    fi
    case $out in *"stub:"*) fail "update: pixi's output is shown without --verbose" ;; esac)
logged "[update][--manifest-path][$dir/demo/pixi.toml]" "update"
rm -f "$work/updated"
(cd demo && export STUB_NEWER_MOJO=1 && run update
    ok "update with a newer mojo and create"
    says "New package versions available:" "update's note of a newer mojo and create"
    says "  mojo 1.3.0 (release notes: https://docs.modular.com/mojo/changelog/)" "update's note of a newer mojo and create"
    says "They are outside the versions pixi.toml allows" "update's note of a newer mojo and create"
    says "See their release notes for any breaking changes." "update's note of a newer mojo and create"
    says "To upgrade anyway, use: create upgrade" "update's note of a newer mojo and create")
rm -f "$work/updated"
(cd demo && export STUB_FAIL=update && run update && fails "update when pixi update fails" \
    && says "stub: update failed" "update when pixi update fails")
(cd demo && run update --help && ok "update --help" && says "Usage: create update" "update --help")
(cd demo && run update extra && fails "update with an argument" \
    && says "unexpected argument 'extra'; see 'create update --help'" "update with an argument")
(cd demo && run update --frobnicate && fails "update with an unknown option" \
    && says "unknown option '--frobnicate'; see 'create update --help'" "update with an unknown option")
run update; fails "update outside a project"
rm -f "$work/updated"

# --- upgrade

fresh upgrade
"$create" new demo >/dev/null
mkdir demo/src
: >"$STUB_LOG"
(cd demo/src && run upgrade && ok "upgrade" && says "Upgrading project 'demo'" "upgrade" \
    && says "create 0.1.1 -> 0.2.0 (release notes: https://github.com/create-framework/create/releases/tag/v0.2.0)" "upgrade" \
    && says "mojo 1.1.0 (unchanged)" "upgrade" && says "See the release notes for any breaking changes" "upgrade")
logged "[upgrade][--manifest-path][$dir/demo/pixi.toml][mojo][create]" "upgrade"
(cd demo && run upgrade && ok "upgrade when up to date" \
    && case $out in *"See the release notes"*) fail "upgrade with nothing to upgrade points to the release notes" ;; esac)
(cd demo && run update && ok "update once upgraded" \
    && case $out in *"New package"*) fail "update notes a newer release once upgraded: $out" ;; esac)
rm -f "$work/upgraded" "$work/updated"
(cd demo && export STUB_FAIL=upgrade && run upgrade && fails "upgrade when pixi upgrade fails" \
    && says "stub: upgrade failed" "upgrade when pixi upgrade fails")
(cd demo && run upgrade --help && ok "upgrade --help" && says "Usage: create upgrade" "upgrade --help")
(cd demo && run upgrade --frobnicate && fails "upgrade with an unknown option" \
    && says "unknown option '--frobnicate'; see 'create upgrade --help'" "upgrade with an unknown option")
(cd demo && run upgrade extra && fails "upgrade with an argument")
run upgrade; fails "upgrade outside a project"

# --- doctor

fresh doctor
"$create" new demo >/dev/null
run doctor; ok "doctor outside a project"; says "not in a project" "doctor outside a project"
(cd demo && run doctor && ok "doctor" && says "create 0.1.1, mojo 1.1.0" "doctor" \
    && says "create-cli dev" "doctor")
(PATH="$work/freebsd:$PATH"; run doctor; fails "doctor on FreeBSD"; says "1 problem found." "doctor on FreeBSD")
run doctor extra; fails "doctor with an argument"; says "unexpected argument 'extra'; see 'create doctor --help'" "doctor with an argument"

# --- the output style

esc=$(printf '\033')
fresh style
"$create" new demo >/dev/null
: >"$STUB_LOG"
(cd demo && export FORCE_COLOR=1 && run update
    ok "update with FORCE_COLOR"
    says "${esc}[1;34m==>${esc}[0m ${esc}[1mUpdating project 'demo'${esc}[0m" "a step's style"
    says "${esc}[2mmojo 1.1.0 (unchanged)${esc}[0m" "an unchanged version's style"
    says "${esc}[2m0.1.1 ->${esc}[0m ${esc}[32m0.1.2${esc}[0m" "a changed version's style"
    says "${esc}[1;33mNew package version available:${esc}[0m" "a note heading's style"
    says "use: ${esc}[36mcreate upgrade${esc}[0m" "a hint's style")
rm -f "$work/updated"
(cd demo && export FORCE_COLOR=1 && run update --frobnicate
    says "${esc}[1;31mcreate:${esc}[0m unknown option '--frobnicate'; see '${esc}[36mcreate update --help${esc}[0m'" "an error's style")
(cd demo && export FORCE_COLOR=1 NO_COLOR=1 && run update
    case $out in *"$esc"*) fail "colour with NO_COLOR and FORCE_COLOR set: $out" ;; esac)
rm -f "$work/updated"
(cd demo && export FORCE_COLOR=0 && run doctor
    case $out in *"$esc"*) fail "colour with FORCE_COLOR=0: $out" ;; esac)
(export FORCE_COLOR=1 && run bogus
    says "${esc}[1mUsage:${esc}[0m" "help after an unknown command, coloured as stderr")
(cd demo && export LC_ALL=C.UTF-8 && run doctor && says "✓ platform" "doctor's marks in UTF-8")
(cd demo && export LC_ALL=C && run doctor && says "ok platform" "doctor's marks without UTF-8")

if [ -s "$work/failures" ]; then
    printf '%s failure(s)\n' "$(wc -l <"$work/failures" | tr -d ' ')" >&2
    exit 1
fi
echo "ok"
