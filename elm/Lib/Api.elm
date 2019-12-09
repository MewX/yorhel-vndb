module Lib.Api exposing (..)

import Json.Encode as JE
import Http

import Gen.Api exposing (..)


-- Handy state enum for forms
type State
  = Normal
  | Loading
  | Error Response


-- User-friendly error message if the response isn't what the code expected.
-- (Technically a good chunk of this function could also be automatically
-- generated by Elm.pm, but that wouldn't really have all that much value).
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
    Redirect _                      -> unexp
    CSRF                            -> "Invalid CSRF token, please refresh the page and try again."
    Invalid                         -> "Invalid form data, please report a bug."
    Unauth                          -> "You do not have the permission to perform this action."
    Unchanged                       -> "No changes"
    Content _                       -> unexp
    BadLogin                        -> "Invalid username or password."
    LoginThrottle                   -> "Action throttled, too many failed login attempts."
    InsecurePass                    -> "Your chosen password is in a database of leaked passwords, please choose another one."
    BadEmail                        -> "Unknown email address."
    Bot                             -> "Invalid answer to the anti-bot question."
    Taken                           -> "Username already taken, please choose a different name."
    DoubleEmail                     -> "Email address already used for another account."
    DoubleIP                        -> "You can only register one account from the same IP within 24 hours."
    BadCurPass                      -> "Current password is invalid."
    MailChange                      -> unexp
    Releases _                      -> unexp
    BoardResult _                   -> unexp


expectResponse : (Response -> msg) -> Http.Expect msg
expectResponse msg =
  let
    res r = msg <| case r of
      Err e -> HTTPError e
      Ok v -> v
  in Http.expectJson res decode


-- Send a POST request with a JSON body to the VNDB API and get a Response back.
post : String -> JE.Value -> (Response -> msg) -> Cmd msg
post url body msg =
  Http.post
    { url = url
    , body = Http.jsonBody body
    , expect = expectResponse msg
    }
