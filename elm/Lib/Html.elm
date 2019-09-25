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


inputSelect : String -> String -> (String -> m) -> List (Attribute m) -> List (String, String) -> Html m
inputSelect nam sel onch attrs lst =
  let opt (id, name) = option [ value id, selected (id == sel) ] [ text name ]
  in select (
    [ tabindex 10
    , onInput onch
    ]
    ++ attrs
    ++ (if nam == "" then [] else [ id nam, name nam ])
  ) <| List.map opt lst


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
