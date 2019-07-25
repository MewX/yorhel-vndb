module VNEdit.Main exposing (Model, Msg, main, new, view, update)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Lazy exposing (..)
import Json.Encode as JE
import Browser
import Browser.Navigation exposing (load)
import Lib.Html exposing (..)
import Lib.Gen exposing (..)
import Lib.Api as Api
import Lib.Editsum as Editsum
import VNEdit.Titles as Titles
import VNEdit.General as Gen
import VNEdit.Seiyuu as Seiyuu
import VNEdit.Staff as Staff
import VNEdit.Screenshots as Scr
import VNEdit.Relations as Rel


main : Program VNEdit Model Msg
main = Browser.element
  { init   = \e -> (init e, Cmd.none)
  , view   = view
  , update = update
  , subscriptions = always Sub.none
  }


type alias Model =
  { state       : Api.State
  , new         : Bool
  , editsum     : Editsum.Model
  , l_encubed   : String
  , titles      : Titles.Model
  , general     : Gen.Model
  , staff       : Staff.Model
  , seiyuu      : Seiyuu.Model
  , relations   : Rel.Model
  , screenshots : Scr.Model
  , id          : Maybe Int
  , dupVNs      : List Api.VN
  }


init : VNEdit -> Model
init d =
  { state       = Api.Normal
  , new         = False
  , editsum     = { authmod = d.authmod, editsum = d.editsum, locked = d.locked, hidden = d.hidden }
  , l_encubed   = d.l_encubed
  , titles      = Titles.init d
  , general     = Gen.init d
  , staff       = Staff.init d.staff
  , seiyuu      = Seiyuu.init d.seiyuu d.chars
  , relations   = Rel.init d.relations
  , screenshots = Scr.init d.screenshots d.releases
  , id          = d.id
  , dupVNs      = []
  }


new : Model
new =
  { state       = Api.Normal
  , new         = True
  , editsum     = Editsum.new
  , l_encubed   = ""
  , titles      = Titles.new
  , general     = Gen.new
  , staff       = Staff.init []
  , seiyuu      = Seiyuu.init [] []
  , relations   = Rel.init []
  , screenshots = Scr.init [] []
  , id          = Nothing
  , dupVNs      = []
  }


encode : Model -> VNEditSend
encode model =
  { editsum     = model.editsum.editsum
  , hidden      = model.editsum.hidden
  , locked      = model.editsum.locked
  , l_encubed   = model.l_encubed
  , title       = model.titles.title
  , original    = model.titles.original
  , alias       = model.titles.alias
  , desc        = model.general.desc
  , image       = model.general.image
  , img_nsfw    = model.general.img_nsfw
  , length      = model.general.length
  , l_renai     = model.general.l_renai
  , l_wp        = model.general.l_wp
  , anime       = model.general.animeList
  , staff       = List.map (\e -> { aid = e.aid, role = e.role, note = e.note }) model.staff.staff
  , seiyuu      = List.map (\e -> { aid = e.aid, cid  = e.cid,  note = e.note }) model.seiyuu.seiyuu
  , screenshots = List.map (\e -> { scr = e.scr, rid  = e.rid,  nsfw = e.nsfw }) model.screenshots.screenshots
  , relations   = List.map (\e -> { vid = e.vid, relation = e.relation, official = e.official }) model.relations.relations
  }


type Msg
  = Editsum Editsum.Msg
  | Submit
  | Submitted Api.Response
  | Titles Titles.Msg
  | General Gen.Msg
  | Staff Staff.Msg
  | Seiyuu Seiyuu.Msg
  | Relations Rel.Msg
  | Screenshots Scr.Msg
  | CheckDup
  | RecvDup Api.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Editsum m -> ({ model | editsum = Editsum.update m model.editsum }, Cmd.none)
    Titles m  -> ({ model | titles  = Titles.update  m model.titles, dupVNs = [] }, Cmd.none)

    Submit ->
      let
        path =
          case model.id of
            Just id -> "/v" ++ String.fromInt id ++ "/edit"
            Nothing -> "/v/add"
        body = vneditSendEncode (encode model)
      in ({ model | state = Api.Loading }, Api.post path body Submitted)

    Submitted (Api.Changed id rev) -> (model, load <| "/v" ++ String.fromInt id ++ "." ++ String.fromInt rev)
    Submitted r -> ({ model | state = Api.Error r }, Cmd.none)

    General m     -> let (nm, c) = Gen.update    m model.general     in ({ model | general     = nm }, Cmd.map General     c)
    Staff m       -> let (nm, c) = Staff.update  m model.staff       in ({ model | staff       = nm }, Cmd.map Staff       c)
    Seiyuu m      -> let (nm, c) = Seiyuu.update m model.seiyuu      in ({ model | seiyuu      = nm }, Cmd.map Seiyuu      c)
    Screenshots m -> let (nm, c) = Scr.update    m model.screenshots in ({ model | screenshots = nm }, Cmd.map Screenshots c)
    Relations   m -> let (nm, c) = Rel.update    m model.relations   in ({ model | relations   = nm }, Cmd.map Relations   c)

    CheckDup ->
      let body = JE.object
            [ ("search", JE.list JE.string <| List.filter ((/=)"") <| model.titles.title :: model.titles.original :: model.titles.aliasList)
            , ("hidden", JE.bool True) ]
      in
        if List.isEmpty model.dupVNs
        then ({ model | state = Api.Loading }, Api.post "/js/vn.json" body RecvDup)
        else ({ model | new = False }, Cmd.none)

    RecvDup (Api.VNResult dup) ->
      ({ model | state = Api.Normal, dupVNs = dup, new = not (List.isEmpty dup) }, Cmd.none)
    RecvDup r -> ({ model | state = Api.Error r }, Cmd.none)



isValid : Model -> Bool
isValid model = not
  (  model.titles.aliasDuplicates
  || not (List.isEmpty model.titles.aliasBad)
  || model.general.animeDuplicates
  || model.staff.duplicates
  || model.seiyuu.duplicates
  || model.relations.duplicates
  )


view : Model -> Html Msg
view model =
  if model.new
  then form_ CheckDup (model.state == Api.Loading)
    [ card "new" "Add a new visual novel"
      [ div [class "card__subheading"]
        [ text "Carefully read the "
        , a [ href "/d2" ] [ text "guidelines" ]
        , text " before creating a new visual novel entry, to make sure that the game indeed conforms to our inclusion criteria."
        ]
      ] <|
      List.map (Html.map Titles) <| Titles.view model.titles
    , if List.isEmpty model.dupVNs
      then text ""
      else card "dup" "Possible duplicates" [ div [ class "card__subheading" ] [ text "Please check the list below for possible duplicates." ] ]
        [ cardRow "" Nothing <| formGroup [ div [ class "form-group__help" ] [
          ul [] <| List.map (\e ->
            li [] [ a [ href <| "/v" ++ String.fromInt e.id, title e.original, target "_black" ] [ text e.title ]
                  , text <| if e.hidden then " (deleted)" else "" ]
          ) model.dupVNs
        ] ] ]
    , submitButton "Continue" model.state (isValid model) False
    ]

  else form_ Submit (model.state == Api.Loading)
    [ Gen.view model.general General <| List.map (Html.map Titles) <| Titles.view model.titles
    , Html.map Staff       <| lazy  Staff.view   model.staff
    , Html.map Seiyuu      <| lazy2 Seiyuu.view  model.seiyuu model.id
    , Html.map Relations   <| lazy  Rel.view     model.relations
    , Html.map Screenshots <| lazy2 Scr.view     model.screenshots model.id
    , Html.map Editsum     <| lazy  Editsum.view model.editsum
    , submitButton "Submit" model.state (isValid model) (model.general.imgState == Api.Loading || Scr.loading model.screenshots)
    ]
