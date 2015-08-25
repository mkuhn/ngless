{- Copyright 2013-2015 NGLess Authors
 - License: MIT
 -}
{-# LANGUAGE RecordWildCards #-}
module Configuration
    ( NGLessConfiguration(..)
    , InstallMode(..)
    , nglConfiguration
    , nglessDataBaseURL
    , initConfiguration
    , setupTestConfiguration
    , globalDataDirectory
    , userDataDirectory
    , samtoolsBin
    , bwaBin
    , outputDirectory
    , temporaryFileDirectory
    , traceFlag
    , versionStr
    ) where

import Control.Monad
import Control.Monad.IO.Class (liftIO)
import Control.Applicative ((<$>))
import System.Environment (getExecutablePath)
import System.Directory
import System.FilePath.Posix
import qualified Data.ByteString as B
import Data.Maybe
import System.IO.Unsafe (unsafePerformIO)
import Data.IORef

import NGLess
import Dependencies.Embedded
import CmdArgs

data InstallMode = User | Root deriving (Eq, Show)

data NGLessConfiguration = NGLessConfiguration
    { nConfDownloadBaseURL :: FilePath
    , nConfGlobalDataDirectory :: FilePath
    , nConfUserDirectory :: FilePath
    , nConfTemporaryDirectory :: FilePath
    , nConfKeepTemporaryFiles :: Bool
    , nConfTrace :: Bool
    , nConfOutputDirectory :: FilePath
    , nConfColor :: ColorSetting
    , nConfPrintHeader :: Bool
    } deriving (Eq, Show)


guessConfiguration :: IO NGLessConfiguration
guessConfiguration = do
    tmp <- getTemporaryDirectory
    nglessBinDirectory <- takeDirectory <$> getExecutablePath
    defaultUserNglessDirectory <- (</> ".ngless") <$> getHomeDirectory
    return NGLessConfiguration
        { nConfDownloadBaseURL = "http://127.0.0.1/"
        , nConfGlobalDataDirectory = nglessBinDirectory </> "../share/ngless/data"
        , nConfUserDirectory = defaultUserNglessDirectory
        , nConfTemporaryDirectory = tmp
        , nConfKeepTemporaryFiles = False
        , nConfTrace = False
        , nConfOutputDirectory = ""
        , nConfColor = AutoColor
        , nConfPrintHeader = True
        }


updateConfiguration :: NGLessConfiguration -> FilePath -> IO NGLessConfiguration
updateConfiguration config cfile = error "Reading a config file is not implemented yet"

setupTestConfiguration :: IO ()
setupTestConfiguration = do
    config <- guessConfiguration
    writeIORef nglConfigurationRef $ config { nConfTemporaryDirectory = "testing_tmp_dir", nConfKeepTemporaryFiles = True }

initConfiguration :: NGLess -> IO ()
initConfiguration opts = do
    config <- guessConfiguration
    config' <- foldM updateConfiguration config (case opts of
        DefaultMode{config_files = Just cs} -> cs
        _ -> [])
    writeIORef nglConfigurationRef (updateConfigurationOpts opts config')

updateConfigurationOpts opts@DefaultMode{..} config =
    let trace = fromMaybe
                    (nConfTrace config)
                    trace_flag
        ktemp = fromMaybe
                    (nConfKeepTemporaryFiles config)
                    keep_temporary_files
        tmpdir = fromMaybe
                    (nConfTemporaryDirectory config)
                    temporary_directory
        odir = case (output_directory, input) of
            (Nothing, "-") -> "STDIN.output_ngless"
            (Nothing, _) -> input ++ ".output_ngless"
            (Just odir', _) -> odir'
    in config
            { nConfTrace = trace
            , nConfKeepTemporaryFiles = ktemp
            , nConfOutputDirectory = odir
            , nConfTemporaryDirectory = tmpdir
            , nConfPrintHeader = (nConfPrintHeader config) && not no_header
            }

updateConfigurationOpts _ config = config

nglConfigurationRef :: IORef NGLessConfiguration
{-# NOINLINE nglConfigurationRef #-}
nglConfigurationRef = unsafePerformIO (newIORef (error "not yet"))

nglConfiguration :: NGLessIO NGLessConfiguration
nglConfiguration = liftIO $ readIORef nglConfigurationRef

outputDirectory :: NGLessIO FilePath
outputDirectory = nConfOutputDirectory <$> nglConfiguration

temporaryFileDirectory :: NGLessIO FilePath
temporaryFileDirectory = nConfTemporaryDirectory <$> nglConfiguration

traceFlag :: NGLessIO Bool
traceFlag = nConfTrace <$> nglConfiguration

versionStr :: String
versionStr = "0.0.0"

nglessDataBaseURL :: NGLessIO FilePath
nglessDataBaseURL = nConfDownloadBaseURL <$> nglConfiguration
globalDataDirectory :: NGLessIO FilePath
globalDataDirectory = nConfGlobalDataDirectory <$> nglConfiguration

userNglessDirectory :: NGLessIO FilePath
userNglessDirectory = nConfUserDirectory <$> nglConfiguration

userDataDirectory :: NGLessIO FilePath
userDataDirectory = (</> "data") <$> userNglessDirectory

check_executable :: String -> FilePath -> IO FilePath
check_executable name bin = do
    exists <- doesFileExist bin
    unless exists
        (error $ concat [name, " binary not found!\n","Expected it at ", bin])
    is_executable <- executable <$> getPermissions bin
    unless is_executable
        (error $ concat [name, " binary found at ", bin, ".\nHowever, it is not an executable file!"])
    return bin

canExecute bin = do
    exists <- doesFileExist bin
    if exists
        then executable <$> getPermissions bin
        else return False


binPath :: InstallMode -> NGLessIO FilePath
binPath Root = do
    nglessBinDirectory <- takeDirectory <$> liftIO getExecutablePath
    return (nglessBinDirectory </> "../share/bin")
binPath User = (</> "bin") <$> userNglessDirectory

findBin :: FilePath -> NGLessIO (Maybe FilePath)
findBin fname = do
    rootPath <- (</> fname) <$> binPath Root
    rootex <- liftIO $ canExecute rootPath
    if rootex then
        return (Just rootPath)
    else do
        userpath <- (</> fname) <$> binPath User
        userex <- liftIO $ canExecute userpath
        return $ if userex
            then Just userpath
            else Nothing

writeBin :: FilePath -> B.ByteString -> NGLessIO FilePath
writeBin fname bindata = do
    userBinPath <- binPath User
    liftIO $ do
        createDirectoryIfMissing True userBinPath
        let fname' = userBinPath </> fname
        B.writeFile fname' bindata
        p <- getPermissions fname'
        setPermissions fname' (setOwnerExecutable True p)
        return fname'

findOrCreateBin :: FilePath -> B.ByteString -> NGLessIO FilePath
findOrCreateBin fname bindata = do
    path <- findBin fname
    maybe (writeBin fname bindata) return path

bwaBin :: NGLessIO FilePath
bwaBin = findOrCreateBin bwaFname =<< liftIO bwaData
    where
        bwaFname = "ngless-" ++ versionStr ++ "-bwa"

samtoolsBin :: NGLessIO FilePath
samtoolsBin = findOrCreateBin samtoolsFname =<< liftIO samtoolsData
    where
        samtoolsFname = "ngless-" ++ versionStr ++ "-samtools"

