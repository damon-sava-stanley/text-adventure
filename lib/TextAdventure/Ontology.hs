module TextAdventure.Ontology (
    SqlType (..),
    Column (..),
    Table (..),
    SomeTable (..),
    Ontology (..),
    Id (..),
)
where

import Data.Int (Int64)
import Data.Text (Text)

data SqlType a where
    SqlInt :: SqlType Int64
    SqlText :: SqlType Text
    SqlBool :: SqlType Bool
    SqlNullable :: SqlType a -> SqlType (Maybe a)

data Column row where
    Column :: Text -> SqlType field -> (row -> field) -> Column row

data Table row = Table
    { tableName :: Text
    , columns :: [Column row]
    }

data SomeTable where
    SomeTable :: Table row -> [row] -> SomeTable

newtype Ontology = Ontology [SomeTable]

newtype Id entity = Id Int64
