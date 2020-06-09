module CharEdit exposing (main)

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
import Lib.RDate as RDate
import Gen.Release as GR
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
  | Traits
  | VNs
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
  , mainSpoil   : Int
  , image       : Maybe String
  , imageState  : Api.State
  , imageNew    : Set.Set String
  , imageSex    : Maybe Int
  , imageVio    : Maybe Int
  , traits      : List GCE.RecvTraits
  , traitSearch : A.Model GApi.ApiTraitResult
  , traitSelId  : Int
  , traitSelSpl : Int
  , vns         : List GCE.RecvVns
  , vnSearch    : A.Model GApi.ApiVNResult
  , releases    : Dict.Dict Int (List GCE.RecvReleasesRels) -- vid -> list of releases
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
  , mainSpoil   = d.main_spoil
  , image       = d.image
  , imageState  = Api.Normal
  , imageNew    = Set.empty
  , imageSex    = d.image_sex
  , imageVio    = d.image_vio
  , traits      = d.traits
  , traitSearch = A.init ""
  , traitSelId  = 0
  , traitSelSpl = 0
  , vns         = d.vns
  , vnSearch    = A.init ""
  , releases    = Dict.fromList <| List.map (\v -> (v.id, v.rels)) d.releases
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
  , main_spoil  = model.mainSpoil
  , image       = model.image
  , image_sex   = model.imageSex
  , image_vio   = model.imageVio
  , traits      = List.map (\t -> { tid = t.tid, spoil = t.spoil }) model.traits
  , vns         = List.map (\v -> { vid = v.vid, rid = v.rid, spoil = v.spoil, role = v.role }) model.vns
  }

mainConfig : A.Config Msg GApi.ApiCharResult
mainConfig = { wrap = MainSearch, id = "mainadd", source = A.charSource }

traitConfig : A.Config Msg GApi.ApiTraitResult
traitConfig = { wrap = TraitSearch, id = "traitadd", source = A.traitSource }

vnConfig : A.Config Msg GApi.ApiVNResult
vnConfig = { wrap = VnSearch, id = "vnadd", source = A.vnSource }

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
  | MainSpoil Int
  | ImageSet String
  | ImageSelect
  | ImageSelected File
  | ImageLoaded GApi.Response
  | ImageSex Int Bool
  | ImageVio Int Bool
  | TraitDel Int
  | TraitSel Int Int
  | TraitSpoil Int Int
  | TraitSearch (A.Msg GApi.ApiTraitResult)
  | VnRel Int (Maybe Int)
  | VnRole Int String
  | VnSpoil Int Int
  | VnDel Int
  | VnRelAdd Int String
  | VnSearch (A.Msg GApi.ApiVNResult)
  | VnRelGet Int GApi.Response


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
    MainSpoil n -> ({ model | mainSpoil = n }, Cmd.none)

    ImageSet s  -> ({ model | image = if s == "" then Nothing else Just s}, Cmd.none)
    ImageSelect -> (model, FSel.file ["image/png", "image/jpg"] ImageSelected)
    ImageSelected f -> ({ model | imageState = Api.Loading }, Api.postImage Api.Ch f ImageLoaded)
    ImageLoaded (GApi.Image i _ _) -> ({ model | image = Just i, imageNew = Set.insert i model.imageNew, imageState = Api.Normal }, Cmd.none)
    ImageLoaded e -> ({ model | imageState = Api.Error e }, Cmd.none)
    ImageSex i _ -> ({ model | imageSex = Just i }, Cmd.none)
    ImageVio i _ -> ({ model | imageVio = Just i }, Cmd.none)

    TraitDel idx       -> ({ model | traits = delidx idx model.traits }, Cmd.none)
    TraitSel id spl    -> ({ model | traitSelId = id, traitSelSpl = spl }, Cmd.none)
    TraitSpoil idx spl -> ({ model | traits = modidx idx (\t -> { t | spoil = spl }) model.traits }, Cmd.none)
    TraitSearch m ->
      let (nm, c, res) = A.update traitConfig m model.traitSearch
      in case res of
        Nothing -> ({ model | traitSearch = nm }, c)
        Just t ->
          if not t.applicable || t.state /= 2 || List.any (\l -> l.tid == t.id) model.traits
          then ({ model | traitSearch = A.clear nm "" }, c)
          else ({ model | traitSearch = A.clear nm "", traits = model.traits ++ [{ tid = t.id, spoil = t.defaultspoil, name = t.name, group = t.group_name, applicable = t.applicable, new = True }] }, Cmd.none)

    VnRel   idx r -> ({ model | vns = modidx idx (\v -> { v | rid   = r }) model.vns }, Cmd.none)
    VnRole  idx s -> ({ model | vns = modidx idx (\v -> { v | role  = s }) model.vns }, Cmd.none)
    VnSpoil idx n -> ({ model | vns = modidx idx (\v -> { v | spoil = n }) model.vns }, Cmd.none)
    VnDel   idx   -> ({ model | vns = delidx idx model.vns }, Cmd.none)
    VnRelAdd vid title ->
      let rid = Dict.get vid model.releases |> Maybe.andThen (\rels -> List.filter (\r -> not (List.any (\v -> v.vid == vid && v.rid == Just r.id) model.vns)) rels |> List.head |> Maybe.map (\r -> r.id))
      in ({ model | vns = model.vns ++ [{ vid = vid, title = title, rid = rid, spoil = 0, role = "primary" }] }, Cmd.none)
    VnSearch m ->
      let (nm, c, res) = A.update vnConfig m model.vnSearch
      in case res of
        Nothing -> ({ model | vnSearch = nm }, c)
        Just vn ->
          if List.any (\v -> v.vid == vn.id) model.vns
          then ({ model | vnSearch = A.clear nm "" }, c)
          else ({ model | vnSearch = A.clear nm "", vns = model.vns ++ [{ vid = vn.id, title = vn.title, rid = Nothing, spoil = 0, role = "primary" }] }
               , if Dict.member vn.id model.releases then Cmd.none else GR.send { vid = vn.id } (VnRelGet vn.id))
    VnRelGet vid (GApi.Releases r) -> ({ model | releases = Dict.insert vid r model.releases }, Cmd.none)
    VnRelGet _ r -> ({ model | state = Api.Error r }, Cmd.none) -- XXX

    Submit -> ({ model | state = Api.Loading }, GCE.send (encode model) Submitted)
    Submitted (GApi.Redirect s) -> (model, load s)
    Submitted r -> ({ model | state = Api.Error r }, Cmd.none)


isValid : Model -> Bool
isValid model = not
  (  (model.name /= "" && model.name == model.original)
  || hasDuplicates (List.map (\v -> (v.vid, Maybe.withDefault 0 v.rid)) model.vns)
  )


spoilOpts =
  [ (0, "Not a spoiler")
  , (1, "Minor spoiler")
  , (2, "Major spoiler")
  ]


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
        [ inputSelect "" model.mainSpoil MainSpoil [] spoilOpts
        , br_ 2
        , Maybe.withDefault (text "No character selected") <| Maybe.map (\m -> span []
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
        , if not (Set.member (Maybe.withDefault "" model.image) model.imageNew) then text "" else div []
          [ br [] []
          , text "Please flag this image: (see the ", a [ href "/d19" ] [ text "image flagging guidelines" ], text " for guidance)"
          , table []
            [ thead [] [ tr [] [ td [] [ text "Sexual" ], td [] [ text "Violence" ] ] ]
            , tr []
              [ td []
                [ label [] [ inputRadio "" (model.imageSex == Just 0) (ImageSex 0), text " Safe" ], br [] []
                , label [] [ inputRadio "" (model.imageSex == Just 1) (ImageSex 1), text " Suggestive" ], br [] []
                , label [] [ inputRadio "" (model.imageSex == Just 2) (ImageSex 2), text " Explicit" ]
                ]
              , td []
                [ label [] [ inputRadio "" (model.imageVio == Just 0) (ImageVio 0), text " Tame" ], br [] []
                , label [] [ inputRadio "" (model.imageVio == Just 1) (ImageVio 1), text " Violent" ], br [] []
                , label [] [ inputRadio "" (model.imageVio == Just 2) (ImageVio 2), text " Brutal" ]
                ]
              ]
            ]
          ]
        ]
      ]

    traits =
      let
        old = List.filter (\(_,t) -> not t.new) <| List.indexedMap (\i t -> (i,t)) model.traits
        new = List.filter (\(_,t) ->     t.new) <| List.indexedMap (\i t -> (i,t)) model.traits
        spoil t = if t.tid == model.traitSelId then model.traitSelSpl else t.spoil
        trait (i,t) = (String.fromInt t.tid,
          tr []
          [ td [ style "padding" "0 0 0 10px", style "text-decoration" (if t.applicable then "none" else "line-through") ]
            [ Maybe.withDefault (text "") <| Maybe.map (\g -> b [ class "grayedout" ] [ text <| g ++ " / " ]) t.group
            , a [ href <| "/i" ++ String.fromInt t.tid ] [ text t.name ]
            , if t.applicable then text "" else b [ class "standout" ] [ text " (not applicable)" ]
            ]
          , td [ class "buts" ]
            [ a [ href "#", onMouseOver (TraitSel t.tid 0), onMouseOut (TraitSel 0 0), onClickD (TraitSpoil i 0), classList [("s0", spoil t == 0 )], title "Not a spoiler" ] []
            , a [ href "#", onMouseOver (TraitSel t.tid 1), onMouseOut (TraitSel 0 0), onClickD (TraitSpoil i 1), classList [("s1", spoil t == 1 )], title "Minor spoiler" ] []
            , a [ href "#", onMouseOver (TraitSel t.tid 2), onMouseOut (TraitSel 0 0), onClickD (TraitSpoil i 2), classList [("s2", spoil t == 2 )], title "Major spoiler" ] []
            ]
          , td []
            [ case (t.tid == model.traitSelId, lookup model.traitSelSpl spoilOpts) of
                (True, Just s) -> text s
                _ -> a [ href "#", onClickD (TraitDel i)] [ text "remove" ]
            ]
          ])
      in
      K.node "table" [ class "formtable chare_traits" ] <|
        (if List.isEmpty old then []
         else ("head",  tr [ class "newpart" ] [ td [ colspan 3 ] [text "Current traits"     ]]) :: List.map trait old)
        ++
        (if List.isEmpty new then []
         else ("added", tr [ class "newpart" ] [ td [ colspan 3 ] [text "Newly added traits" ]]) :: List.map trait new)
        ++
        [ ("add", tr [] [ td [ colspan 3 ] [ br_ 1, A.view traitConfig model.traitSearch [placeholder "Add trait..."] ] ])
        ]

    -- XXX: This function has quite a few nested loops, prolly rather slow with many VNs/releases
    vns =
      let
        uniq lst set =
          case lst of
            (x::xs) -> if Set.member x set then uniq xs set else x :: uniq xs (Set.insert x set)
            [] -> []
        showrel r = "[" ++ (RDate.format (RDate.expand r.released)) ++ " " ++ (String.join "," r.lang) ++ "] " ++ r.title ++ " (r" ++ String.fromInt r.id ++ ")"
        vn vid lst rels =
          let title = Maybe.withDefault "<unknown>" <| Maybe.map (\(_,v) -> v.title) <| List.head lst
          in
          [ ( String.fromInt vid
            , tr [ class "newpart" ] [ td [ colspan 4, style "padding-bottom" "5px" ]
              [ b [ class "grayedout" ] [ text <| "v" ++ String.fromInt vid ++ ":" ]
              , a [ href <| "/v" ++ String.fromInt vid ] [ text title ]
              ]]
            )
          ] ++ List.map (\(idx,item) ->
            ( String.fromInt vid ++ "i" ++ String.fromInt (Maybe.withDefault 0 item.rid)
            , tr []
              [ td [] [ inputSelect "" item.rid (VnRel idx) [ style "width" "400px", style "margin" "0 15px" ] <|
                  (Nothing, if List.length lst == 1 then "All (full) releases" else "Other releases")
                  :: List.map (\r -> (Just r.id, showrel r)) rels
                  ++ if isJust item.rid && List.isEmpty (List.filter (\r -> Just r.id == item.rid) rels)
                     then [(item.rid, "Deleted release: r" ++ String.fromInt (Maybe.withDefault 0 item.rid))] else []
                ]
              , td [] [ inputSelect "" item.role (VnRole idx) [] GT.charRoles ]
              , td [] [ inputSelect "" item.spoil (VnSpoil idx) [ style "width" "130px", style "margin" "0 5px" ] spoilOpts ]
              , td [] [ inputButton "remove" (VnDel idx) [] ]
              ]
            )
          ) lst
          ++ (if List.map (\(_,r) -> Maybe.withDefault 0 r.rid) lst |> hasDuplicates |> not then [] else [
            ( String.fromInt vid ++ "dup"
            , td [] [ td [ colspan 4, style "padding" "0 15px" ] [ b [ class "standout" ] [ text "List contains duplicate releases." ] ] ]
            )
          ])
          ++ (if 1 /= List.length (List.filter (\(_,r) -> isJust r.rid) lst) then [] else [
            ( String.fromInt vid ++ "warn"
            , tr [] [ td [ colspan 4, style "padding" "0 15px" ]
              [ b [ class "standout" ] [ text "Note: " ]
              , text "Only select specific releases if the character has a significantly different role in those releases. "
              , br [] []
              , text "If the character's role is mostly the same in all releases (ignoring trials), then just select \"All (full) releases\"." ]
            ])
          ])
          ++ (if List.length lst > List.length rels then [] else [
            ( String.fromInt vid ++ "add"
            , tr [] [ td [ colspan 4 ] [ inputButton "add release" (VnRelAdd vid title) [style "margin" "0 15px"] ] ]
            )
          ])
      in
      K.node "table" [ class "formtable" ] <|
        List.concatMap
          (\vid -> vn vid (List.filter (\(_,r) -> r.vid == vid) (List.indexedMap (\i r -> (i,r)) model.vns)) (Maybe.withDefault [] (Dict.get vid model.releases)))
          (uniq (List.map (\v -> v.vid) model.vns) Set.empty)
        ++
        [ ("add", tr [] [ td [ colspan 4 ] [ br_ 1, A.view vnConfig model.vnSearch [placeholder "Add visual novel..."] ] ]) ]

  in
  form_ Submit (model.state == Api.Loading)
  [ div [ class "maintabs left" ]
    [ ul []
      [ li [ classList [("tabselected", model.tab == General)] ] [ a [ href "#", onClickD (Tab General) ] [ text "General info" ] ]
      , li [ classList [("tabselected", model.tab == Image  )] ] [ a [ href "#", onClickD (Tab Image  ) ] [ text "Image"        ] ]
      , li [ classList [("tabselected", model.tab == Traits )] ] [ a [ href "#", onClickD (Tab Traits ) ] [ text "Traits"       ] ]
      , li [ classList [("tabselected", model.tab == VNs    )] ] [ a [ href "#", onClickD (Tab VNs    ) ] [ text "Visual Novels"] ]
      , li [ classList [("tabselected", model.tab == All    )] ] [ a [ href "#", onClickD (Tab All    ) ] [ text "All items"    ] ]
      ]
    ]
  , div [ class "mainbox", classList [("hidden", model.tab /= General && model.tab /= All)] ] [ h1 [] [ text "General info" ], table [ class "formtable" ] geninfo ]
  , div [ class "mainbox", classList [("hidden", model.tab /= Image   && model.tab /= All)] ] [ h1 [] [ text "Image" ], image ]
  , div [ class "mainbox", classList [("hidden", model.tab /= Traits  && model.tab /= All)] ] [ h1 [] [ text "Traits" ], traits ]
  , div [ class "mainbox", classList [("hidden", model.tab /= VNs     && model.tab /= All)] ] [ h1 [] [ text "Visual Novels" ], vns ]
  , div [ class "mainbox" ] [ fieldset [ class "submit" ]
      [ Html.map Editsum (Editsum.view model.editsum)
      , submitButton "Submit" model.state (isValid model)
      ]
    ]
  ]
