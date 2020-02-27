module ReleaseEdit.General exposing (..)

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes exposing (..)
import Set
import Lib.Html exposing (..)
import Lib.Util exposing (..)
import Lib.DropDown as DD
import Lib.Api as Api
import Gen.Api as GApi
import Lib.RDate as D
import Lib.Autocomplete as A
import Lib.ExtLinks as EL
import Gen.Types as GT
import Gen.ReleaseEdit as GRE
import Gen.ExtLinks as GEL

-- TODO: notes, producers, VNs


type alias Model =
  { title      : String
  , original   : String
  , rtype      : String
  , patch      : Bool
  , freeware   : Bool
  , doujin     : Bool
  , lang       : Set.Set String
  , langDd     : DD.Config Msg
  , plat       : Set.Set String
  , platDd     : DD.Config Msg
  , media      : List GRE.RecvMedia
  , gtinInput  : String
  , gtin       : Int
  , catalog    : String
  , released   : D.RDate
  , minage     : Int
  , uncensored : Bool
  , resolution : String
  , voiced     : Int
  , ani_story  : Int
  , ani_ero    : Int
  , website    : String
  , engineConf : A.Config Msg GRE.RecvEngines
  , engine     : A.Model GRE.RecvEngines
  , extlinks   : EL.Model GRE.RecvExtlinks
  }


init : GRE.Recv -> Model
init d =
  { title      = d.title
  , original   = d.original
  , rtype      = d.rtype
  , patch      = d.patch
  , freeware   = d.freeware
  , doujin     = d.doujin
  , lang       = Set.fromList <| List.map (\e -> e.lang) d.lang
  , langDd     = DD.init "lang" LangOpen
  , plat       = Set.fromList <| List.map (\e -> e.platform) d.platforms
  , platDd     = DD.init "platforms" PlatOpen
  , media      = List.map (\m -> { m | qty = if m.qty == 0 then 1 else m.qty }) d.media
  , gtinInput  = formatGtin d.gtin
  , gtin       = d.gtin
  , catalog    = d.catalog
  , released   = d.released
  , minage     = d.minage
  , uncensored = d.uncensored
  , resolution = d.resolution
  , voiced     = d.voiced
  , ani_story  = d.ani_story
  , ani_ero    = d.ani_ero
  , website    = d.website
  , engineConf = { wrap   = Engine
                 , id = "engine"
                 , source = { source = A.Func (\s -> List.filter (\e -> String.contains (String.toLower s) (String.toLower e.engine)) d.engines |> List.take 10)
                            , view   = \i -> [ text i.engine, b [ class "grayedout" ] [ text <| " (" ++ String.fromInt i.count ++ ")" ] ]
                            , key    = \i -> i.engine }
                 }
  , engine     = A.init d.engine
  , extlinks   = EL.new d.extlinks GEL.releaseLinks
  }


sub : Model -> Sub Msg
sub model = Sub.batch [ DD.sub model.langDd, DD.sub model.platDd ]


type Msg
  = Title String
  | Original String
  | RType String
  | Patch Bool
  | Freeware Bool
  | Doujin Bool
  | Lang String Bool
  | LangOpen Bool
  | Plat String Bool
  | PlatOpen Bool
  | MediaType Int String
  | MediaQty Int Int
  | MediaDel Int
  | MediaAdd
  | Gtin String
  | Catalog String
  | Released D.RDate
  | Minage Int
  | Uncensored Bool
  | Resolution String
  | Voiced Int
  | AniStory Int
  | AniEro Int
  | Website String
  | Engine (A.Msg GRE.RecvEngines)
  | ExtLinks (EL.Msg GRE.RecvExtlinks)


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  let mod m = (m, Cmd.none)
  in
  case msg of
    Title s    -> mod { model | title    = s }
    Original s -> mod { model | original = s }
    RType s    -> mod { model | rtype    = s }
    Patch b    -> mod { model | patch    = b }
    Freeware b -> mod { model | freeware = b }
    Doujin b   -> mod { model | doujin   = b }
    Lang s b   -> mod { model | lang     = if b then Set.insert s model.lang else Set.remove s model.lang }
    LangOpen b -> mod { model | langDd   = DD.toggle model.langDd b }
    Plat s b   -> mod { model | plat     = if b then Set.insert s model.plat else Set.remove s model.plat }
    PlatOpen b -> mod { model | platDd   = DD.toggle model.platDd b }
    MediaType n s -> mod { model | media = modidx n (\m -> { m | medium = s }) model.media }
    MediaQty n i  -> mod { model | media = modidx n (\m -> { m | qty    = i }) model.media }
    MediaDel i -> mod { model | media = delidx i model.media }
    MediaAdd   -> mod { model | media = model.media ++ [{ medium = "in", qty = 1 }] }
    Gtin s     -> mod { model | gtinInput = s, gtin = validateGtin s }
    Catalog s  -> mod { model | catalog = s }
    Released d -> mod { model | released = d }
    Minage i   -> mod { model | minage = i }
    Uncensored b->mod { model | uncensored = b }
    Resolution s->mod { model | resolution = s }
    Voiced i   -> mod { model | voiced = i }
    AniStory i -> mod { model | ani_story = i }
    AniEro i   -> mod { model | ani_ero = i }
    Website s  -> mod { model | website = s }
    Engine m   ->
      let (nm, c, en) = A.update model.engineConf m model.engine
          nmod = case en of
            Just e  -> A.clear nm e.engine
            Nothing -> nm
      in ({ model | engine = nmod }, c)
    ExtLinks m -> mod { model | extlinks = EL.update m model.extlinks }


isValid : Model -> Bool
isValid model = not
  (  model.title == model.original
  || Set.isEmpty model.lang
  || hasDuplicates (List.map (\m -> (m.medium, m.qty)) model.media)
  || (model.gtinInput /= "" && model.gtin == 0)
  )

view : Model -> Html Msg
view model =
  table [ class "formtable" ]
  [ formField "title::Title (romaji)" [ inputText "title" model.title Title (style "width" "500px" :: GRE.valTitle) ]
  , formField "original::Original title"
    [ inputText "original" model.original Original (style "width" "500px" :: GRE.valOriginal)
    , if model.title /= "" && model.title == model.original
      then b [ class "standout" ] [ br [] [], text "Should not be the same as the Title (romaji). Leave blank is the original title is already in the latin alphabet" ]
      else text ""
    ]

  , tr [ class "newpart" ] [ td [] [] ]
  , formField "rtype::Type" [ inputSelect "rtype" model.rtype RType [] GT.releaseTypes ]
  , formField "minage::Age rating" [ inputSelect "minage" model.minage Minage [] GT.ageRatings, b [ class "standout" ] [ text " (*)" ] ]
  , formField "" [ label [] [ inputCheck "" model.patch    Patch   , text " This release is a patch to another release.", b [ class "standout" ] [ text " (*)" ] ] ]
  , formField "" [ label [] [ inputCheck "" model.freeware Freeware, text " Freeware (i.e. available at no cost)" ] ]
  , if model.patch then text "" else
    formField "" [ label [] [ inputCheck "" model.doujin   Doujin  , text " Doujin (self-published, not by a company)" ] ]
  , formField "Release date" [ D.view model.released False Released, text " Leave month or day blank if they are unknown." ]

    -- XXX: Not entirely sure if this is a convenient way of handling lists,
    -- the number of languages/platforms is a bit too large for comfortable
    -- selection and it would be nice if a language could be removed directly
    -- from the view rather than by finding it somewhere in the dropdown list.
  , tr [ class "newpart" ] [ td [ colspan 2 ] [ text "Format" ] ]
  , formField "Language(s)"
    [ div [ class "elm_dd_input" ] [ DD.view model.langDd Api.Normal
      (if Set.isEmpty model.lang
       then b [ class "standout" ] [ text "No language selected" ]
       else span [] <| List.intersperse (text ", ") <| List.map (\(l,t) -> span [] [ langIcon l, text t ]) <| List.filter (\(l,_) -> Set.member l model.lang) GT.languages)
      <| \() -> [ ul [] <| List.map (\(l,t) -> li [] [ linkRadio (Set.member l model.lang) (Lang l) [ langIcon l, text t ] ]) GT.languages ]
    ] ]
  , formField "Platform(s)"
    [ div [ class "elm_dd_input" ] [ DD.view model.platDd Api.Normal
      (if Set.isEmpty model.plat
       then text "No platform selected"
       else span [] <| List.intersperse (text ", ") <| List.map (\(p,t) -> span [] [ platformIcon p, text t ]) <| List.filter (\(p,_) -> Set.member p model.plat) GT.platforms)
      <| \() -> [ ul [] <| List.map (\(p,t) -> li [] [ linkRadio (Set.member p model.plat) (Plat p) [ platformIcon p, text t ] ]) GT.platforms ]
    ] ]
  , formField "Media"
    [ table [] <| List.indexedMap (\i m ->
        case List.filter (\(s,_,_) -> m.medium == s) GT.media |> List.head of
          Nothing -> text ""
          Just (_,t,q) ->
            tr []
            [ td [] [ inputSelect "" m.medium (MediaType i) [] <| List.map (\(a,b,_) -> (a,b)) GT.media ]
            , td [] [ if q then inputSelect "" m.qty (MediaQty i) [ style "width" "100px" ] <| List.map (\a -> (a,String.fromInt a)) <| List.range 1 20 else text "" ]
            , td [] [ a [ href "#", onClickD (MediaDel i) ] [ text "remove" ] ]
            ]
      ) model.media
    , if hasDuplicates (List.map (\m -> (m.medium, m.qty)) model.media)
      then b [ class "standout" ] [ text "List contains duplicates", br [] [] ]
      else text ""
    , a [ href "#", onClickD MediaAdd ] [ text "Add medium" ]
    ]

  , if model.patch then text "" else
    formField "engine::Engine" [ A.view model.engineConf model.engine [] ]
  , if model.patch then text "" else
    formField "resolution::Resolution" [ inputSelect "resolution" model.resolution Resolution [] GT.resolutions ]
  , if model.patch then text "" else
    formField "voiced::Voiced" [ inputSelect "voiced" model.voiced Voiced [] GT.voiced ]
  , if model.patch then text "" else
    formField "ani_story::Animations"
    [ inputSelect "ani_story" model.ani_story AniStory [] GT.animated
    , if model.minage == 18 then text " <= story | ero scenes => " else text ""
    , if model.minage == 18 then inputSelect "" model.ani_ero AniEro [] GT.animated else text ""
    ]
  , if model.minage /= 18 then text "" else
    formField "" [ label [] [ inputCheck "" model.uncensored Uncensored, text " Uncensored (No mosaic or other optical censoring, only check if this release has erotic content)" ] ]

  , tr [ class "newpart" ] [ td [ colspan 2 ] [ text "External identifiers & links" ] ]
  , formField "gtin::JAN/UPC/EAN"
    [ inputText "gtin" model.gtinInput Gtin [pattern "[0-9]+"]
    , if model.gtinInput /= "" && model.gtin == 0 then b [ class "standout" ] [ text "Invalid GTIN code" ] else text ""
    ]
  , formField "catalog::Catalog number" [ inputText "catalog" model.catalog Catalog GRE.valCatalog ]
  , formField "website::Website" [ inputText "website" model.website Website (style "width" "500px" :: GRE.valWebsite) ]
  , formField "External Links" [ Html.map ExtLinks (EL.view model.extlinks) ]
  ]
