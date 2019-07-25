module Lib.Html exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import List
import Lib.Api as Api
import Lib.Gen exposing (urlStatic)
import Lib.Ffi as Ffi
import Json.Encode as JE
import String exposing (padLeft)

-- Quick short-hand way of creating a form that can be disabled.
-- Usage:
--   form Submit_msg (state == Disabled) [contents]
form_ : msg -> Bool -> List (Html msg) -> Html msg
form_ sub dis cont = Html.form [ onSubmit sub ]
  [ fieldset [disabled dis] cont ]


-- Submit button with loading indicator and error message display
-- TODO: This use of pull-right is ugly.
submitButton : String -> Api.State -> Bool -> Bool -> Html m
submitButton val state valid load = div []
   [ input [ type_ "submit", class "btn pull-right", tabindex 10, value val, disabled (state == Api.Loading || not valid || load) ] []
   , case state of
       Api.Error r -> div [class "invalid-feedback pull-right" ] [ text <| Api.showResponse r ]
       _ -> if valid
            then text ""
            else div [class "invalid-feedback pull-right" ] [ text "The form contains errors, please fix these before submitting. " ]
   , if state == Api.Loading || load
     then div [ class "spinner spinner--md pull-right" ] []
     else text ""
   ]


inputSelect : List (Attribute m) -> String -> List (String, String) -> Html m
inputSelect attrs sel lst =
  let opt (id, name) = option [ value id, selected (id == sel) ] [ text name ]
  in  select ([class "form-control", tabindex 10] ++ attrs) <| List.map opt lst


inputText : String -> String -> (String -> m) -> List (Attribute m) -> Html m
inputText nam val onch attrs = input (
    [ type_ "text"
    , class "form-control"
    , tabindex 10
    , value val
    , onInput onch
    ]
    ++ attrs
    ++ (if nam == "" then [] else [ id nam, name nam ])
  ) []

inputTextArea : String -> String -> (String -> m) -> List (Attribute m) -> Html m
inputTextArea nam val onch attrs = textarea (
    [ class "form-control"
    , tabindex 10
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

inputRadio : String -> Bool -> (Bool -> m) -> Html m
inputRadio nam val onch = input (
    [ type_ "radio"
    , tabindex 10
    , onCheck onch
    , checked val
    ]
    ++ (if nam == "" then [] else [ name nam ])
  ) []

-- Generate a card with: Id, Title, [Header stuff], [Sections]
-- TODO: Also abstract "small-card"s (many of the User/ things) into this
card : String -> String -> List (Html m) -> List (Html m) -> Html m
card i t h sections = div
  ([class "card"] ++ if i == "" then [] else [id i])
  <|
  [ div [class "card__header"] ([ div [class "card__title"] [text t] ] ++ h)
  ] ++ List.map (\c -> div [class "card__section"] [c]) sections

-- Card without header
card_ : List (Html m) -> Html m
card_ c = div [class "card"] [ div [class "card__body"] c ]

-- Generate a 2-column row for use within a card section: Title, Subtitle, Content
cardRow : String -> Maybe String -> List (Html m) -> Html m
cardRow t s c = div [class "row"]
  [ div [class "col-md col-md--1 card__form-section-left"]
    [ div [class "card__form-section-title"] [text t]
    , case s of
        Just n  -> div [class "card__form-section-subtitle"] [text n]
        Nothing -> text ""
    ]
  , div [class "col-md col-md--2"] c
  ]

formGroup : List (Html m) -> List (Html m)
formGroup c = [div [class "form-group"] c]

formGroups : List (List (Html m)) -> List (Html m)
formGroups groups = List.map (\c -> div [class "form-group"] c) groups


removeButton : m -> Html m
removeButton cmd = button [type_ "button", class "btn", tabindex 10, onClick cmd]
  [ span [class "d-none d-sm-inline"] [text "x"]
  , span [class "d-sm-none"]          [text "Remove"]
  ]



editList : List (Html m) -> List (Html m)
editList ct =
  if List.isEmpty ct
    then []
    else [ div [class "editable-list editable-list--sm"] ct ]

editListRow : String -> List (Html m) -> Html m
editListRow cl ct = div [class ("editable-list__row row row--compact " ++ cl)] ct

editListField : Int -> String -> List (Html m) -> Html m
editListField sm cl ct = div
  [ classList <|
    [ ("editable-list__field", True)
    , ("col-sm",       True   )
    , ("col-sm--auto", sm == 0)
    , ("col-sm--1",    sm == 1)
    , ("col-sm--2",    sm == 2)
    , ("col-sm--3",    sm == 3)
    , (cl,             cl /= "")
    ]
  ] ct


-- Special arguments,
--   id == -1 -> spinner
--   id == 0  -> camera-alt.svg
dbImg : String -> Int -> List (Attribute m) -> Maybe { id: String, width: Int, height: Int } -> Html m
dbImg dir id attrs full =
  if id == 0 then
    div (class "vn-image-placeholder img--rounded" :: attrs)
      [ div [ class "vn-image-placeholder__icon" ]
        [ img [ src (urlStatic ++ "/v3/camera-alt.svg"), class "svg-icon" ] [] ]
      ]
  else if id == -1 then
    div (class "vn-image-placeholder img--rounded" :: attrs)
      [ div [ class "vn-image-placeholder__icon" ]
        [ div [ class "spinner spinner--md" ] [] ]
      ]
  else
  let
    url d = urlStatic ++ "/" ++ d ++ "/" ++ (padLeft 2 '0' (String.fromInt (modBy 100 id))) ++ "/" ++ (String.fromInt id) ++ ".jpg"
    i = img [src (url dir), class "img--fit img--rounded" ] []
    fdir = if dir == "st" then "sf" else dir
  in case full of
    Nothing -> i
    Just f -> a
      [ href (url fdir)
      , Ffi.openLightbox
      , attribute "data-lightbox-id" f.id
      , attribute "data-lightbox-nfo" <| JE.encode 0 <| JE.object [("width", JE.int f.width), ("height", JE.int f.height)]
      ] [ i ]


iconLanguage : String -> Html msg
iconLanguage lang = span [ class "lang-badge" ] [ text lang ]

iconPlatform : String -> Html msg
iconPlatform plat = img [ class "svg-icon", src (urlStatic ++ "/v3/windows.svg"), title "Windows" ] []
