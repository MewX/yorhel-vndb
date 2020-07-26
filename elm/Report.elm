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


type alias ReasonLabel =
  { label  : String
  , vis    : String -> String -> Bool -- Given an rtype & objectid, returns whether it should be listed
  , submit : Bool -- Whether it allows submission of the form
  , msg    : String -> String -> List (Html Msg) -- Message to display
  }


vis _ _ = True
nomsg _ _ = []
initial = { label = "-- Select --" , vis = vis, submit = False , msg = nomsg }

reasons : List ReasonLabel
reasons =
  [ initial
  , { label  = "Spam"
    , vis    = vis
    , submit = True
    , msg    = nomsg
    }
  , { label  = "Links to piracy or illegal content"
    , vis    = vis
    , submit = True
    , msg    = nomsg
    }
  , { label  = "Off-topic / wrong board"
    , vis    = \t _ -> t == "t"
    , submit = True
    , msg    = nomsg
    }
  , { label  = "Unwelcome behavior"
    , vis    = \t _ -> t == "t"
    , submit = True
    , msg    = nomsg
    }
  , { label  = "Unmarked spoilers"
    , vis    = vis
    , submit = True
    , msg    = \t o -> if not (t == "db" && not (String.startsWith "d" o)) then [] else
        [ text "VNDB is an open wiki, it is often easier if you removed the spoilers yourself by "
        , a [ href ("/" ++ o ++ "/edit") ] [ text " editing the entry" ]
        , text ". You likely know more about this entry than our moderators, after all. "
        , br [] []
        , text "If you're not sure whether something is a spoiler or if you need help with editing, you can also report this issue on the "
        , a [ href "/t/db" ] [ text "discussion board" ]
        , text " so that others may be able to help you."
        ]
    }
  , { label  = "Incorrect information"
    , vis    = \t o -> t == "db" && not (String.startsWith "d" o)
    , submit = False
    , msg    = \_ o ->
        [ text "VNDB is an open wiki, you can correct the information in this database yourself by "
        , a [ href ("/" ++ o ++ "/edit") ] [ text " editing the entry" ]
        , text ". You likely know more about this entry than our moderators, after all. "
        , br [] []
        , text "If you need help with editing, you can also report this issue on the "
        , a [ href "/t/db" ] [ text "discussion board" ]
        , text " so that others may be able to help you."
        ]
    }
  , { label  = "Missing information"
    , vis    = \t o -> t == "db" && not (String.startsWith "d" o)
    , submit = False
    , msg    = \_ o ->
        [ text "VNDB is an open wiki, you can add any missing information to this database yourself. "
        , text "You likely know more about this entry than our moderators, after all. "
        , br [] []
        , text "If you need help with contributing information, feel free to ask around on the "
        , a [ href "/t/db" ] [ text "discussion board" ]
        , text "."
        ]
    }
  , { label  = "Not a visual novel"
    , vis    = \t o -> t == "db" && String.startsWith "v" o
    , submit = False
    , msg    = \_ _ ->
        [ text "If you suspect that this entry does not adhere to our "
        , a [ href "/d2#1" ] [ text "inclusion criteria" ]
        , text ", please report it in "
        , a [ href "/t2108" ] [ text "this thread" ]
        , text ", so that other users have a chance to provide feedback before a moderator makes their final decision."
        ]
    }
  , { label  = "Does not belong here"
    , vis    = \t o -> t == "db" && not (String.startsWith "v" o || String.startsWith "d" o)
    , submit = True
    , msg    = nomsg
    }
  , { label  = "Duplicate entry"
    , vis    = \t o -> t == "db" && not (String.startsWith "d" o)
    , submit = True
    , msg    = \_ _ -> [ text "Please include a link to the entry that this is a duplicate of." ]
    }
  , { label  = "Other"
    , vis    = vis
    , submit = True
    , msg    = nomsg
    }
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
  let
    lst = List.filter (\l -> l.vis model.rtype model.object) reasons
    cur = List.filter (\l -> l.label == model.reason) lst |> List.head |> Maybe.withDefault initial
  in
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
        , formField "reason::Reason" [ inputSelect "reason" model.reason Reason [style "width" "300px"] <| List.map (\l->(l.label,l.label)) lst ]
        , formField "" (cur.msg model.rtype model.object)
        ] ++ if not cur.submit then [] else
        [ formField "message::Message" [ inputTextArea "message" model.message Message [] ]
        , formField "" [ submitButton "Submit" state True ]
        ]
    ]
  ]
