module VNEdit.Relations exposing (Model, Msg, init, update, view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Lib.Html exposing (..)
import Lib.Gen as Gen
import Lib.Util exposing (..)
import Lib.Autocomplete as A


type alias Model =
  { relations  : List Gen.VNEditRelations
  , search     : A.Model Gen.ApiVNResult
  , duplicates : Bool
  }


init : List Gen.VNEditRelations -> Model
init l =
  { relations  = l
  , search     = A.init
  , duplicates = False
  }


type Msg
  = Del Int
  | Official Int Bool
  | Rel Int String
  | Search (A.Msg Gen.ApiVNResult)


searchConfig : A.Config Msg Gen.ApiVNResult
searchConfig = { wrap = Search, id = "add-relation", source = A.vnSource }


validate : Model -> Model
validate model = { model | duplicates = hasDuplicates <| List.map .vid model.relations }


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Del i        -> (validate { model | relations = delidx i model.relations }, Cmd.none)
    Official i b -> (validate { model | relations = modidx i (\e -> { e | official = b }) model.relations }, Cmd.none)
    Rel i s      -> (validate { model | relations = modidx i (\e -> { e | relation = s }) model.relations }, Cmd.none)
    Search m ->
      let (nm, c, res) = A.update searchConfig m model.search
      in case res of
        Nothing -> ({ model | search = nm }, c)
        Just r  ->
          let
            rel = List.head Gen.vnRelations |> Maybe.map Tuple.first |> Maybe.withDefault ""
            nrow = { vid = r.id, relation = rel, title = r.title, official = True }
          in (validate { model | search = A.clear nm, relations = model.relations ++ [nrow] }, c)


view : Model -> Html Msg
view model =
  let
    entry n e = editListRow "row--ai-center"
      [ editListField 1 "text-sm-right single-line"
        [ a [href <| "/v" ++ String.fromInt e.vid, title e.title, target "_blank" ] [text e.title ] ]
      , editListField 0 ""
        [ text "is an "
        , label [class "checkbox"]
          [ inputCheck "" e.official (Official n)
          , text " official"
          ]
        ]
      , editListField 1 ""
        [ inputSelect [onInput (Rel n)] e.relation Gen.vnRelations ]
      , editListField 0 "single-line" [ text " of this VN" ]
      , editListField 0 "" [ removeButton (Del n) ]
      ]

  in card "relations" "Relations" [] <|
  editList (List.indexedMap entry model.relations)
  ++ formGroups (
    (if model.duplicates
      then [ [ div [ class "invalid-feedback" ]
        [ text "The list contains duplicates. Make sure that the same visual novel is not listed multiple times." ] ] ]
      else []
    ) ++
    [  label [for "add-relation"] [text "Add relation"]
    :: A.view searchConfig model.search [placeholder "Visual Novel...", style "max-width" "400px"]
    ]
  )
