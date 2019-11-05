port module UList.VoteEdit exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as JD
import Browser
import Task
import Lib.Html exposing (..)
import Lib.Api as Api
import Lib.Ffi as Ffi
import Gen.Api as GApi
import Gen.UListVoteEdit as GVE


main : Program GVE.Send Model Msg
main = Browser.element
  { init = \f -> (init f, Cmd.none)
  , subscriptions = always Sub.none
  , view = view
  , update = update
  }

port ulistVoteChanged : Bool -> Cmd msg

type alias Model =
  { state   : Api.State
  , flags   : GVE.Send
  , text    : String
  , valid   : Bool
  , fieldId : String
  }

init : GVE.Send -> Model
init f =
  { state   = Api.Normal
  , flags   = f
  , text    = Maybe.withDefault "-" f.vote
  , valid   = True
  , fieldId = "vote_edit_" ++ String.fromInt f.vid
  }

type Msg
  = Input String Bool
  | Noop
  | Focus
  | Save
  | Saved GApi.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Input s b -> ({ model | text = String.replace "," "." s, valid = b }, Cmd.none)
    Noop  -> (model, Cmd.none)
    Focus -> ( { model | text = if model.text == "-" then "" else model.text }
             , Task.attempt (always Noop) <| Ffi.elemCall "select" model.fieldId )

    Save ->
      let nmodel = { model | text = if model.text == "" then "-" else model.text }
      in if nmodel.valid && (Just nmodel.text) /= nmodel.flags.vote
         then ( { nmodel | state = Api.Loading }
              , Api.post "/u/ulist/setvote.json" (GVE.encode { uid = model.flags.uid, vid = model.flags.vid, vote = Just model.text }) Saved )
         else (nmodel, Task.attempt (always Noop) <| Ffi.elemCall "reportValidity" model.fieldId)

    Saved GApi.Success ->
      let flags = model.flags
          nflags = { flags | vote = Just model.text }
      in ({ model | flags = nflags, state = Api.Normal }, ulistVoteChanged (model.text /= "" && model.text /= "-"))
    Saved e -> ({ model | state = Api.Error e }, Cmd.none)


view : Model -> Html Msg
view model =
  case model.state of
    Api.Loading -> div [ class "spinner" ] []
    Api.Error _ -> b [ class "standout" ] [ text "error" ] -- Need something more informative and actionable, meh...
    Api.Normal ->
      input (
        [ type_ "text"
        , class "text"
        , id model.fieldId
        , value model.text
        , onInputValidation Input
        , onBlur Save
        , onFocus Focus
        , placeholder "7.5"
        , custom "keydown" -- Grab enter key
          <| JD.andThen (\c -> if c == "Enter" then JD.succeed { preventDefault = True, stopPropagation = True, message = Save } else JD.fail "")
          <| JD.field "key" JD.string
        ]
        ++ GVE.valVote
      ) []
