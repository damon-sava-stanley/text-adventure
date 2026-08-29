module Main (main) where

import Data.Functor.Identity (Identity (..))
import Data.Text (Text)
import Data.Text qualified as Text
import PersistentStoreSpec qualified
import TextAdventure

main :: IO ()
main = do
    coreTypesCanBeConstructed
    handledZeroEventCommandsRetainIntent
    PersistentStoreSpec.run

data Command
    = Look
    | Wait

handledZeroEventCommandsRetainIntent :: IO ()
handledZeroEventCommandsRetainIntent = do
    let look = Handled Look (Accepted [])
        wait = Handled Wait (Accepted [])
    assert
        "handled zero-event commands can be described differently"
        ( runIdentity (describe commandAwareGame look) == Text.pack "You look around."
            && runIdentity (describe commandAwareGame wait) == Text.pack "Time passes."
        )

commandAwareGame :: Game () Identity Identity Command Text Text Text Text
commandAwareGame =
    Game
        { ontology = ()
        , parse = const (pure (Right Look))
        , decide = const (pure (Accepted []))
        , apply = const (pure ())
        , describe = \outcome ->
            pure $ case outcome of
                Handled Look (Accepted []) -> Text.pack "You look around."
                Handled Wait (Accepted []) -> Text.pack "Time passes."
                _ -> Text.pack "Something else happened."
        }

coreTypesCanBeConstructed :: IO ()
coreTypesCanBeConstructed = do
    let input = RawInput (Text.pack "take toaster")
        accepted = Accepted [Text.pack "toaster taken"]
        rejected = Rejected (Text.pack "no toaster here")
        parsed = ParseFailed (Text.pack "not understood")
        acceptedOutcome = Handled (Text.pack "take toaster") accepted
        rejectedOutcome = Handled (Text.pack "take toaster") rejected
        game = exampleGame
        store = identityStore
    assert "raw input retains its text" (rawInputText input == Text.pack "take toaster")
    assert "accepted decisions retain events" (eventCount accepted == 1)
    assert "rejected decisions can be handled" (isRejected rejected)
    assert
        "accepted and rejected outcomes retain their handled command"
        ( handledCommand acceptedOutcome == Just (Text.pack "take toaster")
            && handledCommand rejectedOutcome == Just (Text.pack "take toaster")
        )
    assert
        "parse failures are distinct and have no command"
        (isParseFailure parsed && not (hasCommand parsed) && not (isParseFailure acceptedOutcome))
    assert "game parsers can be consumed" (runIdentity (parse game input) == Right (Text.pack "take toaster"))
    assert "stores execute polymorphic transactions" (runIdentity (atomically store (Identity 42)) == (42 :: Int))

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

rawInputText :: RawInput -> Text
rawInputText (RawInput input) = input

eventCount :: Decision rejection event -> Int
eventCount (Accepted events) = length events
eventCount (Rejected _) = 0

isRejected :: Decision rejection event -> Bool
isRejected (Rejected _) = True
isRejected (Accepted _) = False

isParseFailure :: TurnOutcome parseFailure command rejection event -> Bool
isParseFailure (ParseFailed _) = True
isParseFailure (Handled _ _) = False

handledCommand :: TurnOutcome parseFailure command rejection event -> Maybe command
handledCommand (ParseFailed _) = Nothing
handledCommand (Handled command _) = Just command

hasCommand :: TurnOutcome parseFailure command rejection event -> Bool
hasCommand (ParseFailed _) = False
hasCommand (Handled _ _) = True

assert :: String -> Bool -> IO ()
assert _ True = pure ()
assert message False = fail message
