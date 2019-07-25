module CharEdit.Main exposing (Model,Msg,main,new,update,view)

import Html exposing (..)
import Html.Lazy exposing (..)
import Browser
import Browser.Navigation exposing (load)
import Lib.Html exposing (..)
import Lib.Gen exposing (..)
import Lib.Api as Api
import Lib.Editsum as Editsum
import CharEdit.General as General
import CharEdit.Traits as Traits
import CharEdit.VN as VN


main : Program CharEdit Model Msg
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
  , traits      : Traits.Model
  , vn          : VN.Model
  , id          : Maybe Int
  }


init : CharEdit -> Model
init d =
  { state       = Api.Normal
  , editsum     = { authmod = d.authmod, editsum = d.editsum, locked = d.locked, hidden = d.hidden }
  , general     = General.init d
  , traits      = Traits.init d.traits
  , vn          = VN.init d.vns d.vnrels
  , id          = d.id
  }


new : List CharEditVns -> List CharEditVnrels -> Model
new vns vnrels =
  { state       = Api.Normal
  , editsum     = Editsum.new
  , general     = General.new
  , traits      = Traits.init []
  , vn          = VN.init vns vnrels
  , id          = Nothing
  }


encode : Model -> CharEditSend
encode model =
  { editsum     = model.editsum.editsum
  , hidden      = model.editsum.hidden
  , locked      = model.editsum.locked
  , alias       = model.general.alias
  , b_day       = model.general.bDay
  , b_month     = model.general.bMonth
  , bloodt      = model.general.bloodt
  , desc        = model.general.desc
  , gender      = model.general.gender
  , height      = model.general.height
  , image       = model.general.image
  , name        = model.general.name
  , original    = model.general.original
  , s_bust      = model.general.sBust
  , s_hip       = model.general.sHip
  , s_waist     = model.general.sWaist
  , weight      = model.general.weight
  , main        = if not model.general.mainInstance || model.general.mainId == 0 then Nothing else Just model.general.mainId
  , main_spoil  = model.general.mainSpoil
  , traits      = List.map (\e -> { tid = e.tid, spoil = e.spoil }) model.traits.traits
  , vns         = VN.encode model.vn
  }


type Msg
  = Editsum Editsum.Msg
  | General General.Msg
  | Traits Traits.Msg
  | VN VN.Msg
  | Submit
  | Submitted Api.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Editsum m -> ({ model | editsum = Editsum.update m model.editsum }, Cmd.none)
    General m -> let (nm, c) = General.update m model.general in ({ model | general = nm }, Cmd.map General c)
    Traits m  -> let (nm, c) = Traits.update  m model.traits  in ({ model | traits  = nm }, Cmd.map Traits  c)
    VN m      -> let (nm, c) = VN.update      m model.vn      in ({ model | vn      = nm }, Cmd.map VN      c)

    Submit ->
      let
        path =
          case model.id of
            Just id -> "/c" ++ String.fromInt id ++ "/edit"
            Nothing -> "/c/add"
        body = chareditSendEncode (encode model)
      in ({ model | state = Api.Loading }, Api.post path body Submitted)

    Submitted (Api.Changed id rev) -> (model, load <| "/c" ++ String.fromInt id ++ "." ++ String.fromInt rev)
    Submitted r -> ({ model | state = Api.Error r }, Cmd.none)


isValid : Model -> Bool
isValid model = not
  (  model.general.aliasDuplicates
  || (model.general.mainInstance && model.general.mainId == 0)
  || model.traits.duplicates
  || model.vn.duplicates
  )


view : Model -> Html Msg
view model =
  form_ Submit (model.state == Api.Loading)
    [ Html.map General   <| lazy General.view model.general
    , Html.map Traits    <| lazy Traits.view  model.traits
    , Html.map VN        <| lazy VN.view      model.vn
    , Html.map Editsum   <| lazy Editsum.view model.editsum
    , submitButton "Submit" model.state (isValid model) False
    ]
