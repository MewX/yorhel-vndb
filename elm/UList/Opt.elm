port module UList.Opt exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Task
import Process
import Browser
import Date
import Dict exposing (Dict)
import Lib.Util exposing (..)
import Lib.Html exposing (..)
import Lib.Api as Api
import Lib.RDate as RDate
import Lib.DropDown as DD
import Gen.Types as T
import Gen.Api as GApi
import Gen.UListVNNotes as GVN
import Gen.UListDel as GDE
import Gen.UListRStatus as GRS
import Gen.Release as GR

main : Program GVN.Recv Model Msg
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
  { id     : Int
  , status : Int -- Special value -1 means 'delete this release from my list'
  , state  : Api.State
  , dd     : DD.Config Msg
  }

newrel : Int -> Int -> Int -> Rel
newrel rid vid st =
  { id     = rid
  , status = st
  , state  = Api.Normal
  , dd     = DD.init ("ulist_reldd" ++ String.fromInt vid ++ "_" ++ String.fromInt rid) (RelOpen rid)
  }

type alias Model =
  { flags      : GVN.Recv
  , today      : Date.Date
  , del        : Bool
  , delState   : Api.State
  , notes      : String
  , notesRev   : Int
  , notesState : Api.State
  , rels       : List Rel
  , relNfo     : Dict Int GApi.ApiReleases
  , relOptions : Maybe (List (Int, String))
  , relState   : Api.State
  }

init : GVN.Recv -> Model
init f =
  { flags      = f
  , today      = Date.fromOrdinalDate 2100 1
  , del        = False
  , delState   = Api.Normal
  , notes      = f.notes
  , notesRev   = 0
  , notesState = Api.Normal
  , rels       = List.map2 (\st nfo -> newrel nfo.id f.vid st) f.relstatus f.rels
  , relNfo     = Dict.fromList <| List.map (\r -> (r.id, r)) f.rels
  , relOptions = Nothing
  , relState   = Api.Normal
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
  | RelLoad
  | RelLoaded GApi.Response
  | RelAdd Int


modrel : Int -> (Rel -> Rel) -> List Rel -> List Rel
modrel rid f = List.map (\r -> if r.id == rid then f r else r)


showrel : GApi.ApiReleases -> String
showrel r = "[" ++ (RDate.format (RDate.expand r.released)) ++ " " ++ (String.join "," r.lang) ++ "] " ++ r.title ++ " (r" ++ String.fromInt r.id ++ ")"


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Today d -> ({ model | today = d }, Cmd.none)

    Del b -> ({ model | del = b }, Cmd.none)
    Delete ->
      ( { model | delState = Api.Loading }
      , GDE.send { uid = model.flags.uid, vid = model.flags.vid } Deleted)
    Deleted GApi.Success -> (model, ulistVNDeleted True)
    Deleted e -> ({ model | delState = Api.Error e }, Cmd.none)

    Notes s ->
      ( { model | notes = s, notesRev = model.notesRev + 1 }
      , Task.perform (\_ -> NotesSave (model.notesRev+1)) <| Process.sleep 1000)
    NotesSave rev ->
      if rev /= model.notesRev || model.notes == model.flags.notes
      then (model, Cmd.none)
      else ( { model | notesState = Api.Loading }
           , GVN.send { uid = model.flags.uid, vid = model.flags.vid, notes = model.notes } (NotesSaved rev))
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
      , GRS.send { uid = model.flags.uid, rid = rid, status = st } (RelSaved rid st) )
    RelSaved rid st GApi.Success ->
      let nr = if st == -1 then List.filter (\r -> r.id /= rid) model.rels
                           else modrel rid (\r -> { r | state = Api.Normal }) model.rels
      in ( { model | rels = nr }
         , ulistRelChanged (List.length <| List.filter (\r -> r.status == 2) nr, List.length nr) )
    RelSaved rid _ e -> ({ model | rels = modrel rid (\r -> { r | state = Api.Error e }) model.rels }, Cmd.none)

    RelLoad ->
      ( { model | relState = Api.Loading }
      , GR.send { vid = model.flags.vid } RelLoaded )
    RelLoaded (GApi.Releases rels) ->
      ( { model
        | relState = Api.Normal
        , relNfo = Dict.union (Dict.fromList <| List.map (\r -> (r.id, r)) rels) model.relNfo
        , relOptions = Just <| List.map (\r -> (r.id, showrel r)) rels
        }, Cmd.none)
    RelLoaded e -> ({ model | relState = Api.Error e }, Cmd.none)
    RelAdd rid ->
      ( { model | rels = model.rels ++ (if rid == 0 then [] else [newrel rid model.flags.vid 2]) }
      , Task.perform (RelSet rid 2) <| Task.succeed True)


view : Model -> Html Msg
view model =
  let
    opt =
      [ tr []
        [ td [ colspan 5 ]
          [ textarea (
              [ placeholder "Notes", rows 2, cols 80
              , onInput Notes, onBlur (NotesSave model.notesRev)
              ] ++ GVN.valNotes
            ) [ text model.notes ]
          , div [ ] <|
            [ div [ class "spinner", classList [("hidden", model.notesState /= Api.Loading)] ] []
            , a [ href "#", onClickD (Del True) ] [ text "Remove VN" ]
            ] ++ (
              if model.relOptions == Nothing
              then [ text " | ", a [ href "#", onClickD RelLoad ] [ text "Add release" ] ]
              else []
            ) ++ (
              case model.notesState of
                Api.Error e -> [ br [] [], b [ class "standout" ] [ text <| Api.showResponse e ] ]
                _ -> []
            )
          ]
        ]
      , if model.relOptions == Nothing && model.relState == Api.Normal
        then text ""
        else tfoot []
        [ tr []
          [ td [ colspan 5 ] <|
            -- TODO: This <select> solution is ugly as hell, a Lib.DropDown-based solution would be nicer.
            -- Or just throw all releases in the table and use the status field for add stuff.
            case (model.relOptions, model.relState) of
              (Just opts, _)   -> [ inputSelect "" 0 RelAdd [ style "width" "500px" ]
                                    <| (0, "-- add release --") :: List.filter (\(rid,_) -> not <| List.any (\r -> r.id == rid) model.rels) opts ]
              (_, Api.Normal)  -> []
              (_, Api.Loading) -> [ span [ class "spinner" ] [], text "Loading releases..." ]
              (_, Api.Error e) -> [ b [ class "standout" ] [ text <| Api.showResponse e ], text ". ", a [ href "#", onClickD RelLoad ] [ text "Try again" ] ]
          ]
        ]
      ]

    rel r =
      case Dict.get r.id model.relNfo of
        Nothing -> text ""
        Just nfo -> relnfo r nfo

    relnfo r nfo =
      tr []
      [ td [ class "tco1" ]
        [ DD.view r.dd r.state (text <| Maybe.withDefault "removing" <| lookup r.status T.rlistStatus)
          <| \_ ->
            [ ul [] <| List.map (\(n, status) ->
                li [ ] [ linkRadio (n == r.status) (RelSet r.id n) [ text status ] ]
              ) T.rlistStatus
              ++ [ li [] [ a [ href "#", onClickD (RelSet r.id -1 True) ] [ text "remove" ] ] ]
            ]
        ]
      , td [ class "tco2" ] [ RDate.display model.today nfo.released ]
      , td [ class "tco3" ]
        <| List.map platformIcon nfo.platforms
        ++ List.map langIcon nfo.lang
        ++ [ releaseTypeIcon nfo.rtype ]
      , td [ class "tco4" ] [ a [ href ("/r"++String.fromInt nfo.id), title nfo.original ] [ text nfo.title ] ]
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
