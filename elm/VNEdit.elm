port module VNEdit exposing (main)

import Html exposing (..)
import Html.Events exposing (..)
import Html.Keyed as K
import Html.Attributes exposing (..)
import Browser
import Browser.Navigation exposing (load)
import Dict
import Set
import File exposing (File)
import File.Select as FSel
import Lib.Util exposing (..)
import Lib.Html exposing (..)
import Lib.TextPreview as TP
import Lib.Autocomplete as A
import Lib.RDate as RDate
import Lib.Api as Api
import Lib.Editsum as Editsum
import Lib.Image as Img
import Gen.VN as GV
import Gen.VNEdit as GVE
import Gen.Types as GT
import Gen.Api as GApi


main : Program GVE.Recv Model Msg
main = Browser.element
  { init   = \e -> (init e, Cmd.none)
  , view   = view
  , update = update
  , subscriptions = always Sub.none
  }


port ivRefresh : Bool -> Cmd msg

type Tab
  = General
  | Image
  | Staff
  | Cast
  | Screenshots
  | All

type alias Model =
  { state       : Api.State
  , tab         : Tab
  , editsum     : Editsum.Model
  , title       : String
  , original    : String
  , alias       : String
  , desc        : TP.Model
  , length      : Int
  , lWikidata   : Maybe Int
  , lRenai      : String
  , vns         : List GVE.RecvRelations
  , vnSearch    : A.Model GApi.ApiVNResult
  , anime       : List GVE.RecvAnime
  , animeSearch : A.Model GApi.ApiAnimeResult
  , image       : Img.Image
  , staff       : List GVE.RecvStaff
  , staffSearch : A.Model GApi.ApiStaffResult
  , seiyuu      : List GVE.RecvSeiyuu
  , seiyuuSearch: A.Model GApi.ApiStaffResult
  , seiyuuDef   : Int -- character id for newly added seiyuu
  , screenshots : List (Int,Img.Image,Maybe Int) -- internal id, img, rel
  , scrUplRel   : Maybe Int
  , scrUplNum   : Maybe Int
  , scrId       : Int -- latest used internal id
  , releases    : List GVE.RecvReleases
  , chars       : List GVE.RecvChars
  , id          : Maybe Int
  , dupCheck    : Bool
  , dupVNs      : List GApi.ApiVNResult
  }


init : GVE.Recv -> Model
init d =
  { state       = Api.Normal
  , tab         = General
  , editsum     = { authmod = d.authmod, editsum = TP.bbcode d.editsum, locked = d.locked, hidden = d.hidden }
  , title       = d.title
  , original    = d.original
  , alias       = d.alias
  , desc        = TP.bbcode d.desc
  , length      = d.length
  , lWikidata   = d.l_wikidata
  , lRenai      = d.l_renai
  , vns         = d.relations
  , vnSearch    = A.init ""
  , anime       = d.anime
  , animeSearch = A.init ""
  , image       = Img.info d.image_info
  , staff       = d.staff
  , staffSearch = A.init ""
  , seiyuu      = d.seiyuu
  , seiyuuSearch= A.init ""
  , seiyuuDef   = Maybe.withDefault 0 <| List.head <| List.map (\c -> c.id) d.chars
  , screenshots = List.indexedMap (\n i -> (n, Img.info (Just i.info), i.rid)) d.screenshots
  , scrUplRel   = Nothing
  , scrUplNum   = Nothing
  , scrId       = 100
  , releases    = d.releases
  , chars       = d.chars
  , id          = d.id
  , dupCheck    = False
  , dupVNs      = []
  }


encode : Model -> GVE.Send
encode model =
  { id          = model.id
  , editsum     = model.editsum.editsum.data
  , hidden      = model.editsum.hidden
  , locked      = model.editsum.locked
  , title       = model.title
  , original    = model.original
  , alias       = model.alias
  , desc        = model.desc.data
  , length      = model.length
  , l_wikidata  = model.lWikidata
  , l_renai     = model.lRenai
  , relations   = List.map (\v -> { vid = v.vid, relation = v.relation, official = v.official }) model.vns
  , anime       = List.map (\a -> { aid = a.aid }) model.anime
  , image       = model.image.id
  , staff       = List.map (\s -> { aid = s.aid, role = s.role, note = s.note }) model.staff
  , seiyuu      = List.map (\s -> { aid = s.aid, cid  = s.cid,  note = s.note }) model.seiyuu
  , screenshots = List.map (\(_,i,r) -> { scr = Maybe.withDefault "" i.id, rid = r }) model.screenshots
  }

vnConfig : A.Config Msg GApi.ApiVNResult
vnConfig = { wrap = VNSearch, id = "relationadd", source = A.vnSource }

animeConfig : A.Config Msg GApi.ApiAnimeResult
animeConfig = { wrap = AnimeSearch, id = "animeadd", source = A.animeSource }

staffConfig : A.Config Msg GApi.ApiStaffResult
staffConfig = { wrap = StaffSearch, id = "staffadd", source = A.staffSource }

seiyuuConfig : A.Config Msg GApi.ApiStaffResult
seiyuuConfig = { wrap = SeiyuuSearch, id = "seiyuuadd", source = A.staffSource }

type Msg
  = Editsum Editsum.Msg
  | Tab Tab
  | Submit
  | Submitted GApi.Response
  | Title String
  | Original String
  | Alias String
  | Desc TP.Msg
  | Length Int
  | LWikidata (Maybe Int)
  | LRenai String
  | VNDel Int
  | VNRel Int String
  | VNOfficial Int Bool
  | VNSearch (A.Msg GApi.ApiVNResult)
  | AnimeDel Int
  | AnimeSearch (A.Msg GApi.ApiAnimeResult)
  | ImageSet String Bool
  | ImageSelect
  | ImageSelected File
  | ImageMsg Img.Msg
  | StaffDel Int
  | StaffRole Int String
  | StaffNote Int String
  | StaffSearch (A.Msg GApi.ApiStaffResult)
  | SeiyuuDef Int
  | SeiyuuDel Int
  | SeiyuuChar Int Int
  | SeiyuuNote Int String
  | SeiyuuSearch (A.Msg GApi.ApiStaffResult)
  | ScrUplRel (Maybe Int)
  | ScrUplSel
  | ScrUpl File (List File)
  | ScrMsg Int Img.Msg
  | ScrRel Int (Maybe Int)
  | ScrDel Int
  | DupSubmit
  | DupResults GApi.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Editsum m  -> let (nm,nc) = Editsum.update m model.editsum in ({ model | editsum = nm }, Cmd.map Editsum nc)
    Tab t      -> ({ model | tab = t }, Cmd.none)
    Title s    -> ({ model | title    = s, dupVNs = [] }, Cmd.none)
    Original s -> ({ model | original = s, dupVNs = [] }, Cmd.none)
    Alias s    -> ({ model | alias    = s, dupVNs = [] }, Cmd.none)
    Desc m     -> let (nm,nc) = TP.update m model.desc in ({ model | desc = nm }, Cmd.map Desc nc)
    Length n   -> ({ model | length = n }, Cmd.none)
    LWikidata n-> ({ model | lWikidata = n }, Cmd.none)
    LRenai s   -> ({ model | lRenai = s }, Cmd.none)

    VNDel idx        -> ({ model | vns = delidx idx model.vns }, Cmd.none)
    VNRel idx rel    -> ({ model | vns = modidx idx (\v -> { v | relation = rel }) model.vns }, Cmd.none)
    VNOfficial idx o -> ({ model | vns = modidx idx (\v -> { v | official = o   }) model.vns }, Cmd.none)
    VNSearch m ->
      let (nm, c, res) = A.update vnConfig m model.vnSearch
      in case res of
        Nothing -> ({ model | vnSearch = nm }, c)
        Just v ->
          if List.any (\l -> l.vid == v.id) model.vns
          then ({ model | vnSearch = A.clear nm "" }, c)
          else ({ model | vnSearch = A.clear nm "", vns = model.vns ++ [{ vid = v.id, title = v.title, original = v.original, relation = "seq", official = True }] }, Cmd.none)

    AnimeDel i -> ({ model | anime = delidx i model.anime }, Cmd.none)
    AnimeSearch m ->
      let (nm, c, res) = A.update animeConfig m model.animeSearch
      in case res of
        Nothing -> ({ model | animeSearch = nm }, c)
        Just a ->
          if List.any (\l -> l.aid == a.id) model.anime
          then ({ model | animeSearch = A.clear nm "" }, c)
          else ({ model | animeSearch = A.clear nm "", anime = model.anime ++ [{ aid = a.id, title = a.title, original = a.original }] }, Cmd.none)

    ImageSet s b -> let (nm, nc) = Img.new b s in ({ model | image = nm }, Cmd.map ImageMsg nc)
    ImageSelect -> (model, FSel.file ["image/png", "image/jpg"] ImageSelected)
    ImageSelected f -> let (nm, nc) = Img.upload Api.Cv f in ({ model | image = nm }, Cmd.map ImageMsg nc)
    ImageMsg m -> let (nm, nc) = Img.update m model.image in ({ model | image = nm }, Cmd.map ImageMsg nc)

    StaffDel idx    -> ({ model | staff = delidx idx model.staff }, Cmd.none)
    StaffRole idx v -> ({ model | staff = modidx idx (\s -> { s | role = v }) model.staff }, Cmd.none)
    StaffNote idx v -> ({ model | staff = modidx idx (\s -> { s | note = v }) model.staff }, Cmd.none)
    StaffSearch m ->
      let (nm, c, res) = A.update staffConfig m model.staffSearch
      in case res of
        Nothing -> ({ model | staffSearch = nm }, c)
        Just s -> ({ model | staffSearch = A.clear nm "", staff = model.staff ++ [{ id = s.id, aid = s.aid, name = s.name, original = s.original, role = "staff", note = "" }] }, Cmd.none)

    SeiyuuDef c      -> ({ model | seiyuuDef = c }, Cmd.none)
    SeiyuuDel idx    -> ({ model | seiyuu = delidx idx model.seiyuu }, Cmd.none)
    SeiyuuChar idx v -> ({ model | seiyuu = modidx idx (\s -> { s | cid  = v }) model.seiyuu }, Cmd.none)
    SeiyuuNote idx v -> ({ model | seiyuu = modidx idx (\s -> { s | note = v }) model.seiyuu }, Cmd.none)
    SeiyuuSearch m ->
      let (nm, c, res) = A.update seiyuuConfig m model.seiyuuSearch
      in case res of
        Nothing -> ({ model | seiyuuSearch = nm }, c)
        Just s -> ({ model | seiyuuSearch = A.clear nm "", seiyuu = model.seiyuu ++ [{ id = s.id, aid = s.aid, name = s.name, original = s.original, cid = model.seiyuuDef, note = "" }] }, Cmd.none)

    ScrUplRel s -> ({ model | scrUplRel = s }, Cmd.none)
    ScrUplSel -> (model, FSel.files ["image/png", "image/jpg"] ScrUpl)
    ScrUpl f1 fl ->
      if 1 + List.length fl > 10 - List.length model.screenshots
      then ({ model | scrUplNum = Just (1 + List.length fl) }, Cmd.none)
      else
        let imgs = List.map (Img.upload Api.Sf) (f1::fl)
        in ( { model
             | scrId = model.scrId + 100
             , scrUplNum = Nothing
             , screenshots = model.screenshots ++ List.indexedMap (\n (i,_) -> (model.scrId+n,i,model.scrUplRel)) imgs
             }
           , List.indexedMap (\n (_,c) -> Cmd.map (ScrMsg (model.scrId+n)) c) imgs |> Cmd.batch)
    ScrMsg id m ->
      let f (i,s,r) =
            if i /= id then ((i,s,r), Cmd.none)
            else let (nm,nc) = Img.update m s in ((i,nm,r), Cmd.map (ScrMsg id) nc)
          lst = List.map f model.screenshots
      in ({ model | screenshots = List.map Tuple.first lst }, Cmd.batch (ivRefresh True :: List.map Tuple.second lst))
    ScrRel n s -> ({ model | screenshots = List.map (\(i,img,r) -> if i == n then (i,img,s) else (i,img,r)) model.screenshots }, Cmd.none)
    ScrDel n   -> ({ model | screenshots = List.filter (\(i,_,_) -> i /= n) model.screenshots }, ivRefresh True)

    DupSubmit ->
      if List.isEmpty model.dupVNs
      then ({ model | state = Api.Loading }, GV.send { hidden = True, search = model.title :: model.original :: String.lines model.alias } DupResults)
      else ({ model | dupCheck = True, dupVNs = [] }, Cmd.none)
    DupResults (GApi.VNResult vns) ->
      if List.isEmpty vns
      then ({ model | state = Api.Normal, dupCheck = True, dupVNs = [] }, Cmd.none)
      else ({ model | state = Api.Normal, dupVNs = vns }, Cmd.none)
    DupResults r -> ({ model | state = Api.Error r }, Cmd.none)

    Submit -> ({ model | state = Api.Loading }, GVE.send (encode model) Submitted)
    Submitted (GApi.Redirect s) -> (model, load s)
    Submitted r -> ({ model | state = Api.Error r }, Cmd.none)


isValid : Model -> Bool
isValid model = not
  (  (model.title /= "" && model.title == model.original)
  || not (Img.isValid model.image)
  || List.any (\(_,i,r) -> r == Nothing || not (Img.isValid i)) model.screenshots
  || hasDuplicates (List.map (\s -> (s.aid, s.role)) model.staff)
  || hasDuplicates (List.map (\s -> (s.aid, s.cid)) model.seiyuu)
  )


view : Model -> Html Msg
view model =
  let
    titles =
      [ formField "title::Title (romaji)"
        [ inputText "title" model.title Title (style "width" "500px" :: GVE.valTitle)
        , if containsNonLatin model.title
          then b [ class "standout" ] [ br [] [], text "This title field should only contain latin-alphabet characters, please put the \"actual\" title in the field below and the romanization above." ]
          else text ""
        ]
      , formField "original::Original title"
        [ inputText "original" model.original Original (style "width" "500px" :: GVE.valOriginal)
        , if model.title /= "" && model.title == model.original
          then b [ class "standout" ] [ br [] [], text "Should not be the same as the Title (romaji). Leave blank is the original title is already in the latin alphabet" ]
          else if model.original /= "" && String.toLower model.title /= String.toLower model.original && not (containsNonLatin model.original)
          then b [ class "standout" ] [ br [] [], text "Original title does not seem to contain any non-latin characters. Leave this field empty if the title is already in the latin alphabet" ]
          else text ""
        ]
      , formField "alias::Aliases"
        [ inputTextArea "alias" model.alias Alias (rows 3 :: GVE.valAlias)
        , br [] []
        , if hasDuplicates <| String.lines <| String.toLower model.alias
          then b [ class "standout" ] [ text "List contains duplicate aliases.", br [] [] ]
          else text ""
          -- TODO: Warn when release titles are entered?
        , text "List of alternative titles or abbreviations. One line for each alias. Can include both official (japanese/english) titles and unofficial titles used around net."
        , br [] []
        , text "Titles that are listed in the releases should not be added here!"
        ]
      ]

    geninfo = titles ++
      [ formField "desc::Description"
        [ TP.view "desc" model.desc Desc 600 (style "height" "180px" :: GVE.valDesc) [ b [ class "standout" ] [ text "English please!" ] ]
        , text "Short description of the main story. Please do not include spoilers, and don't forget to list the source in case you didn't write the description yourself."
        ]
      , formField "length::Length" [ inputSelect "length" model.length Length [] GT.vnLengths ]
      , formField "l_wikidata::Wikidata ID" [ inputWikidata "l_wikidata" model.lWikidata LWikidata ]
      , formField "l_renai::Renai.us link" [ text "http://renai.us/game/", inputText "l_renai" model.lRenai LRenai [], text ".shtml" ]

      , tr [ class "newpart" ] [ td [ colspan 2 ] [ text "Database relations" ] ]
      , formField "Related VNs"
        [ if List.isEmpty model.vns then text ""
          else table [] <| List.indexedMap (\i v -> tr []
            [ td [ style "text-align" "right" ] [ b [ class "grayedout" ] [ text <| "v" ++ String.fromInt v.vid ++ ":" ] ]
            , td [ style "text-align" "right"] [ a [ href <| "/v" ++ String.fromInt v.vid ] [ text v.title ] ]
            , td []
              [ text "is an "
              , label [] [ inputCheck "" v.official (VNOfficial i), text " official" ]
              , inputSelect "" v.relation (VNRel i) [] GT.vnRelations
              , text " of this VN"
              ]
            , td [] [ inputButton "remove" (VNDel i) [] ]
            ]
          ) model.vns
        , A.view vnConfig model.vnSearch [placeholder "Add visual novel..."]
        ]
      , tr [ class "newpart" ] [ td [ colspan 2 ] [] ]
      , formField "Related anime"
        [ if List.isEmpty model.anime then text ""
          else table [] <| List.indexedMap (\i e -> tr []
            [ td [ style "text-align" "right" ] [ b [ class "grayedout" ] [ text <| "a" ++ String.fromInt e.aid ++ ":" ] ]
            , td [] [ a [ href <| "https://anidb.net/anime/" ++ String.fromInt e.aid ] [ text e.title ] ]
            , td [] [ inputButton "remove" (AnimeDel i) [] ]
            ]
          ) model.anime
        , A.view animeConfig model.animeSearch [placeholder "Add anime..."]
        ]
      ]

    image =
      table [ class "formimage" ] [ tr []
      [ td [] [ Img.viewImg model.image ]
      , td []
        [ h2 [] [ text "Image ID" ]
        , input ([ type_ "text", class "text", tabindex 10, value (Maybe.withDefault "" model.image.id), onInputValidation ImageSet ] ++ GVE.valImage) []
        , br [] []
        , text "Use an image that already exists on the server or empty to remove the current image."
        , br_ 2
        , h2 [] [ text "Upload new image" ]
        , inputButton "Browse image" ImageSelect []
        , br [] []
        , text "Preferably the cover of the CD/DVD/package. Image must be in JPEG or PNG format and at most 10 MiB. Images larger than 256x400 will automatically be resized."
        , case Img.viewVote model.image of
            Nothing -> text ""
            Just v ->
              div []
              [ br [] []
              , text "Please flag this image: (see the ", a [ href "/d19" ] [ text "image flagging guidelines" ], text " for guidance)"
              , Html.map ImageMsg v
              ]
        ]
      ] ]

    staff =
      let
        head =
          if List.isEmpty model.staff then [] else [
            thead [] [ tr []
            [ td [] []
            , td [] [ text "Staff" ]
            , td [] [ text "Role" ]
            , td [] [ text "Note" ]
            , td [] []
            ] ] ]
        foot =
          tfoot [] [ tr [] [ td [] [], td [ colspan 4 ]
          [ br [] []
          , if hasDuplicates (List.map (\s -> (s.aid, s.role)) model.staff)
            then b [ class "standout" ] [ text "List contains duplicate staff roles.", br [] [] ]
            else text ""
          , A.view staffConfig model.staffSearch [placeholder "Add staff..."]
          , text "Can't find the person you're looking for? You can "
          , a [ href "/s/new" ] [ text "create a new entry" ]
          , text ", but "
          , a [ href "/s/all" ] [ text "please check for aliasses first." ]
          , br_ 2
          , text "Some guidelines:"
          , ul []
            [ li [] [ text "Please add major staff only, i.e. people who had a significant and noticable impact on the work." ]
            , li [] [ text "If one person performed several roles, you can add multiple entries with different major roles." ]
            ]
          ] ] ]
        item n s = tr []
          [ td [ style "text-align" "right" ] [ b [ class "grayedout" ] [ text <| "s" ++ String.fromInt s.id ++ ":" ] ]
          , td [] [ a [ href <| "/s" ++ String.fromInt s.id ] [ text s.name ] ]
          , td [] [ inputSelect "" s.role (StaffRole n) [style "width" "150px" ] GT.creditTypes ]
          , td [] [ inputText "" s.note (StaffNote n) (style "width" "300px" :: GVE.valStaffNote) ]
          , td [] [ inputButton "remove" (StaffDel n) [] ]
          ]
      in table [] <| head ++ [ foot ] ++ List.indexedMap item model.staff

    cast =
      let
        chars = List.map (\c -> (c.id, c.name ++ " (c" ++ String.fromInt c.id ++ ")")) model.chars
        head =
          if List.isEmpty model.seiyuu then [] else [
            thead [] [ tr []
            [ td [] [ text "Character" ]
            , td [] [ text "Cast" ]
            , td [] [ text "Note" ]
            , td [] []
            ] ] ]
        foot =
          tfoot [] [ tr [] [ td [ colspan 4 ]
          [ br [] []
          , b [] [ text "Add cast" ]
          , br [] []
          , if hasDuplicates (List.map (\s -> (s.aid, s.cid)) model.seiyuu)
            then b [ class "standout" ] [ text "List contains duplicate cast roles.", br [] [] ]
            else text ""
          , inputSelect "" model.seiyuuDef SeiyuuDef [] chars
          , text " voiced by "
          , div [ style "display" "inline-block" ] [ A.view seiyuuConfig model.seiyuuSearch [] ]
          , br [] []
          , text "Can't find the person you're looking for? You can "
          , a [ href "/s/new" ] [ text "create a new entry" ]
          , text ", but "
          , a [ href "/s/all" ] [ text "please check for aliasses first." ]
          ] ] ]
        item n s = tr []
          [ td [] [ inputSelect "" s.cid (SeiyuuChar n) []
            <| chars ++ if List.any (\c -> c.id == s.cid) model.chars then [] else [(s.cid, "[deleted/moved character: c" ++ String.fromInt s.cid ++ "]")] ]
          , td []
            [ b [ class "grayedout" ] [ text <| "s" ++ String.fromInt s.id ++ ":" ]
            , a [ href <| "/s" ++ String.fromInt s.id ] [ text s.name ] ]
          , td [] [ inputText "" s.note (SeiyuuNote n) (style "width" "300px" :: GVE.valSeiyuuNote) ]
          , td [] [ inputButton "remove" (SeiyuuDel n) [] ]
          ]
      in
        if model.id == Nothing
        then text <| "Voice actors can be added to this visual novel once it has character entries associated with it. "
                  ++ "To do so, first create this entry without cast, then create the appropriate character entries, and finally come back to this form by editing the visual novel."
        else if List.isEmpty model.chars && List.isEmpty model.seiyuu
        then p []
             [ text "This visual novel does not have any characters associated with it (yet). Please "
             , a [ href <| "/v" ++ Maybe.withDefault "" (Maybe.map String.fromInt model.id) ++ "/addchar" ] [ text "add the appropriate character entries" ]
             , text " first and then come back to this form to assign voice actors."
             ]
        else table [] <| head ++ [ foot ] ++ List.indexedMap item model.seiyuu

    screenshots =
      let
        showrel r = "[" ++ (RDate.format (RDate.expand r.released)) ++ " " ++ (String.join "," r.lang) ++ "] " ++ r.title ++ " (r" ++ String.fromInt r.id ++ ")"
        rellist = List.map (\r -> (Just r.id, showrel r)) model.releases
        scr n (id, i, rel) = tr [] <|
          let getdim img = Maybe.map (\nfo -> (nfo.width, nfo.height)) img |> Maybe.withDefault (0,0)
              imgdim = getdim i.img
              relnfo = List.filter (\r -> Just r.id == rel) model.releases |> List.head
              reldim = relnfo |> Maybe.andThen (\r -> if r.reso_x == 0 then Nothing else Just (r.reso_x, r.reso_y))
              dimstr (x,y) = String.fromInt x ++ "x" ++ String.fromInt y
          in
          [ td [] [ Img.viewImg i ]
          , td [] [ Img.viewVote i |> Maybe.map (Html.map (ScrMsg id)) |> Maybe.withDefault (text "") ]
          , td []
            [ b [] [ text <| "Screenshot #" ++ String.fromInt (n+1) ]
            , text " (", a [ href "#", onClickD (ScrDel id) ] [ text "remove" ], text ")"
            , br [] []
            , text <| "Image resolution: " ++ dimstr imgdim
            , br [] []
            , text <| Maybe.withDefault "" <| Maybe.map (\dim -> "Release resolution: " ++ dimstr dim) reldim
            , span [] <|
              if reldim == Just imgdim then [ text " ✔", br [] [] ]
              else if reldim /= Nothing
              then [ text " ❌"
                   , br [] []
                   , b [ class "standout" ] [ text "WARNING: Resolutions do not match, please take screenshots with the correct resolution and make sure to crop them correctly!" ]
                   ]
              else if i.img /= Nothing && rel /= Nothing && List.any (\(_,si,sr) -> sr == rel && si.img /= Nothing && imgdim /= getdim si.img) model.screenshots
              then [ b [ class "standout" ] [ text "WARNING: Inconsistent image resolutions for the same release, please take screenshots with the correct resolution and make sure to crop them correctly!" ]
                   , br [] []
                   ]
              else [ br [] [] ]
            , br [] []
            , inputSelect "" rel (ScrRel id) [style "width" "500px"] <| rellist ++
              case (relnfo, rel) of
                (_, Nothing) -> [(Nothing, "[No release selected]")]
                (Nothing, Just r) -> [(Just r, "[Deleted or unlinked release: r" ++ String.fromInt r ++ "]")]
                _ -> []
            ]
          ]

        add =
          let free = 10 - List.length model.screenshots
          in
          if free <= 0
          then [ b [] [ text "Enough screenshots" ]
               , br [] []
               , text "The limit of 10 screenshots per visual novel has been reached. If you want to add a new screenshot, please remove an existing one first."
               ]
          else
            [ b [] [ text "Add screenshots" ]
            , br [] []
            , text <| String.fromInt free ++ " more screenshot" ++ (if free == 1 then "" else "s") ++ " can be added."
            , br [] []
            , inputSelect "" model.scrUplRel ScrUplRel [style "width" "500px"] ((Nothing, "-- select release --") :: rellist)
            , br [] []
            , if model.scrUplRel == Nothing then text "" else span []
              [ inputButton "Select images" ScrUplSel []
              , case model.scrUplNum of
                  Just num -> text " Too many images selected."
                  Nothing -> text ""
              , br [] []
              ]
            , br [] []
            , b [] [ text "Important reminder" ]
            , ul []
              [ li [] [ text "Screenshots must be in the native resolution of the game" ]
              , li [] [ text "Screenshots must not include window borders and should not have copyright markings" ]
              , li [] [ text "Don't only upload event CGs" ]
              ]
            , text "Read the ", a [ href "/d2#6" ] [ text "full guidelines" ], text " for more information."
            ]
      in
        if model.id == Nothing
        then text <| "Screenshots can be uploaded to this visual novel once it has a release entry associated with it. "
                  ++ "To do so, first create this entry without screenshots, then create the appropriate release entries, and finally come back to this form by editing the visual novel."
        else if List.isEmpty model.releases
        then p []
             [ text "This visual novel does not have any releases associated with it (yet). Please "
             , a [ href <| "/v" ++ Maybe.withDefault "" (Maybe.map String.fromInt model.id) ++ "/add" ] [ text "add the appropriate release entries" ]
             , text " first and then come back to this form to upload screenshots."
             ]
        else table [ class "vnedit_scr" ]
             <| tfoot [] [ tr [] [ td [] [], td [ colspan 2 ] add ] ] :: List.indexedMap scr model.screenshots

    newform () =
      form_ DupSubmit (model.state == Api.Loading)
      [ div [ class "mainbox" ] [ h1 [] [ text "Add a new visual novel" ], table [ class "formtable" ] titles ]
      , div [ class "mainbox" ]
        [ if List.isEmpty model.dupVNs then text "" else
          div []
          [ h1 [] [ text "Possible duplicates" ]
          , text "The following is a list of visual novels that match the title(s) you gave. "
          , text "Please check this list to avoid creating a duplicate visual novel entry. "
          , text "Be especially wary of items that have been deleted! To see why an entry has been deleted, click on its title."
          , ul [] <| List.map (\v -> li []
              [ a [ href <| "/v" ++ String.fromInt v.id ] [ text v.title ]
              , if v.hidden then b [ class "standout" ] [ text " (deleted)" ] else text ""
              ]
            ) model.dupVNs
          ]
        , fieldset [ class "submit" ] [ submitButton (if List.isEmpty model.dupVNs then "Continue" else "Continue anyway") model.state (isValid model) ]
        ]
      ]

    fullform () =
      form_ Submit (model.state == Api.Loading)
      [ div [ class "maintabs left" ]
        [ ul []
          [ li [ classList [("tabselected", model.tab == General    )] ] [ a [ href "#", onClickD (Tab General    ) ] [ text "General info" ] ]
          , li [ classList [("tabselected", model.tab == Image      )] ] [ a [ href "#", onClickD (Tab Image      ) ] [ text "Image"        ] ]
          , li [ classList [("tabselected", model.tab == Staff      )] ] [ a [ href "#", onClickD (Tab Staff      ) ] [ text "Staff"        ] ]
          , li [ classList [("tabselected", model.tab == Cast       )] ] [ a [ href "#", onClickD (Tab Cast       ) ] [ text "Cast"         ] ]
          , li [ classList [("tabselected", model.tab == Screenshots)] ] [ a [ href "#", onClickD (Tab Screenshots) ] [ text "Screenshots"  ] ]
          , li [ classList [("tabselected", model.tab == All        )] ] [ a [ href "#", onClickD (Tab All        ) ] [ text "All items"    ] ]
          ]
        ]
      , div [ class "mainbox", classList [("hidden", model.tab /= General     && model.tab /= All)] ] [ h1 [] [ text "General info" ], table [ class "formtable" ] geninfo ]
      , div [ class "mainbox", classList [("hidden", model.tab /= Image       && model.tab /= All)] ] [ h1 [] [ text "Image" ], image ]
      , div [ class "mainbox", classList [("hidden", model.tab /= Staff       && model.tab /= All)] ] [ h1 [] [ text "Staff" ], staff ]
      , div [ class "mainbox", classList [("hidden", model.tab /= Cast        && model.tab /= All)] ] [ h1 [] [ text "Cast" ], cast ]
      , div [ class "mainbox", classList [("hidden", model.tab /= Screenshots && model.tab /= All)] ] [ h1 [] [ text "Screenshots" ], screenshots ]
      , div [ class "mainbox" ] [ fieldset [ class "submit" ]
          [ Html.map Editsum (Editsum.view model.editsum)
          , submitButton "Submit" model.state (isValid model)
          ]
        ]
      ]
  in if model.id == Nothing && not model.dupCheck then newform () else fullform ()
