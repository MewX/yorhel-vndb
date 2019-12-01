module Lib.Html exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as JD
import List
import Lib.Api as Api
import Lib.Util exposing (..)
import Gen.Types as T


-- onClick with stopPropagation & preventDefault
onClickN : m -> Attribute m
onClickN action = custom "click" (JD.succeed { message = action, stopPropagation = True, preventDefault = True})

-- onClick with preventDefault
onClickD : m -> Attribute m
onClickD action = custom "click" (JD.succeed { message = action, stopPropagation = False, preventDefault = True})

-- onInput that also tells us whether the input is valid
onInputValidation : (String -> Bool -> msg) -> Attribute msg
onInputValidation msg = custom "input" <|
  JD.map2 (\value valid -> { preventDefault = False, stopPropagation = True, message = msg value valid })
          targetValue
          (JD.at ["target", "validity", "valid"] JD.bool)


-- Multi-<br> (ugly but oh, so, convenient)
br_ : Int -> Html m
br_ n = if n == 1 then br [] [] else span [] <| List.repeat n <| br [] []


-- Quick short-hand way of creating a form that can be disabled.
-- Usage:
--   form_ Submit_msg (state == Disabled) [contents]
form_ : msg -> Bool -> List (Html msg) -> Html msg
form_ sub dis cont = Html.form [ onSubmit sub ]
  [ fieldset [disabled dis] cont ]


inputButton : String -> m -> List (Attribute m) -> Html m
inputButton val onch attrs =
  input ([ type_ "button", class "submit", tabindex 10, value val, onClick onch] ++ attrs) []


-- Submit button with loading indicator and error message display
submitButton : String -> Api.State -> Bool -> Html m
submitButton val state valid = div []
   [ input [ type_ "submit", class "submit", tabindex 10, value val, disabled (state == Api.Loading || not valid) ] []
   , case state of
       Api.Error r -> p [] [ b [class "standout" ] [ text <| Api.showResponse r ] ]
       _ -> if valid
            then text ""
            else p [] [ b [class "standout" ] [ text "The form contains errors, please fix these before submitting. " ] ]
   , if state == Api.Loading
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
    , rows 4
    , cols 50
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


inputRadio : String -> Bool -> (Bool -> m) -> Html m
inputRadio nam val onch = input (
    [ type_ "radio"
    , tabindex 10
    , onCheck onch
    , checked val
    ]
    ++ (if nam == "" then [] else [ name nam ])
  ) []


-- Same as an inputText, but formats/parses an integer as Q###
inputWikidata : String -> Maybe Int -> (Maybe Int -> m) -> Html m
inputWikidata nam val onch =
  inputText nam
            (case val of
              Nothing -> ""
              Just v  -> "Q" ++ String.fromInt v)
            (\v -> onch <| if v == "" then Nothing else String.toInt <| if String.startsWith "Q" v then String.dropLeft 1 v else v)
            [ pattern "^Q?[1-9][0-9]{0,8}$" ]


-- Similar to inputCheck and inputRadio with a label, except this is just a link.
linkRadio : Bool -> (Bool -> m) -> List (Html m) -> Html m
linkRadio val onch content =
  a [ href "#", onClickD (onch (not val)), class "linkradio", classList [("checked", val)] ] content


-- Generate a form field (table row) with a label. The `label` string can be:
--
--   "none"            -> To generate a full-width field (colspan=2)
--   ""                -> Empty label
--   "Some string"     -> Text label
--   "Some string#eng" -> Text label with (English please!) message
--   "input::String"   -> Label that refers to the named input (also supports #eng)
--
-- (Yeah, stringly typed arguments; I wish Elm had typeclasses)
formField : String -> List (Html m) -> Html m
formField lbl cont =
  tr [ class "newfield" ]
  [ if lbl == "none"
    then text ""
    else
      let
        (nlbl, eng) = if String.endsWith "#eng" lbl then (String.dropRight 4 lbl, True) else (lbl, False)
        genlbl str = text str :: if eng then [ br [] [], b [ class "standout" ] [ text "English please!" ] ] else []
      in
        td [ class "label" ] <|
          case String.split "::" nlbl of
            [name, txt] -> [ label [ for name ] (genlbl txt) ]
            txt         -> genlbl (String.concat txt)
  , td (class "field" :: if lbl == "none" then [ colspan 2 ] else []) cont
  ]



langIcon : String -> Html m
langIcon l = abbr [ class "icons lang", class l, title (Maybe.withDefault "" <| lookup l T.languages) ] [ text " " ]

releaseTypeIcon : String -> Html m
releaseTypeIcon t = abbr [ class ("icons rt"++t), title (Maybe.withDefault "" <| lookup t T.releaseTypes) ] [ text " " ]
