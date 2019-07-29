module RelEdit.Vn exposing (Model, Msg, init, update, view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Lib.Html exposing (..)
import Lib.Gen as Gen
import Lib.Util exposing (..)
import Lib.Autocomplete as A


type alias Model =
  { vn         : List Gen.RelEditVn
  , search     : A.Model Gen.ApiVNResult
  , duplicates : Bool
  }


init : List Gen.RelEditVn -> Model
init l =
  { vn         = l
  , search     = A.init
  , duplicates = False
  }


type Msg
  = Del Int
  | Search (A.Msg Gen.ApiVNResult)


searchConfig : A.Config Msg Gen.ApiVNResult
searchConfig = { wrap = Search, id = "add-vn", source = A.vnSource }


validate : Model -> Model
validate model = { model | duplicates = hasDuplicates <| List.map .vid model.vn }


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Del i    -> (validate { model | vn = delidx i model.vn }, Cmd.none)
    Search m ->
      let (nm, c, res) = A.update searchConfig m model.search
      in case res of
        Nothing -> ({ model | search = nm }, c)
        Just r  ->
          let nrow = { vid = r.id, title = r.title }
          in (validate { model | search = A.clear nm, vn = model.vn ++ [nrow] }, c)


view : Model -> Html Msg
view model =
  let
    entry n e = editListRow "row--ai-center"
      [ editListField 1 "col-form-label single-line"
        [ a [href <| "/v" ++ String.fromInt e.vid, title e.title, target "_blank" ] [text e.title ] ]
      , editListField 0 "" [ removeButton (Del n) ]
      ]

  in cardRow "Visual Novels" Nothing
    <| editList (List.indexedMap entry model.vn)
    ++ formGroups (
      (if model.duplicates
        then [ [ div [ class "invalid-feedback" ]
          [ text "The list contains duplicates. Make sure that the same visual novel is not listed multiple times." ] ] ]
        else []
      ) ++
      (if List.isEmpty model.vn
        then [ [ div [ class "invalid-feedback" ]
          [ text "Please make sure that at least one visual novel is selected." ] ] ]
        else []
      ) ++
      [ label [for "add-vn"] [text "Add visual novel"]
      :: A.view searchConfig model.search [placeholder "Visual Novel...", style "max-width" "400px"]
      ]
    )
