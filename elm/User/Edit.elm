module User.Edit exposing (main)

import Bitwise exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Browser
import Browser.Navigation exposing (load)
import Lib.Html exposing (..)
import Lib.Api as Api
import Gen.Api as GApi
import Gen.Types as GT
import Gen.UserEdit as GUE


main : Program GUE.Send Model Msg
main = Browser.element
  { init   = \e -> (init e, Cmd.none)
  , view   = view
  , update = update
  , subscriptions = always Sub.none
  }


type alias Model =
  { state       : Api.State
  , data        : GUE.Send
  , cpass       : Bool
  , pass1       : String
  , pass2       : String
  , opass       : String
  , passNeq     : Bool
  , mailConfirm : Bool
  }


init : GUE.Send -> Model
init d =
  { state       = Api.Normal
  , data        = d
  , cpass       = False
  , pass1       = ""
  , pass2       = ""
  , opass       = ""
  , passNeq     = False
  , mailConfirm = False
  }


type Data
  = Username String
  | EMail String
  | Perm Int Bool
  | IgnVotes Bool
  | HideList Bool
  | ShowNsfw Bool
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


updateData : Data -> GUE.Send -> GUE.Send
updateData msg model =
  case msg of
    Username n -> { model | username = n }
    EMail n    -> { model | email = n }
    Perm n b   -> { model | perm = if b then or model.perm n else and model.perm (complement n) }
    IgnVotes n -> { model | ign_votes = n }
    HideList b -> { model | hide_list = b }
    ShowNsfw b -> { model | show_nsfw = b }
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


type Msg
  = Set Data
  | CPass Bool
  | OPass String
  | Pass1 String
  | Pass2 String
  | Submit
  | Submitted GApi.Response


-- Synchronizes model.data.password with model.stuff
fixup : Model -> Model
fixup model =
  let
      data  = model.data
      ndata = { data | password = if model.cpass && model.pass1 == model.pass2 then Just { old = model.opass, new = model.pass1 } else Nothing }
  in { model | data = ndata }


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Set d   -> ({ model | data = updateData d model.data }, Cmd.none)
    CPass b -> (fixup { model | cpass = b, passNeq = False }, Cmd.none)
    OPass n -> (fixup { model | opass = n, passNeq = False }, Cmd.none)
    Pass1 n -> (fixup { model | pass1 = n, passNeq = False }, Cmd.none)
    Pass2 n -> (fixup { model | pass2 = n, passNeq = False }, Cmd.none)

    Submit ->
      if model.cpass && model.pass1 /= model.pass2
      then ({ model | passNeq = True }, Cmd.none )
      else ({ model | state = Api.Loading }, Api.post "/u/edit" (GUE.encode model.data) Submitted)

    -- TODO: This reload is only necessary for the skin and customcss options to apply, but it's nicer to do that directly from JS.
    Submitted GApi.Success    -> (model, load <| "/u" ++ String.fromInt model.data.id ++ "/edit")
    Submitted GApi.MailChange -> ({ model | mailConfirm = True, state = Api.Normal }, Cmd.none)
    Submitted r -> ({ model | state = Api.Error r }, Cmd.none)



view : Model -> Html Msg
view model =
  let
    data = model.data

    modform =
      [ tr [ class "newpart" ] [ td [ colspan 2 ] [ text "Admin options" ] ]
      , formField "username::Username" [ inputText "username" data.username (Set << Username) GUE.valUsername ]
      , formField "Permissions"
        <| List.intersperse (br_ 1)
        <| List.map (\(n,s) -> label [] [ inputCheck "" (and data.perm n > 0) (Set << Perm n), text (" " ++ s) ])
           GT.userPerms
      , formField "Other" [ label [] [ inputCheck "" data.ign_votes (Set << IgnVotes), text " Ignore votes in VN statistics" ] ]
      ]

    passform =
      [ formField "opass::Old password" [ inputPassword "opass" model.opass OPass GUE.valPasswordOld ]
      , formField "pass1::New password" [ inputPassword "pass1" model.pass1 Pass1 GUE.valPasswordNew ]
      , formField "pass2::Repeat"
        [ inputPassword "pass2" model.pass2 Pass2 GUE.valPasswordNew
        , br_ 1
        , if model.passNeq
          then b [ class "standout" ] [ text "Passwords do not match" ]
          else text ""
        ]
      ]

    supportform =
      [ tr [ class "newpart" ] [ td [ colspan 2 ] [ text "Supporter options⭐" ] ]
      , if not data.nodistract_can && not data.authmod then text ""
        else formField "" [ label [] [ inputCheck "" data.nodistract_noads (Set << NoAds), text " Disable advertising and other distractions (only hides the Patreon icon for the moment)" ] ]
      , if not data.nodistract_can && not data.authmod then text ""
        else formField "" [ label [] [ inputCheck "" data.nodistract_nofancy (Set << NoFancy), text " Disable supporters badges, custom display names and profile skins" ] ]
      , if not data.support_can && not data.authmod then text ""
        else formField "" [ label [] [ inputCheck "" data.support_enabled (Set << Support), text " Display my supporters badge" ] ]
      , if not data.pubskin_can && not data.authmod then text ""
        else formField "" [ label [] [ inputCheck "" data.pubskin_enabled (Set << PubSkin), text " Apply my skin and custom CSS when others visit my profile" ] ]
      , if not data.uniname_can && not data.authmod then text ""
        else formField "uniname::Display name" [ inputText "uniname" (if data.uniname == "" then data.username else data.uniname) (Set << Uniname) GUE.valUniname ]
      ]

  in Html.form [ onSubmit Submit ]
    [ div [ class "mainbox" ]
      [ h1 [] [ text <| if data.authmod then "Edit " ++ data.username else "My preferences" ]
      , table [ class "formtable" ] <|
        [ tr [ class "newpart" ] [ td [ colspan 2 ] [ text "General" ] ]
        , formField "Username" [ text data.username ]
        , formField "email::E-Mail" [ inputText "email" data.email (Set << EMail) GUE.valEmail ]
        ]
        ++ (if data.authmod then modform else [])
        ++ (if data.authmod || data.nodistract_can || data.support_can || data.uniname_can || data.pubskin_can then supportform else []) ++
        [ tr [ class "newpart" ] [ td [ colspan 2 ] [ text "Password" ] ]
        , formField "" [ label [] [ inputCheck "" model.cpass CPass, text " Change password" ] ]
        ] ++ (if model.cpass then passform else [])
        ++
        [ tr [ class "newpart" ] [ td [ colspan 2 ] [ text "Preferences" ] ]
        , formField "Privacy"
          [ label []
            [ inputCheck "" data.hide_list (Set << HideList)
            , text " Don't allow others to see my visual novel list, vote list and wishlist and exclude these lists from the database dumps and API."
            ]
          ]
        , formField "NSFW" [ label [] [ inputCheck "" data.show_nsfw     (Set << ShowNsfw),     text " Show NSFW images by default" ] ]
        , formField ""     [ label [] [ inputCheck "" data.traits_sexual (Set << TraitsSexual), text " Show sexual traits by default on character pages" ] ]
        , formField "Tags" [ label [] [ inputCheck "" data.tags_all      (Set << TagsAll),      text " Show all tags by default on visual novel pages (don't summarize)" ] ]
        , formField ""
          [ text "Default tag categories on visual novel pages:", br_ 1
          , label [] [ inputCheck "" data.tags_cont (Set << TagsCont), text " Content" ], br_ 1
          , label [] [ inputCheck "" data.tags_ero  (Set << TagsEro ), text " Sexual content" ], br_ 1
          , label [] [ inputCheck "" data.tags_tech (Set << TagsTech), text " Technical" ]
          ]
        , formField "spoil::Spoiler level"
          [ inputSelect "spoil" data.spoilers (Set << Spoilers) []
            [ (0, "Hide spoilers")
            , (1, "Show only minor spoilers")
            , (2, "Show all spoilers")
            ]
          ]
        , formField "skin::Skin" [ inputSelect "skin" data.skin (Set << Skin) [ style "width" "300px" ] GT.skins ]
        , formField "css::Custom CSS" [ inputTextArea "css" data.customcss (Set << Css) ([ rows 5, cols 60 ] ++ GUE.valCustomcss) ]
        ]

      ]
    , div [ class "mainbox" ]
      [ fieldset [ class "submit" ] [ submitButton "Submit" model.state (not model.passNeq) False ]
      , if not model.mailConfirm then text "" else
          div [ class "notice" ]
          [ text "A confirmation email has been sent to your new address. Your address will be updated after following the instructions in that mail." ]
      ]
    ]
