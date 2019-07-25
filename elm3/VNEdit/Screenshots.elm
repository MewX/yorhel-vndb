module VNEdit.Screenshots exposing (Model, Msg, loading, init, update, view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import File exposing (File)
import Lib.Html exposing (..)
import Lib.Util exposing (..)
import Lib.Api as Api
import Lib.Gen exposing (resolutions, VNEditScreenshots, VNEditReleases)
import Lib.Util exposing (lookup, isJust)


type alias Model =
  { screenshots : List VNEditScreenshots
  , releases    : List VNEditReleases
  , state       : List Api.State
  , id          : Int -- Temporary negative internal screenshot identifier, until the image has been uploaded and the actual ID is known
  , rel         : Int
  , nsfw        : Bool
  , files       : List File
  }


init : List VNEditScreenshots -> List VNEditReleases -> Model
init scr rels =
  { screenshots = scr
  , releases    = rels
  , state       = List.map (always Api.Normal) scr
  , id          = -1
  , rel         = Maybe.withDefault 0 <| Maybe.map .id <| List.head rels
  , nsfw        = False
  , files       = []
  }


loading : Model -> Bool
loading model = List.any (\s -> s /= Api.Normal) model.state


type Msg
  = Del Int
  | SetNSFW Int Bool
  | SetRel Int String
  | DefNSFW Bool
  | DefRel String
  | DefFiles (List File)
  | Upload
  | Done Int Api.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Del i       -> ({ model | screenshots = delidx i model.screenshots, state = delidx i model.state }, Cmd.none)
    SetNSFW i b -> ({ model | screenshots = modidx i (\e -> { e | nsfw = b }) model.screenshots }, Cmd.none)
    SetRel i s  -> ({ model | screenshots = modidx i (\e -> { e | rid = Maybe.withDefault e.rid (String.toInt s) }) model.screenshots }, Cmd.none)
    DefNSFW b   -> ({ model | nsfw = b }, Cmd.none)
    DefRel s    -> ({ model | rel = Maybe.withDefault 0 (String.toInt s) }, Cmd.none)
    DefFiles l  -> ({ model | files = l }, Cmd.none)

    Upload ->
      let
        st = model.state ++ List.map (always Api.Loading) model.files
        scr i _ = { scr = model.id - i, rid = model.rel, nsfw = model.nsfw, width = 0, height = 0 }
        alst = List.indexedMap scr model.files
        lst = model.screenshots ++ alst
        nid = model.id - List.length model.files
        cmd f i = Api.postImage Api.Sf f (Done i.scr)
        cmds = List.map2 cmd model.files alst
      in ({ model | screenshots = lst, id = nid, state = st, files = [] }, Cmd.batch cmds)

    Done id r ->
      case List.head <| List.filter (\(_,i) -> i.scr == id) <| List.indexedMap (\a b -> (a,b)) model.screenshots of
        Nothing -> (model, Cmd.none)
        Just (n,_) ->
          let
            st _ = case r of
              Api.Image _ _ _ -> Api.Normal
              re -> Api.Error re
            scr s = case r of
              Api.Image nid width height -> { s | scr = nid, width = width, height = height }
              _ -> s
          in ({ model | screenshots = modidx n scr model.screenshots, state = modidx n st model.state }, Cmd.none)



view : Model -> Maybe Int -> Html Msg
view model vid =
  let
    row image remove titl opts after = div [class "screenshot-edit__row"]
      [ div [ class "screenshot-edit__screenshot" ] [ image ]
      , div [ class "screenshot-edit__fields" ] <|
        [ remove
        , div [ class "screenshot-edit__title" ] [ text titl ]
        , div [ class "screenshot-edit__options" ] opts
        ] ++ after
      ]

    rm  n = div [ class "screenshot-edit__remove" ] [ removeButton (Del n) ]
    img n f = dbImg "st" n [class "vn-image-placeholder--wide"] f

    commonRes res =
      -- NDS resolution, not in the database
      res == "256x384" || isJust (lookup res resolutions)

    resWarn e =
      let res = String.fromInt e.width ++ "x" ++ String.fromInt e.height
      in case List.filter (\r -> r.id == e.rid) model.releases |> List.head of
        Nothing -> text "" -- Shouldn't happen
        Just r ->
          -- If the release resolution is known and does *not* match the image resolution, warn about that
          if r.resolution /= "unknown" && r.resolution /= "nonstandard" && r.resolution /= res
          then div [ class "invalid-feedback" ]
            [ text <| "Screenshot resolution is not the same as that of the selected release (" ++ r.resolution ++ "). Please make sure take screenshots in that *exact* resolution!" ]
          -- Otherwise, if this isn't a non-standard resolution, check for common ones
          else if r.resolution == "nonstandard" || commonRes res
          then text ""
          else div [ class "invalid-feedback" ]
            [ text <| "Odd screenshot resolution. Please make sure take screenshots in the correct resolution!" ]

    entry n (s,e) = case s of
      Api.Loading -> row (img -1 Nothing) (rm n) "Uploading screenshot" [] []
      Api.Error r -> row
        (img 0 Nothing) (rm n) "Upload failed"
        [ div [ class "invalid-feedback" ] [ text <| Api.showResponse r ] ]
        []
      Api.Normal -> row
        (img e.scr <| Just { width = e.width, height = e.height, id = "scr" })
        (rm n) ("Screenshot #" ++ String.fromInt e.scr)
        [ span [ class "muted" ] [ text <| String.fromInt e.width ++ "x" ++ String.fromInt e.height ]
        , label [ class "checkbox" ]
          [ inputCheck "" e.nsfw (SetNSFW n)
          , text " Not safe for work"
          ]
        ]
        [ resWarn e
        , releaseSelect e.rid (SetRel n) ]

    add = if List.length model.screenshots == 10 then text "" else row
      (text "")
      (text "")
      "Add screenshot"
      [ span [ class "muted" ] [ text "Image must be smaller than 5MB and in PNG or JPEG format. No more than 10 screenshots can be uploaded." ] ]
      [ releaseSelect model.rel DefRel
      , div [ class "screenshot-edit__upload-options" ]
        [ div [ class "screenshot-edit__upload-option" ] [ input [ type_ "file", id "addscr", tabindex 10, multiple True, Api.onFileChange DefFiles ] [] ]
        , div [ class "screenshot-edit__upload-option" ]
          [ label [ class "checkbox screenshot-edit__upload-nsfw-label" ]
            [ inputCheck "" model.nsfw DefNSFW
            , text " Not safe for work" ] ]
        , div [ class "flex-expand" ] []
        , div [ class "screenshot-edit__upload-option" ]
          [ button
            [ type_ "button", class "btn screenshot-edit__upload-btn", tabindex 10, onClick Upload
            , disabled <| List.isEmpty model.files || (List.length model.files + List.length model.screenshots) > 10
            ] [ text "Upload!" ] ]
        ]
      ]

    releaseSelect rid msg = inputSelect [onInput msg] (String.fromInt rid)
      <| List.map (\s -> (String.fromInt s.id, s.display)) model.releases

    norel =
      case vid of
        Nothing -> [ text "Screenshots can be uploaded after adding releases to this visual novel." ]
        Just i ->
          [ text "Screenshots can be added after "
          , a [ href <| "/v"  ++ (String.fromInt i) ++ "/add", target "_blank" ] [ text "adding a release entry" ]
          , text "."
          ]

  in if List.isEmpty model.releases
  then card "screenshots" "Screenshots" [ div [class "card__subheading"] norel ] []
  else card "screenshots" "Screenshots"
    [ div [class "card__subheading"]
      [ text "Keep in mind that all screenshots must conform to "
      , a [href "/d2#6", target "blank"] [ text "strict guidelines" ]
      , text ", read those carefully!"
      ]
    ]
    [ div [class "screenshot-edit"] <| List.indexedMap entry (List.map2 (\a b -> (a,b)) model.state model.screenshots) ++ [ add ] ]
