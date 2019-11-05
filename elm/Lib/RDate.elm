-- Utility module and UI widget for handling release dates.
--
-- Release dates are integers with the following format: 0 or yyyymmdd
-- Special values
--   0        -> unknown
--   99999999 -> TBA
--   yyyy9999 -> year known, month & day unknown
--   yyyymm99 -> year & month known, day unknown
module Lib.RDate exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Date


type alias RDate = Int

type alias RDateComp =
  { y : Int
  , m : Int
  , d : Int
  }


expand : RDate -> RDateComp
expand r =
  { y = r // 10000
  , m = modBy 100 (r // 100)
  , d = modBy 100 r
  }


compact : RDateComp -> RDate
compact r = r.y * 10000 + r.m * 100 + r.d


fromDate : Date.Date -> RDateComp
fromDate d =
  { y = Date.year d
  , m = Date.monthNumber d
  , d = Date.day d
  }


normalize : RDateComp -> RDateComp
normalize r =
       if r.y == 0    then { y = 0,    m = 0,  d = 0  }
  else if r.y == 9999 then { y = 9999, m = 99, d = 99 }
  else if r.m == 99   then { y = r.y,  m = 99, d = 99 }
  else r


format : RDateComp -> String
format date =
  case (date.y, date.m, date.d) of
    (   0,  _,  _) -> "unknown"
    (9999,  _,  _) -> "TBA"
    (   y, 99, 99) -> String.fromInt y
    (   y,  m, 99) -> String.fromInt y ++ "-" ++ (String.padLeft 2 '0' <| String.fromInt m)
    (   y,  m,  d) -> String.fromInt y ++ "-" ++ (String.padLeft 2 '0' <| String.fromInt m) ++ "-" ++ (String.padLeft 2 '0' <| String.fromInt d)


display : Date.Date -> RDate -> Html msg
display today d =
  let fmt = expand d |> format
      future = d > (fromDate today |> compact)
  in if future then b [ class "future" ] [ text fmt ] else text fmt
