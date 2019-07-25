module DocEdit exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Browser
import Browser.Navigation exposing (load)
import Json.Encode as JE
import Lib.Html exposing (..)
import Lib.Gen exposing (..)
import Lib.Api as Api
import Lib.Ffi as Ffi
import Lib.Editsum as Editsum


main : Program DocEdit Model Msg
main = Browser.element
  { init   = \e -> (init e, Cmd.none)
  , view   = view
  , update = update
  , subscriptions = always Sub.none
  }


type alias Model =
  { state       : Api.State
  , editsum     : Editsum.Model
  , title       : String
  , content     : String
  , id          : Int
  , preview     : String
  }


init : DocEdit -> Model
init d =
  { state       = Api.Normal
  , editsum     = { authmod = True, editsum = d.editsum, locked = d.locked, hidden = d.hidden }
  , title       = d.title
  , content     = d.content
  , id          = d.id
  , preview     = ""
  }


encode : Model -> DocEditSend
encode model =
  { editsum     = model.editsum.editsum
  , hidden      = model.editsum.hidden
  , locked      = model.editsum.locked
  , title       = model.title
  , content     = model.content
  }


type Msg
  = Editsum Editsum.Msg
  | Submit
  | Submitted Api.Response
  | Title String
  | Content String
  | Preview
  | HandlePreview Api.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Editsum e -> ({ model | editsum = Editsum.update e model.editsum }, Cmd.none)
    Title s   -> ({ model | title   = s }, Cmd.none)
    Content s -> ({ model | content = s }, Cmd.none)

    Submit ->
      let
        path = "/d" ++ String.fromInt model.id ++ "/edit"
        body = doceditSendEncode (encode model)
      in ({ model | state = Api.Loading }, Api.post path body Submitted)

    Submitted (Api.Changed id rev) -> (model, load <| "/d" ++ String.fromInt id ++ "." ++ String.fromInt rev)
    Submitted r -> ({ model | state = Api.Error r }, Cmd.none)

    Preview ->
      ( { model | state = Api.Loading, preview = "" }
      , Api.post "/js/markdown.json" (JE.object [("content", JE.string model.content)]) HandlePreview
      )

    HandlePreview (Api.Content s) -> ({ model | state = Api.Normal, preview = s }, Cmd.none)
    HandlePreview r -> ({ model | state = Api.Error r }, Cmd.none)


view : Model -> Html Msg
view model =
  form_ Submit (model.state == Api.Loading)
    [ card "general" "General" [] <| formGroups
      [ [ label [ for "title" ] [ text "Title" ]
        , inputText "title" model.title Title [required True, maxlength 200]
        ]
      , [ label [ for "content" ] [ text "Content" ]
        , inputTextArea "content" model.content Content [rows 100, required True]
        ]
      , [ button [ type_ "button", class "btn", onClick Preview ] [ text "Preview" ]
        , div [ class "doc", Ffi.innerHtml model.preview ] []
        ]
      ]
    , Html.map Editsum (Editsum.view model.editsum)
    , submitButton "Submit" model.state True False
    ]
