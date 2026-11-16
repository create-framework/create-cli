# AGENTS.md — create-cli

create-cli's docs are written for every contributor, human or agent. Read them before working
here; this file adds only what is specific to agents.

## Always

These apply to every task and are imported below:

- [README.md](README.md): what each command does for its user, which every change must keep.
- [CONTRIBUTING.md](CONTRIBUTING.md): the design ethos, how the code is organised, building and
  testing, the workflow and commit messages, and the code conventions.

@README.md

@CONTRIBUTING.md

## When the task touches it

- [RELEASING.md](RELEASING.md), only when asked to cut a release.
- [Create's CONTRIBUTING.md](https://github.com/create-framework/create/blob/main/CONTRIBUTING.md),
  when changing the project template: it lives in Create's repository, not here.

## As an agent

- **Judge an idea on its merits.** When discussing a design or an idea, don't count breaking
  changes, doc churn, or rewriting tests as costs; CONTRIBUTING.md's "Early development" says
  why. If an idea is worse for other reasons, say so.
- Leave merging to the user unless they ask for it.
- Run `pixi run lint` and `pixi run test` for every change; add `pixi run e2e` (network, minutes)
  only when the change reaches the real pixi or Create, such as `create new`.
- Write POSIX `sh`, and check it with `shellcheck` rather than trusting what bash accepts.
