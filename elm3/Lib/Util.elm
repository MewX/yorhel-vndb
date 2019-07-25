module Lib.Util exposing (..)

import Char
import Dict

-- Delete an element from a List
delidx : Int -> List a -> List a
delidx n l = List.take n l ++ List.drop (n+1) l


-- Modify an element in a List
modidx : Int -> (a -> a) -> List a -> List a
modidx n f = List.indexedMap (\i e -> if i == n then f e else e)


isJust : Maybe a -> Bool
isJust m = case m of
  Just _ -> True
  _      -> False


-- Split by newline, trim whitespace and remove empty lines
splitLn : String -> List String
splitLn = String.lines >> List.map String.trim >> List.filter ((/=)"")

-- Returns true if the list contains duplicates
hasDuplicates : List comparable -> Bool
hasDuplicates l =
  let
    step e acc =
      case acc of
        Nothing -> Nothing
        Just m -> if Dict.member e m then Nothing else Just (Dict.insert e True m)
  in
    case List.foldr step (Just Dict.empty) l of
      Nothing -> True
      Just _  -> False


-- Similar to perl's ucfirst() (not terribly efficient)
toUpperFirst : String -> String
toUpperFirst s = String.toList s |> List.indexedMap (\i c -> if i == 0 then Char.toUpper c else c) |> String.fromList


-- Haskell's 'lookup' - find an entry in an association list
lookup : a -> List (a,b) -> Maybe b
lookup n l = List.filter (\(a,_) -> a == n) l |> List.head |> Maybe.map Tuple.second


formatGtin : Int -> String
formatGtin n = if n == 0 then "" else String.fromInt n |> String.padLeft 12 '0'


-- Based on VNDBUtil::gtintype()
validateGtin : String -> Maybe Int
validateGtin =
  let check = String.fromInt
        >> String.reverse
        >> String.toList
        >> List.indexedMap (\i c -> (Char.toCode c - Char.toCode '0') * if modBy 2 i == 0 then 1 else 3)
        >> List.sum
      inval n =
            n <     1000000000
        || (n >=  200000000000 && n <  600000000000)
        || (n >= 2000000000000 && n < 3000000000000)
        ||  n >= 9770000000000
        || modBy 10 (check n) /= 0
  in String.filter Char.isDigit >> String.toInt >> Maybe.andThen (\n -> if inval n then Nothing else Just n)


spoilLevels : List (String, String)
spoilLevels =
  [ ("0", "No spoiler")
  , ("1", "Minor spoiler")
  , ("2", "Major spoiler")
  ]
