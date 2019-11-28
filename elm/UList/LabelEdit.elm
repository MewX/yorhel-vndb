port module UList.LabelEdit exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Browser
import Set exposing (Set)
import Dict exposing (Dict)
import Lib.Html exposing (..)
import Lib.Api as Api
import Lib.DropDown as DD
import Gen.Api as GApi
import Gen.UListLabelEdit as GLE


main : Program GLE.Recv Model Msg
main = Browser.element
  { init = \f -> (init f, Cmd.none)
  , subscriptions = \model -> DD.sub model.dd
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
  , dd       : DD.Config Msg
  }

init : GLE.Recv -> Model
init f =
  { uid      = f.uid
  , vid      = f.vid
  , labels   = f.labels
  , sel      = Set.fromList f.selected
  , tsel     = Set.fromList f.selected
  , state    = Dict.empty
  , dd       = DD.init ("ulist_labeledit_dd" ++ String.fromInt f.vid) Open
  }

type Msg
  = Open Bool
  | Toggle Int Bool
  | Saved Int Bool GApi.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Open b -> ({ model | dd = DD.toggle model.dd b }, Cmd.none)

    Toggle l b ->
      ( { model
        | tsel   = if b then Set.insert l model.tsel else Set.remove l model.tsel
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
      li [ ]
      [ linkRadio (Set.member l.id model.tsel) (Toggle l.id)
        [ text l.label
        , text " "
        , span [ class "spinner", classList [("invisible", Dict.get l.id model.state /= Just Api.Loading)] ] []
        , case Dict.get l.id model.state of
            Just (Api.Error _) -> b [ class "standout" ] [ text "error" ] -- Need something better
            _ -> text ""
        ]
      ]
  in
    DD.view model.dd
      (if List.any (\s -> s == Api.Loading) <| Dict.values model.state then Api.Loading else Api.Normal)
      (text <| if str == "" then "-" else str)
      (\_ -> [ ul [] <| List.map item <| List.filter (\l -> l.id /= 7) model.labels ])
