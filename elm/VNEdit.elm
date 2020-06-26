module VNEdit exposing (main)

import Html exposing (..)
import Html.Events exposing (..)
import Html.Keyed as K
import Html.Attributes exposing (..)
import Browser
import Browser.Navigation exposing (load)
import Dict
import Set
import File exposing (File)
import File.Select as FSel
import Lib.Util exposing (..)
import Lib.Html exposing (..)
import Lib.TextPreview as TP
import Lib.Autocomplete as A
import Lib.Api as Api
import Lib.Editsum as Editsum
import Gen.VNEdit as GVE
import Gen.Types as GT
import Gen.Api as GApi


main : Program GVE.Recv Model Msg
main = Browser.element
  { init   = \e -> (init e, Cmd.none)
  , view   = view
  , update = update
  , subscriptions = always Sub.none
  }


type Tab
  = General
  | Image
  | Staff
  | Cast
  | Relations
  | Screenshots
  | All

type alias Model =
  { state       : Api.State
  , tab         : Tab
  , editsum     : Editsum.Model
  , title       : String
  , original    : String
  , alias       : String
  , desc        : TP.Model
  , id          : Maybe Int
  }


init : GVE.Recv -> Model
init d =
  { state       = Api.Normal
  , tab         = General
  , editsum     = { authmod = d.authmod, editsum = TP.bbcode d.editsum, locked = d.locked, hidden = d.hidden }
  , title       = d.title
  , original    = d.original
  , alias       = d.alias
  , desc        = TP.bbcode d.desc
  , id          = d.id
  }


encode : Model -> GVE.Send
encode model =
  { id          = model.id
  , editsum     = model.editsum.editsum.data
  , hidden      = model.editsum.hidden
  , locked      = model.editsum.locked
  , title       = model.title
  , original    = model.original
  , alias       = model.alias
  , desc        = model.desc.data
  }

type Msg
  = Editsum Editsum.Msg
  | Tab Tab
  | Submit
  | Submitted GApi.Response
  | Title String
  | Original String
  | Alias String
  | Desc TP.Msg


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Editsum m  -> let (nm,nc) = Editsum.update m model.editsum in ({ model | editsum = nm }, Cmd.map Editsum nc)
    Tab t      -> ({ model | tab = t }, Cmd.none)
    Title s    -> ({ model | title = s }, Cmd.none)
    Original s -> ({ model | original = s }, Cmd.none)
    Alias s    -> ({ model | alias = s }, Cmd.none)
    Desc m     -> let (nm,nc) = TP.update m model.desc in ({ model | desc = nm }, Cmd.map Desc nc)

    Submit -> ({ model | state = Api.Loading }, GVE.send (encode model) Submitted)
    Submitted (GApi.Redirect s) -> (model, load s)
    Submitted r -> ({ model | state = Api.Error r }, Cmd.none)


isValid : Model -> Bool
isValid model = not
  (  (model.title /= "" && model.title == model.original)
  )


view : Model -> Html Msg
view model =
  let
    geninfo =
      [ formField "title::Title (romaji)" [ inputText "title" model.title Title GVE.valTitle ]
      , formField "original::Original title"
        [ inputText "original" model.original Title GVE.valOriginal
        , if model.title /= "" && model.title == model.original
          then b [ class "standout" ] [ br [] [], text "Should not be the same as the Title (romaji). Leave blank is the original title is already in the latin alphabet" ]
          else text ""
        ]
      , formField "alias::Aliases"
        [ inputTextArea "alias" model.alias Alias (rows 3 :: GVE.valAlias)
        , br [] []
        , text "List of alternative titles or abbreviations. One line for each alias. Can include both official (japanese/english) titles and unofficial titles used around net."
        , br [] []
        , text "Titles that are listed in the releases should not be added here!"
        -- TODO: Compare & warn when release title is listed as alias
        ]
      , formField "desc::Description"
        [ TP.view "desc" model.desc Desc 600 (style "height" "180px" :: GVE.valDesc) [ b [ class "standout" ] [ text "English please!" ] ]
        , text "Short description of the main story. Please do not include spoilers, and don't forget to list the source in case you didn't write the description yourself."
        ]
      ]

  in
  form_ Submit (model.state == Api.Loading)
  [ div [ class "maintabs left" ]
    [ ul []
      [ li [ classList [("tabselected", model.tab == General    )] ] [ a [ href "#", onClickD (Tab General    ) ] [ text "General info" ] ]
      , li [ classList [("tabselected", model.tab == Image      )] ] [ a [ href "#", onClickD (Tab Image      ) ] [ text "Image"        ] ]
      , li [ classList [("tabselected", model.tab == Staff      )] ] [ a [ href "#", onClickD (Tab Staff      ) ] [ text "Staff"        ] ]
      , li [ classList [("tabselected", model.tab == Cast       )] ] [ a [ href "#", onClickD (Tab Cast       ) ] [ text "Cast"         ] ]
      , li [ classList [("tabselected", model.tab == Relations  )] ] [ a [ href "#", onClickD (Tab Relations  ) ] [ text "Relations"    ] ]
      , li [ classList [("tabselected", model.tab == Screenshots)] ] [ a [ href "#", onClickD (Tab Screenshots) ] [ text "Screenshots"  ] ]
      , li [ classList [("tabselected", model.tab == All        )] ] [ a [ href "#", onClickD (Tab All        ) ] [ text "All items"    ] ]
      ]
    ]
  , div [ class "mainbox", classList [("hidden", model.tab /= General     && model.tab /= All)] ] [ h1 [] [ text "General info" ], table [ class "formtable" ] geninfo ]
  , div [ class "mainbox", classList [("hidden", model.tab /= Image       && model.tab /= All)] ] [ h1 [] [ text "Image" ] ]
  , div [ class "mainbox", classList [("hidden", model.tab /= Staff       && model.tab /= All)] ] [ h1 [] [ text "Staff" ] ]
  , div [ class "mainbox", classList [("hidden", model.tab /= Cast        && model.tab /= All)] ] [ h1 [] [ text "Cast" ] ]
  , div [ class "mainbox", classList [("hidden", model.tab /= Relations   && model.tab /= All)] ] [ h1 [] [ text "Relations" ] ]
  , div [ class "mainbox", classList [("hidden", model.tab /= Screenshots && model.tab /= All)] ] [ h1 [] [ text "Screenshots" ] ]
  , div [ class "mainbox" ] [ fieldset [ class "submit" ]
      [ Html.map Editsum (Editsum.view model.editsum)
      , submitButton "Submit" model.state (isValid model)
      ]
    ]
  ]
