module VNEdit.Seiyuu exposing (Model, Msg, init, update, view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Lib.Util exposing (..)
import Lib.Html exposing (..)
import Lib.Gen exposing (VNEditSeiyuu, VNEditChars)
import Lib.Autocomplete as A
import Lib.Api exposing (Staff)


type alias Model =
  { chars       : List VNEditChars
  , seiyuu      : List VNEditSeiyuu
  , search      : A.Model Staff
  , duplicates  : Bool
  }


init : List VNEditSeiyuu -> List VNEditChars -> Model
init s c =
  { chars      = c
  , seiyuu     = s
  , search     = A.init
  , duplicates = False
  }


type Msg
  = Del Int
  | SetNote Int String
  | SetChar Int String
  | Search (A.Msg Staff)


searchConfig : A.Config Msg Staff
searchConfig = { wrap = Search, id = "add-seiyuu", source = A.staffSource }


validate : Model -> Model
validate model = { model | duplicates = hasDuplicates <| List.map (\e -> (e.aid,e.cid )) model.seiyuu }


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Del i       -> (validate { model | seiyuu = delidx i model.seiyuu }, Cmd.none)
    SetNote i s -> (validate { model | seiyuu = modidx i (\e -> { e | note = s }) model.seiyuu }, Cmd.none)
    SetChar i s -> (validate { model | seiyuu = modidx i (\e -> { e | cid = Maybe.withDefault e.cid (String.toInt s) }) model.seiyuu }, Cmd.none)

    Search m ->
      let (nm, c, res) = A.update searchConfig m model.search
      in case res of
        Nothing -> ({ model | search = nm }, c)
        Just r  ->
          let
            char = List.head model.chars |> Maybe.map .id |> Maybe.withDefault 0
            nrow = { aid = r.aid, cid = char, id = r.id, name = r.name, note = "" }
            nmod = { model | search = A.clear nm, seiyuu = model.seiyuu ++ [nrow] }
          in (validate nmod, c)



view : Model -> Maybe Int -> Html Msg
view model id =
  let
    entry n e = editListRow ""
      [ editListField 1 "col-form-label single-line"
        [ a [href <| "/s" ++ String.fromInt e.id, target "_blank" ] [ text e.name ] ]
      , editListField 1 ""
        [ inputSelect
            [onInput (SetChar n)]
            (String.fromInt e.cid)
            (List.map (\c -> (String.fromInt c.id, c.name)) model.chars)
        ]
      , editListField 2 "" [ inputText "" e.note (SetNote n) [placeholder "Note", maxlength 250] ]
      , editListField 0 "" [ removeButton (Del n) ]
      ]

    nochars =
      case id of
        Nothing -> [ text "Cast can be added when the visual novel entry has characters linked to it." ]
        Just n ->
          [ text "Cast can be added after "
          , a [ href <| "/c/new?vid=" ++ (String.fromInt n), target "_blank" ] [ text "creating" ]
          , text " the appropriate character entries, or after linking "
          , a [ href "/c/all" ] [ text "existing characters" ]
          , text " to this visual novel entry."
          ]

  in if List.isEmpty model.chars
  then card "cast" "Cast" [ div [class "card__subheading"] nochars ] []
  else card "cast" "Cast" [] <|
    editList (List.indexedMap entry model.seiyuu)
    ++ formGroups (
      (if model.duplicates
        then [ [ div [ class "invalid-feedback" ]
          [ text "The cast list contains duplicates. Make sure that each person is only listed at most once for the same character" ] ] ]
        else []
      ) ++
      [ label [for "add-seiyuu"] [text "Add cast"]
        :: A.view searchConfig model.search [placeholder "Cast name", style "max-width" "400px"]
      ]
    )
