module ProdEdit.General exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Lib.Html exposing (..)
import Lib.Gen exposing (languages, weburlPattern, producerTypes, ProdEdit)
import Lib.Util exposing (..)


type alias Model =
  { desc    : String
  , l_wp    : String
  , lang    : String
  , ptype   : String
  , website : String
  }


init : ProdEdit -> Model
init d =
  { desc    = d.desc
  , l_wp    = d.l_wp
  , lang    = d.lang
  , ptype   = d.ptype
  , website = d.website
  }


new : Model
new =
  { desc    = ""
  , l_wp    = ""
  , lang    = "ja"
  , ptype   = "co"
  , website = ""
  }


type Msg
  = Desc String
  | LWP String
  | Lang String
  | PType String
  | Website String


update : Msg -> Model -> Model
update msg model =
  case msg of
    Desc s    -> { model | desc    = s }
    LWP s     -> { model | l_wp    = s }
    Lang s    -> { model | lang    = s }
    PType s   -> { model | ptype   = s }
    Website s -> { model | website = s }


view : Model -> (Msg -> a) -> List (Html a) -> Html a
view model wrap names = card "general" "General info" [] <|
  names ++ List.map (Html.map wrap)
  [ cardRow "Meta" Nothing <| formGroups
    [ [ label [for "ptype"] [ text "Type" ]
      , inputSelect [id "ptype", name "ptype", onInput PType] model.ptype producerTypes
      ]
    , [ label [for "lang"] [ text "Primary language" ]
      , inputSelect [id "lang", name "lang", onInput Lang] model.lang languages
      ]
    , [ label [for "website"] [ text "Official Website" ]
      , inputText "website" model.website Website [pattern weburlPattern]
      ]
    , [ label [] [ text "Wikipedia" ]
      , p [] [ text "https://en.wikipedia.org/wiki/", inputText "l_wp" model.l_wp LWP [class "form-control--inline", maxlength 100] ]
      ]
    ]

  , cardRow "Description" (Just "English please!") <| formGroup
    [ inputTextArea "desc" model.desc Desc [rows 8] ]
  ]
