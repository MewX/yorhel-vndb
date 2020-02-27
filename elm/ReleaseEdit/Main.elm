module ReleaseEdit.Main exposing (Model, Msg, main, view, update)

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes exposing (..)
import Browser
import Browser.Navigation exposing (load)
import Set
import Lib.Util exposing (..)
import Lib.Html exposing (..)
import Lib.TextPreview as TP
import Lib.Api as Api
import Lib.Editsum as Editsum
import Gen.ReleaseEdit as GRE
import Gen.Types as GT
import Gen.Api as GApi
import ReleaseEdit.General as RG


main : Program GRE.Recv Model Msg
main = Browser.element
  { init   = \e -> (init e, Cmd.none)
  , view   = view
  , update = update
  , subscriptions = \m -> Sub.map General (RG.sub m.general)
  }


type alias Model =
  { state       : Api.State
  , editsum     : Editsum.Model
  , general     : RG.Model
  , id          : Maybe Int
  }


init : GRE.Recv -> Model
init d =
  { state       = Api.Normal
  , editsum     = { authmod = d.authmod, editsum = TP.bbcode d.editsum, locked = d.locked, hidden = d.hidden }
  , general     = RG.init d
  , id          = d.id
  }


encode : Model -> GRE.Send
encode model =
  { id          = model.id
  , editsum     = model.editsum.editsum.data
  , hidden      = model.editsum.hidden
  , locked      = model.editsum.locked
  , title       = model.general.title
  , original    = model.general.original
  , rtype       = model.general.rtype
  , patch       = model.general.patch
  , freeware    = model.general.freeware
  , doujin      = model.general.doujin
  , lang        = List.map (\l -> {lang=l    }) <| Set.toList model.general.lang
  , platforms   = List.map (\l -> {platform=l}) <| Set.toList model.general.plat
  , media       = model.general.media
  , gtin        = model.general.gtin
  , catalog     = model.general.catalog
  , released    = model.general.released
  , minage      = model.general.minage
  , uncensored  = model.general.uncensored
  , resolution  = model.general.resolution
  , voiced      = model.general.voiced
  , ani_story   = model.general.ani_story
  , ani_ero     = model.general.ani_ero
  , website     = model.general.website
  , engine      = model.general.engine.value
  , extlinks    = model.general.extlinks.links
  }


type Msg
  = Editsum Editsum.Msg
  | General RG.Msg
  | Submit
  | Submitted GApi.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Editsum m  -> let (nm,nc) = Editsum.update m model.editsum in ({ model | editsum = nm }, Cmd.map Editsum nc)
    General m  -> let (nm,nc) = RG.update      m model.general in ({ model | general = nm }, Cmd.map General nc)

    Submit -> ({ model | state = Api.Loading }, GRE.send (encode model) Submitted)
    Submitted (GApi.Redirect s) -> (model, load s)
    Submitted r -> ({ model | state = Api.Error r }, Cmd.none)


isValid : Model -> Bool
isValid model = RG.isValid model.general


view : Model -> Html Msg
view model =
  form_ Submit (model.state == Api.Loading)
  [ div [ class "mainbox" ]
    [ h1 [] [ text "General info" ]
    , Html.map General (RG.view model.general)
    ]
  , div [ class "mainbox" ]
    [ fieldset [ class "submit" ]
      [ Html.map Editsum (Editsum.view model.editsum)
      , submitButton "Submit" model.state (isValid model)
      ]
    ]
  ]
