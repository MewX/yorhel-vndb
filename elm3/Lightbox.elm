port module Lightbox exposing (main)

-- TODO: Display quick-select thumbnails below the image if there's enough room?
-- TODO: The first image in a gallery is not aligned properly
-- TODO: Indicate which images are NSFW

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Array
import Task
import List
import Browser
import Browser.Events as EV
import Browser.Dom as DOM
import Json.Decode as JD
import Lib.Html exposing (..)


main : Program () (Maybe Model) Msg
main = Browser.element
  { init   = always (Nothing, Cmd.none)
  , view   = view
  , update = update
  , subscriptions = \m ->
      if m == Nothing
      then open Open
      else Sub.batch
        [ EV.onResize Resize
        , EV.onKeyDown <| JD.map Keydown <| JD.field "key" JD.string
        , preloaded Preloaded
        ]
  }

port close : Bool -> Cmd msg
port open : (Model -> msg) -> Sub msg
port preload : String -> Cmd msg
port preloaded : (String -> msg) -> Sub msg

type alias Release =
  { id     : Int
  , title  : String
  , lang   : List String
  , plat   : List String
  }

type alias Image =
  { thumb  : String
  , full   : String
  , width  : Int
  , height : Int
  , load   : Bool
  , rel    : Maybe Release
  }

type alias Model =
  { images  : Array.Array Image
  , current : Int
  , width   : Int
  , height  : Int
  }

type Msg
  = Noop
  | Next
  | Prev
  | Open Model
  | Close
  | Resize Int Int
  | Viewport DOM.Viewport
  | Preloaded String
  | Keydown String


setPreload : Model -> Cmd Msg
setPreload model =
  let cmd n =
        case Array.get (model.current+n) model.images of
          Nothing -> Cmd.none
          Just i -> if i.load then Cmd.none else preload i.full
  in if cmd 0 /= Cmd.none then cmd 0 else Cmd.batch [cmd -1, cmd 1]


update_ : Msg -> Model -> (Model, Cmd Msg)
update_ msg model =
  let move n = 
        case Array.get (model.current+n) model.images of
          Nothing -> (model, Cmd.none)
          Just i -> let m = { model | current = model.current+n } in (m, setPreload m)
  in
  case msg of
    Noop                 -> (model, Cmd.none)
    Next                 -> move 1
    Prev                 -> move -1
    Keydown "ArrowLeft"  -> move -1
    Keydown "ArrowRight" -> move 1
    Keydown _            -> (model, Cmd.none)
    Resize width height  -> ({ model | width = width,                  height = height                  }, Cmd.none)
    Viewport v           -> ({ model | width = round v.viewport.width, height = round v.viewport.height }, Cmd.none)
    Preloaded url ->
      let m = { model | images = Array.map (\img -> if img.full == url then { img | load = True } else img) model.images }
      in (m, setPreload m)
    _ -> (model, Cmd.none)


update : Msg -> Maybe Model -> (Maybe Model, Cmd Msg)
update msg model =
  case (msg, model) of
    (Open m          , _) -> ( Just m
                             , Cmd.batch [setPreload m, Task.perform Viewport DOM.getViewport]
                             )
    (Close           , _) -> (Nothing, close True)
    (Keydown "Escape", _) -> (Nothing, close True)
    (_               , Just m) -> let (newm, cmd) = update_ msg m in (Just newm, cmd)
    _ -> (model, Cmd.none)



view_ : Model -> Html Msg
view_ model =
  let
    -- 'onClick' with stopPropagation and preventDefault
    onClickN action = custom "click" (JD.succeed { message = action, stopPropagation = True, preventDefault = True})
    -- 'onClick' with stopPropagation
    onClickP action = custom "click" (JD.succeed { message = action, stopPropagation = True, preventDefault = False})

    -- Maximum image dimensions
    awidth  = toFloat model.width * 0.84
    aheight = toFloat model.height - 80

    full_img action position i =
      -- Scale image down to fit inside awidth/aheight
      let swidth  = awidth  / toFloat i.width
          sheight = aheight / toFloat i.height
          scale   = Basics.min 1 <| if swidth < sheight then swidth else sheight
          iwidth  = round <| scale * toFloat i.width
          iheight = round <| scale * toFloat i.height
          cwidth  = style "width"  <| String.fromInt iwidth  ++ "px"
          cheight = style "height" <| String.fromInt iheight ++ "px"
          imgsrc  = if i.load then i.full else i.thumb
      in
      a [ href "#", onClickN action, cheight
        , class <| "lightbox__image lightbox__image-" ++ position ]
        [ img [ class "lightbox__img", src imgsrc, cwidth, cheight ] [] ]

    full offset action position =
      case Array.get (model.current + offset) model.images of
        Nothing -> text ""
        Just i -> full_img action position i

    meta img = div [ class "lightbox__meta", onClickP Noop ] <|
      [ a [ href img.full, class "lightbox__dims" ] [ text <| String.fromInt img.width ++ "x" ++ String.fromInt img.height ]
      ] ++ relMeta img.rel

    relMeta r = case r of
      Nothing  -> []
      Just rel ->
           (List.map iconPlatform rel.plat)
        ++ (List.map iconLanguage rel.lang)
        ++ [ a [ href ("/r" ++ String.fromInt rel.id) ] [ text rel.title ] ]

    container img = div [ class "lightbox", onClick Close ]
      [ a [ href "#", onClickN Close, class "lightbox__close" ] []
      , full -1 Prev  "left"
      , full  0 Close "current"
      , full  1 Next  "right"
      , meta img
      ]

  in case Array.get model.current model.images of
    Just img -> container img
    Nothing  -> text ""


view : (Maybe Model) -> Html Msg
view m = case m of
  Just mod -> view_ mod
  Nothing  -> text ""
