module User.PassReset exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Encode as JE
import Browser
import Lib.Api as Api
import Gen.Api as GApi
import Gen.RegReset as GRR
import Lib.Html exposing (..)


main : Program () Model Msg
main = Browser.element
  { init = always (init, Cmd.none)
  , subscriptions = always Sub.none
  , view = view
  , update = update
  }


type alias Model =
  { email    : String
  , state    : Api.State
  , success  : Bool
  }


init : Model
init =
  { email    = ""
  , state    = Api.Normal
  , success  = False
  }


encodeForm : Model -> JE.Value
encodeForm o = JE.object
  [ ("email",    JE.string o.email) ]


type Msg
  = EMail String
  | Submit
  | Submitted GApi.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    EMail    n -> ({ model | email    = n }, Cmd.none)

    Submit -> ( { model | state = Api.Loading }
              , Api.post "/u/newpass" (encodeForm model) Submitted )

    Submitted GApi.Success      -> ({ model | success = True }, Cmd.none)
    Submitted e                 -> ({ model | state = Api.Error e }, Cmd.none)


view : Model -> Html Msg
view model =
  if model.success
  then
    div [ class "mainbox" ]
    [ h1 [] [ text "New password" ]
    , div [ class "notice" ]
      [ p [] [ text "Your password has been reset and instructions to set a new one should reach your mailbox in a few minutes." ] ]
    ]
  else
    Html.form [ onSubmit Submit ]
    [ div [ class "mainbox" ]
      [ h1 [] [ text "Forgot Password" ]
      , p []
        [ text "Forgot your password and can't login to VNDB anymore? "
        , text "Don't worry! Just give us the email address you used to register on VNDB "
        , text " and we'll send you instructions to set a new password within a few minutes!"
        ]
      , table [ class "formtable" ]
        [ tr [ class "newfield" ]
          [ td [ class "label" ] [ label [ for "email" ] [ text "E-Mail" ]]
          , td [ class "field" ] [ inputText "email" model.email EMail GRR.valEmail ]
          ]
        ]
      ]
    , div [ class "mainbox" ]
      [ fieldset [ class "submit" ] [ submitButton "Submit" model.state True False ]
      ]
    ]
