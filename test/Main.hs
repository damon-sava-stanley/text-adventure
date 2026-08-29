module Main (main) where

import Data.Functor.Identity (Identity (..))
import Data.Text (Text)
import Data.Text qualified as Text
import TextAdventure

main :: IO ()
main = do
    coreTypesCanBeConstructed
    ontologyTypesCanBeConstructed

coreTypesCanBeConstructed :: IO ()
coreTypesCanBeConstructed = do
    let input = RawInput (Text.pack "take toaster")
        accepted = Accepted [Text.pack "toaster taken"]
        rejected = Rejected (Text.pack "no toaster here")
        parsed = ParseFailed (Text.pack "not understood")
        handled = Handled accepted
        game = exampleGame
        store = identityStore
    assert "raw input retains its text" (rawInputText input == Text.pack "take toaster")
    assert "accepted decisions retain events" (eventCount accepted == 1)
    assert "rejected decisions can be handled" (isRejected rejected)
    assert "parse failures are distinct from handled turns" (isParseFailure parsed && not (isParseFailure handled))
    assert "game parsers can be consumed" (runIdentity (parse game input) == Right (Text.pack "take toaster"))
    assert "stores execute polymorphic transactions" (runIdentity (atomically store (Identity 42)) == (42 :: Int))

ontologyTypesCanBeConstructed :: IO ()
ontologyTypesCanBeConstructed = do
    let Ontology tables = exampleOntology
    assert "an ontology combines unrelated row types" (length tables == 2)
    assert "existential tables retain their schema and seeds" (all hasOneSeed tables)
    assert "SQL types retain field evidence" (sqlTypeName (SqlNullable SqlText) == "nullable text")

exampleGame :: Game () Identity Identity Text Text Text Text Text
exampleGame =
    Game
        { ontology = ()
        , parse = \(RawInput input) -> pure (Right input)
        , decide = \command -> pure (Accepted [command])
        , apply = const (pure ())
        , describe = const (pure (Text.pack "described"))
        }

identityStore :: Store Identity Identity Identity ()
identityStore =
    Store
        { install = const (pure ())
        , atomically = id
        , queryInside = id
        }

data Room

data Object

data RoomRow = RoomRow (Id Room) Text

data ObjectRow = ObjectRow (Id Object) Bool

exampleOntology :: Ontology
exampleOntology =
    Ontology
        [ SomeTable
            ( Table
                { tableName = Text.pack "rooms"
                , columns =
                    [ Column (Text.pack "id") SqlInt (\(RoomRow (Id identifier) _) -> identifier)
                    , Column (Text.pack "name") SqlText (\(RoomRow _ name) -> name)
                    ]
                }
            )
            [RoomRow (Id 1) (Text.pack "Kitchen")]
        , SomeTable
            ( Table
                { tableName = Text.pack "objects"
                , columns =
                    [ Column (Text.pack "id") SqlInt (\(ObjectRow (Id identifier) _) -> identifier)
                    , Column (Text.pack "portable") SqlBool (\(ObjectRow _ portable) -> portable)
                    ]
                }
            )
            [ObjectRow (Id 1) True]
        ]

hasOneSeed :: SomeTable -> Bool
hasOneSeed (SomeTable table seeds) =
    not (Text.null (tableName table))
        && not (null (columns table))
        && length seeds == 1

sqlTypeName :: SqlType a -> String
sqlTypeName SqlInt = "integer"
sqlTypeName SqlText = "text"
sqlTypeName SqlBool = "boolean"
sqlTypeName (SqlNullable sqlType) = "nullable " <> sqlTypeName sqlType

rawInputText :: RawInput -> Text
rawInputText (RawInput input) = input

eventCount :: Decision rejection event -> Int
eventCount (Accepted events) = length events
eventCount (Rejected _) = 0

isRejected :: Decision rejection event -> Bool
isRejected (Rejected _) = True
isRejected (Accepted _) = False

isParseFailure :: TurnOutcome parseFailure rejection event -> Bool
isParseFailure (ParseFailed _) = True
isParseFailure (Handled _) = False

assert :: String -> Bool -> IO ()
assert _ True = pure ()
assert message False = fail message
