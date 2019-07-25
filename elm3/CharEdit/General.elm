module CharEdit.General exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import File exposing (File)
import Lib.Html exposing (..)
import Lib.Autocomplete as A
import Lib.Gen exposing (..)
import Lib.Util exposing (..)
import Lib.Api as Api


type alias Model =
  { alias           : String
  , aliasDuplicates : Bool
  , bDay            : Int
  , bMonth          : Int
  , bloodt          : String
  , desc            : String
  , gender          : String
  , height          : Int
  , image           : Int
  , imgState        : Api.State
  , name            : String
  , original        : String
  , sBust           : Int
  , sHip            : Int
  , sWaist          : Int
  , weight          : Maybe Int
  , mainIs          : Bool
  , mainInstance    : Bool
  , mainId          : Int
  , mainSpoil       : Int
  , mainName        : String
  , mainSearch      : A.Model Api.Char
  }


init : CharEdit -> Model
init d =
  { alias           = d.alias
  , aliasDuplicates = False
  , bDay            = d.b_day
  , bMonth          = d.b_month
  , bloodt          = d.bloodt
  , desc            = d.desc
  , gender          = d.gender
  , height          = d.height
  , image           = d.image
  , imgState        = Api.Normal
  , name            = d.name
  , original        = d.original
  , sBust           = d.s_bust
  , sHip            = d.s_hip
  , sWaist          = d.s_waist
  , weight          = d.weight
  , mainIs          = d.main_is
  , mainInstance    = isJust d.main
  , mainId          = Maybe.withDefault 0 d.main
  , mainSpoil       = d.main_spoil
  , mainName        = d.main_name
  , mainSearch      = A.init
  }


new : Model
new =
  { alias           = ""
  , aliasDuplicates = False
  , bDay            = 0
  , bMonth          = 0
  , bloodt          = "unknown"
  , desc            = ""
  , gender          = "unknown"
  , height          = 0
  , image           = 0
  , imgState        = Api.Normal
  , name            = ""
  , original        = ""
  , sBust           = 0
  , sHip            = 0
  , sWaist          = 0
  , weight          = Nothing
  , mainIs          = False
  , mainInstance    = False
  , mainId          = 0
  , mainSpoil       = 0
  , mainName        = ""
  , mainSearch      = A.init
  }


searchConfig : A.Config Msg Api.Char
searchConfig = { wrap = MainSearch, id = "add-main", source = A.charSource }


type Msg
  = Name String
  | Original String
  | Alias String
  | Desc String
  | Image String
  | Gender String
  | Bloodt String
  | BMonth String
  | BDay String
  | SBust String
  | SWaist String
  | SHip String
  | Height String
  | Weight String
  | MainInstance Bool
  | MainSpoil String
  | MainSearch (A.Msg Api.Char)
  | ImgUpload (List File)
  | ImgDone Api.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Name s       -> ({ model | name     = s }, Cmd.none)
    Original s   -> ({ model | original = s }, Cmd.none)
    Alias s      -> ({ model | alias    = s, aliasDuplicates = hasDuplicates (model.name :: model.original :: splitLn s) }, Cmd.none)
    Desc s       -> ({ model | desc     = s }, Cmd.none)
    Image s      -> ({ model | image    = if s == "" then 0 else Maybe.withDefault model.image (String.toInt s) }, Cmd.none)
    Gender s     -> ({ model | gender   = s }, Cmd.none)
    Bloodt s     -> ({ model | bloodt   = s }, Cmd.none)
    BMonth s     -> ({ model | bMonth   = if s == "" then 0 else Maybe.withDefault model.bMonth (String.toInt s) }, Cmd.none)
    BDay s       -> ({ model | bDay     = if s == "" then 0 else Maybe.withDefault model.bDay   (String.toInt s) }, Cmd.none)
    SBust s      -> ({ model | sBust    = if s == "" then 0 else Maybe.withDefault model.sBust  (String.toInt s) }, Cmd.none)
    SWaist s     -> ({ model | sWaist   = if s == "" then 0 else Maybe.withDefault model.sWaist (String.toInt s) }, Cmd.none)
    SHip s       -> ({ model | sHip     = if s == "" then 0 else Maybe.withDefault model.sHip   (String.toInt s) }, Cmd.none)
    Height s     -> ({ model | height   = if s == "" then 0 else Maybe.withDefault model.height (String.toInt s) }, Cmd.none)
    Weight s     -> ({ model | weight   = String.toInt s }, Cmd.none)
    MainInstance b->({ model | mainInstance = b }, Cmd.none)
    MainSpoil s  -> ({ model | mainSpoil    = Maybe.withDefault model.mainSpoil (String.toInt s) }, Cmd.none)
    MainSearch m ->
      let (nm, c, res) = A.update searchConfig m model.mainSearch
      in case res of
        Nothing -> ({ model | mainSearch = nm }, c)
        Just r  ->
          -- If the selected char has a main, automatically select that as our main
          let chr = Maybe.withDefault {id = r.id, name = r.name} r.main
          in ({ model | mainId = chr.id, mainName = chr.name, mainSearch = A.clear nm }, c)

    ImgUpload [i] -> ({ model | imgState = Api.Loading }, Api.postImage Api.Ch i ImgDone)
    ImgUpload _   -> (model, Cmd.none)

    ImgDone (Api.Image id _ _) -> ({ model | image = id, imgState = Api.Normal  }, Cmd.none)
    ImgDone r                  -> ({ model | image =  0, imgState = Api.Error r }, Cmd.none)


zeroEmpty : Int -> String
zeroEmpty i = if i == 0 then "" else String.fromInt i


view : Model -> Html Msg
view model = card "general" "General info" []

  [ cardRow "Name" Nothing <| formGroups
    [ [ label [for "name"] [text "Name (romaji)"]
      , inputText "name" model.name Name [required True, maxlength 200]
      ]
    , [ label [for "original"] [text "Original"]
      , inputText "original" model.original Original [maxlength 200]
      , div [class "form-group__help"] [text "The character's name in the language of the visual novel, leave blank if it already is in the Latin alphabet."]
      ]
    , [ inputTextArea "aliases" model.alias Alias
        [ rows 4, maxlength 500
        , classList [("is-invalid", model.aliasDuplicates)]
        ]
      , if model.aliasDuplicates
        then div [class "invalid-feedback"]
          [ text "There are duplicate aliases." ]
        else text ""
      , div [class "form-group__help"] [ text "(Un)official aliases, separated by a newline." ]
      ]
    ]

  , cardRow "Description" (Just "English please!") <| formGroup
    [ inputTextArea "desc" model.desc Desc [rows 8] ]

  , cardRow "Image" Nothing
    [ div [class "row"]
      [ div [class "col-md col-md--1"]
        [ div [style "max-width" "200px", style "margin-bottom" "8px"]
          [ dbImg "ch" (if model.imgState == Api.Loading then -1 else model.image) [] Nothing ]
        ]
      , div [class "col-md col-md--2"] <| formGroups
        [ [ label [for "img"] [ text "Upload new image" ]
          , input [type_ "file", class "text", name "img", id "img", Api.onFileChange ImgUpload, disabled (model.imgState == Api.Loading) ] []
          , case model.imgState of
              Api.Error r -> div [class "invalid-feedback"] [text <| Api.showResponse r]
              _ -> text ""
          , div [class "form-group__help"]
            [ text "Image must be in JPEG or PNG format and at most 1MiB. Images larger than 256x300 will be resized automatically. Image must be safe for work!" ]
          ]
        , [ label [for "img_id"] [ text "Image ID" ]
          , inputText "img_id" (String.fromInt model.image) Image [pattern "^[0-9]+$", disabled (model.imgState == Api.Loading)]
          , div [class "form-group__help"]
            [ text "Use a character image that is already on the server. Set to '0' to remove the current image." ]
          ]
        ]
      ]
    ]

  , cardRow "Meta" Nothing <| formGroups
    [ [ label [for "sex"] [text "Sex"]
      , inputSelect [id "sex", onInput Gender] model.gender genders
      ]
    , [ label [for "bloodt"] [text "Blood type"]
      , inputSelect [id "bloodt", onInput Bloodt] model.bloodt bloodTypes
      ]
      -- TODO: Enforce that both or neither are set
    , [ label [for "b_month"] [text "Birthday"]
      , inputSelect [id "b_month", onInput BMonth, class "form-control--inline"] (String.fromInt model.bMonth)
          <| ("0", "--month--") :: List.map (\i -> (String.fromInt i, String.fromInt i)) (List.range 1 12)
      , inputSelect [id "b_day",   onInput BDay,   class "form-control--inline"] (String.fromInt model.bDay)
          <| ("0", "--day--"  ) :: List.map (\i -> (String.fromInt i, String.fromInt i)) (List.range 1 31)
      ]
      -- XXX: This looks messy
    , [ label [] [ text "Measurements" ]
      , p []
        [ text "Bust (cm): ",   inputText "s_bust"  (zeroEmpty model.sBust ) SBust  [class "form-control--inline", style "width" "4em", pattern "^[0-9]{0,5}$"]
        , text " Waist (cm): ", inputText "s_waist" (zeroEmpty model.sWaist) SWaist [class "form-control--inline", style "width" "4em", pattern "^[0-9]{0,5}$"]
        , text " Hip (cm): ",   inputText "s_hip"   (zeroEmpty model.sHip  ) SHip   [class "form-control--inline", style "width" "4em", pattern "^[0-9]{0,5}$"]
        ]
      , p []
        [ text "Height (cm): ", inputText "height"  (zeroEmpty model.height) Height [class "form-control--inline", style "width" "5em", pattern "^[0-9]{0,5}$"]
        , text " Weight (kg): ",inputText "weight"  (Maybe.withDefault "" <| Maybe.map String.fromInt model.weight) Weight [class "form-control--inline", style "width" "5em", pattern "^[0-9]{0,5}$"]
        ]
      ]
    ]

  , cardRow "Instance" Nothing <|
    if model.mainIs
    then formGroup [ div [class "form-group__help"]
        [ text "This character is already referenced as \"main\" from another character entry."
        , text " If you want link this entry to another character, please edit that other character instead."
        ]
      ]
    else formGroups <|
      [ label [class "checkbox"] [ inputCheck "" model.mainInstance MainInstance, text " This character is an instance of another character" ] ]
      :: if not model.mainInstance then [] else
      [ [ if model.mainId == 0
          then div [] [ text "No character selected." ]
          else div []
            [ text "Main character: "
            , span [class "muted"] [ text <| "c" ++ String.fromInt model.mainId ++ ":" ]
            , a [href <| "/c" ++ String.fromInt model.mainId, target "_blank"] [ text model.mainName ]
            ]
        ]
      , if model.mainId == 0 then [] else
          [ inputSelect [id "mainspoil", onInput MainSpoil, class "form-control--inline"] (String.fromInt model.mainSpoil) spoilLevels ]
      , A.view searchConfig model.mainSearch [placeholder "Character name...", style "max-width" "400px"]
      ]

  ]
