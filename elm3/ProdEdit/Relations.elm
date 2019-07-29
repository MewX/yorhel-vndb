module ProdEdit.Relations exposing (Model, Msg, init, update, view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Lib.Html exposing (..)
import Lib.Gen as Gen
import Lib.Util exposing (..)
import Lib.Autocomplete as A


type alias Model =
  { relations  : List Gen.ProdEditRelations
  , search     : A.Model Gen.ApiProducerResult
  , duplicates : Bool
  }


init : List Gen.ProdEditRelations -> Model
init l =
  { relations  = l
  , search     = A.init
  , duplicates = False
  }


type Msg
  = Del Int
  | Rel Int String
  | Search (A.Msg Gen.ApiProducerResult)


searchConfig : A.Config Msg Gen.ApiProducerResult
searchConfig = { wrap = Search, id = "add-relation", source = A.producerSource }


validate : Model -> Model
validate model = { model | duplicates = hasDuplicates <| List.map .pid model.relations }


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Del i        -> (validate { model | relations = delidx i model.relations }, Cmd.none)
    Rel i s      -> (validate { model | relations = modidx i (\e -> { e | relation = s }) model.relations }, Cmd.none)
    Search m ->
      let (nm, c, res) = A.update searchConfig m model.search
      in case res of
        Nothing -> ({ model | search = nm }, c)
        Just r  ->
          let
            rel = List.head Gen.producerRelations |> Maybe.map Tuple.first |> Maybe.withDefault ""
            nrow = { pid = r.id, relation = rel, name = r.name }
          in (validate { model | search = A.clear nm, relations = model.relations ++ [nrow] }, c)


view : Model -> Html Msg
view model =
  let
    entry n e = editListRow "row--ai-center"
      [ editListField 1 "single-line"
        [ a [href <| "/p" ++ String.fromInt e.pid, title e.name, target "_blank" ] [text e.name ] ]
      , editListField 1 ""
        [ inputSelect [onInput (Rel n)] e.relation Gen.producerRelations ]
      , editListField 0 "" [ removeButton (Del n) ]
      ]

  in card "relations" "Relations" [] <|
  editList (List.indexedMap entry model.relations)
  ++ formGroups (
    (if model.duplicates
      then [ [ div [ class "invalid-feedback" ]
        [ text "The list contains duplicates. Make sure that the same producer is not listed multiple times." ] ] ]
      else []
    ) ++
    [  label [for "add-relation"] [text "Add relation"]
    :: A.view searchConfig model.search [placeholder "Producer...", style "max-width" "400px"]
    ]
  )
