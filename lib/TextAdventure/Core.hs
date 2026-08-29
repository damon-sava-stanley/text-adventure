module TextAdventure.Core (
    RawInput (..),
    Decision (..),
    TurnOutcome (..),
    Game (..),
    Store (..),
    installGame,
    runTurn,
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

-- | Install a game's schema and seed data in a store.
installGame :: Store io query transaction schema -> Game schema query transaction command event parseFailure rejection output -> io ()
installGame store game = install store (ontology game)

{- | Run one complete turn in a single store transaction.

Accepted events are applied before the outcome is described, so descriptions
observe the resulting world state. If any operation raises an exception, the
store's transaction runner determines the rollback behavior.
-}
runTurn ::
    (Monad transaction) =>
    Store io query transaction schema ->
    Game schema query transaction command event parseFailure rejection output ->
    RawInput ->
    io output
runTurn store game rawInput =
    atomically store $ do
        parsed <- queryInside store (parse game rawInput)
        case parsed of
            Left parseFailure ->
                queryInside store (describe game (ParseFailed parseFailure))
            Right command -> do
                decision <- queryInside store (decide game command)
                case decision of
                    Rejected _ -> pure ()
                    Accepted events -> mapM_ (apply game) events
                queryInside store (describe game (Handled command decision))
