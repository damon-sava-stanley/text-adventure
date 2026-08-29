# Text Adventure

An experimental Haskell toolkit for building text adventures.

The project is exploring an interactive-fiction engine whose world is modeled
as relational data, with a turn split into parsing, deciding, applying events,
and describing the outcome. SQLite is intended to provide the authoritative
world state and save format. The early design notes live in
[`notes/rough_thoughts.md`](notes/rough_thoughts.md).

This repository is currently only a project skeleton. It contains a small
library, a Hello World executable, and a smoke test so the build is known to be
wired together correctly; none of the engine design has been implemented yet.

## Development

Enter the Nix development environment:

```console
nix develop
```

The development shell includes [Task](https://taskfile.dev/) for the common
project commands:

```console
task build
task run
task test
task lint
task format
```

## Layout

- `lib/` — library source
- `app/` — executable source
- `test/` — test source
- `notes/` — design notes
