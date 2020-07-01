module VNEdit exposing (main)

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


type Tab
  = General
  | Image
  | Staff
  | Cast
  | Relations
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
  , anime       = d.anime
  , animeSearch = A.init ""
  , image       = Img.info d.image_info
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
  , anime       = List.map (\a -> { aid = a.aid }) model.anime
  , image       = model.image.id
  }

animeConfig : A.Config Msg GApi.ApiAnimeResult
animeConfig = { wrap = AnimeSearch, id = "animeadd", source = A.animeSource }

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
  | AnimeDel Int
  | AnimeSearch (A.Msg GApi.ApiAnimeResult)
  | ImageSet String Bool
  | ImageSelect
  | ImageSelected File
  | ImageMsg Img.Msg


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

    Submit -> ({ model | state = Api.Loading }, GVE.send (encode model) Submitted)
    Submitted (GApi.Redirect s) -> (model, load s)
    Submitted r -> ({ model | state = Api.Error r }, Cmd.none)


isValid : Model -> Bool
isValid model = not
  (  (model.title /= "" && model.title == model.original)
  || not (Img.isValid model.image)
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

  in
  form_ Submit (model.state == Api.Loading)
  [ div [ class "maintabs left" ]
    [ ul []
      [ li [ classList [("tabselected", model.tab == General    )] ] [ a [ href "#", onClickD (Tab General    ) ] [ text "General info" ] ]
      , li [ classList [("tabselected", model.tab == Image      )] ] [ a [ href "#", onClickD (Tab Image      ) ] [ text "Image"        ] ]
      , li [ classList [("tabselected", model.tab == Staff      )] ] [ a [ href "#", onClickD (Tab Staff      ) ] [ text "Staff"        ] ]
      , li [ classList [("tabselected", model.tab == Cast       )] ] [ a [ href "#", onClickD (Tab Cast       ) ] [ text "Cast"         ] ]
      , li [ classList [("tabselected", model.tab == Relations  )] ] [ a [ href "#", onClickD (Tab Relations  ) ] [ text "Relations"    ] ]
      , li [ classList [("tabselected", model.tab == Screenshots)] ] [ a [ href "#", onClickD (Tab Screenshots) ] [ text "Screenshots"  ] ]
      , li [ classList [("tabselected", model.tab == All        )] ] [ a [ href "#", onClickD (Tab All        ) ] [ text "All items"    ] ]
      ]
    ]
  , div [ class "mainbox", classList [("hidden", model.tab /= General     && model.tab /= All)] ] [ h1 [] [ text "General info" ], table [ class "formtable" ] geninfo ]
  , div [ class "mainbox", classList [("hidden", model.tab /= Image       && model.tab /= All)] ] [ h1 [] [ text "Image" ], image ]
  , div [ class "mainbox", classList [("hidden", model.tab /= Staff       && model.tab /= All)] ] [ h1 [] [ text "Staff" ] ]
  , div [ class "mainbox", classList [("hidden", model.tab /= Cast        && model.tab /= All)] ] [ h1 [] [ text "Cast" ] ]
  , div [ class "mainbox", classList [("hidden", model.tab /= Relations   && model.tab /= All)] ] [ h1 [] [ text "Relations" ] ]
  , div [ class "mainbox", classList [("hidden", model.tab /= Screenshots && model.tab /= All)] ] [ h1 [] [ text "Screenshots" ] ]
  , div [ class "mainbox" ] [ fieldset [ class "submit" ]
      [ Html.map Editsum (Editsum.view model.editsum)
      , submitButton "Submit" model.state (isValid model)
      ]
    ]
  ]
