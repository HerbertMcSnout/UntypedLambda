module Main where
import System.Environment (getProgName, getArgs)
import Inline
import Parse
import Helpers

usage = guardIO (getProgName >>= \ p -> return (Left ("Usage:\n  " ++ p ++ " --with FILES...")))

main =
  setBuffering >>
  getArgs >>= \ as ->
  case as of
    ("--with" : fns) ->
      parseFiles fns >>= \ p ->
      readTerms $ Right . show . inline p
    _ -> usage
