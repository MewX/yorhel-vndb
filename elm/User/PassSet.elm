module User.PassSet exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Encode as JE
import Browser
import Browser.Navigation exposing (load)
import Lib.Api as Api
import Gen.Api as GApi
import Gen.UserEdit as GUE
import Lib.Html exposing (..)


main : Program String Model Msg
main = Browser.element
  { init = \url -> (init url, Cmd.none)
  , subscriptions = always Sub.none
  , view = view
  , update = update
  }


type alias Model =
  { url      : String
  , newpass1 : String
  , newpass2 : String
  , state    : Api.State
  , noteq    : Bool
  }


init : String -> Model
init url =
  { url      = url
  , newpass1 = ""
  , newpass2 = ""
  , state    = Api.Normal
  , noteq    = False
  }


encodeForm : Model -> JE.Value
encodeForm o = JE.object
  [ ("password", JE.string o.newpass1) ]


type Msg
  = Newpass1 String
  | Newpass2 String
  | Submit
  | Submitted GApi.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Newpass1 n -> ({ model | newpass1 = n, noteq = False }, Cmd.none)
    Newpass2 n -> ({ model | newpass2 = n, noteq = False }, Cmd.none)

    Submit ->
      if model.newpass1 /= model.newpass2
      then ( { model | noteq = True }, Cmd.none)
      else ( { model | state = Api.Loading }
           , Api.post model.url (encodeForm model) Submitted )

    Submitted GApi.Success -> (model, load "/")
    Submitted e            -> ({ model | state = Api.Error e }, Cmd.none)


view : Model -> Html Msg
view model =
  Html.form [ onSubmit Submit ]
  [ div [ class "mainbox" ]
    [ h1 [] [ text "Set your password" ]
    , p [] [ text "Now you can set a password for your account. You will be logged in automatically after your password has been saved." ]
    , table [ class "formtable" ]
      [ formField "newpass1::New password" [ inputPassword "newpass1" model.newpass1 Newpass1 GUE.valPasswordNew ]
      , formField "newpass2::Repeat"
        [ inputPassword "newpass2" model.newpass2 Newpass2 GUE.valPasswordNew
        , br_ 1
        , if model.noteq then b [ class "standout" ] [ text "Passwords do not match" ] else text ""
        ]
      ]
   ]
  , div [ class "mainbox" ]
    [ fieldset [ class "submit" ] [ submitButton "Submit" model.state True False ]
    ]
  ]
