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
  , anime       : List GVE.RecvAnime
  , animeSearch : A.Model GApi.ApiAnimeResult
  , image       : Img.Image
  , vns         : List GVE.RecvRelations
  , vnSearch    : A.Model GApi.ApiVNResult
  , screenshots : List (Int,Img.Image,Maybe Int) -- internal id, img, rel
  , scrUplRel   : Maybe Int
  , scrUplNum   : Maybe Int
  , scrId       : Int -- latest used internal id
  , releases    : List GVE.RecvReleases
  , id          : Maybe Int
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
  , screenshots = List.indexedMap (\n i -> (n, Img.info (Just i.info), i.rid)) d.screenshots
  , scrUplRel   = Nothing
  , scrUplNum   = Nothing
  , scrId       = 100
  , releases    = d.releases
  , id          = d.id
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
  , screenshots = List.map (\(_,i,r) -> { scr = Maybe.withDefault "" i.id, rid = r }) model.screenshots
  }

animeConfig : A.Config Msg GApi.ApiAnimeResult
animeConfig = { wrap = AnimeSearch, id = "animeadd", source = A.animeSource }

vnConfig : A.Config Msg GApi.ApiVNResult
vnConfig = { wrap = VNSearch, id = "relationadd", source = A.vnSource }

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
  | ScrUplRel (Maybe Int)
  | ScrUplSel
  | ScrUpl File (List File)
  | ScrMsg Int Img.Msg
  | ScrRel Int (Maybe Int)
  | ScrDel Int


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Editsum m  -> let (nm,nc) = Editsum.update m model.editsum in ({ model | editsum = nm }, Cmd.map Editsum nc)
    Tab t      -> ({ model | tab = t }, Cmd.none)
    Title s    -> ({ model | title = s }, Cmd.none)
    Original s -> ({ model | original = s }, Cmd.none)
    Alias s    -> ({ model | alias = s }, Cmd.none)
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

    Submit -> ({ model | state = Api.Loading }, GVE.send (encode model) Submitted)
    Submitted (GApi.Redirect s) -> (model, load s)
    Submitted r -> ({ model | state = Api.Error r }, Cmd.none)


isValid : Model -> Bool
isValid model = not
  (  (model.title /= "" && model.title == model.original)
  || not (Img.isValid model.image)
  || List.any (\(_,i,r) -> r == Nothing || not (Img.isValid i)) model.screenshots
  )


view : Model -> Html Msg
view model =
  let
    geninfo =
      [ formField "title::Title (romaji)" [ inputText "title" model.title Title GVE.valTitle ]
      , formField "original::Original title"
        [ inputText "original" model.original Title GVE.valOriginal
        , if model.title /= "" && model.title == model.original
          then b [ class "standout" ] [ br [] [], text "Should not be the same as the Title (romaji). Leave blank is the original title is already in the latin alphabet" ]
          else text ""
        ]
      , formField "alias::Aliases"
        [ inputTextArea "alias" model.alias Alias (rows 3 :: GVE.valAlias)
        , br [] []
        , text "List of alternative titles or abbreviations. One line for each alias. Can include both official (japanese/english) titles and unofficial titles used around net."
        , br [] []
        , text "Titles that are listed in the releases should not be added here!"
        -- TODO: Compare & warn when release title is listed as alias
        ]
      , formField "desc::Description"
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

    screenshots =
      let
        showrel r = "[" ++ (RDate.format (RDate.expand r.released)) ++ " " ++ (String.join "," r.lang) ++ "] " ++ r.title ++ " (r" ++ String.fromInt r.id ++ ")"
        rellist = List.map (\r -> (Just r.id, showrel r)) model.releases
        scr n (id, i, rel) = tr [] <|
          let imgdim = Maybe.map (\nfo -> (nfo.width, nfo.height)) i.img |> Maybe.withDefault (0,0)
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
              if reldim == Nothing then [ br [] [] ]
              else if reldim == Just imgdim then [ text " ✔", br [] [] ]
              else [ text " ❌"
                   , br [] []
                   , b [ class "standout" ] [ text "WARNING: Resolutions do not match, please take screenshots with the correct resolution and make sure to crop them correctly!" ]
                   ]
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
        then text <| "Screenshots can be uploaded when this visual novel once it has a release entry associated with it. "
                  ++ "To do so, first create this entry without screenshots, then create the appropriate release entries, and finally come back to this form by editing the visual novel."
        else if List.isEmpty model.releases
        then p []
             [ text "This visual novel does not have any releases associated with it (yet). Please "
             , a [ href <| "/v" ++ Maybe.withDefault "" (Maybe.map String.fromInt model.id) ++ "/add" ] [ text "add the appropriate release entries" ]
             , text " first and then come back to this form to upload screenshots."
             ]
        else table [ class "vnedit_scr" ]
             <| tfoot [] [ tr [] [ td [] [], td [ colspan 2 ] add ] ] :: List.indexedMap scr model.screenshots

  in
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
  , div [ class "mainbox", classList [("hidden", model.tab /= Staff       && model.tab /= All)] ] [ h1 [] [ text "Staff" ] ]
  , div [ class "mainbox", classList [("hidden", model.tab /= Cast        && model.tab /= All)] ] [ h1 [] [ text "Cast" ] ]
  , div [ class "mainbox", classList [("hidden", model.tab /= Screenshots && model.tab /= All)] ] [ h1 [] [ text "Screenshots" ], screenshots ]
  , div [ class "mainbox" ] [ fieldset [ class "submit" ]
      [ Html.map Editsum (Editsum.view model.editsum)
      , submitButton "Submit" model.state (isValid model)
      ]
    ]
  ]
