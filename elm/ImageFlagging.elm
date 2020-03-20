port module ImageFlagging exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Array
import Dict
import Browser
import Browser.Events as EV
import Task
import Process
import Json.Decode as JD
import Lib.Html exposing (..)
import Lib.Util exposing (..)
import Lib.Api as Api
import Lib.Ffi as Ffi
import Gen.Api as GApi
import Gen.Images as GI
import Gen.ImageVote as GIV


main : Program GI.Recv Model Msg
main = Browser.element
  { init   = \e -> (init e, Cmd.none)
  , view   = view
  , update = update
  , subscriptions = \m -> if m.warn then Sub.none else EV.onKeyDown (keymap m)
  }


port preload : String -> Cmd msg


type alias Model =
  { warn      : Bool
  , images    : Array.Array GApi.ApiImageResult
  , index     : Int
  , desc      : (Maybe Int, Maybe Int)
  , changes   : Dict.Dict String GIV.SendVotes
  , saved     : Bool
  , saveTimer : Bool
  , loadState : Api.State
  , saveState : Api.State
  }

init : GI.Recv -> Model
init d =
  { warn      = True
  , images    = Array.fromList d.history
  , index     = List.length d.history
  , desc      = (Nothing, Nothing)
  , changes   = Dict.empty
  , saved     = False
  , saveTimer = False
  , saveState = Api.Normal
  , loadState = Api.Normal
  }


-- TODO: Document keyboard shortcuts somewhere
keymap : Model -> JD.Decoder Msg
keymap model =
  let (s,v) = Maybe.withDefault (Nothing,Nothing) <| Maybe.map (\i -> (i.my_sexual, i.my_violence)) <| Array.get model.index model.images
  in JD.andThen (\k ->
    case k of
      "ArrowLeft"  -> JD.succeed Prev
      "ArrowRight" -> JD.succeed Next
      "1" -> JD.succeed (Vote (Just 0) (Just 0) True)
      "2" -> JD.succeed (Vote (Just 1) (Just 0) True)
      "3" -> JD.succeed (Vote (Just 2) (Just 0) True)
      "4" -> JD.succeed (Vote (Just 0) (Just 1) True)
      "5" -> JD.succeed (Vote (Just 1) (Just 1) True)
      "6" -> JD.succeed (Vote (Just 2) (Just 1) True)
      "7" -> JD.succeed (Vote (Just 0) (Just 2) True)
      "8" -> JD.succeed (Vote (Just 1) (Just 2) True)
      "9" -> JD.succeed (Vote (Just 2) (Just 2) True)
      "s" -> JD.succeed (Vote (Just 0) v True)
      "d" -> JD.succeed (Vote (Just 1) v True)
      "f" -> JD.succeed (Vote (Just 2) v True)
      "j" -> JD.succeed (Vote s (Just 0) True)
      "k" -> JD.succeed (Vote s (Just 1) True)
      "l" -> JD.succeed (Vote s (Just 2) True)
      _ -> JD.fail ""
  ) (JD.field "key" JD.string)


type Msg
  = SkipWarn
  | Desc (Maybe Int) (Maybe Int)
  | Load GApi.Response
  | Vote (Maybe Int) (Maybe Int) Bool
  | Save
  | Saved GApi.Response
  | Prev
  | Next


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  let -- Load more images if we're about to run out
      load (m,c) =
        if m.loadState /= Api.Loading && Array.length m.images - m.index <= 3
        then ({ m | loadState = Api.Loading }, Cmd.batch [ c, GI.send {} Load ])
        else (m,c)
      -- Start a timer to save changes
      save (m,c) =
        if not m.saveTimer && not (Dict.isEmpty m.changes) && m.saveState /= Api.Loading
        then ({ m | saveTimer = True }, Cmd.batch [ c, Task.perform (always Save) (Process.sleep 5000) ])
        else (m,c)
      -- Set desc to current image
      desc (m,c) =
        ({ m | desc = Maybe.withDefault (Nothing,Nothing) <| Maybe.map (\i -> (i.my_sexual, i.my_violence)) <| Array.get m.index m.images}, c)
      -- Preload next image
      pre (m, c) =
        case Array.get (m.index+1) m.images of
          Just i  -> (m, Cmd.batch [ c, preload i.url ])
          Nothing -> (m, Cmd.none)
  in
  case msg of
    SkipWarn -> load ({ model | warn = False }, Cmd.none)
    Desc s v -> ({ model | desc = (s,v) }, Cmd.none)

    Load (GApi.ImageResult l) ->
      let nm = { model | loadState = Api.Normal, images = Array.append model.images (Array.fromList l) }
          nc = if nm.index < 1000 then nm
               else { nm | index = nm.index - 100, images = Array.slice 100 (Array.length nm.images) nm.images }
      in pre (nc, Cmd.none)
    Load e -> ({ model | loadState = Api.Error e }, Cmd.none)

    Vote s v _ ->
      case Array.get model.index model.images of
        Nothing -> (model, Cmd.none)
        Just i ->
          let m = { model | saved = False, images = Array.set model.index { i | my_sexual = s, my_violence = v } model.images }
          in case (s,v) of
              -- Complete vote, mark it as a change and go to next image
              (Just xs, Just xv) -> desc <| pre <| save <| load
                ({ m | index   = m.index + (if i.my_sexual == Nothing || i.my_violence == Nothing then 1 else 0)
                     , changes = Dict.insert i.id { id = i.id, sexual = xs, violence = xv } m.changes
                 }, Cmd.none)
              -- Otherwise just save it internally
              _ -> (m, Cmd.none)

    Save -> ({ model | saveTimer = False, saveState = Api.Loading, changes = Dict.empty }, GIV.send { votes = Dict.values model.changes } Saved)
    Saved r -> save ({ model | saved = True, saveState = if r == GApi.Success then Api.Normal else Api.Error r }, Cmd.none)

    Prev -> desc ({ model | saved = False, index = model.index - (if model.index == 0 then 0 else 1) }, Cmd.none)
    Next -> desc <| pre <| load ({ model | saved = False, index = model.index + 1 }, Cmd.none)


view : Model -> Html Msg
view model =
  let
    -- TODO: Dynamic box size depending on available space?
    boxwidth = 800
    boxheight = 600
    px n = String.fromInt (floor n) ++ "px"
    stat avg stddev =
      case (avg, stddev) of
        (Just a, Just s) -> Ffi.fmtFloat a 2 ++ " σ " ++ Ffi.fmtFloat s 2
        _ -> "-"

    but i s v lbl =
      let sel = i.my_sexual == s && i.my_violence == v
      in li [ classList [("sel", sel)] ]
         [ label [ onMouseOver (Desc s v), onMouseOut (Desc i.my_sexual i.my_violence) ] [ inputRadio "" sel (Vote s v), text lbl ]
         ]

    imgView i =
      [ div []
        [ inputButton "««" Prev [ classList [("invisible", model.index == 0)] ]
        , span [] <|
          case i.entry of
            Nothing -> []
            Just e ->
              [ b [ class "grayedout" ] [ text (e.id ++ ":") ]
              , a [ href ("/" ++ e.id) ] [ text e.title ]
              ]
        , inputButton "»»" Next []
        ]
      , div [ style "width" (px boxwidth), style "height" (px boxheight) ] <|
        -- Don't use an <img> here, changing the src= causes the old image to be displayed with the wrong dimensions while the new image is being loaded.
        [ a [ href i.url, style "background-image" ("url("++i.url++")")
            , style "background-size" (if i.width > boxwidth || i.height > boxheight then "contain" else "auto")
            ] [ text "" ] ]
      , div []
        [ span [] <|
          case model.saveState of
            Api.Error e -> [ b [ class "standout" ] [ text <| "Save failed: " ++ Api.showResponse e ] ]
            _ ->
              [ span [ class "spinner", classList [("invisible", model.saveState == Api.Normal)] ] []
              , b [ class "grayedout" ] [ text <|
                if not (Dict.isEmpty model.changes)
                then "Unsaved votes: " ++ String.fromInt (Dict.size model.changes)
                else if model.saved then "Saved!" else "" ]
              ]
        , span []
          [ text <| String.fromInt i.votecount ++ (if i.votecount == 1 then " vote" else " votes")
          , b [ class "grayedout" ] [ text " / " ]
          , text <| "sexual: " ++ stat i.sexual_avg i.sexual_stddev
          , b [ class "grayedout" ] [ text " / " ]
          , text <| "violence: " ++ stat i.violence_avg i.violence_stddev
          , b [ class "grayedout" ] [ text " / " ]
          , a [ href i.url ] [ text <| String.fromInt i.width ++ "x" ++ String.fromInt i.height ]
          ]
        ]
      , div []
        [ p [] <|
          case Tuple.first model.desc of
            Just 0 -> [ b [] [ text "Safe" ], br [] []
                      , text "- No nudity", br [] []
                      , text "- No (implied) sexual actions", br [] []
                      , text "- No suggestive clothing or visible underwear", br [] []
                      , text "- No sex toys" ]
            Just 1 -> [ b [] [ text "Suggestive" ], br [] []
                      , text "- Visible underwear or skimpy clothing", br [] []
                      , text "- Erotic posing", br [] []
                      , text "- Sex toys (but not visibly being used)", br [] []
                      , text "- No visible genitals or female nipples" ]
            Just 2 -> [ b [] [ text "Explicit" ], br [] []
                      , text "- Visible genitals or female nipples", br [] []
                      , text "- Penetrative sex (regardless of clothing)", br [] []
                      , text "- Visible use of sex toys" ]
            _ -> []
        , ul []
          [ li [] [ b [] [ text "Sexual" ] ]
          , but i (Just 0) i.my_violence " Safe"
          , but i (Just 1) i.my_violence " Suggestive"
          , but i (Just 2) i.my_violence " Explicit"
          ]
        , ul []
          [ li [] [ b [] [ text "Violence" ] ]
          , but i i.my_sexual (Just 0) " Tame"
          , but i i.my_sexual (Just 1) " Violent"
          , but i i.my_sexual (Just 2) " Brutal"
          ]
        , p [] <|
          case Tuple.second model.desc of
            Just 0 -> [ b [] [ text "Tame" ], br [] []
                      , text "- No visible violence", br [] []
                      , text "- Tame slapstick comedy", br [] []
                      , text "- Weapons, but not used to harm anyone", br [] []
                      , text "- Only very minor visible blood or bruises", br [] [] ]
            Just 1 -> [ b [] [ text "Violent" ], br [] []
                      , text "- Visible blood", br [] []
                      , text "- Non-comedic fight scenes", br [] []
                      , text "- Physically harmful activities" ]
            Just 2 -> [ b [] [ text "Brutal" ], br [] []
                      , text "- Excessive amounts of blood", br [] []
                      , text "- Cut off limbs", br [] []
                      , text "- Sliced-open bodies", br [] []
                      , text "- Harmful activities leading to death" ]
            _ -> []
        ]
      , p [ class "center" ] [ text "Not sure? Read the ", a [ href "/d19" ] [ text "full guidelines" ], text " for more detailed guidance." ]
      -- TODO: list of users who voted on this image
      ]

  in div [ class "mainbox" ]
  [ h1 [] [ text "Image flagging" ]
  , div [ class "imageflag" ] <|
    if model.warn
    then [ ul []
           [ li [] [ text "Make sure you are familiar with the ", a [ href "/d19" ] [ text "image flagging guidelines" ], text "." ]
           , li [] [ b [ class "standout" ] [ text "WARNING: " ], text "Images shown may include spoilers, be highly offensive and/or contain very explicit depictions of sexual acts." ]
           ]
         , br [] []
         , inputButton "I understand, continue" SkipWarn []
         ]
    else case (Array.get model.index model.images, model.loadState) of
           (Just i, _)    -> imgView i
           (_, Api.Loading) -> [ span [ class "spinner" ] [] ]
           (_, Api.Error e) -> [ b [ class "standout" ] [ text <| Api.showResponse e ] ]
           (_, Api.Normal)  -> [ text "No more images to vote on!" ]
  ]
