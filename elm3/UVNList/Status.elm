module UVNList.Status exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Encode as JE
import Browser
import Lib.Api as Api
import Lib.Html exposing (..)
import Lib.Util exposing (lookup)
import Lib.Gen as Gen


main : Program Flags Model Msg
main = Browser.element
  { init = \f -> (init f, Cmd.none)
  , subscriptions = always Sub.none
  , view = view
  , update = update
  }

type alias Flags =
  { uid    : Int
  , vid    : Int
  , status : Int
  }

type alias Model =
  { state : Api.State
  , flags : Flags
  }

init : Flags -> Model
init f =
  { state = Api.Normal
  , flags = f
  }


encodeForm : Model -> JE.Value
encodeForm o = JE.object
  [ ("uid",    JE.int o.flags.uid)
  , ("vid",    JE.int o.flags.vid)
  , ("status", JE.int o.flags.status) ]


type Msg
  = Input String
  | Saved Api.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Input s ->
      let flags = model.flags
          nflags = { flags | status = Maybe.withDefault 0 <| String.toInt s }
          nmodel = { model | flags = nflags, state = Api.Loading }
      in ( nmodel
         , Api.post "/u/setvnstatus" (encodeForm nmodel) Saved )

    Saved Gen.Success -> ({ model | state = Api.Normal  }, Cmd.none)
    Saved e           -> ({ model | state = Api.Error e }, Cmd.none)


view : Model -> Html Msg
view model =
  -- TODO: Display error somewhere
  if model.state == Api.Loading
  then div [ class "spinner spinner--md" ] []
  else div []
    [ text <| Maybe.withDefault "" <| lookup model.flags.status Gen.vnlistStatus
    , inputSelect
      [ class "form-control--table-edit form-control--table-edit-overlay", onInput Input ]
      (String.fromInt model.flags.status)
      (List.map (\(a,b) -> (String.fromInt a, b)) Gen.vnlistStatus)
    ]
