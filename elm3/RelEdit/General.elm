module RelEdit.General exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Lib.Html exposing (..)
import Lib.Gen exposing (..)
import Lib.Util exposing (..)
import Lib.RDate as RDate


type alias Model =
  { aniEro     : Int
  , aniStory   : Int
  , catalog    : String
  , doujin     : Bool
  , freeware   : Bool
  , gtinInput  : String
  , gtinVal    : Maybe Int
  , lang       : List { lang : String }
  , media      : List { medium : String, qty : Int }
  , minage     : Maybe Int
  , notes      : String
  , original   : String
  , patch      : Bool
  , platforms  : List { platform : String }
  , released   : RDate.RDate
  , resolution : String
  , rtype      : String
  , title      : String
  , uncensored : Bool
  , voiced     : Int
  , website    : String
  }


init : RelEdit -> Model
init d =
  { aniEro     = d.ani_ero
  , aniStory   = d.ani_story
  , catalog    = d.catalog
  , doujin     = d.doujin
  , freeware   = d.freeware
  , gtinInput  = formatGtin d.gtin
  , gtinVal    = Just d.gtin
  , lang       = d.lang
  , media      = d.media
  , minage     = d.minage
  , notes      = d.notes
  , original   = d.original
  , patch      = d.patch
  , platforms  = d.platforms
  , released   = d.released
  , resolution = d.resolution
  , rtype      = d.rtype
  , title      = d.title
  , uncensored = d.uncensored
  , voiced     = d.voiced
  , website    = d.website
  }


new : String -> String -> Model
new title orig =
  { aniEro     = 0
  , aniStory   = 0
  , catalog    = ""
  , doujin     = False
  , freeware   = False
  , gtinInput  = ""
  , gtinVal    = Just 0
  , lang       = [{lang = "ja"}]
  , media      = []
  , minage     = Nothing
  , notes      = ""
  , original   = orig
  , patch      = False
  , platforms  = []
  , released   = 99999999
  , resolution = "unknown"
  , rtype      = "complete"
  , title      = title
  , uncensored = False
  , voiced     = 0
  , website    = ""
  }


type Msg
  = Title String
  | Original String
  | RType String
  | Patch Bool
  | Freeware Bool
  | Doujin Bool
  | LangDel Int
  | LangAdd String
  | Notes String
  | Released RDate.Msg
  | Gtin String
  | Catalog String
  | Website String
  | Minage String
  | Uncensored Bool
  | Resolution String
  | Voiced String
  | AniStory String
  | AniEro String
  | PlatDel Int
  | PlatAdd String
  | MedDel Int
  | MedQty Int String
  | MedAdd String


update : Msg -> Model -> Model
update msg model =
  case msg of
    Title s      -> { model | title    = s }
    Original s   -> { model | original = s }
    RType s      -> { model | rtype    = s }
    Patch b      -> { model | patch    = b }
    Freeware b   -> { model | freeware = b }
    Doujin b     -> { model | doujin   = b }
    LangDel n    -> { model | lang     = delidx n model.lang }
    LangAdd s    -> if s == "" then model else { model | lang = model.lang ++ [{ lang = s }] }
    Notes s      -> { model | notes    = s }
    Released m   -> { model | released = RDate.update m model.released }
    Gtin s       -> { model | gtinInput= s, gtinVal = if s == "" then Just 0 else validateGtin s }
    Catalog s    -> { model | catalog  = s }
    Website s    -> { model | website  = s }
    Minage s     -> { model | minage   = String.toInt s }
    Uncensored b -> { model | uncensored = b }
    Resolution s -> { model | resolution = s }
    Voiced s     -> { model | voiced     = Maybe.withDefault model.voiced     <| String.toInt s }
    AniStory s   -> { model | aniStory   = Maybe.withDefault model.aniStory   <| String.toInt s }
    AniEro s     -> { model | aniEro     = Maybe.withDefault model.aniEro     <| String.toInt s }
    PlatDel n    -> { model | platforms  = delidx n model.platforms }
    PlatAdd s    -> if s == "" then model else { model | platforms = model.platforms ++ [{ platform = s }] }
    MedDel n     -> { model | media = delidx n model.media }
    MedQty i s   -> { model | media = modidx i (\e -> { e | qty = Maybe.withDefault 0 (String.toInt s) }) model.media }
    MedAdd s     -> if s == "" then model else { model | media = model.media ++ [{ medium = s, qty = 1 }] }


general : Model -> Html Msg
general model = card "general" "General info" []

  [ cardRow "Title" Nothing <| formGroups
    [ [ label [for "title"] [text "Title (romaji)"]
      , inputText "title" model.title Title [required True, maxlength 250]
      ]
    , [ label [for "original"] [text "Original"]
      , inputText "original" model.original Original [maxlength 250]
      , div [class "form-group__help"] [text "The original title of this release, leave blank if it already is in the Latin alphabet."]
      ]
    ]

  , cardRow "Type" Nothing <| formGroups <|
    [ [ inputSelect [id "type", onInput RType] model.rtype <| List.map (\s -> (s, toUpperFirst s)) releaseTypes ]
    , [ label [class "checkbox"] [ inputCheck "" model.patch    Patch   , text " This release is a patch to another release" ] ]
    , [ label [class "checkbox"] [ inputCheck "" model.freeware Freeware, text " Freeware (i.e. available at no cost)" ] ]
    ] ++ if model.patch
      then []
      else [ [ label [class "checkbox"] [ inputCheck "" model.doujin Doujin, text " Doujin (self-published, not by a company)" ] ] ]

  , cardRow "Languages" Nothing <| formGroups
    [ editList <| List.indexedMap (\n l ->
        editListRow ""
        [ editListField 3 "" [ iconLanguage l.lang, text <| " " ++ (Maybe.withDefault l.lang <| lookup l.lang languages) ]
        , editListField 0 "" [ removeButton (LangDel n) ]
        ]
      ) model.lang
    , [ if List.isEmpty model.lang
        then div [class "invalid-feedback"] [ text "No language selected." ]
        else text ""
      , label [for "addlang"] [ text "Add language" ]
      -- TODO: Move selection back to "" when a new language has been added
      , inputSelect [id "addlang", onInput LangAdd] ""
        <| ("", "-- Add language --")
        :: List.filter (\(n,_) -> not <| List.any (\l -> l.lang == n) model.lang) languages
      ]
    ]

  , cardRow "Meta" Nothing <| formGroups <|
    [ [ label [for "released"] [text "Release date"]
      , Html.map Released <| RDate.view model.released False
      , div [class "form-group__help"] [text "Leave month or day blank if they are unknown"]
      ]
    , [ label [for "gtin"] [text "JAN/EAN/UPC"]
      , inputText "gtin" model.gtinInput Gtin [pattern "[0-9]+"]
      , if model.gtinVal == Nothing
        then div [class "invalid-feedback"] [ text "Invalid bar code." ]
        else text ""
      ]
    , [ label [for "catalog"] [text "Catalog number"]
      , inputText "catalog" model.catalog Catalog [maxlength 50]
      ]
    , [ label [for "website"] [text "Official website"]
      , inputText "website" model.website Website [pattern weburlPattern]
      ]
    , [ label [for "minage"] [text "Age rating"]
      , inputSelect [id "minage", onInput Minage] (Maybe.withDefault "" (Maybe.map String.fromInt model.minage)) (List.map (\(a,b) -> (String.fromInt a, b)) minAges)
      ]
    ] ++ if model.minage /= Just 18
      then []
      else [ [ label [class "checkbox"] [ inputCheck "" model.uncensored Uncensored, text " No mosaic or other optical censoring (only check if this release has erotic content)" ] ] ]

  , cardRow "Notes" (Just "English please!") <| formGroup
    [ inputTextArea "" model.notes Notes [rows 5, maxlength 10240]
    , div [class "form-group__help"]
      [ text "Miscellaneous notes/comments, information that does not fit in the other fields."
      , text " For example, types of censoring or for which other releases this patch applies."
      ]
    ]
  ]


format : Model -> Html Msg
format model = card "format" "Format" [] <|

  (if model.patch then [] else [ cardRow "Technical" Nothing <| formGroups
    [ [ label [for "resolution"] [text "Native screen resolution"]
      , inputSelect [id "resolution", onInput Resolution] model.resolution resolutions
      ]
    , [ label [for "voiced"] [text "Voiced"]
      , inputSelect [id "voiced", onInput Voiced] (String.fromInt model.voiced) <| List.indexedMap (\a b -> (String.fromInt a, b)) voiced
      ]
    , [ label [for "ani_story"] [text "Story animation"]
      , inputSelect [id "ani_story", onInput AniStory] (String.fromInt model.aniStory) <| List.indexedMap (\a b -> (String.fromInt a, b)) animated
      ]
    , [ label [for "ani_ero"] [text "Ere scene animation"]
      , inputSelect [id "ani_ero", onInput AniEro] (String.fromInt model.aniEro) <| List.indexedMap (\a b -> (String.fromInt a, if a == 0 then "Unknown / no ero scenes" else b)) animated
      ]
    ]
  ]) ++

  [ cardRow "Platforms" Nothing <| formGroups
    [ editList <| List.indexedMap (\n p ->
        editListRow ""
        [ editListField 3 "" [ iconPlatform p.platform, text <| " " ++ (Maybe.withDefault p.platform <| lookup p.platform platforms) ]
        , editListField 0 "" [ removeButton (PlatDel n) ]
        ]
      ) model.platforms
    , [ label [for "addplat"] [ text "Add platform" ]
      -- TODO: Move selection back to "" when a new platform has been added
      , inputSelect [id "addplat", onInput PlatAdd] ""
        <| ("", "-- Add platform --")
        :: List.filter (\(n,_) -> not <| List.any (\p -> p.platform == n) model.platforms) platforms
      ]
    ]

  , cardRow "Media" Nothing <| formGroups
    [ editList <| List.indexedMap (\n m ->
        let md = Maybe.withDefault { qty = False, single = "", plural = "" } <| lookup m.medium Lib.Gen.media
        in editListRow ""
          [ editListField 2 "" [ text md.single ] -- TODO: Add icon
          , editListField 2 ""
            [ if md.qty
              then inputSelect [ onInput (MedQty n) ] (String.fromInt m.qty) <| List.map (\i -> (String.fromInt i, String.fromInt i)) <| List.range 1 20
              else text ""
            ]
          , editListField 0 "" [ removeButton (MedDel n) ]
          ]
      ) model.media
    , [ label [for "addmed"] [ text "Add medium" ]
      -- TODO: Move selection back to "" when a new medium has been added
      , inputSelect [id "addmed", onInput MedAdd] ""
        <| ("", "-- Add medium --")
        :: List.map (\(n,m) -> (n,m.single)) Lib.Gen.media
      ]
    ]
  ]
