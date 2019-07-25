module User.Register exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Browser
import Json.Encode as JE
import Lib.Gen exposing (emailPattern)
import Lib.Api as Api
import Lib.Html exposing (..)


main : Program () Model Msg
main = Browser.element
  { init = always (Model "" "" 0 False Api.Normal, Cmd.none)
  , subscriptions = always Sub.none
  , view = view
  , update = update
  }


encodeForm : Model -> JE.Value
encodeForm o = JE.object
  [ ("username", JE.string o.username)
  , ("email",    JE.string o.email   )
  , ("vns",      JE.int    o.vns     )]


type alias Model =
  { username : String
  , email    : String
  , vns      : Int
  , success  : Bool
  , state    : Api.State
  }

type Msg
  = Username String
  | EMail String
  | VNs String
  | Submit
  | Submitted Api.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Username n -> ({ model | username = n }, Cmd.none)
    EMail    n -> ({ model | email    = n }, Cmd.none)
    VNs      n -> ({ model | vns      = Maybe.withDefault 0 (String.toInt n) }, Cmd.none)

    Submit -> ( { model | state = Api.Loading }
              , Api.post "/u/register" (encodeForm model) Submitted)

    Submitted Api.Success     -> ({ model | state = Api.Normal, success = True }, Cmd.none)
    Submitted e               -> ({ model | state = Api.Error e}, Cmd.none)


view : Model -> Html Msg
view model = form_ Submit (model.state == Api.Loading)
  [ div [ class "card card--white card--no-separators flex-expand small-card mb-5" ] <|
    [ div [ class "card__header" ] [ div [ class "card__title" ] [ text "Register" ]]
    , case model.state of
        Api.Error e ->
          div [ class "card__section card__section--error fs-medium" ]
            [ h5 [] [ text "Error" ]
            , text <| Api.showResponse e
            ]
        _ -> text ""
    ] ++ if model.success
    then
    [ div [ class "card__section fs-medium" ]
      [ text "Your account has been created! In a few minutes, you should receive an email with instructions to set a password and activate your account." ]
    ]
    else
    [
      div [ class "card__section fs-medium" ]
      [ div [ class "form-group" ]
        [ label [ for "username" ] [ text "Username" ]
        , inputText "username" model.username Username [required True, pattern "[a-z0-9-]{2,15}"]
        , div [ class "form-group__help" ] [ text "Preferred username. Must be lowercase and can only consist of alphanumeric characters." ]
        ]
      , div [ class "form-group" ]
        [ label [ for "email" ] [ text "Email" ]
        , inputText "email" model.email EMail [required True, type_ "email", pattern emailPattern]
        , div [ class "form-group__help" ]
          [ text "Your email address will only be used in case you lose your password. We will never send spam or newsletters unless you explicitly ask us for it or we get hacked." ]
        ]
      , div [ class "form-group" ]
        [ label [ for "vns" ] [ text "How many visual novels are there in the database?" ]
        , inputText "vns" (String.fromInt model.vns) VNs [required True, pattern "[0-9]+"]
        , div [ class "form-group__help" ]
          [ text "Anti-bot question, you can find the answer on the "
          , a [ href "/", target "_blank" ] [ text "main page" ]
          , text "."
          ]
        ]
      ]
    , div [ class "card__section" ]
      [ div [ class "d-flex jc-end" ]
        [ if model.state == Api.Loading
          then div [ class "spinner spinner--md pull-right" ] []
          else text ""
        , input [ type_ "submit", class "btn", tabindex 10, value "Submit" ] []
        ]
      ]
    ]
  ]
