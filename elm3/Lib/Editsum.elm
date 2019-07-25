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
    lockhid = cardRow "Mod actions" Nothing <| formGroups
      [ [ label [ class "checkbox" ]
          [ inputCheck "" model.locked Locked
          , text " Locked" ]
        ]
      , [ label [ class "checkbox" ]
          [ inputCheck "" model.hidden Hidden
          , text " Hidden" ]
        ]
      ]
  in card_
    [ lockhid
    , cardRow "Edit summary" (Just "English please!")
      <| formGroup [ inputTextArea "" model.editsum Editsum [rows 4, minlength 2, maxlength 5000, required True] ]
    ]
