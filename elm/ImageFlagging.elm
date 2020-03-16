module ImageFlagging exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Array
import Dict
import Browser
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


-- TODO: Keyboard shortcuts
main : Program () Model Msg
main = Browser.element
  { init   = \e -> (init e, Cmd.none)
  , view   = view
  , update = update
  , subscriptions = always Sub.none
  }


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

init : () -> Model
init _ =
  { warn      = True
  , images    = Array.empty
  , index     = 0
  , desc      = (Nothing, Nothing)
  , changes   = Dict.empty
  , saved     = False
  , saveTimer = False
  , saveState = Api.Normal
  , loadState = Api.Normal
  }


type Msg
  = SkipWarn
  | Desc (Maybe Int) (Maybe Int)
  | Load GApi.Response
  | Vote (Maybe Int) (Maybe Int) Bool
  | Save
  | Saved GApi.Response
  | Prev
  | Next


isLast : Model -> Bool
isLast model = Array.get model.index model.images |> Maybe.map (\i -> i.my_sexual == Nothing || i.my_violence == Nothing) |> Maybe.withDefault True


-- TODO: preload next image
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
  in
  case msg of
    SkipWarn -> load ({ model | warn = False }, Cmd.none)
    Desc s v -> ({ model | desc = (s,v) }, Cmd.none)

    Load (GApi.ImageResult l) ->
      let nm = { model | loadState = Api.Normal, images = Array.append model.images (Array.fromList l) }
          nc = if nm.index < 200 then nm
               else { nm | index = nm.index - 100, images = Array.slice 100 (Array.length nm.images) nm.images }
      in (nc, Cmd.none)
    Load e -> ({ model | loadState = Api.Error e }, Cmd.none)

    Vote s v _ ->
      case Array.get model.index model.images of
        Nothing -> (model, Cmd.none)
        Just i ->
          let m = { model | saved = False, images = Array.set model.index { i | my_sexual = s, my_violence = v } model.images }
          in case (s,v) of
              -- Complete vote, mark it as a change and go to next image
              (Just xs, Just xv) -> desc <| save <| load
                ({ m | index   = m.index + (if isLast model then 1 else 0)
                     , changes = Dict.insert i.id { id = i.id, sexual = xs, violence = xv } m.changes
                 }, Cmd.none)
              -- Otherwise just save it internally
              _ -> (m, Cmd.none)

    Save -> ({ model | saveTimer = False, saveState = Api.Loading, changes = Dict.empty }, GIV.send { votes = Dict.values model.changes } Saved)
    Saved r -> save ({ model | saved = True, saveState = if r == GApi.Success then Api.Normal else Api.Error r }, Cmd.none)

    Prev -> desc ({ model | saved = False, index = model.index - (if model.index == 0 then 0 else 1) }, Cmd.none)
    Next -> desc ({ model | saved = False, index = model.index + (if isLast model then 0 else 1) }, Cmd.none)


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

    but i name s v lbl =
      let sel = i.my_sexual == s && i.my_violence == v
      in li [ classList [("sel", sel)] ]
         [ label [ onMouseOver (Desc s v), onMouseOut (Desc i.my_sexual i.my_violence) ] [ inputRadio name sel (Vote s v), text lbl ]
         ]

    imgView i =
      let entry = i.entry_type ++ String.fromInt i.entry_id
      in
      [ div []
        [ a [ href "#", onClickD Prev, classList [("invisible", model.index == 0)] ] [ text "««" ]
        , span []
          [ b [ class "grayedout" ] [ text (entry ++ ":") ]
          , a [ href ("/" ++ entry) ] [ text i.entry_title ]
          ]
        , a [ href "#", onClickD Next, classList [("invisible", isLast model)] ] [ text "»»" ]
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
        [ div []
          [ ul []
            [ li [] [ span [] [ text "Sexual" ] ]
            , but i "sexual" (Just 0) i.my_violence " Safe"
            , but i "sexual" (Just 1) i.my_violence " Suggestive"
            , but i "sexual" (Just 2) i.my_violence " Explicit"
            ]
          , p [] <|
            case Tuple.first model.desc of
              Just 0 -> [ text "- No nudity", br [] []
                        , text "- No (implied) sexual actions", br [] []
                        , text "- No suggestive clothing or visible underwear", br [] []
                        , text "- No sex toys" ]
              Just 1 -> [ text "- Visible underwear or skimpy clothing", br [] []
                        , text "- Erotic posing", br [] []
                        , text "- Sex toys (but not visibly being used)", br [] []
                        , text "- No visible genitals or female nipples" ]
              Just 2 -> [ text "- Visible genitals or female nipples", br [] []
                        , text "- Penetrative sex (regardless of clothing)", br [] []
                        , text "- Visible use of sex toys" ]
              _ -> []
          ]
        , div []
          [ ul []
            [ li [] [ span [] [ text "Violence" ] ]
            , but i "violence" i.my_sexual (Just 0) " Tame"
            , but i "violence" i.my_sexual (Just 1) " Violent"
            , but i "violence" i.my_sexual (Just 2) " Brutal"
            ]
          , p [] <|
            case Tuple.second model.desc of
              Just 0 -> [ text "- No visible violence", br [] []
                        , text "- Tame slapstick comedy", br [] []
                        , text "- Weapons, but not used to harm anyone", br [] []
                        , text "- Only very minor visible blood or bruises", br [] [] ]
              Just 1 -> [ text "- Visible blood", br [] []
                        , text "- Non-comedic fight scenes", br [] []
                        , text "- Physically harmful activities" ]
              Just 2 -> [ text "- Excessive amounts of blood", br [] []
                        , text "- Cut off limbs", br [] []
                        , text "- Sliced-open bodies", br [] []
                        , text "- Harmful activities leading to death" ]
              _ -> []
          ]
        ]
      -- TODO: list of users who voted on this image
      ]

  in div [ class "mainbox" ]
  [ h1 [] [ text "Image flagging" ]
  , div [ class "imageflag" ] <|
    if model.warn
    then [ ul []
           [ li [] [ text "Make sure you are familiar with the ", a [ href "/d19" ] [ text "image flagging guidelines" ], text "." ]
           , li [] [ b [ class "standout" ] [ text "WARNING: " ], text "Images shown may be highly offensive and/or depictions of explicit sexual acts." ]
           ]
         , inputButton "I understand, continue" SkipWarn []
         ]
    else case (Array.get model.index model.images, model.loadState) of
           (Just i, _)    -> imgView i
           (_, Api.Loading) -> [ span [ class "spinner" ] [] ]
           (_, Api.Error e) -> [ b [ class "standout" ] [ text <| Api.showResponse e ] ]
           (_, Api.Normal)  -> [ text "No more images to vote on!" ]
  ]
