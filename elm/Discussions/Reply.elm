module Discussions.Reply exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Browser
import Browser.Navigation exposing (load)
import Lib.Html exposing (..)
import Lib.TextPreview as TP
import Lib.Api as Api
import Gen.Api as GApi
import Gen.DiscussionsReply as GDR


main : Program GDR.Recv Model Msg
main = Browser.element
  { init   = \e -> (init e, Cmd.none)
  , view   = view
  , update = update
  , subscriptions = always Sub.none
  }


type alias Model =
  { state  : Api.State
  , newurl : String
  , tid    : Int
  , msg    : TP.Model
  }


init : GDR.Recv -> Model
init d =
  { state  = Api.Normal
  , newurl = d.newurl
  , tid    = d.tid
  , msg    = TP.bbcode ""
  }


type Msg
  = Content TP.Msg
  | Submit
  | Submitted GApi.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Content m -> let (nm,nc) = TP.update m model.msg in ({ model | msg = nm }, Cmd.map Content nc)

    Submit ->
      let body = GDR.encode { msg = model.msg.data, tid = model.tid }
      in ({ model | state = Api.Loading }, Api.post "/t/reply.json" body Submitted)
    Submitted GApi.Success -> (model, load model.newurl)
    Submitted r -> ({ model | state = Api.Error r }, Cmd.none)


view : Model -> Html Msg
view model =
  form_ Submit (model.state == Api.Loading)
  [ div [ class "mainbox" ]
    [ fieldset [ class "submit" ]
      [ h2 [] [ text "Quick reply", b [ class "standout" ] [ text " (English please!)" ] ]
      , TP.view "msg" model.msg Content 600 ([rows 4, cols 50] ++ GDR.valMsg)
      , submitButton "Submit" model.state True
      ]
    ]
  ]
