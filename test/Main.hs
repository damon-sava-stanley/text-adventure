module Main (main) where

import TextAdventure (greeting)

main :: IO ()
main =
    if greeting == "Hello, world!"
        then pure ()
        else fail "unexpected greeting"
