module Reviews.Vote exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Browser
import Lib.Util exposing (..)
import Lib.Html exposing (..)
import Lib.Api as Api
import Gen.Api as GApi
import Gen.ReviewsVote as GRV


main : Program GRV.Recv Model Msg
main = Browser.element
  { init = \d -> (init d, Cmd.none)
  , subscriptions = always Sub.none
  , view = view
  , update = update
  }

type alias Model =
  { state    : Api.State
  , id       : String
  , my       : Maybe Bool
  , up       : Int
  , down     : Int
  }

init : GRV.Recv -> Model
init d =
  { state    = Api.Normal
  , id       = d.id
  , my       = d.my
  , up       = d.up
  , down     = d.down
  }

type Msg
  = Vote Bool
  | Saved GApi.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Vote b ->
      let nm = case (model.my, b) of
                (Nothing,    True)  -> { model | my = Just b,  up = model.up+1                      }
                (Nothing,    False) -> { model | my = Just b                  , down = model.down+1 }
                (Just True,  False) -> { model | my = Just b,  up = model.up-1, down = model.down+1 }
                (Just False, True)  -> { model | my = Just b,  up = model.up+1, down = model.down-1 }
                (Just True,  True)  -> { model | my = Nothing, up = model.up-1                      }
                (Just False, False) -> { model | my = Nothing                 , down = model.down-1 }
      in ({ nm | state = Api.Loading }, GRV.send { id = nm.id, my = nm.my } Saved)

    Saved GApi.Success -> ({ model | state = Api.Normal }, Cmd.none)
    Saved e -> ({ model | state = Api.Error e }, Cmd.none)


view : Model -> Html Msg
view model =
  let but opt lbl = a [ href "#", onClickD (Vote opt), classList [("votebut", True), ("myvote", model.my == Just opt)] ] [ text lbl ]
  in
  span []
  [ case model.state of
      Api.Loading -> span [ class "spinner" ] []
      Api.Error e -> b [ class "standout" ] [ text (Api.showResponse e) ]
      Api.Normal  -> if model.my == Nothing then text "Was this review helpful? " else text ""
  , but True ("👍 " ++ String.fromInt model.up)
  , text " "
  , but False ("👎 " ++ String.fromInt model.down)
  ]
