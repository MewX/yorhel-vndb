module User.Login exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Encode as JE
import Browser
import Browser.Navigation exposing (load)
import Lib.Api as Api
import Lib.Gen as Gen
import Lib.Html exposing (..)


main : Program () Model Msg
main = Browser.element
  { init = always (Model "" "" Api.Normal, Cmd.none)
  , subscriptions = always Sub.none
  , view = view
  , update = update
  }


encodeForm : Model -> JE.Value
encodeForm o = JE.object
  [ ("username", JE.string o.username)
  , ("password", JE.string o.password) ]


type alias Model =
  { username : String
  , password : String
  , state    : Api.State
  }


type Msg
  = Username String
  | Password String
  | Submit
  | Submitted Api.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Username n -> ({ model | username = n }, Cmd.none)
    Password n -> ({ model | password = n }, Cmd.none)

    Submit -> ( { model | state = Api.Loading }
              , Api.post "/u/login" (encodeForm model) Submitted
              )

    Submitted Gen.Success -> (model, load "/")
    Submitted e           -> ({ model | state = Api.Error e }, Cmd.none)


view : Model -> Html Msg
view model = form_ Submit (model.state == Api.Loading)
  [ div [ class "card card--white card--no-separators flex-expand small-card mb-5" ]
    [ div [ class "card__header" ] [ div [ class "card__title" ] [ text "Log in" ]]
    , case model.state of
        Api.Error e ->
          div [ class "card__section card__section--error fs-medium" ]
            [ h5 [] [ text "Error" ]
            , ul []
              [ li [] [ text <| Api.showResponse e ]
              , li [] [ text "If you have not used this login form since October 2014, your account has likely been disabled. You can reset your password to regain access." ]
              ]
            ]
        _ -> text ""
    , div [ class "card__section fs-medium" ]
      [ div [ class "form-group" ] [ inputText "username" model.username Username [placeholder "Username", required True, pattern "[a-z0-9-]{2,15}"] ]
      , div [ class "form-group" ] [ inputText "password" model.password Password [placeholder "Password", required True, minlength 4, maxlength 500, type_ "password"] ]
      , div [ class "d-flex jc-between" ] [ a [ href "/u/newpass" ] [ text "Forgot your password?" ] ]
      ]
    , div [ class "card__section" ]
      [ div [ class "d-flex jc-between" ]
        [ a [ class "btn btn--subtle", href "/u/register" ] [ text "Create an account" ]
        , if model.state == Api.Loading
          then div [ class "spinner spinner--md pull-right" ] []
          else text ""
        , input [ type_ "submit", class "btn", tabindex 10, value "Log in" ] []
        ]
      ]
    ]
  ]
