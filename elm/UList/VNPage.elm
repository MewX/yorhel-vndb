module UList.VNPage exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Browser
import Lib.Html exposing (..)
import Lib.Api as Api
import Lib.DropDown as DD
import Gen.Api as GApi
import Gen.UListDel as GDE
import Gen.UListAdd as GAD
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
  }


main : Program Recv Model Msg
main = Browser.element
  { init = \f -> (init f, Cmd.none)
  , subscriptions = \model -> Sub.map Labels (DD.sub model.labels.dd)
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
  }

init : Recv -> Model
init f =
  { flags      = f
  , onlist     = f.onlist
  , del        = False
  , state      = Api.Normal
  , labels     = LE.init { uid = f.uid, vid = f.vid, labels = f.labels, selected = f.selected }
  , vote       = VE.init { uid = f.uid, vid = f.vid, vote = f.vote }
  }

type Msg
  = Add
  | Added GApi.Response
  | Labels LE.Msg
  | Vote VE.Msg
  | Del Bool
  | Delete
  | Deleted GApi.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Labels m -> let (nm, cmd) = LE.update m model.labels in ({ model | labels = nm}, Cmd.map Labels cmd)
    Vote   m -> let (nm, cmd) = VE.update m model.vote   in ({ model | vote   = nm}, Cmd.map Vote   cmd)

    Add -> ({ model | state = Api.Loading }, Api.post "/u/ulist/add.json" (GAD.encode { uid = model.flags.uid, vid = model.flags.vid }) Added)
    Added GApi.Success -> ({ model | state = Api.Normal, onlist = True }, Cmd.none)
    Added e -> ({ model | state = Api.Error e }, Cmd.none)

    Del b -> ({ model | del = b }, Cmd.none)
    Delete -> ({ model | state = Api.Loading }, Api.post "/u/ulist/del.json" (GDE.encode { uid = model.flags.uid, vid = model.flags.vid }) Deleted)
    Deleted GApi.Success -> ({ model | state = Api.Normal, onlist = False, del = False }, Cmd.none)
    Deleted e -> ({ model | state = Api.Error e }, Cmd.none)


isPublic : Model -> Bool
isPublic model =
     LE.isPublic model.labels
  || (model.vote.text /= "" && model.vote.text /= "-" && List.any (\l -> l.id == 7 && not l.private) model.labels.labels)


view : Model -> Html Msg
view model =
  case model.state of
    Api.Loading -> div [ class "spinner" ] []
    Api.Error e -> b [ class "standout" ] [ text <| Api.showResponse e ]
    Api.Normal ->
      if not model.onlist
      then a [ href "#", onClickD Add ] [ text "Add to list" ]
      else if model.del
      then
        span []
        [ text "Sure you want to remove this VN from your list? "
        , a [ onClickD Delete ] [ text "Yes" ]
        , text " | "
        , a [ onClickD (Del False) ] [ text "Cancel" ]
        ]
      else
        table [ style "width" "100%" ]
        [ tr [ class "nostripe" ]
          [ td [ style "width" "70px" ] [ text "Labels:" ]
          , td [] [ Html.map Labels (LE.view model.labels) ]
          ]
        , if model.flags.canvote || (Maybe.withDefault "-" model.flags.vote /= "-")
          then tr [ class "nostripe" ]
               [ td [] [ text "Vote:" ]
               , td [ class "compact stealth" ] [ Html.map Vote (VE.view model.vote) ]
               ]
          else text ""
        , tr [ class "nostripe" ]
          [ td [ colspan 2 ]
            [ span [ classList [("invisible", not (isPublic model))], title "This visual novel is on your public list" ] [ text "👁 " ]
            , a [ onClickD (Del True) ] [ text "Remove from list" ]
            ]
          ]
        ]
