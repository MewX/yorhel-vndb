module ProdEdit.Main exposing (Model, Msg, main, new, view, update)

import Html exposing (..)
import Html.Attributes exposing (..)
import Json.Encode as JE
import Browser
import Browser.Navigation exposing (load)
import Lib.Util exposing (splitLn)
import Lib.Html exposing (..)
import Lib.Gen as Gen
import Lib.Api as Api
import Lib.Editsum as Editsum
import ProdEdit.Names as Names
import ProdEdit.General as General
import ProdEdit.Relations as Rel


main : Program Gen.ProdEdit Model Msg
main = Browser.element
  { init   = \e -> (init e, Cmd.none)
  , view   = view
  , update = update
  , subscriptions = always Sub.none
  }


type alias Model =
  { state       : Api.State
  , new         : Bool
  , editsum     : Editsum.Model
  , names       : Names.Model
  , general     : General.Model
  , relations   : Rel.Model
  , id          : Maybe Int
  , dupProds    : List Gen.ApiProducerResult
  }


init : Gen.ProdEdit -> Model
init d =
  { state       = Api.Normal
  , new         = False
  , editsum     = { authmod = d.authmod, editsum = d.editsum, locked = d.locked, hidden = d.hidden }
  , names       = Names.init d
  , general     = General.init d
  , relations   = Rel.init d.relations
  , id          = d.id
  , dupProds    = []
  }


new : Model
new =
  { state       = Api.Normal
  , new         = True
  , editsum     = Editsum.new
  , names       = Names.new
  , general     = General.new
  , relations   = Rel.init []
  , id          = Nothing
  , dupProds    = []
  }


encode : Model -> Gen.ProdEditSend
encode model =
  { editsum     = model.editsum.editsum
  , hidden      = model.editsum.hidden
  , locked      = model.editsum.locked
  , name        = model.names.name
  , original    = model.names.original
  , alias       = model.names.alias
  , desc        = model.general.desc
  , lang        = model.general.lang
  , ptype       = model.general.ptype
  , l_wp        = model.general.l_wp
  , website     = model.general.website
  , relations   = List.map (\e -> { pid = e.pid, relation = e.relation }) model.relations.relations
  }


type Msg
  = Editsum Editsum.Msg
  | Submit
  | Submitted Api.Response
  | Names Names.Msg
  | General General.Msg
  | Relations Rel.Msg
  | CheckDup
  | RecvDup Api.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Names   m -> ({ model | names   = Names.update   m model.names, dupProds = [] }, Cmd.none)
    General m -> ({ model | general = General.update m model.general }, Cmd.none)
    Editsum m -> ({ model | editsum = Editsum.update m model.editsum }, Cmd.none)
    Relations m -> let (nm, c) = Rel.update m model.relations in ({ model | relations = nm }, Cmd.map Relations c)

    Submit ->
      let
        path =
          case model.id of
            Just id -> "/p" ++ String.fromInt id ++ "/edit"
            Nothing -> "/p/add"
        body = Gen.prodeditSendEncode (encode model)
      in ({ model | state = Api.Loading }, Api.post path body Submitted)

    Submitted (Gen.Changed id rev) -> (model, load <| "/p" ++ String.fromInt id ++ "." ++ String.fromInt rev)
    Submitted r -> ({ model | state = Api.Error r }, Cmd.none)

    CheckDup ->
      let body = JE.object
            [ ("search", JE.list JE.string <| List.filter ((/=)"") <| model.names.name :: model.names.original :: model.names.aliasList)
            , ("hidden", JE.bool True) ]
      in
        if List.isEmpty model.dupProds
        then ({ model | state = Api.Loading }, Api.post "/js/producer.json" body RecvDup)
        else ({ model | new = False }, Cmd.none)

    RecvDup (Gen.ProducerResult dup) ->
      ({ model | state = Api.Normal, dupProds = dup, new = not (List.isEmpty dup) }, Cmd.none)
    RecvDup r -> ({ model | state = Api.Error r }, Cmd.none)



isValid : Model -> Bool
isValid model = not
  (  model.names.aliasDuplicates
  || model.relations.duplicates
  )


view : Model -> Html Msg
view model =
  if model.new
  then form_ CheckDup (model.state == Api.Loading)
    [ card "new" "Add a new producer" []
      <| List.map (Html.map Names) <| Names.view model.names
    , if List.isEmpty model.dupProds
      then text ""
      else card "dup" "Possible duplicates" [ div [ class "card__subheading" ] [ text "Please check the list below for possible duplicates." ] ]
        [ cardRow "" Nothing <| formGroup [ div [ class "form-group__help" ] [
          ul [] <| List.map (\e ->
            li [] [ a [ href <| "/p" ++ String.fromInt e.id, title e.original, target "_black" ] [ text e.name ]
                  , text <| if e.hidden then " (deleted)" else "" ]
          ) model.dupProds
        ] ] ]
    , submitButton "Continue" model.state (isValid model) False
    ]

  else form_ Submit (model.state == Api.Loading)
    [ General.view model.general General <| List.map (Html.map Names) <| Names.view model.names
    , Html.map Relations   <| Rel.view     model.relations
    , Html.map Editsum     <| Editsum.view model.editsum
    , submitButton "Submit" model.state (isValid model) False
    ]
