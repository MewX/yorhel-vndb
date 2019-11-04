port module UList.Opt exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Task
import Process
import Browser
import Lib.Util exposing (..)
import Lib.Html exposing (..)
import Lib.Api as Api
import Gen.Types as T
import Gen.Api as GApi
import Gen.UListVNOpt as GVO
import Gen.UListDel as GDE

main : Program GVO.Send Model Msg
main = Browser.element
  { init = \f -> (init f, Cmd.none)
  , subscriptions = always Sub.none
  , view = view
  , update = update
  }

port ulistVNDeleted : Bool -> Cmd msg

type alias Model =
  { flags    : GVO.Send
  , del      : Bool
  , delState : Api.State
  }

init : GVO.Send -> Model
init f =
  { flags    = f
  , del      = False
  , delState = Api.Normal
  }

type Msg
  = Del Bool
  | Delete
  | Deleted GApi.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Del b -> ({ model | del = b }, Cmd.none)
    Delete -> ({ model | delState = Api.Loading }, Api.post "/u/ulist/del.json" (GDE.encode { uid = model.flags.uid, vid = model.flags.vid }) Deleted)
    Deleted GApi.Success -> (model, ulistVNDeleted True)
    Deleted e -> ({ model | delState = Api.Error e }, Cmd.none)


view : Model -> Html Msg
view model =
  let
    opt =
      [ tr []
        [ td [ colspan 5 ]
          [ textarea ([ placeholder "Notes", rows 2, cols 100 ] ++ GVO.valNotes) [ text model.flags.notes ]
          , div [ ]
            [ div [ class "spinner invisible" ] []
            , br_ 2
            , a [ href "#", onClickD (Del True) ] [ text "Remove VN" ]
            ]
          ]
        ]
      , tfoot []
        [ tr []
          [ td [ colspan 5 ] [ a [ href "#" ] [ text "Add release" ] ] ]
        ]
      ]

    rel i r =
      tr []
      [ if model.flags.own
        then td [ class "tco1" ] [ a [ href "#" ] [ text "remove" ] ]
        else text ""
      , td [ class "tco2" ] [ text <| Maybe.withDefault "status" <| lookup r.status T.rlistStatus ]
      , td [ class "tco3" ] [ text "2018-11-10" ]
      , td [ class "tco4" ] <| List.map langIcon r.lang ++ [ releaseTypeIcon r.rtype ]
      , td [ class "tco5" ] [ a [ href ("/r"++String.fromInt r.id), title r.original ] [ text r.title ] ]
      ]

    confirm =
      div []
      [ text "Are you sure you want to remove this visual novel from your list? "
      , a [ onClickD Delete ] [ text "Yes" ]
      , text " | "
      , a [ onClickD (Del False) ] [ text "Cancel" ]
      ]

  in case (model.del, model.delState) of
      (False, _) -> table [] <| (if model.flags.own then opt else []) ++ List.indexedMap rel model.flags.rels
      (_, Api.Normal)  -> confirm
      (_, Api.Loading) -> div [ class "spinner" ] []
      (_, Api.Error e) -> b [ class "standout" ] [ text <| "Error removing item: " ++ Api.showResponse e ]
