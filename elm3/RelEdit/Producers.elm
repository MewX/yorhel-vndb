module RelEdit.Producers exposing (Model, Msg, init, update, view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Lib.Html exposing (..)
import Lib.Autocomplete as A
import Lib.Gen as Gen
import Lib.Util exposing (..)


type alias Model =
  { producers  : List Gen.RelEditProducers
  , search     : A.Model Gen.ApiProducerResult
  , duplicates : Bool
  }


init : List Gen.RelEditProducers -> Model
init l =
  { producers  = l
  , search     = A.init
  , duplicates = False
  }


type Msg
  = Del Int
  | SetRole Int String
  | Search (A.Msg Gen.ApiProducerResult)


searchConfig : A.Config Msg Gen.ApiProducerResult
searchConfig = { wrap = Search, id = "add-producer", source = A.producerSource }


validate : Model -> Model
validate model = { model | duplicates = hasDuplicates <| List.map .pid model.producers }


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Del i       -> (validate { model | producers = delidx i model.producers }, Cmd.none)
    SetRole i s -> (validate { model | producers = modidx i (\e -> { e | developer = s == "d" || s == "b", publisher = s == "p" || s == "b" }) model.producers }
                   , Cmd.none )

    Search m ->
      let (nm, c, res) = A.update searchConfig m model.search
      in case res of
        Nothing -> ({ model | search = nm }, c)
        Just r  ->
          let nrow = { pid = r.id, name = r.name, developer = False, publisher = True }
          in (validate { model | search = A.clear nm, producers = model.producers ++ [nrow] }, c)



view : Model -> Html Msg
view model =
  let
    role e =
      case (e.developer, e.publisher) of
        (True, False) -> "d"
        (False, True) -> "p"
        _             -> "b"

    roles =
      [ ("d", "Developer")
      , ("p", "Publisher")
      , ("b", "Both")
      ]

    entry n e = editListRow ""
      [ editListField 1 "col-form-label single-line"
        [ a [href <| "/p" ++ String.fromInt e.pid, title e.name, target "_blank" ] [text e.name ] ]
      , editListField 1 ""
        [ inputSelect [onInput (SetRole n)] (role e) roles ]
      , editListField 0 "" [ removeButton (Del n) ]
      ]

  in cardRow "Producers" Nothing
    <| editList (List.indexedMap entry model.producers)
    ++ formGroups (
      (if model.duplicates
        then [ [ div [ class "invalid-feedback" ]
          [ text "The producers list contains duplicates." ] ] ]
        else []
      ) ++
      [ label [for "add-producer"] [text "Add producer"]
        :: A.view searchConfig model.search [placeholder "Producer", style "max-width" "400px"]
      ]
    )
