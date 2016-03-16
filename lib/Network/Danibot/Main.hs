{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE OverloadedStrings #-}

module Network.Danibot.Main (
        mainWith
    ) where

import Data.Function ((&))
import qualified Data.ByteString as Bytes
import Data.Text (Text)
import Data.String
import Data.Aeson (FromJSON,eitherDecodeStrict')

import Control.Monad
import Control.Monad.IO.Class
import Control.Monad.Trans.Except
import qualified Control.Foldl as Foldl

import Control.Concurrent.Conceit

import System.Environment (lookupEnv)
import GHC.Generics

import Network.Danibot.Slack 
import Network.Danibot.Slack.Types (introUrl,introChat)
import Network.Danibot.Slack.API (startRTM)
import Network.Danibot.Slack.RTM (fromWSSURI,loopRTM)

slack_api_token_env_var :: String
slack_api_token_env_var = "DANIBOT_SLACK_API_TOKEN"

slack_api_token_env_var_missing :: String 
slack_api_token_env_var_missing = 
    "Environment variable " ++ 
    slack_api_token_env_var ++
    " not found."

--data Conf = Conf
--    {
--        slack_api_token :: Text
--    } deriving (Generic,Show)
--
--instance FromJSON Conf
--
--data Args = Args
--    {
--        confPath :: String
--    } deriving (Show)
--
--parserInfo :: Options.ParserInfo Args
--parserInfo = 
--    info (helper <*> parser) infoMod
--  where
--    parser = 
--        Args <$> strArgument (help "configuration file" <> metavar "CONF")
--    infoMod = 
--        fullDesc <> header "program desc" 

exceptMain :: IO (Either String (Text -> IO Text)) -> ExceptT String IO ()
exceptMain handlerio = do
    slack_api_token <- ExceptT (fmap (maybe (Left slack_api_token_env_var_missing) 
                                            (Right . fromString))
                                     (lookupEnv "DANIBOT_SLACK_API_TOKEN"))
    handler <- ExceptT handlerio
    intro <- ExceptT (startRTM slack_api_token)
    liftIO (print intro)
    endpoint <- fromWSSURI (introUrl intro)
              & either throwE pure
    (workChan,workerAction) <- liftIO (worker handler)
    (chatState,source) <- liftIO (makeChatState (introChat intro))
    let theEventFold = eventFold workChan chatState
    liftIO (_runConceit (_Conceit (loopRTM theEventFold source endpoint) 
                         *> _Conceit workerAction))

mainWith :: IO (Either String (Text -> IO Text)) -> IO ()
mainWith handlerio = do
    final <- runExceptT (exceptMain handlerio)
    case final of
        Left err -> print err
        Right () -> pure ()

