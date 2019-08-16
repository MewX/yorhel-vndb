module User.Settings exposing (main)

import Bitwise exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Browser
import Browser.Navigation exposing (reload)
import Lib.Html exposing (..)
import Lib.Gen as Gen
import Lib.Api as Api


main : Program Gen.UserEdit Model Msg
main = Browser.element
  { init   = init
  , view   = view
  , update = update
  , subscriptions = always Sub.none
  }


type alias Model =
  { state       : Api.State
  , saved       : Bool
  , data        : Gen.UserEdit
  , cpass       : Bool
  , pass1       : String
  , pass2       : String
  , opass       : String
  , passNeq     : Bool
  }


init : Gen.UserEdit -> (Model, Cmd Msg)
init d =
  ({state         = Api.Normal
  , saved         = False
  , data          = d
  , cpass         = False
  , pass1         = ""
  , pass2         = ""
  , opass         = ""
  , passNeq       = False
  }, Cmd.none)


encode : Model -> Gen.UserEditSend
encode model =
  { hide_list     = model.data.hide_list
  , ign_votes     = model.data.ign_votes
  , mail          = model.data.mail
  , password      = if model.cpass then Just { old = model.opass, new = model.pass1 } else Nothing
  , perm          = model.data.perm
  , show_nsfw     = model.data.show_nsfw
  , spoilers      = model.data.spoilers
  , tags_all      = model.data.tags_all
  , tags_cont     = model.data.tags_cont
  , tags_ero      = model.data.tags_ero
  , tags_tech     = model.data.tags_tech
  , traits_sexual = model.data.traits_sexual
  , username      = model.data.username
  }


type UpdateMsg
  = Username String
  | Email String
  | Perm Int Bool
  | IgnVotes Bool
  | HideList Bool
  | ShowNsfw Bool
  | TraitsSexual Bool
  | Spoilers String
  | TagsAll  Bool
  | TagsCont Bool
  | TagsEro  Bool
  | TagsTech Bool

type Msg
  = Submit
  | Submitted Api.Response
  | Set UpdateMsg
  | CPass Bool
  | OPass String
  | Pass1 String
  | Pass2 String


updateField : UpdateMsg -> Gen.UserEdit -> Gen.UserEdit
updateField msg model =
  case msg of
    Username s -> { model | username = s }
    Email s    -> { model | mail = s }
    Perm n b   -> { model | perm = if b then or model.perm n else and model.perm (complement n) }
    IgnVotes b -> { model | ign_votes = b }
    HideList b -> { model | hide_list = b }
    ShowNsfw b -> { model | show_nsfw = b }
    TraitsSexual b -> { model | traits_sexual = b }
    Spoilers s -> { model | spoilers = Maybe.withDefault model.spoilers (String.toInt s) }
    TagsAll  b -> { model | tags_all  = b }
    TagsCont b -> { model | tags_cont = b }
    TagsEro  b -> { model | tags_ero  = b }
    TagsTech b -> { model | tags_tech = b }


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Set m      -> ({ model | saved = False, data = updateField m model.data }, Cmd.none)
    CPass b    -> ({ model | saved = False, cpass = b }, Cmd.none)
    OPass s    -> ({ model | saved = False, opass = s }, Cmd.none)
    Pass1 s    -> ({ model | saved = False, pass1 = s, passNeq = s /= model.pass2 }, Cmd.none)
    Pass2 s    -> ({ model | saved = False, pass2 = s, passNeq = s /= model.pass1 }, Cmd.none)

    Submit ->
      let
        path = "/u" ++ String.fromInt model.data.id ++ "/edit"
        body = Gen.usereditSendEncode (encode model)
      in ({ model | state = Api.Loading }, Api.post path body Submitted)

    Submitted (Gen.Success) ->
      ( { model | state = Api.Normal, saved = True, cpass = False, opass = "", pass1 = "", pass2 = "" }
      , if model.cpass then reload else Cmd.none
      )
    Submitted r -> ({ model | state = Api.Error r }, Cmd.none)


view : Model -> Html Msg
view model =
  form_ Submit (model.state == Api.Loading)
    [ card "account" "Account info" [] <|

      [ cardRow "General" Nothing <| formGroups
        [ [ label [ for "username" ] [ text "Username" ]
          , inputText "username" model.data.username (Set << Username) [required True, maxlength 200, pattern "[a-z0-9-]{2,15}", disabled (not model.data.authmod)]
          ]
        , [ label [ for "email" ] [ text "Email address" ]
          , inputText "email" model.data.mail (Set << Email) [type_ "email", required True, pattern Gen.emailPattern]
          ]
        ]

      , cardRow "Password" Nothing <| formGroups <|
          [ label [ class "checkbox" ]
            [ inputCheck "" model.cpass CPass
            , text " Change password" ]
          ]
        :: if not model.cpass then [] else
        [ [ label [ class "opass" ] [ text "Current password" ]
          , inputText "opass" model.opass OPass [type_ "password", required True, minlength 4, maxlength 500]
          ]
        , [ label [ class "pass1" ] [ text "New password" ]
          , inputText "pass1" model.pass1 Pass1 [type_ "password", required True, minlength 4, maxlength 500]
          ]
        , [ label [ class "pass2" ] [ text "Repeat" ]
          , inputText "pass2" model.pass2 Pass2 [type_ "password", required True, minlength 4, maxlength 500, classList [("is-invalid", model.passNeq)]]
          , if model.passNeq
            then div [class "invalid-feedback"]
              [ text "Passwords do not match." ]
            else text ""
          ]
        ]

      ] ++ if not model.data.authmod then [] else
      [ cardRow "Mod options" Nothing <| formGroups
        [ [ label [] [ text "Permissions" ]
          ] ++ List.map (\(n,s) ->
            label [ class "checkbox" ] [ inputCheck "" (and model.data.perm n > 0) (Set << Perm n), text (" " ++ s) ]
          ) Gen.userPerms
        , [ label [] [ text "Other" ]
          , label [ class "checkbox" ] [ inputCheck "" model.data.ign_votes (Set << IgnVotes), text "Ignore votes in VN statistics" ]
          ]
        ]
      ]

    , card "preferences" "Preferences" [] <|

      [ cardRow "Privacy" Nothing <| formGroup
        [ label [ class "checkbox" ] [ inputCheck "" model.data.hide_list (Set << HideList), text "Hide my visual novel list, vote list and wishlist and exclude these lists from the database dumps and API" ] ]

      , cardRow "NSFW" Nothing <| formGroups
        [ [ label [ class "checkbox" ] [ inputCheck "" model.data.show_nsfw     (Set << ShowNsfw),     text "Disable warnings for images that are not safe for work" ] ]
        , [ label [ class "checkbox" ] [ inputCheck "" model.data.traits_sexual (Set << TraitsSexual), text "Show sexual traits by default on character pages" ] ]
        ]

      , cardRow "Spoilers" Nothing <| formGroup
        [ label [ for "spoilers" ] [ text "Default spoiler level" ]
        , inputSelect [onInput (Set << Spoilers)] (String.fromInt model.data.spoilers)
          [ ("0", "Hide spoilers")
          , ("1", "Show only minor spoilers")
          , ("2", "Show all spoilers")
          ]
        ]

      , cardRow "Tags" Nothing <| formGroups
        [ [ label [ class "checkbox" ] [ inputCheck "" model.data.tags_all (Set << TagsAll), text "Show all tags by default on visual novel pages (don't summarize)" ] ]
        , [ label [] [ text "Default tag categories on visual novel pages:" ]
          , label [ class "chexkbox" ] [ inputCheck "" model.data.tags_cont (Set << TagsCont), text "Content" ]
          , label [ class "chexkbox" ] [ inputCheck "" model.data.tags_ero  (Set << TagsEro ), text "Sexual content" ]
          , label [ class "chexkbox" ] [ inputCheck "" model.data.tags_tech (Set << TagsTech), text "Technical" ]
          ]
        ]
      ]

    , submitButton (if model.saved then "Saved!" else "Save") model.state (not model.passNeq) False
    ]
