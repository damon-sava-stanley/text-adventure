module Main (main) where

import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import TextAdventure (RawInput (..))

main :: IO ()
main =
    let RawInput input = RawInput (Text.pack "Text Adventure")
     in Text.IO.putStrLn input
