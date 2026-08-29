module TextAdventure.Ontology (
    Ontology (..),
    Key,
)
where

import Control.Monad.IO.Class (MonadIO)
import Control.Monad.Trans.Reader (ReaderT)
import Database.Persist (Key)
import Database.Persist.Sql (Migration, SqlWriteBackend)

{- | The database setup supplied by a game.

Persistent generates the migration from the game's entity definitions. The
seed action runs in the same transaction and should be idempotent so that an
existing world can be installed again safely.
-}
data Ontology = Ontology
    { ontologyMigration :: Migration
    , ontologySeed :: forall m. (MonadIO m) => ReaderT SqlWriteBackend m ()
    }
