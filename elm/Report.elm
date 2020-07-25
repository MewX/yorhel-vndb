module Report exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Browser
import Browser.Navigation exposing (load)
import Lib.Html exposing (..)
import Lib.Api as Api
import Lib.Ffi as Ffi
import Gen.Api as GApi
import Gen.Report as GR


main : Program GR.Send Model Msg
main = Browser.element
  { init   = \e -> ((Api.Normal, e), Cmd.none)
  , view   = view
  , update = update
  , subscriptions = always Sub.none
  }

type alias Model = (Api.State,GR.Send)

type Msg
  = Reason String
  | Message String
  | Submit
  | Submitted GApi.Response


-- These can be different depending on the rtype.
reasons =
  [ "Spam"
  , "Links to piracy or illegal content"
  , "Off-topic / wrong board"
  , "Unmarked spoilers"
  , "Unwelcome behavior"
  , "Other"
  ]


update : Msg -> Model -> (Model, Cmd Msg)
update msg (state,model) =
  case msg of
    Reason s    -> ((state, { model | reason  = s }), Cmd.none)
    Message s   -> ((state, { model | message = s }), Cmd.none)
    Submit      -> ((Api.Loading, model), GR.send model Submitted)
    Submitted r -> ((Api.Error r, model), Cmd.none)


view : Model -> Html Msg
view (state,model) =
  form_ Submit (state == Api.Loading)
  [ div [ class "mainbox" ]
    [ h1 [] [ text "Submit report" ]
    , if state == Api.Error GApi.Success
      then p [] [ text "Your report has been submitted, a moderator will look at it as soon as possible." ]
      else table [ class "formtable" ] <|
        [ formField "Subject" [ span [ Ffi.innerHtml model.title ] [] ]
        , formField ""
          [ text "Your report will be forwarded to a moderator."
          , br [] []
          , text "Keep in mind that not every report will be acted upon, we may decide that the problem you reported is still within acceptable limits."
          , br [] []
          , if model.loggedin
            then text "We generally do not provide feedback on reports, but a moderator may decide to contact you for clarification."
            else text "We generally do not provide feedback on reports, but you may leave your email address in the message if you wish to be available for clarification."
          ]
        , formField "reason::Reason" [ inputSelect "reason" model.reason Reason [style "width" "300px"] (("","-- Select --") :: List.map (\s->(s,s)) reasons) ]
        ] ++ if model.reason == "" then [] else
        [ formField "message::Message" [ inputTextArea "message" model.message Message [] ]
        , formField "" [ submitButton "Submit" state True ]
        ]
    ]
  ]
