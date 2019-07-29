module VNEdit.Staff exposing (Model, Msg, init, update, view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Lib.Html exposing (..)
import Lib.Autocomplete as A
import Lib.Gen as Gen
import Lib.Util exposing (..)


type alias Model =
  { staff      : List Gen.VNEditStaff
  , search     : A.Model Gen.ApiStaffResult
  , duplicates : Bool
  }


init : List Gen.VNEditStaff -> Model
init l =
  { staff      = l
  , search     = A.init
  , duplicates = False
  }


type Msg
  = Del Int
  | SetNote Int String
  | SetRole Int String
  | Search (A.Msg Gen.ApiStaffResult)


searchConfig : A.Config Msg Gen.ApiStaffResult
searchConfig = { wrap = Search, id = "add-staff", source = A.staffSource }


validate : Model -> Model
validate model = { model | duplicates = hasDuplicates <| List.map (\e -> (e.aid,e.role)) model.staff }


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Del i       -> (validate { model | staff = delidx i model.staff }, Cmd.none)
    SetNote i s -> (validate { model | staff = modidx i (\e -> { e | note = s }) model.staff }, Cmd.none)
    SetRole i s -> (validate { model | staff = modidx i (\e -> { e | role = s }) model.staff }, Cmd.none)

    Search m ->
      let (nm, c, res) = A.update searchConfig m model.search
      in case res of
        Nothing -> ({ model | search = nm }, c)
        Just r  ->
          let
            role = List.head Gen.staffRoles |> Maybe.map Tuple.first |> Maybe.withDefault ""
            nrow = { aid = r.aid, id = r.id, name = r.name, role = role, note = "" }
          in (validate { model | search = A.clear nm, staff = model.staff ++ [nrow] }, c)



view : Model -> Html Msg
view model =
  let
    entry n e = editListRow ""
      [ editListField 1 "col-form-label single-line"
        [ a [href <| "/s" ++ String.fromInt e.id, target "_blank" ] [text e.name ] ]
      , editListField 1 ""
        [ inputSelect [onInput (SetRole n)] e.role Gen.staffRoles ]
      , editListField 2 ""
        [ inputText "" e.note (SetNote n) [placeholder "Note", maxlength 250] ]
      , editListField 0 "" [ removeButton (Del n) ]
      ]

  in card "staff" "Staff"
  [ div [class "card__subheading"]
    [ text "For information, check the "
    , a [href "/d2#3", target "_blank"] [text "staff editing guidelines"]
    , text ". You can "
    , a [href "/s/new", target "_blank"] [text "create a new staff entry"]
    , text " if it is not in the database yet, but please "
    , a [href "/s/all", target "_blank"] [text "check for aliases first"]
    , text "."
    ]
  ] <|
  editList (List.indexedMap entry model.staff)
  ++ formGroups (
    (if model.duplicates
      then [ [ div [ class "invalid-feedback" ]
        [ text "The staff list contains duplicates. Make sure that each person is only listed at most once with the same role" ] ] ]
      else []
    ) ++
    [ label [for "add-staff"] [text "Add staff"]
      :: A.view searchConfig model.search [placeholder "Staff name", style "max-width" "400px"]
    ]
  )
