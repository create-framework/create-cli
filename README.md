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
create new my-project     # a pixi project with mojo, create and a main.mojo
cd my-project
create run                # runs main.mojo
```

- `create new <path>` makes a project with the Modular, modular-community and conda-forge
  channels, for Linux (x86-64) and macOS (Apple silicon), adds the `mojo` and `create` packages
  and writes a `main.mojo` to start from. If a step fails, nothing is left behind.
- `create run [args...]` runs the project's `main.mojo` from anywhere inside the project,
  passing any arguments to the program: `create run gpu` runs it on the GPU backend.

A project is a plain pixi project, so `pixi run mojo run main.mojo` does the same as `create run`.

## Development

The CLI is one POSIX shell script, [bin/create](bin/create), packaged as a `noarch` conda package.

```sh
pixi run lint      # shellcheck
pixi run test      # end to end: create new, then build its main.mojo (needs the network)
pixi run package   # build the conda package into build/
```

To release, set the version in both [bin/create](bin/create) and
[recipe/recipe.yaml](recipe/recipe.yaml) (the package's test checks they match), then push a
`vX.Y.Z` tag: the release workflow builds the package and uploads it to the channel.
