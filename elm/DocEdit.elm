module DocEdit exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Browser
import Browser.Navigation exposing (load)
import Json.Encode as JE
import Lib.Html exposing (..)
import Lib.Api as Api
import Lib.Ffi as Ffi
import Lib.Editsum as Editsum
import Gen.Api as GApi
import Gen.DocEdit as GD


main : Program GD.Recv Model Msg
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


init : GD.Recv -> Model
init d =
  { state       = Api.Normal
  , editsum     = { authmod = True, editsum = d.editsum, locked = d.locked, hidden = d.hidden }
  , title       = d.title
  , content     = d.content
  , id          = d.id
  , preview     = ""
  }


encode : Model -> GD.Send
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
  | Submitted GApi.Response
  | Title String
  | Content String
  | Preview
  | HandlePreview GApi.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Editsum e -> ({ model | editsum = Editsum.update e model.editsum }, Cmd.none)
    Title s   -> ({ model | title   = s }, Cmd.none)
    Content s -> ({ model | content = s }, Cmd.none)

    Submit ->
      let
        path = "/d" ++ String.fromInt model.id ++ "/edit"
        body = GD.encode (encode model)
      in ({ model | state = Api.Loading }, Api.post path body Submitted)

    Submitted (GApi.Changed id rev) -> (model, load <| "/d" ++ String.fromInt id ++ "." ++ String.fromInt rev)
    Submitted r -> ({ model | state = Api.Error r }, Cmd.none)

    Preview ->
      if model.preview /= "" then ( { model | preview = "" }, Cmd.none )
      else
        ( { model | state = Api.Loading, preview = "" }
        , Api.post "/js/markdown.json" (JE.object [("content", JE.string model.content)]) HandlePreview
        )

    HandlePreview (GApi.Content s) -> ({ model | state = Api.Normal, preview = s }, Cmd.none)
    HandlePreview r -> ({ model | state = Api.Error r }, Cmd.none)


view : Model -> Html Msg
view model =
  Html.form [ onSubmit Submit ]
    [ div [ class "mainbox" ]
      [ h1 [] [ text <| "Edit d" ++ String.fromInt model.id ]
      , table [ class "formtable" ]
        [ formField "title::Title" [ inputText "title" model.title Title (style "width" "300px" :: GD.valTitle) ]
        , formField "none"
          [ br_ 1
          , b [] [ text "Contents" ]
          , br_ 1
          , text "HTML and MultiMarkdown supported, which is "
          , a [ href "https://daringfireball.net/projects/markdown/basics", target "_blank" ] [ text "Markdown" ]
          , text " with some "
          , a [ href "http://fletcher.github.io/MultiMarkdown-5/syntax.html", target "_blank" ][ text "extensions" ]
          , text "."
          , a [ href "#", style "float" "right", onClickN Preview ]
            [ text <| if model.preview == "" then "Preview" else "Edit"
            , if model.state == Api.Loading then div [ class "spinner" ] [] else text ""
            ]
          , br_ 1
          , if model.preview == ""
            then inputTextArea "content" model.content Content ([rows 50, cols 90, style "width" "850px"] ++ GD.valContent)
            else div [ class "docs preview", style "width" "850px", Ffi.innerHtml model.preview ] []
          ]
        ]
      ]
    , div [ class "mainbox" ]
      [ fieldset [ class "submit" ]
        [ Html.map Editsum (Editsum.view model.editsum)
        , submitButton "Submit" model.state True False
        ]
      ]
    ]
