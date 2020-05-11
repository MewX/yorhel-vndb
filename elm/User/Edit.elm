module User.Edit exposing (main)

import Bitwise exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Keyed as K
import Browser
import Browser.Navigation exposing (load)
import Lib.Html exposing (..)
import Lib.Api as Api
import Gen.Api as GApi
import Gen.Types as GT
import Gen.UserEdit as GUE


main : Program GUE.Recv Model Msg
main = Browser.element
  { init   = \e -> (init e, Cmd.none)
  , view   = view
  , update = update
  , subscriptions = always Sub.none
  }


type alias PassData =
  { cpass       : Bool
  , pass1       : String
  , pass2       : String
  , opass       : String
  }

type alias Model =
  { state       : Api.State
  , id          : Int
  , title       : String
  , username    : String
  , opts        : GUE.RecvOpts
  , admin       : Maybe GUE.SendAdmin
  , prefs       : Maybe GUE.SendPrefs
  , pass        : Maybe PassData
  , passNeq     : Bool
  , mailConfirm : Bool
  }


init : GUE.Recv -> Model
init d =
  { state       = Api.Normal
  , id          = d.id
  , title       = d.title
  , username    = d.username
  , opts        = d.opts
  , admin       = d.admin
  , prefs       = d.prefs
  , pass        = Maybe.map (always { cpass = False, pass1 = "", pass2 = "", opass = "" }) d.prefs
  , passNeq     = False
  , mailConfirm = False
  }


type AdminMsg
  = PermBoard Bool
  | PermBoardmod Bool
  | PermEdit Bool
  | PermImgvote Bool
  | PermImgmod Bool
  | PermTag Bool
  | PermDbmod Bool
  | PermTagmod Bool
  | PermUsermod Bool
  | IgnVotes Bool

type PrefMsg
  = EMail String
  | ShowNsfw Bool
  | MaxSexual Int
  | MaxViolence Int
  | TraitsSexual Bool
  | Spoilers Int
  | TagsAll Bool
  | TagsCont Bool
  | TagsEro Bool
  | TagsTech Bool
  | Skin String
  | Css String
  | NoAds Bool
  | NoFancy Bool
  | Support Bool
  | PubSkin Bool
  | Uniname String

type PassMsg
  = CPass Bool
  | OPass String
  | Pass1 String
  | Pass2 String

type Msg
  = Username String
  | Admin AdminMsg
  | Prefs PrefMsg
  | Pass PassMsg
  | Submit
  | Submitted GApi.Response


updateAdmin : AdminMsg -> GUE.SendAdmin -> GUE.SendAdmin
updateAdmin msg model =
  case msg of
    PermBoard b    -> { model | perm_board    = b }
    PermBoardmod b -> { model | perm_boardmod = b }
    PermEdit b     -> { model | perm_edit     = b }
    PermImgvote b  -> { model | perm_imgvote  = b }
    PermImgmod b   -> { model | perm_imgmod   = b }
    PermTag b      -> { model | perm_tag      = b }
    PermDbmod b    -> { model | perm_dbmod    = b }
    PermTagmod b   -> { model | perm_tagmod   = b }
    PermUsermod b  -> { model | perm_usermod  = b }
    IgnVotes b     -> { model | ign_votes     = b }

updatePrefs : PrefMsg -> GUE.SendPrefs -> GUE.SendPrefs
updatePrefs msg model =
  case msg of
    EMail n    -> { model | email = n }
    ShowNsfw b -> { model | show_nsfw = b }
    MaxSexual n-> { model | max_sexual = n }
    MaxViolence n  -> { model | max_violence = n }
    TraitsSexual b -> { model | traits_sexual = b }
    Spoilers n -> { model | spoilers  = n }
    TagsAll b  -> { model | tags_all  = b }
    TagsCont b -> { model | tags_cont = b }
    TagsEro b  -> { model | tags_ero  = b }
    TagsTech b -> { model | tags_tech = b }
    Skin n     -> { model | skin = n }
    Css n      -> { model | customcss = n }
    NoAds b    -> { model | nodistract_noads = b }
    NoFancy b  -> { model | nodistract_nofancy = b }
    Support b  -> { model | support_enabled = b }
    PubSkin b  -> { model | pubskin_enabled = b }
    Uniname n  -> { model | uniname = n }

updatePass : PassMsg -> PassData -> PassData
updatePass msg model =
  case msg of
    CPass b -> { model | cpass = b }
    OPass n -> { model | opass = n }
    Pass1 n -> { model | pass1 = n }
    Pass2 n -> { model | pass2 = n }


encode : Model -> GUE.Send
encode model =
  { id       = model.id
  , username = model.username
  , admin    = model.admin
  , prefs    = model.prefs
  , password = Maybe.andThen (\p -> if p.cpass && p.pass1 == p.pass2 then Just { old = p.opass, new = p.pass1 } else Nothing) model.pass
  }


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Admin m -> ({ model | admin = Maybe.map (updateAdmin m) model.admin }, Cmd.none)
    Prefs m -> ({ model | prefs = Maybe.map (updatePrefs m) model.prefs }, Cmd.none)
    Pass  m -> ({ model | pass  = Maybe.map (updatePass  m) model.pass, passNeq = False }, Cmd.none)
    Username s -> ({ model | username = s }, Cmd.none)

    Submit ->
      if Maybe.withDefault False (Maybe.map (\p -> p.cpass && p.pass1 /= p.pass2) model.pass)
      then ({ model | passNeq = True }, Cmd.none )
      else ({ model | state = Api.Loading }, GUE.send (encode model) Submitted)

    -- TODO: This reload is only necessary for the skin and customcss options to apply, but it's nicer to do that directly from JS.
    Submitted GApi.Success    -> (model, load <| "/u" ++ String.fromInt model.id ++ "/edit")
    Submitted GApi.MailChange -> ({ model | mailConfirm = True, state = Api.Normal }, Cmd.none)
    Submitted r -> ({ model | state = Api.Error r }, Cmd.none)



view : Model -> Html Msg
view model =
  let
    opts = model.opts
    perm b f = if opts.perm_usermod || b then f else text ""

    adminform m =
      [ tr [ class "newpart" ] [ td [ colspan 2 ] [ text "Admin options" ] ]
      , perm False <| formField "username::Username" [ inputText "username" model.username Username GUE.valUsername ]
      , formField "Permissions"
        [ text "Fields marked with * indicate permissions assigned to new users by default", br_ 1
        , perm opts.perm_boardmod <| label [] [ inputCheck "" m.perm_board    (Admin << PermBoard),    text " board*", br_ 1 ]
        , perm False              <| label [] [ inputCheck "" m.perm_boardmod (Admin << PermBoardmod), text " boardmod", br_ 1 ]
        , perm opts.perm_dbmod    <| label [] [ inputCheck "" m.perm_edit     (Admin << PermEdit),     text " edit*", br_ 1 ]
        , perm opts.perm_imgmod   <| label [] [ inputCheck "" m.perm_imgvote  (Admin << PermImgvote),  text " imgvote* (existing votes will stop counting when unset)", br_ 1 ]
        , perm False              <| label [] [ inputCheck "" m.perm_imgmod   (Admin << PermImgmod),   text " imgmod", br_ 1 ]
        , perm opts.perm_tagmod   <| label [] [ inputCheck "" m.perm_tag      (Admin << PermTag),      text " tag* (existing tag votes will stop counting when unset)", br_ 1 ]
        , perm False              <| label [] [ inputCheck "" m.perm_dbmod    (Admin << PermDbmod),    text " dbmod", br_ 1 ]
        , perm False              <| label [] [ inputCheck "" m.perm_tagmod   (Admin << PermTagmod),   text " tagmod", br_ 1 ]
        , perm False              <| label [] [ inputCheck "" m.perm_usermod  (Admin << PermUsermod),  text " usermod", br_ 1 ]
        ]
      , perm False <| formField "Other" [ label [] [ inputCheck "" m.ign_votes (Admin << IgnVotes), text " Ignore votes in VN statistics" ] ]
      ]

    passform m =
      [ formField "" [ label [] [ inputCheck "" m.cpass (Pass << CPass), text " Change password" ] ]
      ] ++ if not m.cpass then [] else
        [ tr [] [ K.node "td" [colspan 2] [("pass_change", table []
          [ formField "opass::Old password" [ inputPassword "opass" m.opass (Pass << OPass) GUE.valPasswordOld ]
          , formField "pass1::New password" [ inputPassword "pass1" m.pass1 (Pass << Pass1) GUE.valPasswordNew ]
          , formField "pass2::Repeat"
            [ inputPassword "pass2" m.pass2 (Pass << Pass2) GUE.valPasswordNew
            , br_ 1
            , if model.passNeq
              then b [ class "standout" ] [ text "Passwords do not match" ]
              else text ""
            ]
          ])]]
        ]

    supportform m =
      if not (opts.perm_usermod || opts.nodistract_can || opts.support_can || opts.uniname_can || opts.pubskin_can) then [] else
      [ tr [ class "newpart" ] [ td [ colspan 2 ] [ text "Supporter options⭐" ] ]
      , perm opts.nodistract_can <| formField "" [ label [] [ inputCheck "" m.nodistract_noads   (Prefs << NoAds),   text " Disable advertising and other distractions (only hides the support icons for the moment)" ] ]
      , perm opts.nodistract_can <| formField "" [ label [] [ inputCheck "" m.nodistract_nofancy (Prefs << NoFancy), text " Disable supporters badges, custom display names and profile skins" ] ]
      , perm opts.support_can    <| formField "" [ label [] [ inputCheck "" m.support_enabled    (Prefs << Support), text " Display my supporters badge" ] ]
      , perm opts.pubskin_can    <| formField "" [ label [] [ inputCheck "" m.pubskin_enabled    (Prefs << PubSkin), text " Apply my skin and custom CSS when others visit my profile" ] ]
      , perm opts.uniname_can    <| formField "uniname::Display name" [ inputText "uniname" (if m.uniname == "" then model.username else m.uniname) (Prefs << Uniname) GUE.valPrefsUniname ]
      ]

    prefsform m =
      [ tr [ class "newpart" ] [ td [ colspan 2 ] [ text "Preferences" ] ]
      , formField "NSFW" [ label [] [ inputCheck "" m.show_nsfw (Prefs << ShowNsfw), text " Show NSFW images by default" ] ]
      , formField ""
        [ b [ class "grayedout" ] [ text "The two options below are only used for character images at the moment, they will eventually replace the above checkbox and apply to all images on the site." ]
        , br [] []
        , inputSelect "" m.max_sexual (Prefs << MaxSexual) [style "width" "400px"]
          [ (0, "Hide sexually suggestive or explicit images")
          , (1, "Hide only sexually explicit images")
          , (2, "Don't hide suggestive or explicit images")
          ]
        , br [] []
        , inputSelect "" m.max_violence (Prefs << MaxViolence) [style "width" "400px"]
          [ (0, "Hide violent or brutal images")
          , (1, "Hide only brutal images")
          , (2, "Don't hide violent or brutal images")
          ]
        ]
      , formField ""     [ label [] [ inputCheck "" m.traits_sexual (Prefs << TraitsSexual), text " Show sexual traits by default on character pages" ], br_ 2 ]
      , formField "Tags" [ label [] [ inputCheck "" m.tags_all      (Prefs << TagsAll),      text " Show all tags by default on visual novel pages (don't summarize)" ] ]
      , formField ""
        [ text "Default tag categories on visual novel pages:", br_ 1
        , label [] [ inputCheck "" m.tags_cont (Prefs << TagsCont), text " Content" ], br_ 1
        , label [] [ inputCheck "" m.tags_ero  (Prefs << TagsEro ), text " Sexual content" ], br_ 1
        , label [] [ inputCheck "" m.tags_tech (Prefs << TagsTech), text " Technical" ]
        ]
      , formField "spoil::Spoiler level"
        [ inputSelect "spoil" m.spoilers (Prefs << Spoilers) []
          [ (0, "Hide spoilers")
          , (1, "Show only minor spoilers")
          , (2, "Show all spoilers")
          ]
        ]
      , formField "skin::Skin" [ inputSelect "skin" m.skin (Prefs << Skin) [ style "width" "300px" ] GT.skins ]
      , formField "css::Custom CSS" [ inputTextArea "css" m.customcss (Prefs << Css) ([ rows 5, cols 60 ] ++ GUE.valPrefsCustomcss) ]
      ]

  in form_ Submit (model.state == Api.Loading)
    [ div [ class "mainbox" ]
      [ h1 [] [ text model.title ]
      , table [ class "formtable" ] <|
        [ tr [ class "newpart" ] [ td [ colspan 2 ] [ text "Account settings" ] ]
        , formField "Username" [ text model.username ]
        , Maybe.withDefault (text "") <| Maybe.map (\m ->
            formField "email::E-Mail" [ inputText "email" m.email (Prefs << EMail) GUE.valPrefsEmail ]
          ) model.prefs
        ]
        ++ (Maybe.withDefault [] (Maybe.map passform model.pass))
        ++ (Maybe.withDefault [] (Maybe.map adminform model.admin))
        ++ (Maybe.withDefault [] (Maybe.map supportform model.prefs))
        ++ (Maybe.withDefault [] (Maybe.map prefsform model.prefs))
      ]
    , div [ class "mainbox" ]
      [ fieldset [ class "submit" ] [ submitButton "Submit" model.state (not model.passNeq) ]
      , if not model.mailConfirm then text "" else
          div [ class "notice" ]
          [ text "A confirmation email has been sent to your new address. Your address will be updated after following the instructions in that mail." ]
      ]
    ]
