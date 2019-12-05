module Lib.TextPreview exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Encode as JE
import Lib.Html exposing (..)
import Lib.Ffi as Ffi
import Lib.Api as Api
import Gen.Api as GApi


type alias Model =
  { state   : Api.State
  , data    : String  -- contents of the textarea
  , preview : String  -- Rendered HTML, "" if not in sync with data
  , display : Bool    -- False = textarea is displayed, True = preview is displayed
  , apiUrl  : String
  , class   : String
  }


bbcode : String -> Model
bbcode data =
  { state   = Api.Normal
  , data    = data
  , preview = ""
  , display = False
  , apiUrl  = "/js/bbcode.json"
  , class   = "preview bbcode"
  }


markdown : String -> Model
markdown data =
  { state   = Api.Normal
  , data    = data
  , preview = ""
  , display = False
  , apiUrl  = "/js/markdown.json"
  , class   = "preview docs"
  }


type Msg
  = Edit String
  | TextArea
  | Preview
  | HandlePreview GApi.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Edit s   -> ({ model | preview = "", data = s, display = False, state = Api.Normal }, Cmd.none)
    TextArea -> ({ model | display = False }, Cmd.none)

    Preview ->
      if model.preview /= ""
      then ( { model | display = True }, Cmd.none)
      else ( { model | display = True, state = Api.Loading }
           , Api.post model.apiUrl (JE.object [("content", JE.string model.data)]) HandlePreview
           )

    HandlePreview (GApi.Content s) -> ({ model | state = Api.Normal, preview = s }, Cmd.none)
    HandlePreview r -> ({ model | state = Api.Error r }, Cmd.none)


view : String -> Model -> (Msg -> m) -> Int -> List (Attribute m) -> Html m
view name model cmdmap width attr =
  let
    display = model.display && model.preview /= ""
  in
    div [ class "textpreview", style "width" (String.fromInt width ++ "px") ]
    [ p (class "head" :: (if model.data == "" then [class "invisible"] else []))
      [ case model.state of
          Api.Loading -> span [ class "spinner" ] []
          Api.Error _ -> b [ class "grayedout" ] [ text "Error loading preview. " ]
          Api.Normal  -> text ""
      , if display
        then a [ onClickN (cmdmap TextArea) ] [ text "Edit" ]
        else i [] [text "Edit"]
      , if display
        then i [] [text "Preview"]
        else a [ onClickN (cmdmap Preview) ] [ text "Preview" ]
      ]
    , inputTextArea name model.data (cmdmap << Edit) (class (if display then "hidden" else "") :: attr)
    , if not display then text ""
      else div [ class model.class, Ffi.innerHtml model.preview ] []
    ]
