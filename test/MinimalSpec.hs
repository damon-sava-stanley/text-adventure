module MinimalSpec (run) where

import Control.Exception (Exception, throwIO, try)
import Control.Monad.IO.Class (liftIO)
import Data.Text (Text)
import Data.Text qualified as Text
import Minimal (minimalGame)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import TextAdventure

run :: IO ()
run = do
    inMemoryTurnsCarryState
    acceptedRejectedAndParseFailedTurnsAreDescribed
    carriedStateSurvivesReopeningAndReinstallation
    descriptionFailureRollsBackTheTurn

inMemoryTurnsCarryState :: IO ()
inMemoryTurnsCarryState =
    withSqliteStore (Text.pack ":memory:") $ \store -> do
        installGame store minimalGame

        taken <- runTurn store minimalGame (input "take toaster")
        alreadyCarried <- runTurn store minimalGame (input "take toaster")

        assert "the first in-memory turn updates the world" (taken == Text.pack "You take the Toaster.")
        assert
            "a later in-memory turn sees the updated world"
            (alreadyCarried == Text.pack "You are already carrying the Toaster.")

acceptedRejectedAndParseFailedTurnsAreDescribed :: IO ()
acceptedRejectedAndParseFailedTurnsAreDescribed =
    withSystemTempDirectory "text-adventure-minimal" $ \directory -> do
        let store = sqliteStore (Text.pack (directory </> "world.sqlite"))
        installGame store minimalGame
        installGame store minimalGame

        taken <- runTurn store minimalGame (input "take toaster")
        alreadyCarried <- runTurn store minimalGame (input "take toaster")
        absent <- runTurn store minimalGame (input "take kettle")
        notUnderstood <- runTurn store minimalGame (input "dance")

        assert "taking the toaster succeeds" (taken == Text.pack "You take the Toaster.")
        assert
            "taking the toaster twice is rejected"
            (alreadyCarried == Text.pack "You are already carrying the Toaster.")
        assert "taking an absent thing is rejected" (absent == Text.pack "There is no Kettle here.")
        assert "unrelated input is not understood" (notUnderstood == Text.pack "I don't understand that.")

carriedStateSurvivesReopeningAndReinstallation :: IO ()
carriedStateSurvivesReopeningAndReinstallation =
    withSystemTempDirectory "text-adventure-minimal" $ \directory -> do
        let database = Text.pack (directory </> "world.sqlite")
            firstStore = sqliteStore database
        installGame firstStore minimalGame
        taken <- runTurn firstStore minimalGame (input "take toaster")

        let reopenedStore = sqliteStore database
        installGame reopenedStore minimalGame
        afterRestart <- runTurn reopenedStore minimalGame (input "take toaster")

        assert "the first process takes the toaster" (taken == Text.pack "You take the Toaster.")
        assert
            "reopening and reinstalling retains carried state"
            (afterRestart == Text.pack "You are already carrying the Toaster.")

descriptionFailureRollsBackTheTurn :: IO ()
descriptionFailureRollsBackTheTurn =
    withSystemTempDirectory "text-adventure-minimal" $ \directory -> do
        let store = sqliteStore (Text.pack (directory </> "world.sqlite"))
            failingGame = minimalGame{describe = const (liftIO (failWith ExpectedFailure))}
        installGame store minimalGame

        failed <- try (runTurn store failingGame (input "take toaster")) :: IO (Either ExpectedFailure Text)
        afterFailure <- runTurn store minimalGame (input "take toaster")

        assert "description exceptions escape the turn" (isLeft failed)
        assert
            "description exceptions roll back accepted events"
            (afterFailure == Text.pack "You take the Toaster.")

input :: String -> RawInput
input = RawInput . Text.pack

data ExpectedFailure = ExpectedFailure
    deriving (Show)

instance Exception ExpectedFailure

failWith :: (Exception exception) => exception -> IO value
failWith = throwIO

isLeft :: Either left right -> Bool
isLeft (Left _) = True
isLeft (Right _) = False

assert :: String -> Bool -> IO ()
assert _ True = pure ()
assert message False = fail message
