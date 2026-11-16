# Releasing create-cli

For maintainers: how a version of the CLI is tagged, published as a conda package and released
on GitHub. Contributors don't need any of this.

A release is an annotated tag `vX.Y.Z` on a commit of `main`. Pushing the tag publishes the
conda package to the prefix.dev channel
[create-framework/create](https://prefix.dev/channels/create-framework/create), the one Create
is on too, which is what the README's `pixi global install` installs from.

## The version

The tag is the one place the version is set. `bin/create` says `VERSION="dev"`, and the package
build writes the tag's version in its place, so there is nothing to bump in a pull request.

While the CLI is at 0.x, a change in what it does or makes, such as a new command, bumps the
minor version; a fix bumps the patch. A Create release needs no CLI release: new projects get
the newest Create, and its template, as soon as it is on the channel.

## The release workflow

[.github/workflows/release.yml](.github/workflows/release.yml) runs on a pushed `v*` tag. It
fails unless the tag is `vX.Y.Z`, then builds and tests the package with `pixi run package` and
uploads it. The package is `noarch`, so one build serves every platform.

The upload authenticates through trusted publishing: the channel's settings on prefix.dev name
this repository and `release.yml` as a trusted publisher, so no token is stored. Renaming the
workflow file breaks that until the setting is updated.

## Steps

1. **Tag what merged**, by the remote's `main` rather than whatever is checked out:
   ```bash
   git fetch origin
   git tag -a vX.Y.Z -m "create-cli X.Y.Z" origin/main
   git push origin vX.Y.Z
   ```
2. **Watch the release workflow** (Actions → Release). When it passes, the package is on the
   channel: `pixi search create-cli -c https://prefix.dev/create-framework/create` lists it. A
   failed run publishes nothing: fix the cause on `main`, then move the tag to the fixed commit
   and push it again (`git push --force origin vX.Y.Z`) to rerun it.
3. **Create the GitHub release**, with notes on what changed for users:
   ```bash
   gh release create vX.Y.Z --title "create-cli X.Y.Z" --verify-tag --notes-file NOTES.md
   ```
