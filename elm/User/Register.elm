module User.Register exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Encode as JE
import Browser
import Lib.Api as Api
import Gen.Api as GApi
import Gen.UserEdit as GUE
import Lib.Html exposing (..)


main : Program () Model Msg
main = Browser.element
  { init = always (init, Cmd.none)
  , subscriptions = always Sub.none
  , view = view
  , update = update
  }


type alias Model =
  { username : String
  , email    : String
  , vns      : Int
  , state    : Api.State
  , success  : Bool
  }


init : Model
init =
  { username = ""
  , email    = ""
  , vns      = 0
  , state    = Api.Normal
  , success  = False
  }


encodeForm : Model -> JE.Value
encodeForm o = JE.object
  [ ("username", JE.string o.username)
  , ("email",    JE.string o.email)
  , ("vns",      JE.int o.vns) ]


type Msg
  = Username String
  | EMail String
  | VNs String
  | Submit
  | Submitted GApi.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Username n -> ({ model | username = String.toLower n }, Cmd.none)
    EMail    n -> ({ model | email    = n }, Cmd.none)
    VNs      n -> ({ model | vns      = Maybe.withDefault model.vns (String.toInt n) }, Cmd.none)

    Submit -> ( { model | state = Api.Loading }
              , Api.post "/u/register" (encodeForm model) Submitted )

    Submitted GApi.Success      -> ({ model | success = True }, Cmd.none)
    Submitted e                 -> ({ model | state = Api.Error e }, Cmd.none)


view : Model -> Html Msg
view model =
  if model.success
  then
    div [ class "mainbox" ]
    [ h1 [] [ text "Account created" ]
    , div [ class "notice" ]
      [ p [] [ text "Your account has been created! In a few minutes, you should receive an email with instructions to set your password." ] ]
    ]
  else
    Html.form [ onSubmit Submit ]
    [ div [ class "mainbox" ]
      [ h1 [] [ text "Create an account" ]
      , table [ class "formtable" ]
        [ formField "username::Username"
          [ inputText "username" model.username Username GUE.valUsername
          , br_ 1
          , text "Preferred username. Must be lowercase and can only consist of alphanumeric characters."
          ]
        , formField "email::E-Mail"
          [ inputText "email" model.email EMail GUE.valEmail
          , br_ 1
          , text "Your email address will only be used in case you lose your password. "
          , text "We will never send spam or newsletters unless you explicitly ask us for it or we get hacked."
          , br_ 3
          , text "Anti-bot question: How many visual novels do we have in the database? (Hint: look to your left)"
          ]
        , formField "vns::Answer" [ inputText "vns" (if model.vns == 0 then "" else String.fromInt model.vns) VNs [] ]
        ]
      ]
    , div [ class "mainbox" ]
      [ fieldset [ class "submit" ] [ submitButton "Submit" model.state True False ]
      ]
    ]