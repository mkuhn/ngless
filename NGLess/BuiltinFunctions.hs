{- Copyright 2013-2016 NGLess Authors
 - License: MIT
 -}
{-# LANGUAGE OverloadedStrings, BangPatterns #-}
module BuiltinFunctions
    ( MethodName(..)
    , MethodInfo(..)
    , builtinFunctions
    , builtinMethods
    ) where

import qualified Data.Text as T

import Modules
import Language

data MethodInfo = MethodInfo
    { methodName :: MethodName
    , methodSelfType :: NGLType
    , methodArgType :: Maybe NGLType
    , methodReturnType :: NGLType
    , methodKwargsInfo :: [ArgInformation]
    , methodIsPure :: Bool
    } deriving (Eq, Show)

builtinFunctions =
    [Function (FuncName "fastq") (Just NGLString) NGLReadSet fastqArgs False
    ,Function (FuncName "paired") (Just NGLString) NGLReadSet pairedArgs False
    ,Function (FuncName "group") (Just (NGList NGLReadSet)) NGLReadSet groupArgs False
    ,Function (FuncName "samfile") (Just NGLString) NGLMappedReadSet samfileArgs False
    ,Function (FuncName "unique") (Just NGLReadSet) NGLReadSet uniqueArgs False
    ,Function (FuncName "preprocess") (Just NGLReadSet) NGLVoid preprocessArgs False
    ,Function (FuncName "substrim") (Just NGLRead) NGLRead substrimArgs False
    ,Function (FuncName "map") (Just NGLReadSet) NGLMappedReadSet mapArgs False
    ,Function (FuncName "select") (Just NGLMappedReadSet) NGLMappedReadSet selectArgs False
    ,Function (FuncName "count") (Just NGLMappedReadSet) NGLCounts countArgs False
    ,Function (FuncName "write") (Just NGLAny) NGLVoid writeArgs False
    ,Function (FuncName "print") (Just NGLAny) NGLVoid [] False
    ]

groupArgs =
    [ArgInformation "name" True NGLString Nothing
    ]

writeArgs =
    [ArgInformation "ofile" True NGLString Nothing
    ,ArgInformation "format" False NGLSymbol (Just ["tsv", "csv", "bam", "sam"])
    ,ArgInformation "verbose" False NGLBool Nothing
    ]

countArgs =
    [ArgInformation "features" False (NGList NGLString) Nothing
    ,ArgInformation "min" False NGLInteger Nothing
    ,ArgInformation "multiple" False NGLSymbol (Just ["all1", "dist1", "1overN"])
    ,ArgInformation "mode" False NGLSymbol (Just ["union", "intersection_strict", "intersection_non_empty"])
    ,ArgInformation "gff_file" False NGLString Nothing
    ,ArgInformation "functional_map" False NGLString Nothing
    ,ArgInformation "keep_ambiguous" False NGLBool Nothing
    ,ArgInformation "strand" False NGLBool Nothing
    ,ArgInformation "norm" False NGLBool Nothing
    ]

selectArgs =
    [ArgInformation "keep_if" False (NGList NGLSymbol) (Just ["mapped", "unmapped", "unique"])
    ,ArgInformation "drop_if" False (NGList NGLSymbol) (Just ["mapped", "unmapped", "unique"])
    ,ArgInformation "__oname" False NGLString Nothing
    ]

fastqArgs =
    [ArgInformation "encoding" False NGLSymbol (Just ["auto", "33", "64", "sanger", "solexa"])
    ,ArgInformation "__perform_qc" False NGLBool Nothing
    ]

samfileArgs =
    [ArgInformation "name" False NGLString Nothing
    ]
pairedArgs =
    [ArgInformation "second" True NGLString Nothing
    ,ArgInformation "singles" False NGLString Nothing
    ,ArgInformation "__perform_qc" False NGLBool Nothing
    ]

uniqueArgs =
    [ArgInformation "max_copies" False NGLInteger Nothing]

preprocessArgs =
    [ArgInformation "keep_singles" False NGLBool Nothing
    ,ArgInformation "__qc_input" False NGLBool Nothing
    ]

mapArgs =
    [ArgInformation "reference" False NGLString Nothing
    ,ArgInformation "fafile" False NGLString Nothing
    ,ArgInformation "__extra_bwa" False (NGList NGLString) Nothing
    ,ArgInformation "__oname" False NGLString Nothing
    ]

substrimArgs =
    [ArgInformation "min_quality" True NGLInteger Nothing
    ]


builtinMethods =
    [MethodInfo Mflag   NGLMappedRead (Just NGLSymbol) NGLBool [] True
    ,MethodInfo Mfilter NGLMappedRead Nothing NGLMappedRead filterArgs True
    ,MethodInfo Munique NGLMappedRead Nothing NGLMappedRead [] True
    ]
filterArgs =
    [ArgInformation "min_identity_pc" False NGLInteger Nothing
    ,ArgInformation "min_match_size" False NGLInteger Nothing
    ,ArgInformation "action" False NGLSymbol (Just ["drop", "unmap"])
    ]

