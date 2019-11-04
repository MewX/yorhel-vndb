port module UList.LabelEdit exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Task
import Process
import Browser
import Browser.Events as E
import Json.Decode as JD
import Set exposing (Set)
import Dict exposing (Dict)
import Lib.Html exposing (..)
import Lib.Api as Api
import Gen.Api as GApi
import Gen.LabelEdit as GLE


main : Program GLE.Recv Model Msg
main = Browser.element
  { init = \f -> (init f, Cmd.none)
  , subscriptions = \model -> if model.opened then E.onClick (JD.succeed (Open False)) else Sub.none
  , view = view
  , update = update
  }

port ulistLabelChanged : Bool -> Cmd msg

type alias Model =
  { uid      : Int
  , vid      : Int
  , labels   : List GLE.RecvLabels
  , sel      : Set Int -- Set of label IDs applied on the server
  , tsel     : Set Int -- Set of label IDs applied on the client
  , state    : Dict Int Api.State -- Only for labels that are being changed
  , opened   : Bool
  }

init : GLE.Recv -> Model
init f =
  { uid      = f.uid
  , vid      = f.vid
  , labels   = f.labels
  , sel      = Set.fromList f.selected
  , tsel     = Set.fromList f.selected
  , state    = Dict.empty
  , opened   = False
  }

type Msg
  = Redo Msg
  | Open Bool
  | Toggle Int Bool
  | Saved Int Bool GApi.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    -- 'Redo' will process the same message again after a very short timeout,
    -- this is used to overrule an 'Open False' triggered by the onClick
    -- subscription.
    Redo m -> (model, Cmd.batch [ Task.perform (\_ -> m) (Task.succeed ()), Task.perform (\_ -> m) (Process.sleep 0) ])
    Open b -> ({ model | opened = b }, Cmd.none)

    -- The 'opened = True' counters the onClick subscription that would have
    -- closed the dropdown, this works because that subscription triggers
    -- before the Toggle (I just hope this is well-defined, otherwise we need
    -- to use Redo for this one as well).
    Toggle l b ->
      ( { model
        | opened = True
        , tsel   = if b then Set.insert l model.tsel else Set.remove l model.tsel
        , state  = Dict.insert l Api.Loading model.state
        }
      , Api.post "/u/ulist/setlabel.json" (GLE.encode { uid = model.uid, vid = model.vid, label = l, applied = b }) (Saved l b)
      )

    Saved l b (GApi.Success) ->
      let nmodel = { model | sel = if b then Set.insert l model.sel else Set.remove l model.sel, state = Dict.remove l model.state }
          public = List.any (\lb -> lb.id /= 7 && not lb.private && Set.member lb.id nmodel.sel) nmodel.labels
       in (nmodel, ulistLabelChanged public)
    Saved l b e -> ({ model | state = Dict.insert l (Api.Error e) model.state }, Cmd.none)


view : Model -> Html Msg
view model =
  let
    str = String.join ", " <| List.filterMap (\l -> if Set.member l.id model.sel then Just l.label else Nothing) model.labels

    item l =
      let lid = "label_edit_" ++ String.fromInt model.vid ++ "_" ++ String.fromInt l.id
      in
        li [ class "linkradio" ]
        [ inputCheck lid (Set.member l.id model.tsel) (Toggle l.id)
        , label [ for lid ]
          [ text l.label
          , text " "
          , span [ class "spinner", classList [("invisible", Dict.get l.id model.state /= Just Api.Loading)] ] []
          , case Dict.get l.id model.state of
              Just (Api.Error _) -> b [ class "standout" ] [ text "error" ] -- Need something better
              _ -> text ""
          ]
        ]

    loading = List.any (\s -> s == Api.Loading) <| Dict.values model.state

  in
    div [ class "labeledit" ]
    [ a [ href "#", onClickD (Redo (Open (not model.opened))) ]
      [ text <| if str == "" then "-" else str
      , span []
        [ if loading && not model.opened
          then span [ class "spinner" ] []
          else i [] [ text "▾" ]
        ]
      ]
    , div []
      [ ul [ classList [("hidden", not model.opened)] ]
        <| List.map item <| List.filter (\l -> l.id /= 7) model.labels
      ]
    ]
