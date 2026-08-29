# Text Adventure

An experimental Haskell toolkit for building text adventures.

The project is exploring an interactive-fiction engine whose world is modeled
as relational data, with a turn split into parsing, deciding, applying events,
and describing the outcome. SQLite is intended to provide the authoritative
world state and save format. The early design notes live in
[`notes/rough_thoughts.md`](notes/rough_thoughts.md).

The library currently defines the foundational structure of that design: the
generic turn pipeline and store boundary in `TextAdventure.Core`, plus the typed
schema vocabulary in `TextAdventure.Ontology`. `TextAdventure` re-exports both
modules as a convenient public entry point. Runtime engine behavior and SQLite
integration have not been implemented yet.

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
