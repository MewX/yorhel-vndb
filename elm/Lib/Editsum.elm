-- This module provides an the 'Edit summary' box, including the 'hidden' and
-- 'locked' moderation checkboxes.

module Lib.Editsum exposing (Model, Msg, new, update, view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Lib.Html exposing (..)


type alias Model =
  { authmod  : Bool
  , locked   : Bool
  , hidden   : Bool
  , editsum  : String
  }


type Msg
  = Locked Bool
  | Hidden Bool
  | Editsum String


new : Model
new =
  { authmod = False
  , locked  = False
  , hidden  = False
  , editsum = ""
  }


update : Msg -> Model -> Model
update msg model =
  case msg of
    Locked b  -> { model | locked  = b }
    Hidden b  -> { model | hidden  = b }
    Editsum s -> { model | editsum = s }


view : Model -> Html Msg
view model =
  let
    lockhid =
      [ label []
        [ inputCheck "" model.hidden Hidden
        , text " Deleted" ]
      , label []
        [ inputCheck "" model.locked Locked
        , text " Locked" ]
      , br [] []
      , text "Note: edit summary of the last edit should indicate the reason for the deletion."
      , br [] []
      ]
  in fieldset [] <|
    (if model.authmod then lockhid else [])
    ++
    [ h2 []
      [ text "Edit summary"
      , b [class "standout"] [text " (English please!)"]
      ]
      -- TODO: BBCode preview
    , inputTextArea "editsum" model.editsum Editsum [rows 4, cols 50, minlength 2, maxlength 5000, required True]
    ]
