module Lib.Html exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as JD
import List
import Lib.Api as Api


-- onClick with stopPropagation & preventDefault
onClickN : m -> Attribute m
onClickN action = custom "click" (JD.succeed { message = action, stopPropagation = True, preventDefault = True})


-- Multi-<br> (ugly but oh, so, convenient)
br_ : Int -> Html m
br_ n = if n == 1 then br [] [] else span [] <| List.repeat n <| br [] []

-- Submit button with loading indicator and error message display
submitButton : String -> Api.State -> Bool -> Bool -> Html m
submitButton val state valid load = div []
   [ input [ type_ "submit", class "submit", tabindex 10, value val, disabled (state == Api.Loading || not valid || load) ] []
   , case state of
       Api.Error r -> p [] [ b [class "standout" ] [ text <| Api.showResponse r ] ]
       _ -> if valid
            then text ""
            else p [] [ b [class "standout" ] [ text "The form contains errors, please fix these before submitting. " ] ]
   , if state == Api.Loading || load
     then div [ class "spinner" ] []
     else text ""
   ]


inputSelect : String -> a -> (a -> m) -> List (Attribute m) -> List (a, String) -> Html m
inputSelect nam sel onch attrs lst =
  let
    opt n (id, name) = option [ value (String.fromInt n), selected (id == sel) ] [ text name ]
    call first n =
      case List.drop (Maybe.withDefault 0 <| String.toInt n) lst |> List.head of
        Just (id, name) -> onch id
        Nothing -> onch first
    ev =
      case List.head lst of
        Just first -> [ onInput <| call <| Tuple.first first ]
        Nothing -> []
  in select (
        [ tabindex 10 ]
        ++ ev
        ++ attrs
        ++ (if nam == "" then [] else [ id nam, name nam ])
      ) <| List.indexedMap opt lst


inputText : String -> String -> (String -> m) -> List (Attribute m) -> Html m
inputText nam val onch attrs = input (
    [ type_ "text"
    , class "text"
    , tabindex 10
    , value val
    , onInput onch
    ]
    ++ attrs
    ++ (if nam == "" then [] else [ id nam, name nam ])
  ) []


inputPassword : String -> String -> (String -> m) -> List (Attribute m) -> Html m
inputPassword nam val onch attrs = input (
    [ type_ "password"
    , class "text"
    , tabindex 10
    , value val
    , onInput onch
    ]
    ++ attrs
    ++ (if nam == "" then [] else [ id nam, name nam ])
  ) []


inputTextArea : String -> String -> (String -> m) -> List (Attribute m) -> Html m
inputTextArea nam val onch attrs = textarea (
    [ tabindex 10
    , onInput onch
    ]
    ++ attrs
    ++ (if nam == "" then [] else [ id nam, name nam ])
  ) [ text val ]


inputCheck : String -> Bool -> (Bool -> m) -> Html m
inputCheck nam val onch = input (
    [ type_ "checkbox"
    , tabindex 10
    , onCheck onch
    , checked val
    ]
    ++ (if nam == "" then [] else [ id nam, name nam ])
  ) []


-- Generate a form field (table row) with a label. The `label` string can be:
--
--   "none"          -> To generate a full-width field (colspan=2)
--   ""              -> Empty label
--   "Some string"   -> Text label
--   "input::String" -> Label that refers to the named input
--
-- (Yeah, stringly typed arguments; I wish Elm had typeclasses)
formField : String -> List (Html m) -> Html m
formField lbl cont =
  tr [ class "newfield" ]
  [ if lbl == "none"
    then text ""
    else
      td [ class "label" ]
      [ case String.split "::" lbl of
          [name, txt] -> label [ for name ] [ text txt ]
          txt         -> text <| String.concat txt
      ]
  , td (class "field" :: if lbl == "none" then [ colspan 2 ] else []) cont
  ]
