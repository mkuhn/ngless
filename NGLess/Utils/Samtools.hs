{- Copyright 2015-2017 NGLess Authors
 - License: MIT
 -}

module Utils.Samtools
    ( samBamConduit
    , convertSamToBam
    , convertBamToSam
    ) where

import Control.Monad
import System.Exit
import System.IO

import qualified Data.ByteString as B
import qualified Data.ByteString.Lazy.Char8 as BL8
import qualified Data.Conduit.List as CL
import qualified Data.Conduit as C
import qualified Data.Conduit.Combinators as C
import qualified Data.Conduit.Process as CP
import qualified Control.Concurrent.Async as A
import           Data.Conduit (($$))
import           Control.Monad.Trans.Resource (runResourceT)
import           Control.Monad.Except
import           Control.Concurrent (getNumCapabilities)
import           Data.List (isSuffixOf)
import           System.Process (proc, CreateProcess(..), StdStream(..))

import Output
import FileManagement
import NGLess.NGError

import Utils.Utils (readProcessErrorWithExitCode)
import Utils.Conduit

-- | reads a SAM (possibly compressed) or BAM file (in the latter case by using
-- 'samtools view' under the hood)
samBamConduit :: FilePath -> C.Source NGLessIO B.ByteString
samBamConduit samfp
  | ".bam" `isSuffixOf` samfp = do
        lift $ outputListLno' TraceOutput ["Starting samtools view of ", samfp]
        samtoolsPath <- lift samtoolsBin
        (hout, herr, err, sp) <- liftIO $ do
            numCapabilities <- getNumCapabilities
            let cp = proc samtoolsPath ["view", "-h", "-@", show numCapabilities, samfp]
            (CP.ClosedStream
                ,hout
                ,herr
                ,sp) <- CP.streamingProcess cp
            err <- A.async $ runResourceT (C.sourceHandle herr $$ CL.consume)
            A.link err
            return (hout, herr, err, sp)
        C.sourceHandle hout
        exitCode <- CP.waitForStreamingProcess sp
        forM_ [hout, herr] (liftIO . hClose)
        errout <- liftIO $ BL8.unpack . BL8.fromChunks <$> A.wait err
        lift $ outputListLno' DebugOutput ["samtools stderr: ", errout]
        case exitCode of
          ExitSuccess -> return ()
          ExitFailure exitError -> throwSystemError ("Samtools view failed with errorcode '" ++ show exitError ++ "'.\nError message was:\n "++errout)
    | otherwise = conduitPossiblyCompressedFile samfp


-- | Convert file types (SAM -> BAM)
-- The output is a newly created temporary file
convertSamToBam :: FilePath -> NGLessIO FilePath
convertSamToBam samfile = do
    samPath <- samtoolsBin
    (newfp, hout) <- openNGLTempFile samfile "converted_" "bam"
    outputListLno' DebugOutput ["SAM->BAM Conversion start ('", samfile, "' -> '", newfp, "')"]
    (errmsg, exitCode) <- liftIO $ do
        numCapabilities <- getNumCapabilities
        readProcessErrorWithExitCode (proc samPath ["view", "-@", show numCapabilities, "-bS", samfile]) { std_out = UseHandle hout }
    if null errmsg
        then outputListLno' DebugOutput ["No output from samtools."]
        else outputListLno' InfoOutput ["Message from samtools: ", errmsg]
    liftIO $ hClose hout
    case exitCode of
       ExitSuccess -> return newfp
       ExitFailure err -> throwSystemError ("Failure on converting sam to bam" ++ show err)

-- | Convert file types (BAM -> SAM)
-- The output is a newly created temporary file
convertBamToSam :: FilePath -> NGLessIO FilePath
convertBamToSam bamfile = do
    (newfp, hout) <- openNGLTempFile bamfile "converted_" "sam"
    outputListLno' DebugOutput ["BAM->SAM Conversion start ('", bamfile, "' -> '", newfp, "')"]
    samBamConduit bamfile $$ C.sinkHandle hout
    liftIO $ hClose hout
    return newfp
