module RelEdit.Main exposing (..)

import Html exposing (..)
import Browser
import Browser.Navigation exposing (load)
import Lib.Html exposing (..)
import Lib.Gen exposing (..)
import Lib.Api as Api
import Lib.Editsum as Editsum
import RelEdit.General as General
import RelEdit.Producers as Producers
import RelEdit.Vn as Vn


main : Program RelEdit Model Msg
main = Browser.element
  { init   = \e -> (init e, Cmd.none)
  , view   = view
  , update = update
  , subscriptions = always Sub.none
  }


type alias Model =
  { state       : Api.State
  , editsum     : Editsum.Model
  , general     : General.Model
  , producers   : Producers.Model
  , vn          : Vn.Model
  , id          : Maybe Int
  }


init : RelEdit -> Model
init d =
  { state       = Api.Normal
  , editsum     = { authmod = d.authmod, editsum = d.editsum, locked = d.locked, hidden = d.hidden }
  , general     = General.init d
  , producers   = Producers.init d.producers
  , vn          = Vn.init d.vn
  , id          = d.id
  }


new : Int -> String -> String -> Model
new vid title orig =
  { state       = Api.Normal
  , editsum     = Editsum.new
  , general     = General.new title orig
  , producers   = Producers.init []
  , vn          = Vn.init [{vid = vid, title = title}]
  , id          = Nothing
  }


encode : Model -> RelEditSend
encode model =
  { editsum     = model.editsum.editsum
  , hidden      = model.editsum.hidden
  , locked      = model.editsum.locked
  , catalog     = model.general.catalog
  , doujin      = model.general.doujin
  , freeware    = model.general.freeware
  , gtin        = Maybe.withDefault 0 model.general.gtinVal
  , lang        = model.general.lang
  , minage      = model.general.minage
  , notes       = model.general.notes
  , original    = model.general.original
  , patch       = model.general.patch
  , rtype       = model.general.rtype
  , released    = model.general.released
  , title       = model.general.title
  , uncensored  = model.general.uncensored
  , website     = model.general.website
  , resolution  = model.general.resolution
  , voiced      = model.general.voiced
  , ani_story   = model.general.aniStory
  , ani_ero     = model.general.aniEro
  , platforms   = model.general.platforms
  , media       = model.general.media
  , producers   = List.map (\e -> { pid = e.pid, developer = e.developer, publisher = e.publisher }) model.producers.producers
  , vn          = List.map (\e -> { vid = e.vid }) model.vn.vn
  }


type Msg
  = Editsum Editsum.Msg
  | General General.Msg
  | Producers Producers.Msg
  | Vn Vn.Msg
  | Submit
  | Submitted Api.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Editsum m -> ({ model | editsum = Editsum.update m model.editsum }, Cmd.none)
    General m -> ({ model | general = General.update m model.general }, Cmd.none)
    Producers m -> let (nm, c) = Producers.update m model.producers in ({ model | producers = nm }, Cmd.map Producers c)
    Vn        m -> let (nm, c) = Vn.update m        model.vn        in ({ model | vn        = nm }, Cmd.map Vn        c)

    Submit ->
      let
        path =
          case model.id of
            Just id -> "/r" ++ String.fromInt id ++ "/edit"
            Nothing -> "/r/add"
        body = releditSendEncode (encode model)
      in ({ model | state = Api.Loading }, Api.post path body Submitted)

    Submitted (Api.Changed id rev) -> (model, load <| "/r" ++ String.fromInt id ++ "." ++ String.fromInt rev)
    Submitted r -> ({ model | state = Api.Error r }, Cmd.none)


isValid : Model -> Bool
isValid model = not
  (  List.isEmpty model.general.lang
  || model.general.gtinVal == Nothing
  || model.producers.duplicates
  || model.vn.duplicates
  || List.isEmpty model.vn.vn
  )


view : Model -> Html Msg
view model =
  form_ Submit (model.state == Api.Loading)
    [ Html.map General   <| General.general   model.general
    , Html.map General   <| General.format    model.general
    , card "relations" "Relations" []
      [ Html.map Producers <| Producers.view model.producers
      , Html.map Vn        <| Vn.view        model.vn
      ]
    , Html.map Editsum   <| Editsum.view   model.editsum
    , submitButton "Submit" model.state (isValid model) False
    ]
