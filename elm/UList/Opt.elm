port module UList.Opt exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Task
import Process
import Browser
import Date
import Lib.Util exposing (..)
import Lib.Html exposing (..)
import Lib.Api as Api
import Lib.RDate as RDate
import Lib.DropDown as DD
import Gen.Types as T
import Gen.Api as GApi
import Gen.UListVNOpt as GVO
import Gen.UListVNNotes as GVN
import Gen.UListDel as GDE
import Gen.UListRStatus as GRS

main : Program GVO.Recv Model Msg
main = Browser.element
  { init = \f -> (init f, Date.today |> Task.perform Today)
  , subscriptions = \model -> Sub.batch (List.map (\r -> DD.sub r.dd) <| model.rels)
  , view = view
  , update = update
  }

port ulistVNDeleted : Bool -> Cmd msg
port ulistNotesChanged : String -> Cmd msg
port ulistRelChanged : (Int, Int) -> Cmd msg

type alias Rel =
  { nfo    : GVO.RecvRels
  , status : Int -- Special value -1 means 'delete this release from my list'
  , state  : Api.State
  , dd     : DD.Config Msg
  }

type alias Model =
  { flags      : GVO.Recv
  , today      : Date.Date
  , del        : Bool
  , delState   : Api.State
  , notes      : String
  , notesRev   : Int
  , notesState : Api.State
  , rels       : List Rel
  }

init : GVO.Recv -> Model
init f =
  { flags      = f
  , today      = Date.fromOrdinalDate 2100 1
  , del        = False
  , delState   = Api.Normal
  , notes      = f.notes
  , notesRev   = 0
  , notesState = Api.Normal
  , rels       = List.map (\r ->
      { nfo = r, status = r.status, state = Api.Normal
      , dd = DD.init ("ulist_reldd" ++ String.fromInt f.vid ++ "_" ++ String.fromInt r.id) (RelOpen r.id)
      } ) f.rels
  }

type Msg
  = Today Date.Date
  | Del Bool
  | Delete
  | Deleted GApi.Response
  | Notes String
  | NotesSave Int
  | NotesSaved Int GApi.Response
  | RelOpen Int Bool
  | RelSet Int Int Bool
  | RelSaved Int Int GApi.Response


modrel : Int -> (Rel -> Rel) -> List Rel -> List Rel
modrel rid f = List.map (\r -> if r.nfo.id == rid then f r else r)


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Today d -> ({ model | today = d }, Cmd.none)

    Del b -> ({ model | del = b }, Cmd.none)
    Delete ->
      ( { model | delState = Api.Loading }
      , Api.post "/u/ulist/del.json" (GDE.encode { uid = model.flags.uid, vid = model.flags.vid }) Deleted)
    Deleted GApi.Success -> (model, ulistVNDeleted True)
    Deleted e -> ({ model | delState = Api.Error e }, Cmd.none)

    Notes s ->
      ( { model | notes = s, notesRev = model.notesRev + 1 }
      , Task.perform (\_ -> NotesSave (model.notesRev+1)) <| Process.sleep 1000)
    NotesSave rev ->
      if rev /= model.notesRev || model.notes == model.flags.notes
      then (model, Cmd.none)
      else ( { model | notesState = Api.Loading }
           , Api.post "/u/ulist/setnote.json" (GVN.encode { uid = model.flags.uid, vid = model.flags.vid, notes = model.notes }) (NotesSaved rev))
    NotesSaved rev GApi.Success ->
      let f = model.flags
          nf = { f | notes = model.notes }
       in if model.notesRev /= rev
          then (model, Cmd.none)
          else ({model | flags = nf, notesState = Api.Normal }, ulistNotesChanged model.notes)
    NotesSaved _ e -> ({ model | notesState = Api.Error e }, Cmd.none)

    RelOpen rid b -> ({ model | rels = modrel rid (\r -> { r | dd = DD.toggle r.dd b }) model.rels }, Cmd.none)
    RelSet rid st _ ->
      ( { model | rels = modrel rid (\r -> { r | dd = DD.toggle r.dd False, status = st, state = Api.Loading }) model.rels }
      , Api.post "/u/ulist/rstatus.json" (GRS.encode { uid = model.flags.uid, rid = rid, status = st }) (RelSaved rid st) )
    RelSaved rid st GApi.Success ->
      let nr = if st == -1 then List.filter (\r -> r.nfo.id /= rid) model.rels
                           else modrel rid (\r -> { r | state = Api.Normal }) model.rels
      in ( { model | rels = nr }
         , ulistRelChanged (List.length <| List.filter (\r -> r.status == 2) nr, List.length nr) )
    RelSaved rid _ e -> ({ model | rels = modrel rid (\r -> { r | state = Api.Error e }) model.rels }, Cmd.none)


view : Model -> Html Msg
view model =
  let
    opt =
      [ tr []
        [ td [ colspan 5 ]
          [ textarea ([ placeholder "Notes", rows 2, cols 80, onInput Notes, onBlur (NotesSave model.notesRev) ] ++ GVN.valNotes) [ text model.notes ]
          , div [ ]
            [ div [ class "spinner", classList [("invisible", model.notesState /= Api.Loading)] ] []
            , br [] []
            , case model.notesState of
                Api.Error e -> b [ class "standout" ] [ text <| Api.showResponse e ]
                _ -> text ""
            , br [] []
            , a [ href "#", onClickD (Del True) ] [ text "Remove VN" ]
            ]
          ]
        ]
      , tfoot []
        [ tr []
          [ td [ colspan 5 ] [ a [ href "#" ] [ text "Add release" ] ] ]
        ]
      ]

    rel r =
      let name = "ulist_relstatus" ++ String.fromInt model.flags.vid ++ "_" ++ String.fromInt r.nfo.id ++ "_"
      in
        tr []
        [ td [ class "tco1" ]
          [ DD.view r.dd r.state (text <| Maybe.withDefault "removing" <| lookup r.status T.rlistStatus)
            <| \_ ->
              [ ul [] <| List.map (\(n, status) ->
                  li [ class "linkradio" ]
                  [ inputCheck (name ++ String.fromInt n) (n == r.status) (RelSet r.nfo.id n)
                  , label [ for <| name ++ String.fromInt n ] [ text status ]
                  ]
                ) T.rlistStatus
                ++ [ li [] [ a [ href "#", onClickD (RelSet r.nfo.id -1 True) ] [ text "remove" ] ] ]
              ]
          ]
        , td [ class "tco2" ] [ RDate.display model.today r.nfo.released ]
        , td [ class "tco3" ] <| List.map langIcon r.nfo.lang ++ [ releaseTypeIcon r.nfo.rtype ]
        , td [ class "tco4" ] [ a [ href ("/r"++String.fromInt r.nfo.id), title r.nfo.original ] [ text r.nfo.title ] ]
        ]

    confirm =
      div []
      [ text "Are you sure you want to remove this visual novel from your list? "
      , a [ onClickD Delete ] [ text "Yes" ]
      , text " | "
      , a [ onClickD (Del False) ] [ text "Cancel" ]
      ]

  in case (model.del, model.delState) of
      (False, _) -> table [] <| (if model.flags.own then opt else []) ++ List.map rel model.rels
      (_, Api.Normal)  -> confirm
      (_, Api.Loading) -> div [ class "spinner" ] []
      (_, Api.Error e) -> b [ class "standout" ] [ text <| "Error removing item: " ++ Api.showResponse e ]
