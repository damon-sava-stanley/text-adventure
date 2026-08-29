module Main (main) where

import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Minimal (minimalGame)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.IO (hFlush, hPutStrLn, isEOF, stderr, stdout)
import TextAdventure

main :: IO ()
main = do
    arguments <- getArgs
    case arguments of
        [databasePath] -> runGame databasePath
        _ -> do
            hPutStrLn stderr "Usage: text-adventure-example-minimal DATABASE"
            exitFailure

runGame :: FilePath -> IO ()
runGame databasePath = do
    let store = sqliteStore (Text.pack databasePath)
    installGame store minimalGame
    TextIO.putStrLn (Text.pack "The Toaster awaits in the Kitchen. Type 'quit' to leave.")
    consoleLoop store

consoleLoop :: Store IO SqliteQuery SqliteTransaction Ontology -> IO ()
consoleLoop store = do
    putStr "> "
    hFlush stdout
    endOfInput <- isEOF
    if endOfInput
        then putStrLn ""
        else do
            rawInput <- TextIO.getLine
            if Text.toCaseFold (Text.strip rawInput) == Text.pack "quit"
                then TextIO.putStrLn (Text.pack "Goodbye.")
                else do
                    output <- runTurn store minimalGame (RawInput rawInput)
                    TextIO.putStrLn output
                    consoleLoop store
