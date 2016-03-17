module Main (
        main
    ) where

import Network.Danibot (dumbHandler,isUpHandler)
import Network.Danibot.Main (mainWith)

import Options.Applicative 
import qualified Options.Applicative as Options

main :: IO ()
main = mainWith (pure (Right isUpHandler))


