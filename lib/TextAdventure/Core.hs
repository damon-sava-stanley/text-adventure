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

data TurnOutcome parseFailure rejection event
    = ParseFailed parseFailure
    | Handled (Decision rejection event)

data Game schema query transaction command event parseFailure rejection output = Game
    { ontology :: schema
    , parse :: RawInput -> query (Either parseFailure command)
    , decide :: command -> query (Decision rejection event)
    , apply :: event -> transaction ()
    , describe :: TurnOutcome parseFailure rejection event -> query output
    }

data Store io query transaction schema = Store
    { install :: schema -> io ()
    , atomically :: forall a. transaction a -> io a
    , queryInside :: forall a. query a -> transaction a
    }
