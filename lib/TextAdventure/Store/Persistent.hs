module TextAdventure.Store.Persistent (
    SqliteQuery,
    SqliteTransaction,
    sqliteStore,
)
where

import Control.Monad.Logger (NoLoggingT)
import Control.Monad.Trans.Reader (ReaderT)
import Control.Monad.Trans.Resource (ResourceT)
import Data.Text (Text)
import Database.Persist.Sql (
    SqlReadBackend,
    SqlWriteBackend,
    readToWrite,
    runMigration,
    writeToUnknown,
 )
import Database.Persist.Sqlite (runSqlite)
import TextAdventure.Core (Store (..))
import TextAdventure.Ontology (Ontology (..))

type SqliteBase = NoLoggingT (ResourceT IO)

-- | Read-only Persistent actions accepted by a SQLite-backed game.
type SqliteQuery = ReaderT SqlReadBackend SqliteBase

-- | Read/write Persistent actions executed atomically by the SQLite store.
type SqliteTransaction = ReaderT SqlWriteBackend SqliteBase

{- | Open the SQLite database at the supplied path for each store operation.

Persistent enables write-ahead logging and foreign-key checks on every
connection. Its runner commits successful actions and rolls them back when
an exception escapes.
-}
sqliteStore :: Text -> Store IO SqliteQuery SqliteTransaction Ontology
sqliteStore database =
    Store
        { install = installOntology database
        , atomically = runSqlite database . writeToUnknown
        , queryInside = readToWrite
        }

installOntology :: Text -> Ontology -> IO ()
installOntology database ontology =
    runSqlite database $ do
        runMigration (ontologyMigration ontology)
        writeToUnknown (ontologySeed ontology)
