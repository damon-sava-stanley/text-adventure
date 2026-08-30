# Text Adventure

An experimental Haskell toolkit for building text adventures.

The project is exploring an interactive-fiction engine whose world is modeled
as relational data, with a turn split into parsing, deciding, applying events,
and describing the outcome. SQLite is intended to provide the authoritative
world state and save format. The early design notes live in
[`notes/rough_thoughts.md`](notes/rough_thoughts.md).

The library currently defines the foundational structure of that design: the
generic turn pipeline and store boundary in `TextAdventure.Core`, plus a
Persistent ontology and SQLite adapter in `TextAdventure.Ontology` and
`TextAdventure.Store.Persistent`. `TextAdventure` re-exports these modules as a
convenient public entry point. The public `installGame` and `runTurn` operations
install a game's ontology and execute its complete turn pipeline in a store
transaction. A handled `TurnOutcome` retains both the canonical parsed command
and its accepted or rejected decision, allowing `Game.describe` to respond to
player intent even when the decision produces no events. Parse failures remain
separate and do not carry a command.

Persistent supplies generated records, typed `Key entity` identifiers, schema
migrations, and CRUD queries. Esqueleto is included for richer relational
queries. The rationale and save-migration caveat are recorded in
[`ADR 0001`](docs/decisions/0001-use-persistent.md).

SQLite-backed applications should scope their store with `withSqliteStore`:

```haskell
withSqliteStore database $ \store -> do
    installGame store game
    runTurn store game input
```

The scope retains one connection, closes it on normal or exceptional exit, and
supports both file paths and literal `:memory:` databases. Store operations are
serialized: callers may use the store from multiple threads, but each install
or transaction completes before the next begins. The older `sqliteStore`
constructor remains available for file-backed compatibility; because it opens
a connection per operation, it does not support literal `:memory:`.

A playable SQLite-backed game is available in the [examples](examples)
directory.

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
- `examples/` — playable examples
- `test/` — test source
- `notes/` — design notes
- `docs/decisions/` — accepted architectural decisions
