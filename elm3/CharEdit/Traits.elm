module CharEdit.Traits exposing (Model, Msg, init, update, view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Lib.Html exposing (..)
import Lib.Autocomplete as A
import Lib.Gen as Gen
import Lib.Util exposing (..)


type alias Model =
  { traits     : List Gen.CharEditTraits
  , search     : A.Model Gen.ApiTraitResult
  , duplicates : Bool
  }


init : List Gen.CharEditTraits -> Model
init l =
  { traits     = l
  , search     = A.init
  , duplicates = False
  }


type Msg
  = Del Int
  | SetSpoil Int String
  | Search (A.Msg Gen.ApiTraitResult)


searchConfig : A.Config Msg Gen.ApiTraitResult
searchConfig = { wrap = Search, id = "add-trait", source = A.traitSource }


validate : Model -> Model
validate model = { model | duplicates = hasDuplicates <| List.map .tid model.traits }


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Del i        -> (validate { model | traits = delidx i model.traits }, Cmd.none)
    SetSpoil i s -> (validate { model | traits = modidx i (\e -> { e | spoil = Maybe.withDefault e.spoil (String.toInt s) }) model.traits }
                   , Cmd.none )

    Search m ->
      let (nm, c, res) = A.update searchConfig m model.search
      in case res of
        Nothing -> ({ model | search = nm }, c)
        Just r  ->
          let nrow = { tid = r.id, name = r.name, group = Maybe.withDefault "" r.group, spoil = 0 }
          in (validate { model | search = A.clear nm, traits = model.traits ++ [nrow] }, c)



view : Model -> Html Msg
view model =
  let
    entry n e = editListRow ""
      [ editListField 2 "col-form-label single-line"
        [ span [ class "muted" ] [ text <| e.group ++ " / " ]
        , a [href <| "/i" ++ String.fromInt e.tid, title e.name, target "_blank" ] [ text e.name ] ]
      , editListField 1 ""
        [ inputSelect [onInput (SetSpoil n)] (String.fromInt e.spoil) spoilLevels ]
      , editListField 0 "" [ removeButton (Del n) ]
      ]

  in card "traits" "Traits" []
    <| editList (List.indexedMap entry model.traits)
    ++ formGroups (
      (if model.duplicates
        then [ [ div [ class "invalid-feedback" ]
          [ text "There are duplicate traits." ] ] ]
        else []
      ) ++
      [ label [for "add-trait"] [text "Add trait"]
        :: A.view searchConfig model.search [placeholder "Trait", style "max-width" "400px"]
      ]
    )
