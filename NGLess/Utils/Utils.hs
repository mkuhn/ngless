{- Copyright 2015 NGLess Authors
 - License: MIT
 -}

{-# LANGUAGE OverloadedStrings #-}

module Utils.Utils
    ( lookupWithDefault
    , uniq
    , readPossiblyCompressedFile
    , hWriteGZIP
    , allSame
    ) where

import qualified Data.ByteString.Lazy.Char8 as BL
import qualified Codec.Compression.GZip as GZip
import qualified Codec.Compression.BZip as BZip
import System.IO

import Control.Applicative ((<$>))

import Data.List (isSuffixOf, group)
import Data.Maybe (fromMaybe)

lookupWithDefault :: Eq b => a -> b -> [(b,a)] -> a
lookupWithDefault def key values = fromMaybe def $ lookup key values

uniq :: Eq a => [a] -> [a]
uniq = map head . group

readPossiblyCompressedFile ::  FilePath -> IO BL.ByteString
readPossiblyCompressedFile fname
    | ".gz" `isSuffixOf` fname = GZip.decompress <$> BL.readFile fname
    | ".bz2" `isSuffixOf` fname = BZip.decompress <$> BL.readFile fname
    | otherwise = BL.readFile fname


hWriteGZIP :: Handle -> BL.ByteString -> IO ()
hWriteGZIP h = BL.hPut h . GZip.compress

allSame :: Eq a => [a] -> Bool
allSame [] = True
allSame (e:es) = all (==e) es

