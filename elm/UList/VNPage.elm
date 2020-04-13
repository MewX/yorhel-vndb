module UList.VNPage exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Browser
import Browser.Dom exposing (focus)
import Task
import Process
import Set
import Lib.Html exposing (..)
import Lib.Util exposing (..)
import Lib.Api as Api
import Lib.DropDown as DD
import Gen.Api as GApi
import Gen.UListVNNotes as GVN
import Gen.UListDel as GDE
import UList.LabelEdit as LE
import UList.VoteEdit as VE

-- We don't have a Gen.* module for this (yet), so define these manually
type alias RecvLabels =
  { id       : Int
  , label    : String
  , private  : Bool
  }

type alias Recv =
  { uid      : Int
  , vid      : Int
  , onlist   : Bool
  , canvote  : Bool
  , vote     : Maybe String
  , labels   : List RecvLabels
  , selected : List Int
  , notes    : String
  }


main : Program Recv Model Msg
main = Browser.element
  { init = \f -> (init f, Cmd.none)
  , subscriptions = \model -> Sub.batch [ Sub.map Labels (DD.sub model.labels.dd), Sub.map Vote (DD.sub model.vote.dd) ]
  , view = view
  , update = update
  }

type alias Model =
  { flags      : Recv
  , onlist     : Bool
  , del        : Bool
  , state      : Api.State -- For adding/deleting; Vote and label edit widgets have their own state
  , labels     : LE.Model
  , vote       : VE.Model
  , notes      : String
  , notesRev   : Int
  , notesState : Api.State
  , notesVis   : Bool
  }

init : Recv -> Model
init f =
  { flags      = f
  , onlist     = f.onlist
  , del        = False
  , state      = Api.Normal
  , labels     = LE.init { uid = f.uid, vid = f.vid, labels = f.labels, selected = f.selected }
  , vote       = VE.init { uid = f.uid, vid = f.vid, vote = f.vote }
  , notes      = f.notes
  , notesRev   = 0
  , notesState = Api.Normal
  , notesVis   = f.notes /= ""
  }

type Msg
  = Noop
  | Labels LE.Msg
  | Vote VE.Msg
  | NotesToggle
  | Notes String
  | NotesSave Int
  | NotesSaved Int GApi.Response
  | Del Bool
  | Delete
  | Deleted GApi.Response


setOnList : Model -> Model
setOnList model = { model | onlist = model.onlist || model.vote.ovote /= Nothing || not (Set.isEmpty model.labels.sel) || model.notes /= "" }

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Noop     -> (model, Cmd.none)
    Labels m -> let (nm, cmd) = LE.update m model.labels in (setOnList { model | labels = nm}, Cmd.map Labels cmd)
    Vote   m -> let (nm, cmd) = VE.update m model.vote   in (setOnList { model | vote   = nm}, Cmd.map Vote   cmd)

    NotesToggle ->
      ( { model | notesVis = not model.notesVis }
      , if model.notesVis then Cmd.none else Task.attempt (always Noop) (focus "uvn_notes"))
    Notes s ->
      if s == model.notes then (model, Cmd.none)
      else ( { model | notes = s, notesRev = model.notesRev + 1 }
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
          else (setOnList {model | flags = nf, notesState = Api.Normal }, Cmd.none)
    NotesSaved _ e -> ({ model | notesState = Api.Error e }, Cmd.none)

    Del b -> ({ model | del = b }, Cmd.none)
    Delete -> ({ model | state = Api.Loading }, GDE.send { uid = model.flags.uid, vid = model.flags.vid } Deleted)
    Deleted GApi.Success ->
      ( { model
        | state  = Api.Normal, onlist = False, del = False
        , labels = LE.init { uid = model.flags.uid, vid = model.flags.vid, labels = model.flags.labels, selected = [] }
        , vote   = VE.init { uid = model.flags.uid, vid = model.flags.vid, vote = Nothing }
        , notes  = "", notesVis = False
        }
      , Cmd.none)
    Deleted e -> ({ model | state = Api.Error e }, Cmd.none)


isPublic : Model -> Bool
isPublic model =
     LE.isPublic model.labels
  || (isJust model.vote.vote && List.any (\l -> l.id == 7 && not l.private) model.labels.labels)


view : Model -> Html Msg
view model =
  div [ class "ulistvn elm_dd_input" ]
  [ span [] <|
    case (model.state, model.del, model.onlist) of
      (Api.Loading, _, _) -> [ span [ class "spinner" ] [] ]
      (Api.Error e, _, _) -> [ b [ class "standout" ] [ text <| Api.showResponse e ] ]
      (Api.Normal, _, False) -> [ b [ class "grayedout" ] [ text "not on your list" ] ]
      (Api.Normal, True, _) ->
        [ a [ onClickD Delete ] [ text "Yes, delete" ]
        , text " | "
        , a [ onClickD (Del False) ] [ text "Cancel" ]
        ]
      (Api.Normal, False, True) ->
        [ span [ classList [("hidden", not (isPublic model))], title "This visual novel is on your public list" ] [ text "👁 " ]
        , text "On your list | "
        , a [ onClickD (Del True) ] [ text "Remove from list" ]
        ]
  , b [] [ text "User options" ]
  , table [ style "margin" "4px 0 0 0" ]
    [ tr [ class "odd" ]
      [ td [ class "key" ] [ text "My labels" ]
      , td [ colspan 2 ] [ Html.map Labels (LE.view model.labels "- select label -") ]
      ]
    , if model.flags.canvote || (Maybe.withDefault "-" model.flags.vote /= "-")
      then tr [ class "nostripe compact" ]
           [ td [] [ text "My vote" ]
           , td [ style "width" "80px" ] [ Html.map Vote (VE.view model.vote "- vote -") ]
           , td []
             [ a [ href "#", onClickD NotesToggle ] [ text "💬" ]
             , span [ class "spinner", classList [("hidden", model.notesState /= Api.Loading)] ] []
             , case model.notesState of
                 Api.Error e -> b [ class "standout" ] [ text <| Api.showResponse e ]
                 _ -> text ""
             ]
           ]
      else text ""
    , if model.notesVis
      then tr [ class "nostripe compact" ]
           [ td [] [ text "Notes" ]
           , td [ colspan 2 ]
             [ textarea ([ id "uvn_notes", placeholder "Notes", rows 2, cols 30, onInput Notes, onBlur (NotesSave model.notesRev)] ++ GVN.valNotes) [ text model.notes ] ]
           ]
      else text ""
    ]
  ]
