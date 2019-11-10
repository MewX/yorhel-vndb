module UList.DateEdit exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Task
import Process
import Browser
import Lib.Api as Api
import Gen.Api as GApi
import Gen.UListDateEdit as GDE


main : Program GDE.Send Model Msg
main = Browser.element
  { init = \f -> (init f, Cmd.none)
  , subscriptions = always Sub.none
  , view = view
  , update = update
  }

type alias Model =
  { state   : Api.State
  , flags   : GDE.Send
  , val     : String
  , debnum  : Int -- Debounce for submit
  , visible : Bool
  }

init : GDE.Send -> Model
init f =
  { state   = Api.Normal
  , flags   = f
  , val     = f.date
  , debnum  = 0
  , visible = False
  }

type Msg
  = Show
  | Val String
  | Save Int
  | Saved GApi.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Show   -> ({ model | visible = True }, Cmd.none)
    Val s  -> ({ model | val = s, debnum = model.debnum + 1 }, Task.perform (\_ -> Save (model.debnum+1)) <| Process.sleep 500)

    Save n ->
      if n /= model.debnum || model.val == model.flags.date
      then (model, Cmd.none)
      else ( { model | state = Api.Loading, debnum = model.debnum+1 }
           , Api.post "/u/ulist/setdate.json" (GDE.encode { uid = model.flags.uid, vid = model.flags.vid, start = model.flags.start, date = model.val }) Saved )

    Saved GApi.Success ->
      let f  = model.flags
          nf = { f | date = model.val }
      in ({ model | state = Api.Normal, flags = nf }, Cmd.none)
    Saved e -> ({ model | state = Api.Error e }, Cmd.none)


view : Model -> Html Msg
view model = div (class "compact" :: if model.visible then [] else [onMouseOver Show]) <|
  case model.state of
    Api.Loading -> [ span [ class "spinner" ] [] ]
    Api.Error _ -> [ b [ class "standout" ] [ text "error" ] ] -- Argh
    Api.Normal ->
      [ if model.visible
        then input ([ type_ "date", class "text", value model.val, onInput Val, onBlur (Save model.debnum), pattern "yyyy-mm-dd" ] ++ GDE.valDate) []
        else text ""
      , span [] [ text model.val ]
      ]
