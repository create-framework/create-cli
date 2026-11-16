# create-cli

The command line tool for [Create](https://github.com/create-framework/create), the creative
coding library for Mojo. It makes creating and running projects more ergonomic.

## Installation

First install [pixi](https://pixi.sh) if you don't have it already:
```sh
curl -fsSL https://pixi.sh/install.sh | sh
```

Then run the following command to install the create-cli:
```sh
pixi global install create-cli --channel https://prefix.dev/create-framework/create
```

## Usage

```sh
create new my-project     # creates a new pixi project with mojo, create and a main.mojo
cd my-project
create run                # runs main.mojo
create watch              # runs main.mojo, and again whenever a .mojo file is saved
create build              # builds an optimised program into build/my-project
create update             # updates Mojo and Create within the versions the project allows
create upgrade            # upgrades Mojo and Create beyond the versions the project allows
create doctor             # checks pixi, this machine and the project for problems
```

- `create new <path>` creates a new project with the Modular, Create and conda-forge channels, for
  Linux (x86-64) and macOS (Apple silicon), adds the `mojo` and `create` packages and writes a
  `main.mojo` to start from, which draws the Create logo from `assets/logo.png`. `<path>` may be an empty directory, so `create new .` sets up the
  current one. If a step fails, nothing is left behind. `--verbose` shows pixi's output.
- `create run [args...]` runs the project's `main.mojo` from anywhere inside the project,
  passing any arguments to the program: `create run gpu` runs it on the GPU backend. The
  program runs in the project's directory, so the paths it opens are relative to the project.
  To pass `--help` to the program, write `create run -- --help`.
- `create watch [args...]` is `create run` that restarts the program whenever a `.mojo` file in
  the project changes. It uses [watchexec](https://github.com/watchexec/watchexec), which pixi
  downloads the first time.
- `create build [options]` builds `main.mojo` into `build/<project name>`; options go to
  `mojo build`, so `create build -o app` writes `./app` instead.
- `create update` runs `pixi update` from anywhere in the project, then shows how Mojo and
  Create changed. It stays within the versions `pixi.toml` allows, so it never brings a Create
  release that could break the project's code. When a newer Mojo or Create is out than those
  versions allow, it says so, with a link to the release notes; `create upgrade` upgrades to it.
- `create upgrade` runs `pixi upgrade mojo create` from anywhere in the project: it upgrades
  Mojo and Create to their newest releases and changes the versions `pixi.toml` allows to match,
  then shows how they changed, each with a link to its release notes. Such a release can
  change Create's API, so any of the project's code that uses it may need changes;
  `create build` checks that the project still builds. Other packages in `pixi.toml` are left as they are.
- `create doctor` reports the versions of the CLI, pixi, Mojo and Create, whether this machine
  is supported, and the display and GPU it would use.

`create <command> --help` explains each command. A project is a plain pixi project, so
`pixi run mojo run main.mojo` does the same as `create run`.

Output is coloured on a terminal. `NO_COLOR=1` turns colour off, and `FORCE_COLOR=1` turns it
on elsewhere, such as through a pipe to `less -R`.

To update the CLI: `pixi global update create-cli`.

## Documentation

- [Create's user guide](https://create-framework.org/guide/):
  how to write a program with Create.
- [Contributing](CONTRIBUTING.md): how to work on the CLI itself: what it values, building and
  testing, and how changes land.
- [Releasing](RELEASING.md): for maintainers, how a version is released.
