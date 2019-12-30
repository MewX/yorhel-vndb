module Lib.Autocomplete exposing
  ( Config
  , SourceConfig
  , Model
  , Msg
  , boardSource
  , init
  , clear
  , update
  , view
  )

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes exposing (..)
import Html.Keyed as Keyed
import Json.Encode as JE
import Json.Decode as JD
import Task
import Process
import Browser.Dom as Dom
import Lib.Html exposing (..)
import Lib.Util exposing (..)
import Lib.Api as Api
import Gen.Types exposing (boardTypes)
import Gen.Api as GApi


type alias Config m a =
    -- How to wrap a Msg from this model into a Msg of the using model
  { wrap     : Msg a -> m
    -- A unique 'id' of the input box (necessary for the blur/focus events)
  , id       : String
    -- The source defines where to get autocomplete results from and how to display them
  , source   : SourceConfig m a
  }


type alias SourceConfig m a =
    -- API path to query for completion results.
    -- (The API must accept POST requests with {"search":".."} as body)
  { path     : String
    -- How to decode results from the API
  , decode   : GApi.Response -> Maybe (List a)
    -- How to display the decoded results
  , view     : a -> List (Html m)
    -- Unique ID of an item (must not be an empty string).
    -- This is used to remember selection across data refreshes and to optimize
    -- HTML generation.
  , key      : a -> String
  }



boardSource : SourceConfig m GApi.ApiBoardResult
boardSource =
  { path    = "/t/boards.json"
  , decode  = \x -> case x of
      GApi.BoardResult e -> Just e
      _ -> Nothing
  , view    = (\i ->
    [ text <| Maybe.withDefault "" (lookup i.btype boardTypes)
    ] ++ case i.title of
      Just title -> [ b [ class "grayedout" ] [ text " > " ], text title ]
      _ -> []
    )
  , key     = \i -> i.btype ++ String.fromInt i.iid
  }


type alias Model a =
  { visible  : Bool
  , value    : String
  , results  : List a
  , sel      : String
  , loading  : Bool
  , wait     : Int
  }


init : Model a
init =
  { visible  = False
  , value    = ""
  , results  = []
  , sel      = ""
  , loading  = False
  , wait     = 0
  }


clear : Model a -> Model a
clear m = { m
  | value    = ""
  , results  = []
  , sel      = ""
  , loading  = False
  }


type Msg a
  = Noop
  | Focus
  | Blur
  | Input String
  | Search Int
  | Key String
  | Sel String
  | Enter a
  | Results String GApi.Response


select : Config m a -> Int -> Model a -> Model a
select cfg offset model =
  let
    get n   = List.drop n model.results |> List.head
    count   = List.length model.results
    find (n,i) = if cfg.source.key i == model.sel then Just n else Nothing
    curidx  = List.indexedMap (\a b -> (a,b)) model.results |> List.filterMap find |> List.head
    nextidx = (Maybe.withDefault -1 curidx) + offset
    nextsel = if nextidx < 0 then 0 else if nextidx >= count then count-1 else nextidx
  in
    { model | sel = Maybe.withDefault "" <| Maybe.map cfg.source.key <| get nextsel }


update : Config m a -> Msg a -> Model a -> (Model a, Cmd m, Maybe a)
update cfg msg model =
  let
    mod m = (m, Cmd.none, Nothing)
    -- Ugly hack: blur and focus the input on enter. This does two things:
    -- 1. If the user clicked on an entry (resulting in the 'Enter' message),
    --    then this will cause the input to be focussed again. This is
    --    convenient when adding multiple entries.
    refocus = Dom.blur cfg.id
           |> Task.andThen (always (Dom.focus cfg.id))
           |> Task.attempt (always (cfg.wrap Noop))
  in
  case msg of
    Noop    -> mod model
    Blur    -> mod { model | visible = False }
    Focus   -> mod { model | loading = False, visible = True }
    Sel s   -> mod { model | sel = s }
    Enter r -> (model, refocus, Just r)

    Key "Enter"     -> (model, refocus,
      case List.filter (\i -> cfg.source.key i == model.sel) model.results |> List.head of
        Just x -> Just x
        Nothing -> List.head model.results)
    Key "ArrowUp"   -> mod <| select cfg -1 model
    Key "ArrowDown" -> mod <| select cfg  1 model
    Key _           -> mod model

    Input s ->
      if s == ""
      then mod { model | value = s, loading = False, results = [] }
      else   ( { model | value = s, loading = True,  wait = model.wait + 1 }
             , Task.perform (always <| cfg.wrap <| Search <| model.wait + 1) (Process.sleep 500)
             , Nothing )

    Search i ->
      if model.value == "" || model.wait /= i
      then mod model
      else ( model
           , Api.post cfg.source.path (JE.object [("search", JE.string model.value)]) (cfg.wrap << Results model.value)
           , Nothing )

    Results s r -> mod <|
      if s == model.value
      then { model | loading = False, results = cfg.source.decode r |> Maybe.withDefault [] }
      else model -- Discard stale results


view : Config m a -> Model a -> List (Attribute m) -> Html m
view cfg model attrs =
  let
    input =
      inputText cfg.id model.value (cfg.wrap << Input) <|
        [ onFocus <| cfg.wrap Focus
        , onBlur  <| cfg.wrap Blur
        , style "width" "270px"
        , custom "keydown" <| JD.map (\c ->
                 if c == "Enter" || c == "ArrowUp" || c == "ArrowDown"
                 then { preventDefault = True,  stopPropagation = True,  message = cfg.wrap (Key c) }
                 else { preventDefault = False, stopPropagation = False, message = cfg.wrap (Key c) }
            ) <| JD.field "key" JD.string
        ] ++ attrs

    visible = model.visible && model.value /= "" && not (model.loading && List.isEmpty model.results)

    msg = [("",
        if List.isEmpty model.results
        then li [ class "msg" ] [ text "No results" ]
        else text ""
      )]

    item i =
      ( cfg.source.key i
      , li []
        [ a
          [ href "#"
          , classList [("active", cfg.source.key i == model.sel)]
          , onMouseOver <| cfg.wrap <| Sel <| cfg.source.key i
          , onMouseDown <| cfg.wrap <| Enter i
          ] <| cfg.source.view i
        ]
      )

  in div [ class "elm_dd", class "search", style "width" "300px" ]
    [ div [ classList [("hidden", not visible)] ] [ Keyed.node "ul" [] <| msg ++ List.map item model.results ]
    , input
    , span [ class "spinner", classList [("hidden", not model.loading)] ] []
    ]