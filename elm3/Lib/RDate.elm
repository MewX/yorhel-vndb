-- Utility module and UI widget for handling release dates.
--
-- Release dates are integers with the following format: 0 or yyyymmdd
-- Special values
--   0        -> unknown
--   99999999 -> TBA
--   yyyy9999 -> year known, month & day unknown
--   yyyymm99 -> year & month known, day unknown
--
-- I'm not a big fan of the UI widget. It's functional, but could be much more
-- convenient and intuitive.
module Lib.RDate exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Date
import Lib.Html exposing (..)
import Lib.Ffi exposing (curYear)


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


normalize : RDateComp -> RDateComp
normalize r =
       if r.y == 0    then { y = 0,    m = 0,  d = 0  }
  else if r.y == 9999 then { y = 9999, m = 99, d = 99 }
  else if r.m == 99   then { y = r.y,  m = 99, d = 99 }
  else r


type Msg
  = Year String
  | Month String
  | Day String


update : Msg -> RDate -> RDate
update msg ro =
  let r = expand ro
  in compact <| normalize <| case msg of
      Year s  -> { r | y = Maybe.withDefault r.y <| String.toInt s }
      Month s -> { r | m = Maybe.withDefault r.m <| String.toInt s }
      Day s   -> { r | d = Maybe.withDefault r.d <| String.toInt s }


view : RDate -> Bool -> Html Msg
view ro permitUnknown =
  let r = expand ro
      range s = List.range s >> List.map (\n -> (String.fromInt n, String.fromInt n))
      yl = (if permitUnknown then [("0", "Unknown")] else [])
           ++ List.reverse (range 1980 (curYear + 5))
           ++ [("9999", "TBA")]
      ml = ("99", "- month -") :: (range 1 12)
      maxDay = Date.fromCalendarDate r.y (Date.numberToMonth r.m) 1 |> Date.add Date.Months 1 |> Date.add Date.Days -1 |> Date.day
      dl = ("99", "- day -") :: (range 1 maxDay)
  in div []
    [ inputSelect [class "form-control--inline", onInput Year] (String.fromInt r.y) yl
    , if r.y == 0 || r.y == 9999
      then text ""
      else inputSelect [class "form-control--inline", onInput Month] (String.fromInt r.m) ml
    , if r.m == 0 || r.m == 99
      then text ""
      else inputSelect [class "form-control--inline", onInput Day] (String.fromInt r.d) dl
    ]
