# ADR 0001: Use Persistent for SQLite worlds

Status: Accepted

## Context

The engine treats SQLite as authoritative world state and as its save format.
The original `SqlType` / `Column` / `Table` vocabulary could describe a small
schema, but completing it would also require maintaining DDL generation, row
codecs, typed keys, constraints, migrations, and a query layer.

The main alternatives considered were:

- **Persistent** with `persistent-sqlite` and Esqueleto: generated records,
  typed keys, migrations, safe SQLite defaults, raw SQL, and a richer optional
  query EDSL.
- **Selda**: ordinary records and a concise relational EDSL, but no native
  distinction between the engine's read and write action types and a less clean
  raw-SQL escape hatch.
- **Beam**: strong SQL-shaped query typing without Template Haskell, but
  substantially more schema and migration boilerplate for game authors.
- **sqlite-simple**: a reliable low-level baseline that would leave the custom
  schema, migration, and query layers for this project to implement.

## Decision

Use Persistent, `persistent-sqlite`, and Esqueleto.

Game authors define entities with Persistent and combine their generated
metadata with `migrateModels`. An `Ontology` contains that `Migration` and an
idempotent seed action. `sqliteStore` installs both in one transaction and
executes subsequent actions using a new connection to the configured database
file.

Persistent's `SqlReadBackend` and `SqlWriteBackend` preserve the generic
engine's distinction between read-only queries and transactions. Generated
`Key entity` values replace the custom `Id entity` type.

## Consequences

- Game schemas use Persistent syntax and Template Haskell rather than ordinary
  record declarations alone.
- SQLite connections enable write-ahead logging and foreign-key enforcement by
  default. Successful store actions commit; exceptions roll back the action.
- Esqueleto is available when CRUD queries are not expressive enough, while
  Persistent's supported raw-SQL APIs remain an escape hatch.
- Automatic schema diffs are useful during development, but they are not the
  long-term save compatibility policy. Before saves are treated as durable
  across released game versions, each game must adopt ordered, versioned schema
  and data migrations and test upgrades from every supported save version.
- The initial adapter opens one connection per operation. Connection pooling
  can be introduced later without changing the generic `Store` boundary.
