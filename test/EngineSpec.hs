module EngineSpec (run) where

import Control.Monad.Trans.State.Strict (State, gets, modify', runState)
import Data.Text (Text)
import Data.Text qualified as Text
import TextAdventure

run :: IO ()
run = successfulTurnRunsTheCompletePipeline

successfulTurnRunsTheCompletePipeline :: IO ()
successfulTurnRunsTheCompletePipeline = do
    let input = RawInput (Text.pack "take toaster")
        (observedAppliedState, finalState) = runState (runTurn engineStore engineGame input) initialState

    assert "a successful turn describes post-application state" observedAppliedState
    assert
        "a successful turn runs the complete pipeline in order"
        (steps finalState == [Parsed, Decided, Applied, Described])

data Step = Parsed | Decided | Applied | Described
    deriving (Eq, Show)

data EngineState = EngineState
    { applied :: Bool
    , steps :: [Step]
    }

initialState :: EngineState
initialState = EngineState{applied = False, steps = []}

engineStore :: Store (State EngineState) (State EngineState) (State EngineState) ()
engineStore =
    Store
        { install = const (pure ())
        , atomically = id
        , queryInside = id
        }

engineGame :: Game () (State EngineState) (State EngineState) Text Text Text Text Bool
engineGame =
    Game
        { ontology = ()
        , parse = \_ -> record Parsed >> pure (Right (Text.pack "take toaster"))
        , decide = \_ -> record Decided >> pure (Accepted [Text.pack "toaster taken"])
        , apply = \_ -> record Applied >> modify' (\state -> state{applied = True})
        , describe = \_ -> do
            wasApplied <- gets applied
            record Described
            pure wasApplied
        }

record :: Step -> State EngineState ()
record step = modify' (\state -> state{steps = steps state ++ [step]})

assert :: String -> Bool -> IO ()
assert _ True = pure ()
assert message False = fail message
