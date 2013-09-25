{-# LANGUAGE TemplateHaskell, OverloadedStrings, TupleSections #-}
-- Unit tests are their own programme.

module Main where

-- Import basic functionality and our own modules

import qualified Data.Map as M
import Test.Framework.TH
import Test.HUnit
import Test.QuickCheck
import Test.Framework.Providers.HUnit
import Test.Framework.Providers.QuickCheck2()
import Control.Applicative
import Text.Parsec (parse)
import Text.Parsec.Combinator (eof)
import Text.ParserCombinators.Parsec.Prim (GenParser)
import qualified Data.Text as T
import Text.Parsec (SourcePos)
import Text.Parsec.Pos (newPos)

import Language
import Parse
import Tokens
import Types
import PrintFastqBasicStats
import FastQFileData
import PerBaseQualityScores
import FPreProcess

-- The main test driver is automatically generated
main = $(defaultMainGenerator)


-- Test Parsing Module
parseText :: GenParser (SourcePos,Token) () a -> T.Text -> a
parseText p t = fromRight . parse p "test" . _cleanupindents . fromRight . tokenize "test" $ t
fromRight (Right r) = r
fromRight (Left e) = error (concat ["Unexpected Left: ",show e])
parseBody = map snd . parseText _nglbody
parsetest = parsengless "test"

case_parse_symbol = parseBody "{symbol}" @?= [ConstSymbol "symbol"]
case_parse_fastq = parseBody fastqcalls @?= fastqcall
    where
        fastqcalls = "fastq(\"input.fq\")"
        fastqcall  = [FunctionCall Ffastq (ConstStr "input.fq") [] Nothing]

case_parse_assignment =  parseBody "reads = \"something\"" @?=
        [Assignment (Variable "reads") (ConstStr "something")]


case_parse_sequence = parseBody seqs @?= seqr
    where
        seqs = "reads = 'something'\nreads = 'something'"
        seqr = [a,a]
        a    = Assignment (Variable "reads") (ConstStr "something")

case_parse_num = parseBody nums @?= num
    where
        nums = "a = 0x10"
        num  = [Assignment (Variable "a") (ConstNum 16)]

case_parse_bool = parseBody bools @?= bool
    where
        bools = "a = true"
        bool  = [Assignment (Variable "a") (ConstBool True)]

case_parse_if_else = parseBody blocks @?= block
    where
        blocks = "if true:\n 0\n 1\nelse:\n 2\n"
        block  = [Condition (ConstBool True) (Sequence [ConstNum 0,ConstNum 1]) (Sequence [ConstNum 2])]

case_parse_if = parseBody blocks @?= block
    where
        blocks = "if true:\n 0\n 1\n"
        block  = [Condition (ConstBool True) (Sequence [ConstNum 0,ConstNum 1]) (Sequence [])]

case_parse_if_end = parseBody blocks @?= block
    where
        blocks = "if true:\n 0\n 1\n2\n"
        block  = [Condition (ConstBool True) (Sequence [ConstNum 0,ConstNum 1]) (Sequence []),ConstNum 2]

case_parse_ngless = parsengless "test" ngs @?= Right ng
    where
        ngs = "ngless 0.0\n"
        ng  = Script (0,0) []

case_parse_list = parseText _listexpr "[a,b]" @?= ListExpression [Lookup (Variable "a"), Lookup (Variable "b")]

case_parse_indexexpr_11 = parseText _indexexpr "read[1:1]" @?= IndexExpression (Lookup (Variable "read")) (IndexTwo j1 j1)
case_parse_indexexpr_10 = parseText _indexexpr "read[1:]"  @?= IndexExpression (Lookup (Variable "read")) (IndexTwo j1 Nothing)
case_parse_indexexpr_01 = parseText _indexexpr "read[:1]"  @?= IndexExpression (Lookup (Variable "read")) (IndexTwo Nothing j1)
case_parse_indexexpr_00 = parseText _indexexpr "read[:]"   @?= IndexExpression (Lookup (Variable "read")) (IndexTwo Nothing Nothing)

case_parse_indexexprone_1 = parseText _indexexpr "read[1]" @?= IndexExpression (Lookup (Variable "read")) (IndexOne (ConstNum 1))
case_parse_indexexprone_2 = parseText _indexexpr "read[2]" @?= IndexExpression (Lookup (Variable "read")) (IndexOne (ConstNum 2))
case_parse_indexexprone_var = parseText _indexexpr "read[var]" @?= IndexExpression (Lookup (Variable "read")) (IndexOne (Lookup (Variable "var")))

case_parse_cleanupindents_0 = tokcleanupindents [TIndent 1] @?= []
case_parse_cleanupindents_1 = tokcleanupindents [TNewLine] @?= [TNewLine]
case_parse_cleanupindents_2 = tokcleanupindents [TIndent 1,TNewLine] @?= [TNewLine]
case_parse_cleanupindents_3 = tokcleanupindents [TOperator '(',TNewLine,TIndent 2,TOperator ')'] @?= [TOperator '(',TOperator ')']

case_parse_cleanupindents_4 = tokcleanupindents toks @?= toks'
    where
        toks  = [TWord "write",TOperator '(',TWord "A",TOperator ',',TNewLine,TIndent 16,TNewLine,TIndent 16,TWord "format",TOperator '=',TExpr (ConstSymbol "csv"),TOperator ')',TNewLine]
        toks' = [TWord "write",TOperator '(',TWord "A",TOperator ','                                        ,TWord "format",TOperator '=',TExpr (ConstSymbol "csv"),TOperator ')',TNewLine]
case_parse_cleanupindents_4' = tokcleanupindents toks @?= toks'
    where
        toks  = [TOperator '(',TOperator ',',TNewLine,TIndent 16,TNewLine,TIndent 16,TOperator ')',TNewLine]
        toks' = [TOperator '(',TOperator ','                                        ,TOperator ')',TNewLine]
case_parse_cleanupindents_4'' = tokcleanupindents toks @?= toks'
    where
        toks  = [TOperator '(',TNewLine,TIndent 16,TNewLine,TIndent 16,TOperator ')',TNewLine]
        toks' = [TOperator '('                                        ,TOperator ')',TNewLine]

j1 = Just (ConstNum 1)
tokcleanupindents = map snd . _cleanupindents . map (newPos "test" 0 0,)

case_parse_kwargs = parseBody "unique(reads,maxCopies=2)\n" @?= [FunctionCall Funique (Lookup (Variable "reads")) [(Variable "maxCopies", ConstNum 2)] Nothing]

-- Test Tokens module
tokenize' fn t = map snd <$> (tokenize fn t)

case_tok_cr = TNewLine @=? (case parse (_eol <* eof) "test" "\r\n" of { Right t -> t; Left _ -> error "Parse failed"; })
case_tok_single_line_comment = tokenize' "test" with_comment @?= Right expected
    where
        with_comment = "a=0# comment\nb=1\n"
        expected = [TWord "a",TOperator '=',TExpr (ConstNum 0),TNewLine,TWord "b",TOperator '=',TExpr (ConstNum 1),TNewLine]

case_tok_single_line_comment_cstyle = tokenize' "test" with_comment @?= Right expected
    where
        with_comment = "a=0// comment\nb=1\n"
        expected = [TWord "a",TOperator '=',TExpr (ConstNum 0),TNewLine,TWord "b",TOperator '=',TExpr (ConstNum 1),TNewLine]

case_tok_multi_line_comment = tokenize' "test" with_comment @?= Right expected
    where
        with_comment = "a=0/* This\n\nwith\nlines*/\nb=1\n"
        expected = [TWord "a",TOperator '=',TExpr (ConstNum 0),TIndent 0,TNewLine,TWord "b",TOperator '=',TExpr (ConstNum 1),TNewLine]

case_tok_word_ = tokenize' "test" "word_with_underscore" @?= Right expected
    where
        expected = [TWord "word_with_underscore"]



-- Test CountChars
case_count_bps_empty = countChars ((0,0,0,0) :: (Int,Int,Int,Int)) "\n" @?= (0,0,0,0)
case_count_bps_normal = countChars ((1,1,1,1) :: (Int,Int,Int,Int)) "AAAGGGTTTCCC\n" @?= (4,4,4,4)
case_count_bps_only_As = countChars ((0,0,0,0) :: (Int,Int,Int,Int)) "AAAAAAAAAA\n" @?= (10,0,0,0)
case_count_bps_mixed_case = countChars ((0,0,0,0) :: (Int,Int,Int,Int)) "AaAaAaaaAA\n" @?= (10,0,0,0)

-- Test Encoding
case_calculateEncoding_sanger = calculateEncoding 55 @?= Encoding "Sanger / Illumina 1.9" sanger_encoding_offset
case_calculateEncoding_illumina_1 = calculateEncoding 60 @?= Encoding "Illumina <1.3" illumina_1_encoding_offset
case_calculateEncoding_illumina_1_5 = calculateEncoding 100 @?= Encoding "Illumina 1.5" illumina_1_3_encoding_offset

-- Test the insertion of Quality Counts
case_add_Qual_Count_without_bp = addToCount [] "!!!" @?= replicate 3 (M.fromList [('!',1)])
case_add_Qual_Count_with_existing_bp = addToCount (replicate 3 (M.fromList [('!',1)])) "!!!" @?= replicate 3 (M.fromList [('!',2)])

--Test the calculation of the Mean
case_calc_simple_mean = calcMean ([1,2] :: [Integer]) [1,2] (2 :: Integer) @?= (2.5 :: Double) -- 5/2
--TODO: compare returned errors to the Mean and Percentile
--case_calc_mean_error = calcMean ([] :: [Integer]) [] (0 :: Integer) @?= error "The total number of quality elements in the fastQ needs to be higher than 0"

--Test the calculation of the Percentile
case_calc_median = calcPerc ([2,5,10] :: [Integer]) [1,5,1] (7 :: Integer) (0.5 :: Double) @?= (5 :: Integer)
case_calc_Low_Quart = calcPerc ([2,5,10] :: [Integer]) [1,1,1] (3 :: Integer) (0.25 :: Double) @?= (2 :: Integer)
case_calc_Upper_Quart = calcPerc ([2,5,10] :: [Integer]) [1,1,1] (3 :: Integer) (0.75 :: Double) @?= (10 :: Integer)

--Calculate Sequence min and max Size
case_seq_size_first_invocation = seqMinMax (maxBound :: Int, minBound :: Int) 10 @?= (10,10)
case_seq_size_max_update = seqMinMax (5,6) 10 @?= (5,10)
case_seq_size_min_update = seqMinMax (5,6) 2 @?= (2,6)

--Propertie 1: For every s, the size must be allways smaller than the input
case_substrim_maxsize = quickCheck (\s -> snd(calculateSubStrim s 20) <= length(s))
case_substrim_normal_exec =  calculateSubStrim [10,11,12,123,122,111,10,11,0] 20 @?= (3,3)
case_substrim_empty_quals = calculateSubStrim [] 20 @?= (0,0)

-- Test Types

isError (Right _) = assertFailure "error not caught"
isError (Left _) = return ()

isOk (Left _) = assertFailure "Type error on good code"
isOk (Right _) = return ()

case_bad_type_fastq = isError $ checktypes (Script (0,0) [(0,FunctionCall Ffastq (ConstNum 3) [] Nothing)])
case_good_type_fastq = isOk $ checktypes (Script (0,0) [(0,FunctionCall Ffastq (ConstStr "fastq.fq") [] Nothing)])

case_type_complete = isOk $ (parsetest complete) >>= checktypes

complete = "ngless 0.0\n\
    \reads = fastq('input1.fq')\n\
    \reads = unique(reads,maxCopies=2)\n\
    \preprocess(reads) using |read|:\n\
    \    read = read[5:]\n\
    \    read = substrim(read,minQuality=24)\n\
    \    if len(read) < 30:\n\
    \        discard\n"

