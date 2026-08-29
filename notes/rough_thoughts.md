# What is a Text Adventure

Emily Wilson calls interactive fiction a novel at war with a crossword.
Crossword undersells the systemic aspect of IF: it involves substantial
simulation. What type of simulation? Abstractly, generally a "lock and
key" puzzle (rather than a crossword) overlaid on a spatial graph where
the user avatar is another object able to move around the graph, pick
up keys and use them on lock. "Keys" and "locks" are an abstract
description here; it will often be nonobvious what is a key, what is
a lock, or how the key is to be applied to the lock.

In my mind the world model is best thought of as a relational database
with a set of contraints. "Rooms" are a table, the nodes between rooms
("east of" / "west of") are another table. The objects in rooms might
be another table.

Then there are actions, which have a certain grammar (e.g. typical
VO, "take toaster" thing) and then on top of that grammar an action
semantics which ties into the world logic. You can't take toaster if
there is no toaster in your room. If there is a toaster, and there is
a toaster, the toaster moves into your inventory.

Instead of thinking of IF as just a kind of state function of
(State, Input) -> (State', Output) flow, we can break it into
a parser: (State, Raw Input) -> Canonical Input, an updater
(State, Canonical Input) -> State' | Error, and then a 
displayer: State' | Error -> Output. This breaking apart makes
clear that we might have different parsers (e.g. a simple VO
parser, an LLM parser) and different displayers. Indeed, the
modality could change.

# Technical Sketch

Part of what thinking of the world model as a relational database gives
us is that we can just use good old SQLITE as our storage engine and
get a save format out of the box.

Because I love Haskell, let's think of this as a Haskell DSL.
What that program needs to be able to do is

1. Define the ontology of its world in a way that gets mapped
   to SQLite table definitions + initial inserts.
2. Define the field of canonical input.
3. Define the state handler.
4. Define the input parser.
5. Define events (a representation of an action taking place)
6. Define the describer.

## A Generic Core

The `State` in the signatures above need not be a single Haskell value.
If SQLite is the authoritative world state, it is more natural to give
the game an abstract way to query and update the database. The engine can
then remain polymorphic over the particular types a game uses for its
commands, events, failures, and output.

The turn pipeline becomes:

```text
RawInput
  -> parse
  -> Command
  -> decide
  -> [Event]
  -> apply
  -> describe
  -> Output
```

Here `Command` is an interpreted intention, while `Event` is a fact that
the world rules have accepted. Separating deciding from applying makes it
possible to validate a command against the current world, record what
happened, and update the database as one transaction.

A first approximation of the core API might be:

```haskell
{-# LANGUAGE GADTs #-}
{-# LANGUAGE RankNTypes #-}

newtype RawInput = RawInput Text

data Decision rejection event
  = Rejected rejection
  | Accepted [event]

data TurnOutcome parseFailure rejection event
  = ParseFailed parseFailure
  | Handled (Decision rejection event)

data Game schema query transaction command event
          parseFailure rejection output =
  Game
    { ontology :: schema
    , parse     :: RawInput
                -> query (Either parseFailure command)
    , decide    :: command
                -> query (Decision rejection event)
    , apply     :: event
                -> transaction ()
    , describe  :: TurnOutcome parseFailure rejection event
                -> query output
    }
```

The storage implementation supplies the operations the generic engine
needs to install and run a game:

```haskell
data Store io query transaction schema =
  Store
    { install     :: schema -> io ()
    , atomically  :: forall a. transaction a -> io a
    , queryInside :: forall a. query a -> transaction a
    }
```

The higher-rank fields say that a store can execute a computation without
knowing or constraining its result type. Keeping `query` and `transaction`
distinct also gives us the option of ensuring that parsing, deciding, and
describing are read-only, while applying an event may change the world.

The engine consequently has no reason to require `Eq`, `Show`, `Read`,
`Generic`, or a serialization class for every game-defined type. A
constraint should be introduced only at the boundary which needs it:

* values stored in SQLite need a SQLite codec;
* events need a codec only if the event log is persisted;
* output needs a renderer appropriate to the frontend rather than a
  blanket `Show` instance.

Records of functions are useful here because parsers, describers, stores,
and test implementations can be exchanged as values. Associated type
families may later provide a less verbose type-level namespace for all the
types belonging to a particular game, but they need not be the primary
extension mechanism.

## A Typed Ontology

The common ontology DSL does have to know enough about a value to turn it
into SQLite DDL and initial rows. GADTs let us keep that evidence local to
the schema instead of imposing it on the rest of the game:

```haskell
data SqlType a where
  SqlInt      :: SqlType Int64
  SqlText     :: SqlType Text
  SqlBool     :: SqlType Bool
  SqlNullable :: SqlType a -> SqlType (Maybe a)

data Column row where
  Column
    :: Text
    -> SqlType field
    -> (row -> field)
    -> Column row

data Table row =
  Table
    { tableName :: Text
    , columns   :: [Column row]
    }

data SomeTable where
  SomeTable :: Table row -> [row] -> SomeTable

newtype Ontology = Ontology [SomeTable]
```

`SomeTable` existentially hides each table's row type, but the `Table`
inside it retains the information necessary to create the table and encode
its seed rows. An ontology can therefore contain unrelated, game-specific
row types without requiring the engine to define a universal `Room`,
`Object`, or `Entity` type.

A real version will also need keys, references, uniqueness and check
constraints, migrations, and probably an escape hatch for raw SQLite.
Deriving codecs with `Generic` or `DerivingVia` can be a convenience rather
than a requirement of the framework.

Typed identifiers are another small useful building block:

```haskell
newtype Id entity = Id Int64

data Room
data Object

type RoomId   = Id Room
type ObjectId = Id Object
```

This prevents accidentally using an object identifier where a room
identifier is expected while making no claims about the changing facts of
the world. Stable structural distinctions belong in Haskell's types;
facts such as whether a particular door is currently locked belong in the
database.


