module Lib.Autocomplete exposing
  ( Config
  , SourceConfig
  , Model
  , Msg
  , staffSource
  , vnSource
  , producerSource
  , charSource
  , traitSource
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
import Lib.Api as Api
import Lib.Gen as Gen


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
  , decode   : Api.Response -> Maybe (List a)
    -- How to display the decoded results
  , view     : a -> List (Html m)
    -- Unique ID of an item (must not be an empty string).
    -- This is used to remember selection across data refreshes and to optimize
    -- HTML generation.
  , key      : a -> String
  }



staffSource : SourceConfig m Gen.ApiStaffResult
staffSource =
  { path    = "/js/staff.json"
  , decode  = \x -> case x of
      Gen.StaffResult e -> Just e
      _ -> Nothing
  , view    = (\i -> [ div [ class "row row-compact" ]
    [ div [ class "col single-line muted" ] [ text <| "s" ++ String.fromInt i.id ]
    , div [ class "col col--2 single-line semi-bold" ] [ text i.name ]
    , div [ class "col col--2 single-line" ] [ text i.original ]
    ] ] )
  , key     = .aid >> String.fromInt
  }


vnSource : SourceConfig m Gen.ApiVNResult
vnSource =
  { path   = "/js/vn.json"
  , decode  = \x -> case x of
      Gen.VNResult e -> Just e
      _ -> Nothing
  , view    = (\i -> [ div [ class "row row-compact" ]
    [ div [ class "col single-line muted" ] [ text <| "v" ++ String.fromInt i.id ]
    , div [ class "col col--4 single-line semi-bold" ] [ text i.title ]
    ] ] )
  , key    = .id >> String.fromInt
  }


producerSource : SourceConfig m Gen.ApiProducerResult
producerSource =
  { path   = "/js/producer.json"
  , decode  = \x -> case x of
      Gen.ProducerResult e -> Just e
      _ -> Nothing
  , view    = (\i -> [ div [ class "row row-compact" ]
    [ div [ class "col single-line muted" ] [ text <| "p" ++ String.fromInt i.id ]
    , div [ class "col col--4 single-line semi-bold" ] [ text i.name ]
    ] ] )
  , key    = .id >> String.fromInt
  }


charSource : SourceConfig m Gen.ApiCharResult
charSource =
  { path   = "/js/char.json"
  , decode  = \x -> case x of
      Gen.CharResult e -> Just e
      _ -> Nothing
  , view    = (\i -> [ div [ class "row row-compact" ]
    [ div [ class "col single-line muted" ] [ text <| "c" ++ String.fromInt i.id ]
    , div [ class "col col--2 single-line semi-bold" ] [ text i.name ]
    , div [ class "col col--2 single-line" ] [ text i.original ]
    ] ] )
  , key    = .id >> String.fromInt
  }


traitSource : SourceConfig m Gen.ApiTraitResult
traitSource =
  { path   = "/js/trait.json"
  , decode  = \x -> case x of
      Gen.TraitResult e -> Just e
      _ -> Nothing
  , view    = (\i -> [ div [ class "row row-compact" ]
    [ div [ class "col single-line muted" ] [ text <| "i" ++ String.fromInt i.id ]
    , div [ class "col col--4 single-line" ]
      [ span [ class "muted" ] [ text <| (Maybe.withDefault "" i.group) ++ " / " ]
      , span [ class "semi-bold" ] [ text i.name ]
      ]
    ] ] )
  , key    = .id >> String.fromInt
  }



type alias Model a =
  { position : Maybe Dom.Element
  , value    : String
  , results  : List a
  , sel      : String
  , loading  : Bool
  , wait     : Int
  }


init : Model a
init =
  { position = Nothing
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
  | Pos (Result Dom.Error Dom.Element)
  | Input String
  | Search Int
  | Key String
  | Sel String
  | Enter a
  | Results String Api.Response


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
    -- 2. If, as a result of the enter key ('Key Enter' message), the input box
    --    position was moved (likely, because the input box is usually below
    --    the data being added), then this blur + focus causes the 'Focus'
    --    message to be triggered again, updating the position of the dropdown
    --    div. Without this hack the div positioning will be incorrect.
    --    (This hack does rely on the view being updated before these tasks
    --    are executed - but the Dom package seems to guarantee this)
    refocus = Dom.blur cfg.id
           |> Task.andThen (always (Dom.focus cfg.id))
           |> Task.attempt (always (cfg.wrap Noop))
  in
  case msg of
    Noop    -> mod model
    Blur    -> mod { model | position = Nothing }
    Focus   -> ({ model | loading = False }, Task.attempt (cfg.wrap << Pos) (Dom.getElement cfg.id), Nothing)
    Pos (Ok p) -> mod { model | position = Just p }
    Pos _   -> mod model
    Sel s   -> mod { model | sel = s }
    Enter r -> (model, refocus, Just r)

    Key "Enter"     -> (model, refocus, List.filter (\i -> cfg.source.key i == model.sel) model.results |> List.head)
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


view : Config m a -> Model a -> List (Attribute m) -> List (Html m)
view cfg model attrs =
  let
    input =
      inputText cfg.id model.value (cfg.wrap << Input)
        [ onFocus <| cfg.wrap Focus
        , onBlur <| cfg.wrap Blur
        , custom "keydown" <| JD.map (\c ->
                 if c == "Enter" || c == "ArrowUp" || c == "ArrowDown"
                 then { preventDefault = True,  stopPropagation = True,  message = cfg.wrap (Key c) }
                 else { preventDefault = False, stopPropagation = False, message = cfg.wrap (Key c) }
            ) <| JD.field "key" JD.string
        ]

    inputDiv = div
      (classList [("form-control-wrap",True), ("form-control-wrap--loading",model.loading)] :: attrs)
      [ input ]

    msg = [("",
        if List.isEmpty model.results
        then b [] [text "No results"]
        else text ""
      )]

    box p =
      Keyed.node "div"
        [ style "top"   <| String.fromFloat (p.element.y + p.element.height) ++ "px"
        , style "left"  <| String.fromFloat p.element.x     ++ "px"
        , style "width" <| String.fromFloat p.element.width ++ "px"
        , class "dropdown-menu dropdown-menu--open"
        ] <| msg ++ List.map item model.results

    item i =
      ( cfg.source.key i
      , a
        [ href "#"
        , classList [("dropdown-menu__item", True), ("dropdown-menu__item--active", cfg.source.key i == model.sel) ]
        , onMouseOver <| cfg.wrap <| Sel <| cfg.source.key i
        , onMouseDown <| cfg.wrap <| Enter i
        ] <| cfg.source.view i
      )

  in
    [ inputDiv
    , case model.position of
        Nothing -> text ""
        Just p ->
          if model.value == "" || (model.loading && List.isEmpty model.results)
          then text ""
          else box p
    ]
