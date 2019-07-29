module CharEdit.VN exposing (Model, Msg, init, encode, update, view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Encode as JE
import Dict exposing (Dict)
import Lib.Html exposing (..)
import Lib.Autocomplete as A
import Lib.Gen as Gen
import Lib.Util exposing (..)
import Lib.Api as Api


type alias VNRel =
  { id     : Int
  , title  : String
  , role   : String
  , spoil  : Int
  , relsel : Bool
  , rel    : Dict Int { role : String, spoil : Int }
  }

type alias Model =
  { vn         : List VNRel
  , releases   : Dict Int (List Gen.CharEditVnrelsReleases)  -- Mapping from VN id -> list of releases
  , search     : A.Model Gen.ApiVNResult
  , duplicates : Bool
  }


init : List Gen.CharEditVns -> List Gen.CharEditVnrels -> Model
init vns rels =
  -- Turn the array from the server into a more usable data structure. This assumes that the array is ordered by VN id.
  let
    merge o n = case n.rid of
      Nothing -> { o | role = n.role, spoil = n.spoil }
      Just i  -> { o | relsel = True, rel = Dict.insert i { role = n.role, spoil = n.spoil } o.rel }

    new n = case n.rid of
      Nothing -> { id = n.vid, title = n.title, relsel = False, role = n.role, spoil = n.spoil, rel = Dict.empty }
      Just i  -> { id = n.vid, title = n.title, relsel = True,  role = "",     spoil = 0,       rel = Dict.fromList [(i, { role = n.role, spoil = n.spoil })] }

    step n l =
      case l of
        []    -> [ new n ]
        i::xs ->
          if i.id == n.vid
          then merge i n :: xs
          else new n :: l
  in
  { vn         = List.foldr step [] vns
  , releases   = Dict.fromList <| List.map (\n -> (n.id, n.releases)) rels
  , search     = A.init
  , duplicates = False
  }


-- XXX: The model and the UI allow an invalid state: VN is present, but
-- role="". This isn't too obvious to trigger, I hope, so in this case we'll
-- just be lazy and not send the VN to the server.
encode : Model -> List Gen.CharEditSendVns
encode model =
  let
    vn e =
      (if e.role == "" then [] else [{ vid = e.id, rid = Nothing, role = e.role, spoil = e.spoil }])
      ++
      (if e.relsel then Dict.foldl (\id r l -> { vid = e.id, rid = Just id, role = r.role, spoil = r.spoil } :: l) [] e.rel else [])
  in List.concat <| List.map vn model.vn



type Msg
  = Del Int
  | SetSel Int Bool
  | SetRole Int String
  | SetSpoil Int String
  | SetRRole Int Int String
  | SetRSpoil Int Int String
  | Search (A.Msg Gen.ApiVNResult)
  | ReleaseInfo Int Api.Response


searchConfig : A.Config Msg Gen.ApiVNResult
searchConfig = { wrap = Search, id = "add-vn", source = A.vnSource }


validate : Model -> Model
validate model = { model | duplicates = hasDuplicates <| List.map .id model.vn }


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  let
    rrole s o_ = if s == "" then Nothing
      else Just <| case o_ of
        Nothing -> { role = s, spoil = 0 }
        Just o  -> { o | role = s }
    rspoil s   = Maybe.map (\o -> { o | spoil = Maybe.withDefault o.spoil (String.toInt s) })
  in case msg of
    Del i            -> (validate { model | vn = delidx i model.vn }, Cmd.none)
    SetSel i b       -> ({ model | vn = modidx i (\e -> { e | relsel = b }) model.vn }, Cmd.none)
    SetRole i s      -> ({ model | vn = modidx i (\e -> { e | role = s   }) model.vn }, Cmd.none)
    SetSpoil i s     -> ({ model | vn = modidx i (\e -> { e | spoil = Maybe.withDefault e.spoil (String.toInt s) }) model.vn }, Cmd.none)
    SetRRole i id s  -> ({ model | vn = modidx i (\e -> { e | rel = Dict.update id (rrole  s) e.rel }) model.vn }, Cmd.none)
    SetRSpoil i id s -> ({ model | vn = modidx i (\e -> { e | rel = Dict.update id (rspoil s) e.rel }) model.vn }, Cmd.none)

    Search m ->
      let (nm, c, res) = A.update searchConfig m model.search
      in case res of
        Nothing -> ({ model | search = nm }, c)
        Just r  ->
          let
            nrow = { id = r.id, title = r.title, relsel = False, role = "primary", spoil = 0, rel = Dict.empty }
            nc = case Dict.get r.id model.releases of
              Nothing -> Api.post "/js/release.json" (JE.object [("vid", JE.int r.id)]) (ReleaseInfo r.id)
              Just _ -> Cmd.none
          in (validate { model | search = A.clear nm, vn = model.vn ++ [nrow] }, Cmd.batch [c, nc])

    ReleaseInfo vid (Gen.ReleaseResult r) -> ({ model | releases = Dict.insert vid r model.releases}, Cmd.none)
    ReleaseInfo _ _ -> (model, Cmd.none)



view : Model -> Html Msg
view model =
  let
    vn n e = editList <|
      editListRow ""
        [ editListField 3 "col-form-label single-line"
          [ span [ class "muted" ] [ text <| "v" ++ String.fromInt e.id ++ ":" ]
          , a [ href <| "/v" ++ String.fromInt e.id, target "_blank" ] [ text e.title ]
          ]
        , editListField 0 "" [ removeButton (Del n) ]
        ]
      :: case Dict.get e.id model.releases of
          Nothing -> [ div [ class "spinner spinner--md" ] [] ]
          Just l -> default n e :: if e.relsel then List.map (rel n e.rel) l else []

    default n e =
      editListRow ""
      [ editListField 2 "ml-3"
        [ label [class "checkbox"] [ inputCheck "" e.relsel (SetSel n), text " Per release" ] ]
      , editListField 1 "col-form-label single-line text-right" [ text <| if e.relsel then "Default:" else "All releases:" ]
      , editListField 1 ""
        [ inputSelect [onInput (SetRole n)] e.role <|
            (if e.relsel then [("", "Not involved")] else [])
            ++ Gen.charRoles
        ]
      , editListField 1 ""
        [ if e.role == ""
          then text ""
          else inputSelect [onInput (SetSpoil n)] (String.fromInt e.spoil) spoilLevels
        ]
      ]

    rel n rels e =
      let
        sel = Maybe.withDefault { role = "", spoil = 0 } <| Dict.get e.id rels
      in editListRow ""
      [ editListField 3 "col-form-label single-line ml-3" <|
        span [ class "muted" ] [ text <| "r" ++ String.fromInt e.id ++ ": " ]
        :: List.map iconLanguage e.lang
        ++
        [ a [href <| "/r" ++ String.fromInt e.id, title e.title, target "_blank" ] [ text e.title ] ]
      , editListField 1 ""
        [ inputSelect [onInput (SetRRole n e.id)] sel.role (("", "-default-") :: Gen.charRoles) ]
      , editListField 1 ""
        [ if sel.role == ""
          then text ""
          else inputSelect [onInput (SetRSpoil n e.id)] (String.fromInt sel.spoil) spoilLevels
        ]
      ]

  in card "vns" "Visual Novels" [] <|
    List.concat (List.indexedMap vn model.vn)
    ++ formGroups (
      (if model.duplicates
        then [ [ div [ class "invalid-feedback" ]
          [ text "There are duplicate visual novels." ] ] ]
        else []
      ) ++
      [ label [for "add-vn"] [text "Add visual novel"]
        :: A.view searchConfig model.search [placeholder "VIsual novel", style "max-width" "400px"]
      ]
    )
