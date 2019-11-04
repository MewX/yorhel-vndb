module UList.Opt exposing (main)

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


main : Program GVO.Send Model Msg
main = Browser.element
  { init = \f -> (init f, Cmd.none)
  , subscriptions = always Sub.none
  , view = view
  , update = update
  }

type alias Model =
  { state  : Api.State
  , flags  : GVO.Send
  , del    : Bool
  }

init : GVO.Send -> Model
init f =
  { state  = Api.Normal
  , flags  = f
  , del    = False
  }

type Msg
  = Del Bool


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Del b -> ({ model | del = b }, Cmd.none)


view : Model -> Html Msg
view model =
  let
    opt =
      [ tr []
        [ td [ colspan 5 ]
          [ textarea ([ placeholder "Notes", rows 2, cols 100 ] ++ GVO.valNotes) [ text model.flags.notes ]
          , div [ ]
            [ div [ class "spinner" ] []
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

  in table [] <| (if model.flags.own then opt else []) ++ List.indexedMap rel model.flags.rels
