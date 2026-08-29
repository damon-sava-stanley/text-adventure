{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Minimal (minimalGame) where

import Data.Maybe (isNothing)
import Data.Text (Text)
import Data.Text qualified as Text
import Database.Persist
import Database.Persist.TH
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

minimalGame :: Game Ontology SqliteQuery SqliteTransaction Command Event ParseFailure Rejection Text
minimalGame =
    Game
        { ontology = minimalOntology
        , parse = parseCommand
        , decide = decideCommand
        , apply = applyEvent
        , describe = describeOutcome
        }

newtype Command = Take Text

newtype Event = ThingTaken ThingId

data ParseFailure = NotUnderstood

data Rejection
    = AlreadyCarried
    | NotPresent
    | NotPortable

minimalOntology :: Ontology
minimalOntology =
    Ontology
        { ontologyMigration = migrateModels worldModels
        , ontologySeed = do
            kitchen <- getBy (UniqueRoomName (Text.pack "Kitchen"))
            kitchenId <- maybe (insert (Room (Text.pack "Kitchen"))) (pure . entityKey) kitchen
            _ <- insertUnique (Thing (Text.pack "Toaster") (Just kitchenId) True)
            pure ()
        }

parseCommand :: RawInput -> SqliteQuery (Either ParseFailure Command)
parseCommand (RawInput rawInput) =
    pure $ case Text.words rawInput of
        verb : noun
            | Text.toCaseFold verb == Text.pack "take" && not (null noun) ->
                Right (Take (canonicalName (Text.unwords noun)))
        _ -> Left NotUnderstood

canonicalName :: Text -> Text
canonicalName = Text.toTitle . Text.toLower

decideCommand :: Command -> SqliteQuery (Decision Rejection Event)
decideCommand (Take name) = do
    thing <- getBy (UniqueThingName name)
    pure $ case thing of
        Nothing -> Rejected NotPresent
        Just entity
            | isNothing (thingRoom (entityVal entity)) -> Rejected AlreadyCarried
            | not (thingPortable (entityVal entity)) -> Rejected NotPortable
            | otherwise -> Accepted [ThingTaken (entityKey entity)]

applyEvent :: Event -> SqliteTransaction ()
applyEvent (ThingTaken thingId) = update thingId [ThingRoom =. Nothing]

describeOutcome :: TurnOutcome ParseFailure Command Rejection Event -> SqliteQuery Text
describeOutcome (ParseFailed NotUnderstood) = pure (Text.pack "I don't understand that.")
describeOutcome (Handled (Take name) (Rejected rejection)) =
    pure $ case rejection of
        AlreadyCarried -> Text.concat [Text.pack "You are already carrying the ", name, Text.pack "."]
        NotPresent -> Text.concat [Text.pack "There is no ", name, Text.pack " here."]
        NotPortable -> Text.concat [Text.pack "The ", name, Text.pack " cannot be carried."]
describeOutcome (Handled (Take name) (Accepted [ThingTaken thingId])) = do
    thing <- get thingId
    pure $
        if maybe False (isNothing . thingRoom) thing
            then Text.concat [Text.pack "You take the ", name, Text.pack "."]
            else Text.concat [Text.pack "The ", name, Text.pack " remains where it was."]
describeOutcome (Handled _ (Accepted _)) = pure (Text.pack "Nothing happens.")
