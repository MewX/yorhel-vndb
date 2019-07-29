module UVNList.Vote exposing (main)

-- XXX: There's some unobvious and unintuitive behavior when removing a vote:
-- If the VN isn't also in the user's 'vnlist', then the VN entry will be
-- removed from the user's list and this is only visible on a page refresh. A
-- clean solution to this is to merge the 'votes' and 'vnlist' tables so that
-- there's always a 'vnlist' entry that remains. This is best done after VNDBv2
-- has been decommissioned.

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Encode as JE
import Browser
import Regex
import Lib.Api as Api
import Lib.Gen as Gen


main : Program Flags Model Msg
main = Browser.element
  { init = \f -> (init f, Cmd.none)
  , subscriptions = always Sub.none
  , view = view
  , update = update
  }

type alias Flags =
  { uid  : Int
  , vid  : Int
  , vote : String
  }

type alias Model =
  { state : Api.State
  , flags : Flags
  , text  : String
  , valid : Bool
  }

init : Flags -> Model
init f =
  { state = Api.Normal
  , flags = f
  , text  = f.vote
  , valid = True
  }


encodeForm : Model -> JE.Value
encodeForm o = JE.object
  [ ("uid",  JE.int o.flags.uid)
  , ("vid",  JE.int o.flags.vid)
  , ("vote", JE.string o.text) ]


type Msg
  = Input String
  | Save
  | Saved Api.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Input s ->
      ( { model | text = s
        , valid = Regex.contains (Maybe.withDefault Regex.never <| Regex.fromString Gen.vnvotePattern) s
        }
      , Cmd.none
      )

    Save ->
      if model.valid && model.text /= model.flags.vote
      then ( { model | state = Api.Loading }
           , Api.post "/u/setvote" (encodeForm model) Saved )
      else (model, Cmd.none)

    Saved Gen.Success ->
      let flags = model.flags
          nflags = { flags | vote = model.text }
      in ({ model | flags = nflags, state = Api.Normal }, Cmd.none)

    Saved e -> ({ model | state = Api.Error e }, Cmd.none)


view : Model -> Html Msg
view model =
  -- TODO: Display error somewhere
  -- TODO: Save when pressing enter
  if model.state == Api.Loading
  then
    div [ class "spinner spinner--md" ] []
  else
    input
      [ type_ "text"
      , pattern Gen.vnvotePattern
      , class "form-control form-control--table-edit form-control--stealth"
      , classList [("is-invalid", not model.valid)]
      , value model.text
      , onInput Input
      , onBlur Save
      ] []
