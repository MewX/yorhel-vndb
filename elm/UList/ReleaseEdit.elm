module UList.ReleaseEdit exposing (main, init, update, view, Model, Msg(..))

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Browser
import Lib.Util exposing (..)
import Lib.Html exposing (..)
import Lib.Api as Api
import Lib.DropDown as DD
import Gen.Types exposing (rlistStatus)
import Gen.Api as GApi
import Gen.UListRStatus as GRS


main : Program GRS.Send Model Msg
main = Browser.element
  { init = \f -> (init 0 f, Cmd.none)
  , subscriptions = \model -> DD.sub model.dd
  , view = view
  , update = update
  }

type alias Model =
  { uid      : Int
  , rid      : Int
  , status   : Maybe Int
  , state    : Api.State
  , dd       : DD.Config Msg
  }

init : Int -> GRS.Send -> Model
init vid f =
  { uid      = f.uid
  , rid      = f.rid
  , status   = f.status
  , state    = Api.Normal
  , dd       = DD.init ("ulist_reldd" ++ String.fromInt vid ++ "_" ++ String.fromInt f.rid) Open
  }

type Msg
  = Open Bool
  | Set (Maybe Int) Bool
  | Saved GApi.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Open b -> ({ model | dd = DD.toggle model.dd b }, Cmd.none)
    Set st _ ->
      ( { model | dd = DD.toggle model.dd False, status = st, state = Api.Loading }
      , GRS.send { uid = model.uid, rid = model.rid, status = st } Saved )

    Saved GApi.Success -> ({ model | state = Api.Normal }, Cmd.none)
    Saved e -> ({ model | state = Api.Error e }, Cmd.none)


view : Model -> Html Msg
view model =
  DD.view model.dd model.state
    (text <| Maybe.withDefault "not on your list" <| Maybe.andThen (\s -> lookup s rlistStatus) model.status)
    <| \_ ->
      [ ul [] <| List.map (\(n, status) ->
          li [ ] [ linkRadio (Just n == model.status) (Set (Just n)) [ text status ] ]
        ) rlistStatus
        ++ [ li [] [ a [ href "#", onClickD (Set Nothing True) ] [ text "remove" ] ] ]
      ]
