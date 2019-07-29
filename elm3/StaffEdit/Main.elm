module StaffEdit.Main exposing (Model, Msg, main, new, view, update)

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes exposing (..)
import Json.Encode as JE
import Browser
import Browser.Navigation exposing (load)
import Lib.Util exposing (..)
import Lib.Html exposing (..)
import Lib.Gen as Gen
import Lib.Api as Api
import Lib.Editsum as Editsum


main : Program Gen.StaffEdit Model Msg
main = Browser.element
  { init   = \e -> (init e, Cmd.none)
  , view   = view
  , update = update
  , subscriptions = always Sub.none
  }


type alias Model =
  { state       : Api.State
  , editsum     : Editsum.Model
  , alias       : List Gen.StaffEditAlias
  , aliasDup    : Bool
  , aid         : Int
  , desc        : String
  , gender      : String
  , l_site      : String
  , l_wp        : String
  , l_twitter   : String
  , l_anidb     : Maybe Int
  , lang        : String
  , id          : Maybe Int
  }


init : Gen.StaffEdit -> Model
init d =
  { state       = Api.Normal
  , editsum     = { authmod = d.authmod, editsum = d.editsum, locked = d.locked, hidden = d.hidden }
  , alias       = d.alias
  , aliasDup    = False
  , aid         = d.aid
  , desc        = d.desc
  , gender      = d.gender
  , l_site      = d.l_site
  , l_wp        = d.l_wp
  , l_twitter   = d.l_twitter
  , l_anidb     = d.l_anidb
  , lang        = "ja"
  , id          = d.id
  }


new : Model
new =
  { state       = Api.Normal
  , editsum     = Editsum.new
  , alias       = [ { aid = -1, name = "", original = "", inuse = False } ]
  , aliasDup    = False
  , aid         = -1
  , desc        = ""
  , gender      = "unknown"
  , l_site      = ""
  , l_wp        = ""
  , l_twitter   = ""
  , l_anidb     = Nothing
  , lang        = "ja"
  , id          = Nothing
  }


encode : Model -> Gen.StaffEditSend
encode model =
  { editsum     = model.editsum.editsum
  , hidden      = model.editsum.hidden
  , locked      = model.editsum.locked
  , aid         = model.aid
  , alias       = List.map (\e -> { aid = e.aid, name = e.name, original = e.original }) model.alias
  , desc        = model.desc
  , gender      = model.gender
  , l_anidb     = model.l_anidb
  , l_site      = model.l_site
  , l_twitter   = model.l_twitter
  , l_wp        = model.l_wp
  , lang        = model.lang
  }


newAid : Model -> Int
newAid model =
  let id = Maybe.withDefault 0 <| List.minimum <| List.map .aid model.alias
  in if id >= 0 then -1 else id - 1


type Msg
  = Editsum Editsum.Msg
  | Submit
  | Submitted Api.Response
  | Lang String
  | Website String
  | LWP String
  | LTwitter String
  | LAnidb String
  | Desc String
  | AliasDel Int
  | AliasName Int String
  | AliasOrig Int String
  | AliasMain Int Bool
  | AliasAdd


validate : Model -> Model
validate model = { model | aliasDup = hasDuplicates <| List.map (\e -> (e.name, e.original)) model.alias }


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Editsum m  -> ({ model | editsum   = Editsum.update m model.editsum }, Cmd.none)
    Lang s     -> ({ model | lang      = s }, Cmd.none)
    Website s  -> ({ model | l_site    = s }, Cmd.none)
    LWP s      -> ({ model | l_wp      = s }, Cmd.none)
    LTwitter s -> ({ model | l_twitter = s }, Cmd.none)
    LAnidb s   -> ({ model | l_anidb   = if s == "" then Nothing else String.toInt s }, Cmd.none)
    Desc s     -> ({ model | desc      = s }, Cmd.none)

    AliasDel i    -> (validate { model | alias = delidx i model.alias }, Cmd.none)
    AliasName i s -> (validate { model | alias = modidx i (\e -> { e | name     = s }) model.alias }, Cmd.none)
    AliasOrig i s -> (validate { model | alias = modidx i (\e -> { e | original = s }) model.alias }, Cmd.none)
    AliasMain n _ -> ({ model | aid = n }, Cmd.none)
    AliasAdd      -> ({ model | alias = model.alias ++ [{ aid = newAid model, name = "", original = "", inuse = False }] }, Cmd.none)

    Submit ->
      let
        path =
          case model.id of
            Just id -> "/s" ++ String.fromInt id ++ "/edit"
            Nothing -> "/s/add"
        body = Gen.staffeditSendEncode (encode model)
      in ({ model | state = Api.Loading }, Api.post path body Submitted)

    Submitted (Gen.Changed id rev) -> (model, load <| "/s" ++ String.fromInt id ++ "." ++ String.fromInt rev)
    Submitted r -> ({ model | state = Api.Error r }, Cmd.none)


isValid : Model -> Bool
isValid model = not
  (  model.aliasDup
  || List.any (\e -> e.name == "") model.alias
  )


view : Model -> Html Msg
view model =
  let
    nameEntry n e = editListRow ""
      [ editListField 0 ""
        [ inputRadio "main" (e.aid == model.aid) (AliasMain e.aid) ]
      , editListField 1 ""
        [ inputText "" e.name (AliasName n) <| (if e.name == "" then [class "is-invalid"] else []) ++ [placeholder "Name (romaji)"] ]
      , editListField 1 ""
        [ inputText "" e.original (AliasOrig n) [placeholder "Original name"] ]
      , editListField 0 ""
        [ if model.aid == e.aid || e.inuse then text "" else removeButton (AliasDel n) ]
      ]

    names = cardRow "Name(s)" (Just "Selected name = primary name.")
      <| editList (List.indexedMap nameEntry model.alias)
      ++ formGroups (
        (if model.aliasDup
          then [ [ div [ class "invalid-feedback" ]
            [ text "The list contains duplicate aliases." ] ] ]
          else []
        ) ++
        [ [ button [type_ "button", class "btn", tabindex 10, onClick AliasAdd] [ text "Add alias" ] ]
        , [ div [ class "form-group__help" ]
            [ text "Aliases can only be removed if they are not selected as this entry's primary name and if they are not credited in visual novel entries."
            , text " In some cases it happens that an alias can not be removed even when there are no visible credits for it."
            , text " This means that the alias is still credited from a deleted entry. A moderator can fix this for you."
            ]
          ]
        ]
      )

    meta = cardRow "Meta" Nothing <| formGroups
      [ [ label [for "lang"] [ text "Primary language" ]
        , inputSelect [id "lang", name "lang", onInput Lang] model.lang Gen.languages
        ]
      , [ label [for "website"] [ text "Official Website" ]
        , inputText "website" model.l_site Website [pattern Gen.weburlPattern]
        ]
      , [ label [] [ text "Wikipedia" ]
        , p [] [ text "https://en.wikipedia.org/wiki/", inputText "l_wp" model.l_wp LWP [class "form-control--inline", maxlength 100] ]
        ]
      , [ label [] [ text "Twitter username" ]
        , p [] [ text "https://twitter.com/", inputText "l_twitter" model.l_twitter LTwitter [class "form-control--inline", maxlength 100] ]
        ]
      , [ label [] [ text "AniDB creator ID" ]
        , p []
          [ text "https://anidb.net/cr"
          , inputText "l_anidb" (Maybe.withDefault "" (Maybe.map String.fromInt model.l_anidb))
              LAnidb [class "form-control--inline", maxlength 10, pattern "^[0-9]*$"]
          ]
        ]
      ]

    desc = cardRow "Description" (Just "English please!") <| formGroup
      [ inputTextArea "desc" model.desc Desc [rows 8] ]

  in form_ Submit (model.state == Api.Loading)
    [ card "general" "General info" [] [ names, meta, desc ]
    , Html.map Editsum     <| Editsum.view model.editsum
    , submitButton "Submit" model.state (isValid model) False
    ]
