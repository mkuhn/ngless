
module InvokeExternalProgs
    ( 
    indexReference,
    mapToReference
    ) where

import GHC.Conc -- Returns number of cores available

import Data.Text as T

import System.FilePath.Posix
import System.Process
import System.Exit

import System.IO

import Language
import FileManagement

-- Constants

dirPath :: String
dirPath = "../bwa-0.7.7/" --setup puts the bwa directory on project root.

mapAlg :: String
mapAlg = "bwa"

indexRequiredFormats :: [String]
indexRequiredFormats = [".amb",".ann",".bwt",".pac",".sa"]

----

indexReference refPath = do
    let refPath' = (T.unpack refPath)
    res <- doesDirContainFormats refPath' indexRequiredFormats
    case res of
        False -> do
            (exitCode, _, herr) <-
                readProcessWithExitCode (dirPath </> mapAlg) ["index", refPath'] []  
            printNglessLn herr 
            case exitCode of
                ExitSuccess -> return ()
                ExitFailure _err -> error (herr)
        True -> printNglessLn $ "index for " ++ refPath' ++ " as been sucessfully generated."
            -- already contain reference index



mapToReference refIndex readSet = do
    newfp <- getTempFilePath readSet
    printNglessLn $ "write .sam file to: " ++ (show newfp)
    jHandle <- mapToReference' newfp refIndex readSet
    exitCode <- waitForProcess jHandle
    case exitCode of
       ExitSuccess -> return (NGOMappedReadSet (T.pack newfp))
       ExitFailure err -> error ("Failure on mapping against reference:" ++ (show err))


-- Process to execute BWA and write to <handle h> .sam file
mapToReference' newfp refIndex readSet = do 
    (_, Just hout, Just herr, jHandle) <-
        createProcess (
            proc 
                (dirPath </> mapAlg)
                ["mem","-t",(show numCapabilities),(T.unpack refIndex), readSet]
            ) { std_out = CreatePipe,
                std_err = CreatePipe }
    writeToFile hout newfp
    hGetContents herr >>= printNglessLn
    return jHandle


writeToFile :: Handle -> FilePath -> IO ()
writeToFile handle path = do
    contents <- hGetContents handle
    writeFile path contents
    hClose handle