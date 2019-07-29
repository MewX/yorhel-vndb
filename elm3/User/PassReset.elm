module User.PassReset exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Browser
import Json.Encode as JE
import Lib.Api as Api
import Lib.Gen as Gen
import Lib.Html exposing (..)


main : Program () Model Msg
main = Browser.element
  { init = always (Model "" False Api.Normal, Cmd.none)
  , subscriptions = always Sub.none
  , view = view
  , update = update
  }


encodeForm : Model -> JE.Value
encodeForm o = JE.object
  [ ("email", JE.string o.email) ]


type alias Model =
  { email   : String
  , success : Bool
  , state   : Api.State
  }


type Msg
  = EMail String
  | Submit
  | Submitted Api.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    EMail n -> ({ model | email = n }, Cmd.none)

    Submit -> ( { model | state = Api.Loading }
              , Api.post "/u/newpass" (encodeForm model) Submitted
              )

    Submitted Gen.Success -> ({ model | success = True  }, Cmd.none)
    Submitted e           -> ({ model | state = Api.Error e }, Cmd.none)


view : Model -> Html Msg
view model = form_ Submit (model.state == Api.Loading)
  [ div [ class "card card--white card--no-separators flex-expand small-card mb-5" ] <|
    [ div [ class "card__header" ] [ div [ class "card__title" ] [ text "Reset password" ]]
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
      [ text "Your password has been reset and instructions to set a new one should reach your mailbox in a few minutes." ]
    ]
    else
    [
      div [ class "card__section fs-medium" ]
      [ div [ class "form-group" ]
        [ div [ class "form-group__help" ]
          [ text "Forgot your password and can\'t login to VNDB anymore?"
          , br [] []
          , text "Don't worry! Just fill in the email address you used to register on VNDB, and you'll receive instructions to set a new password within a few minutes!"
          ]
        , inputText "email" model.email EMail [required True, type_ "email"]
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
