module VNEdit.General exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import File exposing (File)
import Json.Decode as JD
import Lib.Html exposing (..)
import Lib.Gen as Gen
import Lib.Util exposing (..)
import Lib.Api as Api


type alias Model =
  { desc            : String
  , image           : Int
  , imgState        : Api.State
  , img_nsfw        : Bool
  , length          : Int
  , l_renai         : String
  , l_wp            : String
  , anime           : String
  , animeList       : List { aid : Int }
  , animeDuplicates : Bool
  }


init : Gen.VNEdit -> Model
init d =
  { desc            = d.desc
  , image           = d.image
  , imgState        = Api.Normal
  , img_nsfw        = d.img_nsfw
  , length          = d.length
  , l_renai         = d.l_renai
  , l_wp            = d.l_wp
  , anime           = String.join " " (List.map (.aid >> String.fromInt) d.anime)
  , animeList       = d.anime
  , animeDuplicates = False
  }


new : Model
new =
  { desc            = ""
  , image           = 0
  , imgState        = Api.Normal
  , img_nsfw        = False
  , length          = 0
  , l_renai         = ""
  , l_wp            = ""
  , anime           = ""
  , animeList       = []
  , animeDuplicates = False
  }


type Msg
  = Desc String
  | Image String
  | ImgNSFW Bool
  | Length String
  | LWP String
  | LRenai String
  | Anime String
  | ImgUpload (List File)
  | ImgDone Api.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Desc s     -> ({ model | desc = s }, Cmd.none)
    Image s    -> ({ model | image = if s == "" then 0 else Maybe.withDefault model.image (String.toInt s) }, Cmd.none)
    ImgNSFW b  -> ({ model | img_nsfw = b }, Cmd.none)
    Length s   -> ({ model | length = Maybe.withDefault 0 (String.toInt s) }, Cmd.none)
    LWP s      -> ({ model | l_wp = s }, Cmd.none)
    LRenai s   -> ({ model | l_renai = s }, Cmd.none)

    Anime s ->
      let lst = List.map (\e -> { aid = Maybe.withDefault 0 (String.toInt e) }) (String.words s)
      in ({ model | anime = s, animeList = lst, animeDuplicates = hasDuplicates <| List.map .aid lst }, Cmd.none)

    ImgUpload [i] -> ({ model | imgState = Api.Loading }, Api.postImage Api.Cv i ImgDone)
    ImgUpload _   -> (model, Cmd.none)

    ImgDone (Gen.Image id _ _) -> ({ model | image = id, imgState = Api.Normal  }, Cmd.none)
    ImgDone r                  -> ({ model | image =  0, imgState = Api.Error r }, Cmd.none)


view : Model -> (Msg -> a) -> List (Html a) -> Html a
view model wrap titles = card "general" "General info" [] <|
  titles ++ List.map (Html.map wrap)
  [ cardRow "Description" (Just "English please!") <| formGroup
    [ inputTextArea "desc" model.desc Desc [rows 8]
    , div [class "form-group__help"]
      [ text "Short description of the main story. Please do not include untagged spoilers,"
      , text " and don't forget to list the source in case you didn't write the description yourself."
      , text " Formatting codes are allowed."
      ]
    ]
  , cardRow "Image" Nothing
    [ div [class "row"]
      [ div [class "col-md col-md--1"]
        [ div [style "max-width" "200px", style "margin-bottom" "8px"]
          [ dbImg "cv" (if model.imgState == Api.Loading then -1 else model.image) [] Nothing ]
        ]
      , div [class "col-md col-md--2"] <| formGroups
        [ [ label [for "img"] [ text "Upload new image" ]
          , input [type_ "file", class "text", name "img", id "img", Api.onFileChange ImgUpload, disabled (model.imgState == Api.Loading) ] []
          , case model.imgState of
              Api.Error r -> div [class "invalid-feedback"] [text <| Api.showResponse r]
              _ -> text ""
          , div [class "form-group__help"]
            [ text "Preferably the cover of the CD/DVD/package. Image must be in JPEG or PNG format and at most 5MB. Images larger than 256x400 will automatically be resized." ]
          ]
        , [ label [for "img_id"] [ text "Image ID" ]
          , inputText "img_id" (String.fromInt model.image) Image [pattern "^[0-9]+$", disabled (model.imgState == Api.Loading)]
          , div [class "form-group__help"]
            [ text "Use a VN image that is already on the server. Set to '0' to remove the current image." ]
          ]
        , [ label [for "img_nsfw"] [ text "NSFW" ]
          , label [class "checkbox"]
            [ inputCheck "img_nsfw" model.img_nsfw ImgNSFW
            , text " Not safe for work" ]
          , div [class "form-group__help"]
            [ text "Please check this option if the image contains nudity, gore, or is otherwise not safe in a work-friendly environment." ]
          ]
        ]
      ]
    ]
  , cardRow "Properties" Nothing <| formGroups
    [ [ label [for "length"] [ text "Length" ]
      , inputSelect [id "length", name "length", onInput Length]
          (String.fromInt model.length)
          (List.map (\(a,b) -> (String.fromInt a, b)) Gen.vnLengths)
      ]
    , [ label [] [ text "External links" ]
      , p [] [ text "http://en.wikipedia.org/wiki/", inputText "l_wp" model.l_wp LWP [class "form-control--inline", maxlength 100] ]
      , p [] [ text "http://renai.us/game/", inputText "l_renai" model.l_renai LRenai [class "form-control--inline", maxlength 100], text ".shtml" ]
      ]
      -- TODO: Nicer list-editing and search suggestions for anime
    , [ label [ for "anime" ] [ text "Anime" ]
      , inputText "anime" model.anime Anime [pattern "^[ 0-9]*$"]
      , if model.animeDuplicates
        then div [class "invalid-feedback"] [ text "There are duplicate anime." ]
        else text ""
      , div [class "form-group__help"]
        [ text "Whitespace separated list of AniDB anime IDs. E.g. \"1015 3348\" will add Shingetsutan Tsukihime and Fate/stay night as related anime."
        , br [] []
        , text "Note: It can take a few minutes for the anime titles to appear on the VN page."
        ]
      ]
    ]
  ]
