module User.Login exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Encode as JE
import Browser
import Browser.Navigation exposing (load)
import Lib.Api as Api
import Gen.Api as GApi
import Gen.UserLogin as GUL
import Gen.Types exposing (adminEMail)
import Lib.Html exposing (..)


main : Program String Model Msg
main = Browser.element
  { init = \ref -> (init ref, Cmd.none)
  , subscriptions = always Sub.none
  , view = view
  , update = update
  }


type alias Model =
  { ref      : String
  , username : String
  , password : String
  , newpass1 : String
  , newpass2 : String
  , state    : Api.State
  , insecure : Bool
  , noteq    : Bool
  }


init : String -> Model
init ref =
  { ref      = ref
  , username = ""
  , password = ""
  , newpass1 = ""
  , newpass2 = ""
  , state    = Api.Normal
  , insecure = False
  , noteq    = False
  }


encodeLogin : Model -> JE.Value
encodeLogin o = JE.object
  [ ("username", JE.string o.username)
  , ("password", JE.string o.password) ]


encodeChangePass : Model -> JE.Value
encodeChangePass o = JE.object
  [ ("username", JE.string o.username)
  , ("oldpass",  JE.string o.password)
  , ("newpass",  JE.string o.newpass1) ]


type Msg
  = Username String
  | Password String
  | Newpass1 String
  | Newpass2 String
  | Submit
  | Submitted GApi.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Username n -> ({ model | username = n }, Cmd.none)
    Password n -> ({ model | password = n }, Cmd.none)
    Newpass1 n -> ({ model | newpass1 = n, noteq = False }, Cmd.none)
    Newpass2 n -> ({ model | newpass2 = n, noteq = False }, Cmd.none)

    Submit ->
      if not model.insecure
      then ( { model | state = Api.Loading }
           , Api.post "/u/login" (encodeLogin model) Submitted )
      else if model.newpass1 /= model.newpass2
      then ( { model | noteq = True }, Cmd.none )
      else ( { model | state = Api.Loading }
           , Api.post "/u/changepass" (encodeChangePass model) Submitted )

    Submitted GApi.Success      -> (model, load model.ref)
    Submitted GApi.InsecurePass -> ({ model | insecure = True, state = if model.insecure then Api.Error GApi.InsecurePass else Api.Normal }, Cmd.none)
    Submitted e                 -> ({ model | state = Api.Error e }, Cmd.none)


view : Model -> Html Msg
view model =
  let
    loginBox =
      div [ class "mainbox" ]
      [ h1 [] [ text "Login" ]
      , table [ class "formtable" ]
        [ tr [ class "newfield" ]
          [ td [ class "label" ] [ label [ for "username" ] [ text "Username" ]]
          , td [ class "field" ] [ inputText "username" model.username Username GUL.valUsername ]
          ]
        , tr []
          [ td [] []
          , td [ class "field" ] [ a [ href "/u/register" ] [ text "No account yet?" ] ]
          ]
        , tr [ class "newfield" ]
          [ td [ class "label" ] [ label [ for "password" ] [ text "Password" ]]
          , td [ class "field" ] [ inputPassword "password" model.password Password GUL.valPassword ]
          ]
        , tr []
          [ td [] []
          , td [ class "field" ] [ a [ href "/u/newpass" ] [ text "Forgot your password?" ] ]
          ]
        ]
     , if model.state == Api.Normal || model.state == Api.Loading
       then text ""
       else div [ class "notice" ]
            [ h2 [] [ text "Trouble logging in?" ]
            , text "If you have not used this login form since October 2014, your account has likely been disabled. You can "
            , a [ href "/u/newpass" ] [ text "reset your password" ]
            , text " to regain access."
            , br [] []
            , br [] []
            , text "Still having trouble? Send a mail to "
            , a [ href <| "mailto:" ++ adminEMail ] [ text adminEMail ]
            , text ". But keep in mind that I can only help you if the email address associated with your account is correct"
            , text " and you still have access to it. Without that, there is no way to prove that the account is yours."
            ]
     ]

    changeBox =
      div [ class "mainbox" ]
      [ h1 [] [ text "Change your password" ]
      , div [ class "warning" ]
        [ h2 [] [ text "Your current password is not secure" ]
        , text "Your current password is in a public database of leaked passwords. You need to change it before you can continue."
        ]
      , table [ class "formtable" ]
        [ tr [ class "newfield" ]
          [ td [ class "label" ] [ label [ for "newpass1" ] [ text "New password" ]]
          , td [ class "field" ] [ inputPassword "newpass1" model.newpass1 Newpass1 GUL.valPassword ]
          ]
        , tr [ class "newfield" ]
          [ td [ class "label" ] [ label [ for "newpass2" ] [ text "Repeat" ]]
          , td [ class "field" ]
            [ inputPassword "newpass2" model.newpass2 Newpass2 GUL.valPassword
            , if model.noteq then b [ class "standout" ] [ text "Passwords do not match" ] else text ""
            ]
          ]
        ]
     ]

  in Html.form [ onSubmit Submit ]
      [ if model.insecure then changeBox else loginBox
      , div [ class "mainbox" ]
        [ fieldset [ class "submit" ] [ submitButton "Submit" model.state True False ]
        ]
      ]
