module Lib.Api exposing (..)

import Json.Encode as JE
import Json.Decode as JD
import File exposing (File)
import Http
import Html exposing (Attribute)
import Html.Events exposing (on)


-- Handy state enum for forms
type State
  = Normal
  | Loading
  | Error Response


type alias VN =
  { id       : Int
  , title    : String
  , original : String
  , hidden   : Bool
  }

decodeVN : JD.Decoder VN
decodeVN = JD.map4
  (\a b c d -> { id = a, title = b, original = c, hidden = d})
  (JD.field "id"       JD.int)
  (JD.field "title"    JD.string)
  (JD.field "original" JD.string)
  (JD.field "hidden"   JD.bool)


type alias Staff =
  { id       : Int
  , aid      : Int
  , name     : String
  , original : String
  }

decodeStaff : JD.Decoder Staff
decodeStaff = JD.map4
  (\a b c d -> { id = a, aid = b, name = c, original = d })
  (JD.field "id"       JD.int)
  (JD.field "aid"      JD.int)
  (JD.field "name"     JD.string)
  (JD.field "original" JD.string)


type alias Producer =
  { id       : Int
  , name     : String
  , original : String
  , hidden   : Bool
  }

decodeProducer : JD.Decoder Producer
decodeProducer = JD.map4
  (\a b c d -> { id = a, name = b, original = c, hidden = d })
  (JD.field "id"       JD.int)
  (JD.field "name"     JD.string)
  (JD.field "original" JD.string)
  (JD.field "hidden"   JD.bool)


type alias Char =
  { id       : Int
  , name     : String
  , original : String
  , main     : Maybe
    { id       : Int
    , name     : String
    }
  }

decodeChar : JD.Decoder Char
decodeChar = JD.map5
  (\a b c d e ->
    { id = a, name = b, original = c
    , main = case (d, e) of
        (Just id, Just name) -> Just { id = id, name = name }
        _ -> Nothing
    })
  (JD.field "id"            JD.int)
  (JD.field "name"          JD.string)
  (JD.field "original"      JD.string)
  (JD.field "main"          (JD.nullable JD.int   ))
  (JD.field "main_name"     (JD.nullable JD.string))


type alias Trait =
  { id    : Int
  , name  : String
  , gid   : Maybe Int
  , group : Maybe String
  }

decodeTrait : JD.Decoder Trait
decodeTrait = JD.map4
  (\a b c d -> { id = a, name = b, gid = c, group = d })
  (JD.field "id"    JD.int)
  (JD.field "name"  JD.string)
  (JD.field "gid"   (JD.nullable JD.int))
  (JD.field "group" (JD.nullable JD.string))


-- Same as Lib.Gen.CharEditVnrelsReleases
type alias Release =
  { id    : Int
  , title : String
  , lang  : List String
  }

decodeRelease : JD.Decoder Release
decodeRelease = JD.map3
  (\a b c -> { id = a, title = b, lang = c })
  (JD.field "id"    JD.int)
  (JD.field "title" JD.string)
  (JD.field "lang"   (JD.list JD.string))


-- Possible server responses. This only includes "expected" responses. Much of
-- the form validation is performed client side, so a constraint violation in
-- the JSON structure or data fields is unexpected and is reported by the
-- server as a 400 or 500 response.
type Response
  = HTTPError Http.Error
  | Success
  | CSRF
  | Throttled
  | Invalid JE.Value -- JSON structure constraint violation, contains TUWF::Validate error for low-level error reporting
  | Unauth
  | BadEmail
  | BadLogin
  | BadPass
  | Bot
  | Taken
  | DoubleEmail
  | DoubleIP
  | Unchanged
  | Changed Int Int -- DB entry updated, entry ID and revision number
  | VNResult (List VN)
  | StaffResult (List Staff)
  | ProducerResult (List Producer)
  | CharResult (List Char)
  | TraitResult (List Trait)
  | ReleaseResult (List Release)
  | ImgFormat
  | Image Int Int Int  -- Uploaded image (id, width, height)
  | Content String -- Text content


decodeResponse : JD.Decoder Response
decodeResponse = JD.oneOf
  [ JD.field "Success"       <| JD.succeed Success
  , JD.field "Throttled"     <| JD.succeed Throttled
  , JD.field "CSRF"          <| JD.succeed CSRF
  , JD.field "Invalid"       <| JD.map Invalid JD.value
  , JD.field "Unauth"        <| JD.succeed Unauth
  , JD.field "BadEmail"      <| JD.succeed BadEmail
  , JD.field "BadLogin"      <| JD.succeed BadLogin
  , JD.field "BadPass"       <| JD.succeed BadPass
  , JD.field "Bot"           <| JD.succeed Bot
  , JD.field "Taken"         <| JD.succeed Taken
  , JD.field "DoubleEmail"   <| JD.succeed DoubleEmail
  , JD.field "DoubleIP"      <| JD.succeed DoubleIP
  , JD.field "Unchanged"     <| JD.succeed Unchanged
  , JD.field "Changed"       <| JD.map2 Changed (JD.index 0 JD.int) (JD.index 1 JD.int)
  , JD.field "VNResult"      <| JD.map VNResult       <| JD.list decodeVN
  , JD.field "StaffResult"   <| JD.map StaffResult    <| JD.list decodeStaff
  , JD.field "ProducerResult"<| JD.map ProducerResult <| JD.list decodeProducer
  , JD.field "CharResult"    <| JD.map CharResult     <| JD.list decodeChar
  , JD.field "TraitResult"   <| JD.map TraitResult    <| JD.list decodeTrait
  , JD.field "ReleaseResult" <| JD.map ReleaseResult  <| JD.list decodeRelease
  , JD.field "ImgFormat"     <| JD.succeed ImgFormat
  , JD.field "Image"         <| JD.map3 Image (JD.index 0 JD.int) (JD.index 1 JD.int) (JD.index 2 JD.int)
  , JD.field "Content"       <| JD.map Content JD.string
  ]


-- User-friendly error message if the response isn't what the code expected
showResponse : Response -> String
showResponse res =
  let unexp = "Unexpected response, please report a bug."
  in case res of
    HTTPError (Http.Timeout)        -> "Network timeout, please try again later."
    HTTPError (Http.NetworkError)   -> "Network error, please try again later."
    HTTPError (Http.BadStatus r)    -> "Server error " ++ String.fromInt r ++ ", please try again later, or report an issue if this persists."
    HTTPError (Http.BadBody r)      -> "Invalid response from the server, please report a bug (debug info: " ++ r ++")."
    HTTPError (Http.BadUrl _)       -> unexp
    Success                         -> unexp
    CSRF                            -> "Invalid CSRF token, please refresh the page and try again."
    Throttled                       -> "Action throttled."
    Invalid _                       -> "Invalid form data, please report a bug." -- This error is already logged server-side, no debug info necessary
    Unauth                          -> "You do not have the permission to perform this action."
    BadEmail                        -> "Unknown email address."
    BadLogin                        -> "Invalid username or password."
    BadPass                         -> "Your chosen password is in a database of leaked passwords, please choose another one."
    Bot                             -> "Invalid answer to the anti-bot question."
    Taken                           -> "Username already taken, please choose a different name."
    DoubleEmail                     -> "Email address already used for another account."
    DoubleIP                        -> "You can only register one account from the same IP within 24 hours."
    Unchanged                       -> "No changes"
    Changed _ _                     -> unexp
    VNResult _                      -> unexp
    StaffResult _                   -> unexp
    ProducerResult _                -> unexp
    CharResult _                    -> unexp
    TraitResult _                   -> unexp
    ReleaseResult _                 -> unexp
    ImgFormat                       -> "Unrecognized image format, please upload a JPG or PNG file."
    Image _ _ _                     -> unexp
    Content _                       -> unexp


expectResponse : (Response -> msg) -> Http.Expect msg
expectResponse msg =
  let
    res r = msg <| case r of
      Err e -> HTTPError e
      Ok v -> v
  in Http.expectJson res decodeResponse


-- Send a POST request with a JSON body to the VNDB API and get a Response back.
post : String -> JE.Value -> (Response -> msg) -> Cmd msg
post url body msg =
  Http.post
    { url = url
    , body = Http.jsonBody body
    , expect = expectResponse msg
    }



-- Simple image upload API

type ImageType
  = Cv
  | Sf
  | Ch


onFileChange : (List File -> m) -> Attribute m
onFileChange msg = on "change" <| JD.map msg <| JD.at ["target","files"] <| JD.list File.decoder


-- Upload an image to /js/imageupload.json
postImage : ImageType -> File -> (Response -> msg) -> Cmd msg
postImage ty file msg =
  let
    tys = case ty of
      Cv -> "cv"
      Sf -> "sf"
      Ch -> "ch"

    body = Http.multipartBody
      [ Http.stringPart "type" tys
      , Http.filePart "img" file
      ]
  in Http.post
      { url  = "/js/imageupload.json"
      , body = body
      , expect = expectResponse msg
      }
