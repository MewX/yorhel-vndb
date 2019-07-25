module UVNList.Options exposing (main)

-- TODO: Actually implement the Edit form & remove functionality

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Browser
import Lib.Html exposing (..)


main : Program () Model Msg
main = Browser.element
  { init = always ((), Cmd.none)
  , subscriptions = always Sub.none
  , view = view
  , update = \_ _ -> ((), Cmd.none)
  }

type alias Msg = ()
type alias Model = ()

-- XXX: This dropdown thing relies on the fact that the JS code to find and
-- update dropdowns is run *after* all Elm objects have initialized, but this
-- is pretty fragile and may break if we ever update our view. This should be
-- made more reliable - either by making sure the dropdown-JS can handle DOM
-- changes or by moving the handling into Elm.
view : Model -> Html Msg
view model =
  div [class "dropdown"]
    [ a [href "#", class "more-button more-button--light dropdown__toggle d-block"]
      [ span [ class "more-button__dots" ] [] ]
    , div [class "dropdown-menu"]
      [ a [href "#", class "dropdown-menu__item"] [ text "Edit" ]
      , a [href "#", class "dropdown-menu__item"] [ text "Remove" ]
      ]
    ]
