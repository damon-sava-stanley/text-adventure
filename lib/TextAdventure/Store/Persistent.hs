module TextAdventure.Store.Persistent (
    SqliteQuery,
    SqliteTransaction,
    sqliteStore,
    withSqliteStore,
)
where

import Control.Concurrent.MVar (MVar, newMVar, withMVar)
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Logger (NoLoggingT, runNoLoggingT)
import Control.Monad.Trans.Reader (ReaderT)
import Control.Monad.Trans.Resource (ResourceT)
import Data.Text (Text)
import Database.Persist.Sql (
    SqlBackend,
    SqlReadBackend,
    SqlWriteBackend,
    readToWrite,
    runMigration,
    runSqlPersistM,
    writeToUnknown,
 )
import Database.Persist.Sqlite (runSqlite, withSqliteConn)
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

{- | Run an action with a SQLite store backed by one open connection.

All store operations are serialized, so the store may safely be called from
multiple threads but only one operation runs at a time. Successful operations
commit and exceptions roll them back. The connection closes when the callback
returns or throws.

Unlike 'sqliteStore', this supports the literal @:memory:@ database because the
same connection is retained across installation and transactions.
-}
withSqliteStore ::
    Text ->
    (Store IO SqliteQuery SqliteTransaction Ontology -> IO a) ->
    IO a
withSqliteStore database action =
    runNoLoggingT $
        withSqliteConn database $ \backend ->
            liftIO $ do
                operationLock <- newMVar ()
                action (connectedSqliteStore operationLock backend)

connectedSqliteStore ::
    MVar () ->
    SqlBackend ->
    Store IO SqliteQuery SqliteTransaction Ontology
connectedSqliteStore operationLock backend =
    Store
        { install = serialized . installOntologyOn backend
        , atomically = serialized . (`runSqlPersistM` backend) . writeToUnknown
        , queryInside = readToWrite
        }
  where
    serialized :: IO a -> IO a
    serialized operation = withMVar operationLock (const operation)

installOntology :: Text -> Ontology -> IO ()
installOntology database ontology =
    runSqlite database $ do
        runMigration (ontologyMigration ontology)
        writeToUnknown (ontologySeed ontology)

installOntologyOn :: SqlBackend -> Ontology -> IO ()
installOntologyOn backend ontology =
    runSqlPersistM
        ( do
            runMigration (ontologyMigration ontology)
            writeToUnknown (ontologySeed ontology)
        )
        backend
