module CharEdit exposing (main)

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes exposing (..)
import Browser
import Browser.Navigation exposing (load)
import File exposing (File)
import File.Select as FSel
import Lib.Util exposing (..)
import Lib.Html exposing (..)
import Lib.TextPreview as TP
import Lib.Autocomplete as A
import Lib.Api as Api
import Lib.Editsum as Editsum
import Gen.CharEdit as GCE
import Gen.Types as GT
import Gen.Api as GApi


main : Program GCE.Recv Model Msg
main = Browser.element
  { init   = \e -> (init e, Cmd.none)
  , view   = view
  , update = update
  , subscriptions = always Sub.none
  }


type Tab
  = General
  | Image
  | All

type alias Model =
  { state       : Api.State
  , tab         : Tab
  , editsum     : Editsum.Model
  , name        : String
  , original    : String
  , alias       : String
  , desc        : TP.Model
  , gender      : String
  , bMonth      : Int
  , bDay        : Int
  , age         : Maybe Int
  , sBust       : Int
  , sWaist      : Int
  , sHip        : Int
  , height      : Int
  , weight      : Maybe Int
  , bloodt      : String
  , cupSize     : String
  , main        : Maybe Int
  , mainRef     : Bool
  , mainHas     : Bool
  , mainName    : String
  , mainSearch  : A.Model GApi.ApiCharResult
  , image       : Maybe String
  , imageState  : Api.State
  , id          : Maybe Int
  }


init : GCE.Recv -> Model
init d =
  { state       = Api.Normal
  , tab         = General
  , editsum     = { authmod = d.authmod, editsum = TP.bbcode d.editsum, locked = d.locked, hidden = d.hidden }
  , name        = d.name
  , original    = d.original
  , alias       = d.alias
  , desc        = TP.bbcode d.desc
  , gender      = d.gender
  , bMonth      = d.b_month
  , bDay        = if d.b_day == 0 then 1 else d.b_day
  , age         = d.age
  , sBust       = d.s_bust
  , sWaist      = d.s_waist
  , sHip        = d.s_hip
  , height      = d.height
  , weight      = d.weight
  , bloodt      = d.bloodt
  , cupSize     = d.cup_size
  , main        = d.main
  , mainRef     = d.main_ref
  , mainHas     = d.main /= Nothing
  , mainName    = d.main_name
  , mainSearch  = A.init ""
  , image       = d.image
  , imageState  = Api.Normal
  , id          = d.id
  }


encode : Model -> GCE.Send
encode model =
  { id          = model.id
  , editsum     = model.editsum.editsum.data
  , hidden      = model.editsum.hidden
  , locked      = model.editsum.locked
  , name        = model.name
  , original    = model.original
  , alias       = model.alias
  , desc        = model.desc.data
  , gender      = model.gender
  , b_month     = model.bMonth
  , b_day       = model.bDay
  , age         = model.age
  , s_bust      = model.sBust
  , s_waist     = model.sWaist
  , s_hip       = model.sHip
  , height      = model.height
  , weight      = model.weight
  , bloodt      = model.bloodt
  , cup_size    = model.cupSize
  , main        = if model.mainHas then model.main else Nothing
  , image       = model.image
  }

mainConfig : A.Config Msg GApi.ApiCharResult
mainConfig = { wrap = MainSearch, id = "mainadd", source = A.charSource }

type Msg
  = Editsum Editsum.Msg
  | Tab Tab
  | Submit
  | Submitted GApi.Response
  | Name String
  | Original String
  | Alias String
  | Desc TP.Msg
  | Gender String
  | BMonth Int
  | BDay Int
  | Age (Maybe Int)
  | SBust (Maybe Int)
  | SWaist (Maybe Int)
  | SHip (Maybe Int)
  | Height (Maybe Int)
  | Weight (Maybe Int)
  | BloodT String
  | CupSize String
  | MainHas Bool
  | MainSearch (A.Msg GApi.ApiCharResult)
  | ImageSet String
  | ImageSelect
  | ImageSelected File
  | ImageLoaded GApi.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Editsum m  -> let (nm,nc) = Editsum.update m model.editsum in ({ model | editsum = nm }, Cmd.map Editsum nc)
    Tab t      -> ({ model | tab = t }, Cmd.none)
    Name s     -> ({ model | name = s }, Cmd.none)
    Original s -> ({ model | original = s }, Cmd.none)
    Alias s    -> ({ model | alias = s }, Cmd.none)
    Desc m     -> let (nm,nc) = TP.update m model.desc in ({ model | desc = nm }, Cmd.map Desc nc)
    Gender s   -> ({ model | gender = s }, Cmd.none)
    BMonth n   -> ({ model | bMonth = n }, Cmd.none)
    BDay n     -> ({ model | bDay   = n }, Cmd.none)
    Age s      -> ({ model | age    = s }, Cmd.none)
    SBust s    -> ({ model | sBust  = Maybe.withDefault 0 s }, Cmd.none)
    SWaist s   -> ({ model | sWaist = Maybe.withDefault 0 s }, Cmd.none)
    SHip s     -> ({ model | sHip   = Maybe.withDefault 0 s }, Cmd.none)
    Height s   -> ({ model | height = Maybe.withDefault 0 s }, Cmd.none)
    Weight s   -> ({ model | weight = s }, Cmd.none)
    BloodT s   -> ({ model | bloodt = s }, Cmd.none)
    CupSize s  -> ({ model | cupSize= s }, Cmd.none)

    MainHas b  -> ({ model | mainHas = b }, Cmd.none)
    MainSearch m ->
      let (nm, c, res) = A.update mainConfig m model.mainSearch
      in case res of
        Nothing -> ({ model | mainSearch = nm }, c)
        Just m1 ->
          case m1.main of
            Just m2 -> ({ model | mainSearch = A.clear nm "", main = Just m2.id, mainName = m2.name }, c)
            Nothing -> ({ model | mainSearch = A.clear nm "", main = Just m1.id, mainName = m1.name }, c)

    ImageSet s  -> ({ model | image = if s == "" then Nothing else Just s}, Cmd.none)
    ImageSelect -> (model, FSel.file ["image/png", "image/jpg"] ImageSelected)
    ImageSelected f -> ({ model | imageState = Api.Loading }, Api.postImage Api.Ch f ImageLoaded)
    ImageLoaded (GApi.Image i _ _) -> ({ model | image = Just i, imageState = Api.Normal }, Cmd.none)
    ImageLoaded e -> ({ model | imageState = Api.Error e }, Cmd.none)

    Submit -> ({ model | state = Api.Loading }, GCE.send (encode model) Submitted)
    Submitted (GApi.Redirect s) -> (model, load s)
    Submitted r -> ({ model | state = Api.Error r }, Cmd.none)


isValid : Model -> Bool
isValid model = not
  (  model.name == model.original
  )


view : Model -> Html Msg
view model =
  let
    geninfo =
      [ formField "name::Name (romaji)" [ inputText "name" model.name Name GCE.valName ]
      , formField "original::Original name"
        [ inputText "original" model.original Original GCE.valOriginal
        , if model.name /= "" && model.name == model.original
          then b [ class "standout" ] [ br [] [], text "Should not be the same as the Name (romaji). Leave blank is the original name is already in the latin alphabet" ]
          else text ""
        ]
      , formField "alias::Aliases"
        [ inputTextArea "alias" model.alias Alias (rows 3 :: GCE.valAlias)
        , br [] []
        , text "(Un)official aliases, separated by a newline. Must not include spoilers!"
        ]
      , formField "desc::Description" [ TP.view "desc" model.desc Desc 600 (style "height" "150px" :: GCE.valDesc) [ b [ class "standout" ] [ text "English please!" ] ] ]
      , formField "bmonth::Birthday"
        [ inputSelect "bmonth" model.bMonth BMonth [style "width" "128px"]
          [ ( 0, "Unknown")
          , ( 1, "January")
          , ( 2, "February")
          , ( 3, "March")
          , ( 4, "April")
          , ( 5, "May")
          , ( 6, "June")
          , ( 7, "July")
          , ( 8, "August")
          , ( 9, "September")
          , (10, "October")
          , (11, "November")
          , (12, "December")
          ]
        , if model.bMonth == 0 then text ""
          else inputSelect "" model.bDay BDay [style "width" "70px"] <| List.map (\i -> (i, String.fromInt i)) <| List.range 1 31
        ]
      , formField "age::Age"       [ inputNumber "age" model.age Age GCE.valAge, text " years" ]

      , tr [ class "newpart" ] [ td [ colspan 2 ] [ text "Body" ] ]
      , formField "gender::Sex"    [ inputSelect "gender" model.gender Gender [] GT.genders ]
      , formField "sbust::Bust"    [ inputNumber "sbust"  (if model.sBust  == 0 then Nothing else Just model.sBust ) SBust  GCE.valS_Bust, text " cm" ]
      , formField "swaist::Waist"  [ inputNumber "swiast" (if model.sWaist == 0 then Nothing else Just model.sWaist) SWaist GCE.valS_Waist,text " cm" ]
      , formField "ship::Hips"     [ inputNumber "ship"   (if model.sHip   == 0 then Nothing else Just model.sHip  ) SHip   GCE.valS_Hip,  text " cm" ]
      , formField "height::Height" [ inputNumber "height" (if model.height == 0 then Nothing else Just model.height) Height GCE.valHeight, text " cm" ]
      , formField "weight::Weight" [ inputNumber "weight" model.weight Weight GCE.valWeight, text " kg" ]
      , formField "bloodt::Blood type" [ inputSelect "bloodt"  model.bloodt  BloodT  [] GT.bloodTypes ]
      , formField "cupsize::Cup size"  [ inputSelect "cupsize" model.cupSize CupSize [] GT.cupSizes ]

      , tr [ class "newpart" ] [ td [ colspan 2 ] [ text "Instance" ] ]
      ] ++ if model.mainRef
      then
      [ formField "" [ text "This character is already used as an instance for another character. If you want to link more characters to this one, please edit the other characters instead." ] ]
      else
      [ formField "" [ label [] [ inputCheck "" model.mainHas MainHas, text " This character is an instance of another character." ] ]
      , formField "" <| if not model.mainHas then [] else
        [ Maybe.withDefault (text "No character selected") <| Maybe.map (\m -> span []
          [ text "Selected character: "
          , b [ class "grayedout" ] [ text <| "c" ++ String.fromInt m ++ ": " ]
          , a [ href <| "/c" ++ String.fromInt m ] [ text model.mainName ]
          ]) model.main
        , br [] []
        , A.view mainConfig model.mainSearch [placeholder "Set character..."]
        ]
      ]

    image =
      div [ class "formimage" ]
      [ div [] [
        case model.image of
          Nothing -> text "No image."
          Just id -> img [ src (imageUrl id) ] []
        ]
      , div []
        [ h2 [] [ text "Image ID" ]
        , inputText "" (Maybe.withDefault "" model.image) ImageSet GCE.valImage
        , Maybe.withDefault (text "") <| Maybe.map (\i -> a [ href <| "/img/"++i ] [ text " (flagging)" ]) model.image
        , br [] []
        , text "Use an image that already exists on the server or empty to remove the current image."
        , br_ 2
        , h2 [] [ text "Upload new image" ]
        , inputButton "Browse image" ImageSelect []
        , case model.imageState of
            Api.Normal -> text ""
            Api.Loading -> span [ class "spinner" ] []
            Api.Error e -> b [ class "standout" ] [ text <| Api.showResponse e ]
        , br [] []
        , text "Image must be in JPEG or PNG format and at most 10 MiB. Images larger than 256x300 will automatically be resized."
        -- TODO: Add image flagging vote thingy here after uploading a new image.
        ]
      ]

  in
  form_ Submit (model.state == Api.Loading)
  [ div [ class "maintabs left" ]
    [ ul []
      [ li [ classList [("tabselected", model.tab == General)] ] [ a [ href "#", onClickD (Tab General) ] [ text "General info" ] ]
      , li [ classList [("tabselected", model.tab == Image  )] ] [ a [ href "#", onClickD (Tab Image  ) ] [ text "Image"        ] ]
      , li [ classList [("tabselected", model.tab == All    )] ] [ a [ href "#", onClickD (Tab All    ) ] [ text "All items"    ] ]
      ]
    ]
  , div [ class "mainbox", classList [("hidden", model.tab /= General && model.tab /= All)] ]
    [ h1 [] [ text "General info" ], table [ class "formtable" ] geninfo ]
  , div [ class "mainbox", classList [("hidden", model.tab /= Image && model.tab /= All)] ]
    [ h1 [] [ text "Image" ], image ]
  , div [ class "mainbox" ] [ fieldset [ class "submit" ]
      [ Html.map Editsum (Editsum.view model.editsum)
      , submitButton "Submit" model.state (isValid model)
      ]
    ]
  ]
