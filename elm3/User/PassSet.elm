module User.PassSet exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Encode as JE
import Browser
import Browser.Navigation exposing (load)
import Lib.Api as Api
import Lib.Html exposing (..)


main : Program String Model Msg
main = Browser.element
  { init = \s ->
    ( { url     = s
      , pass1   = ""
      , pass2   = ""
      , badPass = False
      , state   = Api.Normal
      }
    , Cmd.none)
  , subscriptions = always Sub.none
  , view = view
  , update = update
  }


encodeForm : Model -> JE.Value
encodeForm o = JE.object
  [ ("pass", JE.string o.pass1) ]


type alias Model =
  { url     : String
  , pass1   : String
  , pass2   : String
  , badPass : Bool
  , state   : Api.State
  }


type Msg
  = Pass1 String
  | Pass2 String
  | Submit
  | Submitted Api.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Pass1 n -> ({ model | pass1 = n, badPass = False }, Cmd.none)
    Pass2 n -> ({ model | pass2 = n, badPass = False }, Cmd.none)

    Submit ->
      if model.pass1 /= model.pass2
      then ({ model | badPass = True }, Cmd.none)
      else ( { model | state = Api.Loading }
           , Api.post model.url (encodeForm model) Submitted)

    Submitted Api.Success -> (model, load "/")
    Submitted e           -> ({ model | state = Api.Error e }, Cmd.none)


view : Model -> Html Msg
view model =
  let err s =
        div [ class "card__section card__section--error fs-medium" ]
            [ h5 [] [ text "Error" ]
            , text s
            ]
  in form_ Submit (model.state == Api.Loading)
  [ div [ class "card card--white card--no-separators flex-expand small-card mb-5" ]
    [ div [ class "card__header" ] [ div [ class "card__title" ] [ text "Set password" ]]
    , case model.state of
        Api.Error e -> err <| Api.showResponse e
        _ -> text ""
    , if model.badPass then err "Passwords to not match" else text ""
    , div [ class "card__section fs-medium" ]
      [ div [ class "form-group" ] [ inputText "pass1" model.pass1 Pass1 [placeholder "New password", required True, minlength 4, maxlength 500, type_ "password"] ]
      , div [ class "form-group" ] [ inputText "pass2" model.pass2 Pass2 [placeholder "Repeat",       required True, minlength 4, maxlength 500, type_ "password"] ]
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
