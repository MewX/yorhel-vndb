module VNEdit.Titles exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Dict
import Lib.Html exposing (..)
import Lib.Gen exposing (..)
import Lib.Util exposing (..)


type alias Model =
  { title           : String
  , original        : String
  , alias           : String
  , aliasList       : List String
  , aliasDuplicates : Bool
  , aliasBad        : List String
  , aliasRel        : Dict.Dict String Bool
  }


init : VNEdit -> Model
init d =
  { title           = d.title
  , original        = d.original
  , alias           = d.alias
  , aliasList       = splitLn d.alias
  , aliasDuplicates = False
  , aliasBad        = []
  , aliasRel        = Dict.fromList <| List.map (\e -> (e,True)) <| List.map .title d.releases ++ List.map .original d.releases
  }


new : Model
new =
  { title           = ""
  , original        = ""
  , alias           = ""
  , aliasList       = []
  , aliasDuplicates = False
  , aliasBad        = []
  , aliasRel        = Dict.empty
  }


type Msg
  = Title String
  | Original String
  | Alias String


update : Msg -> Model -> Model
update msg model =
  case msg of
    Title s    -> { model | title = s }
    Original s -> { model | original = s }
    Alias s    ->
      let
        lst     = splitLn s
        check a = a == model.title || a == model.original || Dict.member a model.aliasRel
      in
        { model
        | alias           = s
        , aliasList       = lst
        , aliasDuplicates = hasDuplicates lst
        , aliasBad        = List.filter check lst
        }


view : Model -> List (Html Msg)
view model =
  [ cardRow "Title" Nothing <| formGroups
    [ [ label [for "title"] [text "Title (romaji)"]
      , inputText "title" model.title Title [required True, maxlength 250]
      ]
    , [ label [for "original"] [text "Original"]
      , inputText "original" model.original Original [maxlength 250]
      , div [class "form-group__help"] [text "The original title of this visual novel, leave blank if it already is in the Latin alphabet."]
      ]
    ]
  , cardRow "Aliases" Nothing <| formGroup
    [ inputTextArea "aliases" model.alias Alias
      [ rows 4, maxlength 500
      , classList [("is-invalid", model.aliasDuplicates || not (List.isEmpty model.aliasBad))]
      ]
    , if model.aliasDuplicates
      then div [class "invalid-feedback"]
        [ text "There are duplicate aliases." ]
      else text ""
    , if List.isEmpty model.aliasBad
      then text ""
      else  div [class "invalid-feedback"]
        [ text
          <| "The following aliases are already listed elsewhere and should be removed: "
          ++ String.join ", " model.aliasBad
        ]
    , div [class "form-group__help"]
      [ text "List of alternative titles or abbreviations. One line for each alias. Can include both official (japanese/english) titles and unofficial titles used around net."
      , br [] []
      , text "Titles that are listed in the releases should not be added here!"
      ]
    ]
  ]
