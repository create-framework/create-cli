# Contributing to create-cli

**create-cli** is the command line tool for [Create](https://github.com/create-framework/create),
the creative coding library for Mojo. It starts, runs, builds and updates Create projects, and
leaves the work itself to [pixi](https://pixi.sh).

This guide is for anyone working on the CLI itself: what the project values, how to make a first
change, and then the reference for building, testing, landing changes and the code's
conventions. Using the CLI is covered in the [README](README.md).

## What we value

### Early development

The CLI is in early development and makes no promise of stability yet. At this stage breaking
changes are fine. Doc churn and rewriting tests are not reasons to reject an idea; judge a change
on whether it makes the CLI better.

### Design ethos

The CLI follows [Create's design ethos](https://github.com/create-framework/create/blob/main/CONTRIBUTING.md#design-ethos):
intuitive, ergonomic, modular, consistent, composable and performant. For a command line tool
that means:

- **Intuitive:** Commands and options say what they do, in full words. Every command has a
  `--help`, and an error says what went wrong and what to do about it.
- **Ergonomic:** The common path is one short command that works from anywhere inside a project.
  Pixi's output is shown only when it helps (`--verbose`, or a failure).
- **Consistent:** Commands take their options, report their steps and fail alike, through the
  same helpers (`die`, `step`, `quietly`).
- **No lock-in:** A project is a plain pixi project. Everything the CLI does, pixi can do by
  hand; the CLI keeps no configuration or state of its own.
- **Safe:** A command that fails leaves nothing half-made behind, and a new project always
  builds: it is pinned to the Create releases its template is written for.

## Your first change

Everything the CLI needs comes from pixi; `pixi run` sets up the environment the first time it
is used.

1. **Clone and set up**, once per clone. `pixi run setup` installs the git hook (see
   [Checks](#checks)):

   ```bash
   git clone https://github.com/create-framework/create-cli.git
   cd create-cli
   pixi run setup
   ```

2. **Run it from the checkout.** `bin/create` runs as it is: `bin/create new /tmp/demo`.

3. **Make the change on a branch**, from an up-to-date `main`: `git switch -c some-change`.
   [How it is organised](#how-it-is-organised) says where it belongs.

4. **Test it**: `pixi run lint` and `pixi run test` take a second. New behaviour gets a test in
   `tests/unit.sh`; a change that reaches pixi or Create for real also runs `pixi run e2e`.

5. **Commit** with a [Conventional Commits](#commit-messages) message. The pre-commit hook runs
   the lint and the offline tests.

6. **Push and open a pull request.** CI runs everything on Linux and macOS, and it merges once
   CI passes (see [Workflow](#workflow)).

## How it is organised

| Path | What it is |
|---|---|
| [bin/create](bin/create) | The CLI: one POSIX `sh` script, with a `cmd_<name>` and a `usage_<name>` per command |
| [tests/unit.sh](tests/unit.sh) | Offline tests: `bin/create` against a stub `pixi` that records how it is called |
| [tests/e2e.sh](tests/e2e.sh) | End to end, against the real pixi: `create new`, then `build`, `update` and `doctor` |
| [recipe/recipe.yaml](recipe/recipe.yaml) | The `noarch` conda package; the build writes the release's version into the script |
| [.github/workflows/](.github/workflows/) | CI (`ci.yml`) and the release (`release.yml`) |

**The template and `CREATE_SPEC`.** `create new` writes a `main.mojo` from the template in
`main_mojo()` and adds Create at `CREATE_SPEC`, the releases that template is written for. So
a new project always builds, even after Create changes its API. CI builds the template against
the newest Create every week (`pixi run e2e-latest`); when that fails, update the template and
`CREATE_SPEC` together. Write the template's Mojo for the Create release it pins, by
[Create's user guide](https://create-framework.org/guide/).

## Building and testing

```bash
bin/create new /tmp/demo   # the CLI runs from the checkout
pixi run lint              # shellcheck every script
pixi run test              # offline tests against a stub pixi, about a second
pixi run e2e               # end to end against the real pixi; needs the network, takes minutes
pixi run e2e-latest        # the same, with the newest Create instead of CREATE_SPEC's
pixi run package           # the conda package, built and tested, into build/
pixi run setup             # once per clone: the git hook
```

### Checks

Two tiers of automated checks:

| Where | Runs |
|---|---|
| `pre-commit` hook (after `pixi run setup`) | `pixi run lint` and `pixi run test`. About a second |
| CI ([.github/workflows/ci.yml](.github/workflows/ci.yml)), every PR and push to `main` | Lint (Linux only), the offline tests, the end-to-end test and the package, on Linux and macOS. Weekly, also the end-to-end test against the newest Create, on Linux |

## Workflow

`main` is protected: every change lands as a pull request, merged once the required checks
`ci (ubuntu-latest)` and `ci (macos-latest)` pass; no approval is required. **Rebase and merge**
is the merge method.

```bash
git switch -c some-change                 # from an up-to-date main
git push -u origin some-change            # pushes run no hook; CI runs on the PR
gh pr create --fill
gh pr merge --auto --rebase               # merges itself once CI is green
git switch main && git pull --ff-only
```

Each of the branch's commits lands on `main` as it is, rebased (new hashes), so every one should
pass the checks and carry a finished message; tidy the branch before merging rather than relying
on a squash.

Releases are cut by a maintainer, as [RELEASING.md](RELEASING.md) describes.

### Commit messages

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/):
`<type>(<command>): <Summary>`, the summary in the imperative and capitalised.

- The scope is the command the change is confined to (`new`, `run`, `watch`, `build`, `update`,
  `doctor`); leave it out when a change spans several commands or touches none, such as the
  docs or CI.
- The types: `feat`, `fix`, `perf`, `refactor`, `docs`, `test`, `build` (pixi, the recipe,
  dependencies), `ci`, `chore`.
- A breaking change of the command line adds `!` before the colon.

```text
feat: Add create doctor
fix(run): Pass over a pixi.toml without a main.mojo
feat(new)!: Make projects with a src/ directory
ci: Test on macOS as well
```

## Code conventions

- **POSIX `sh`, not bash.** `bin/create` runs under `/bin/sh` on Linux and macOS, whose shells
  differ in the corners; CI runs the tests on both. Every script passes `shellcheck`.
- **Pixi does the work.** The CLI shells out to pixi rather than reimplementing it, and depends
  on nothing pixi doesn't provide.
- **A command is a `cmd_<name>` and a `usage_<name>`,** dispatched at the bottom of the script.
  Its `--help` prints the `usage_` text; a new command also gets a line in `usage`, the README's
  usage block and bullet, and tests.
- **Output:** progress through `step`, errors through `die` (to stderr, exiting 1), pixi's own
  output through `quietly`. Colour only on a terminal and never with `NO_COLOR` set, which
  `paint` handles.
- **Clean up on failure.** A command that makes files removes them if it fails, as
  `create new` does through its `EXIT` trap.
- **Tests:** a behaviour the stub pixi can show is tested in `tests/unit.sh`; only what needs
  the real pixi or Create goes in `tests/e2e.sh`. A test that changes the environment does it in
  a subshell.
