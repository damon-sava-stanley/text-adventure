{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module PersistentStoreSpec (run) where

import Control.Exception (Exception, SomeException, throwIO, try)
import Control.Monad.IO.Class (liftIO)
import Data.Maybe (isJust, isNothing)
import Data.Text (Text)
import Data.Text qualified as Text
import Database.Persist
import Database.Persist.Sql (toSqlKey)
import Database.Persist.TH
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import TextAdventure

share
    [mkPersist sqlSettings, mkEntityDefList "worldModels"]
    [persistLowerCase|
Room
    name Text
    UniqueRoomName name
    deriving Eq Show
Thing
    name Text
    room RoomId Maybe
    portable Bool
    UniqueThingName name
    deriving Eq Show
|]

run :: IO ()
run = do
    freshInstallationCreatesSchemaAndSeeds
    installationCanRepeatWithoutDuplicateSeeds
    foreignKeysAreEnforced
    committedDataSurvivesReopening
    failedTransactionsRollBack

freshInstallationCreatesSchemaAndSeeds :: IO ()
freshInstallationCreatesSchemaAndSeeds =
    withSystemTempDirectory "text-adventure" $ \directory -> do
        let store = sqliteStore (Text.pack (directory </> "world.sqlite"))
        install store worldOntology

        kitchen <- atomically store $ queryInside store $ getBy (UniqueRoomName (Text.pack "Kitchen"))
        toaster <- atomically store $ queryInside store $ getBy (UniqueThingName (Text.pack "Toaster"))

        assert "fresh installation creates and seeds rooms" ((entityVal <$> kitchen) == Just (Room (Text.pack "Kitchen")))
        assert
            "fresh installation creates and seeds related things"
            ( case (kitchen, toaster) of
                (Just room, Just thing) ->
                    thingRoom (entityVal thing) == Just (entityKey room)
                        && thingPortable (entityVal thing)
                _ -> False
            )

installationCanRepeatWithoutDuplicateSeeds :: IO ()
installationCanRepeatWithoutDuplicateSeeds =
    withSystemTempDirectory "text-adventure" $ \directory -> do
        let store = sqliteStore (Text.pack (directory </> "world.sqlite"))
        install store worldOntology
        install store worldOntology

        roomCount <- atomically store $ queryInside store $ count ([] :: [Filter Room])
        thingCount <- atomically store $ queryInside store $ count ([] :: [Filter Thing])

        assert "installing twice does not duplicate room seeds" (roomCount == 1)
        assert "installing twice does not duplicate thing seeds" (thingCount == 1)

foreignKeysAreEnforced :: IO ()
foreignKeysAreEnforced =
    withSystemTempDirectory "text-adventure" $ \directory -> do
        let store = sqliteStore (Text.pack (directory </> "world.sqlite"))
        install store worldOntology

        result <-
            try
                (atomically store $ insert_ (Thing (Text.pack "Ghost") (Just (toSqlKey 999999)) True)) ::
                IO (Either SomeException ())

        assert "SQLite rejects references to missing entities" (isLeft result)

committedDataSurvivesReopening :: IO ()
committedDataSurvivesReopening =
    withSystemTempDirectory "text-adventure" $ \directory -> do
        let database = Text.pack (directory </> "world.sqlite")
            firstStore = sqliteStore database
        install firstStore worldOntology
        atomically firstStore $ insert_ (Room (Text.pack "Library"))

        let reopenedStore = sqliteStore database
        library <- atomically reopenedStore $ queryInside reopenedStore $ getBy (UniqueRoomName (Text.pack "Library"))

        assert "committed rows survive reopening the database" (isJust library)

failedTransactionsRollBack :: IO ()
failedTransactionsRollBack =
    withSystemTempDirectory "text-adventure" $ \directory -> do
        let store = sqliteStore (Text.pack (directory </> "world.sqlite"))
        install store worldOntology

        result <-
            try
                ( atomically store $ do
                    insert_ (Room (Text.pack "Observatory"))
                    liftIO $ throwIO ExpectedFailure
                ) ::
                IO (Either ExpectedFailure ())
        observatory <- atomically store $ queryInside store $ getBy (UniqueRoomName (Text.pack "Observatory"))

        assert "the transaction propagates the triggering exception" (isLeft result)
        assert "writes before an exception are rolled back" (isNothing observatory)

worldOntology :: Ontology
worldOntology =
    Ontology
        { ontologyMigration = migrateModels worldModels
        , ontologySeed = do
            kitchen <- getBy (UniqueRoomName (Text.pack "Kitchen"))
            roomId <- maybe (insert (Room (Text.pack "Kitchen"))) (pure . entityKey) kitchen
            _ <- insertUnique (Thing (Text.pack "Toaster") (Just roomId) True)
            pure ()
        }

data ExpectedFailure = ExpectedFailure
    deriving stock (Show)

instance Exception ExpectedFailure

isLeft :: Either left right -> Bool
isLeft (Left _) = True
isLeft (Right _) = False

assert :: String -> Bool -> IO ()
assert _ True = pure ()
assert message False = fail message
