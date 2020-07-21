-- This module provides an the 'Edit summary' box, including the 'hidden' and
-- 'locked' moderation checkboxes.

module Lib.Editsum exposing (Model, Msg, new, update, view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Lib.Html exposing (..)
import Lib.TextPreview as TP


type alias Model =
  { authmod  : Bool
  , locked   : Bool
  , hidden   : Bool
  , editsum  : TP.Model
  }


type Msg
  = Locked Bool
  | Hidden Bool
  | Editsum TP.Msg


new : Model
new =
  { authmod = False
  , locked  = False
  , hidden  = False
  , editsum = TP.bbcode ""
  }


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Locked b  -> ({ model | locked  = b }, Cmd.none)
    Hidden b  -> ({ model | hidden  = b }, Cmd.none)
    Editsum m -> let (nm,nc) = TP.update m model.editsum in ({ model | editsum = nm }, Cmd.map Editsum nc)


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
      , if model.hidden
        then span [] [ text "Note: edit summary of the last edit should indicate the reason for the deletion.", br [] [] ]
        else text ""
      ]
  in fieldset [] <|
    (if model.authmod then lockhid else [])
    ++
    [ TP.view "" model.editsum Editsum 600 [rows 4, cols 50, minlength 2, maxlength 5000, required True]
      [ b [class "title"] [ text "Edit summary", b [class "standout"] [ text " (English please!)" ] ]
      , br [] []
      , text "Summarize the changes you have made, including links to source(s)."
      ]
    ]
