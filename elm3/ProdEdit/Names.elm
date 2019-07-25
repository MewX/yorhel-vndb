module ProdEdit.Names exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Dict
import Lib.Html exposing (..)
import Lib.Gen exposing (ProdEdit)
import Lib.Util exposing (..)


type alias Model =
  { name            : String
  , original        : String
  , alias           : String
  , aliasList       : List String
  , aliasDuplicates : Bool
  }


init : ProdEdit -> Model
init d =
  { name            = d.name
  , original        = d.original
  , alias           = d.alias
  , aliasList       = splitLn d.alias
  , aliasDuplicates = False
  }


new : Model
new =
  { name            = ""
  , original        = ""
  , alias           = ""
  , aliasList       = []
  , aliasDuplicates = False
  }


type Msg
  = Name String
  | Original String
  | Alias String


update : Msg -> Model -> Model
update msg model =
  case msg of
    Name s     -> { model | name = s }
    Original s -> { model | original = s }
    Alias s    ->
      { model
      | alias           = s
      , aliasList       = splitLn s
      , aliasDuplicates = hasDuplicates (model.name :: model.original :: splitLn s)
      }


view : Model -> List (Html Msg)
view model =
  [ cardRow "Name" Nothing <| formGroups
    [ [ label [for "name"] [text "Name (romaji)"]
      , inputText "name" model.name Name [required True, maxlength 200]
      ]
    , [ label [for "original"] [text "Original"]
      , inputText "original" model.original Original [maxlength 200]
      , div [class "form-group__help"] [text "The original name of this producer, leave blank if it already is in the Latin alphabet."]
      ]
    ]
  , cardRow "Aliases" Nothing <| formGroup
    [ inputTextArea "aliases" model.alias Alias
      [ rows 4, maxlength 500
      , classList [("is-invalid", model.aliasDuplicates)]
      ]
    , if model.aliasDuplicates
      then div [class "invalid-feedback"]
        [ text "There are duplicate aliases." ]
      else text ""
    , div [class "form-group__help"] [ text "(Un)official aliases, separated by a newline." ]
    ]
  ]
