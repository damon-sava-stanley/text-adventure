module TextAdventure.Core (
    RawInput (..),
    Decision (..),
    TurnOutcome (..),
    Game (..),
    Store (..),
)
where

import Data.Text (Text)

newtype RawInput = RawInput Text

data Decision rejection event
    = Rejected rejection
    | Accepted [event]

{- | The result of interpreting one raw input.

Parsed commands are retained for both accepted and rejected decisions so a
describer can respond to the interpreted player intent. Parse failures have
no canonical command to retain.
-}
data TurnOutcome parseFailure command rejection event
    = ParseFailed parseFailure
    | Handled command (Decision rejection event)

data Game schema query transaction command event parseFailure rejection output = Game
    { ontology :: schema
    , parse :: RawInput -> query (Either parseFailure command)
    , decide :: command -> query (Decision rejection event)
    , apply :: event -> transaction ()
    , describe :: TurnOutcome parseFailure command rejection event -> query output
    }

data Store io query transaction schema = Store
    { install :: schema -> io ()
    , atomically :: forall a. transaction a -> io a
    , queryInside :: forall a. query a -> transaction a
    }
