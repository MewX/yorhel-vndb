module Reviews.Edit exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Browser
import Browser.Navigation exposing (load)
import Lib.Html exposing (..)
import Lib.TextPreview as TP
import Lib.Api as Api
import Lib.Util exposing (..)
import Lib.RDate as RDate
import Gen.Api as GApi
import Gen.ReviewsEdit as GRE
import Gen.ReviewsDelete as GRD


maxChars = 700

main : Program GRE.Recv Model Msg
main = Browser.element
  { init   = \e -> (init e, Cmd.none)
  , view   = view
  , update = update
  , subscriptions = always Sub.none
  }


type alias Model =
  { state       : Api.State
  , id          : Maybe String
  , vid         : Int
  , vntitle     : String
  , rid         : Maybe Int
  , spoiler     : Bool
  , full        : Bool
  , summary     : TP.Model
  , text        : TP.Model
  , releases    : List GRE.RecvReleases
  , delete      : Bool
  , delState    : Api.State
  }


init : GRE.Recv -> Model
init d =
  { state       = Api.Normal
  , id          = d.id
  , vid         = d.vid
  , vntitle     = d.vntitle
  , rid         = d.rid
  , spoiler     = d.spoiler
  , full        = d.text /= ""
  , summary     = TP.bbcode d.summary
  , text        = TP.bbcode d.text
  , releases    = d.releases
  , delete      = False
  , delState    = Api.Normal
  }


encode : Model -> GRE.Send
encode m =
  { id          = m.id
  , vid         = m.vid
  , rid         = m.rid
  , spoiler     = m.spoiler
  , summary     = m.summary.data
  , text        = if m.full then m.text.data else ""
  }


type Msg
  = Release (Maybe Int)
  | Full Bool
  | Spoiler Bool
  | Summary TP.Msg
  | Text TP.Msg
  | Submit
  | Submitted GApi.Response
  | Delete Bool
  | DoDelete
  | Deleted GApi.Response


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Release i  -> ({ model | rid      = i }, Cmd.none)
    Full b     -> ({ model | full     = b }, Cmd.none)
    Spoiler b  -> ({ model | spoiler  = b }, Cmd.none)
    Summary m  -> let (nm,nc) = TP.update m model.summary in ({ model | summary = nm }, Cmd.map Summary nc)
    Text m     -> let (nm,nc) = TP.update m model.text    in ({ model | text    = nm }, Cmd.map Text    nc)

    Submit -> ({ model | state = Api.Loading }, GRE.send (encode model) Submitted)
    Submitted (GApi.Redirect s) -> (model, load s)
    Submitted r -> ({ model | state = Api.Error r }, Cmd.none)

    Delete b   -> ({ model | delete   = b }, Cmd.none)
    DoDelete -> ({ model | delState = Api.Loading }, GRD.send ({ id = Maybe.withDefault "" model.id }) Deleted)
    Deleted GApi.Success -> (model, load <| "/v" ++ String.fromInt model.vid)
    Deleted r -> ({ model | delState = Api.Error r }, Cmd.none)


showrel r = "[" ++ (RDate.format (RDate.expand r.released)) ++ " " ++ (String.join "," r.lang) ++ "] " ++ r.title ++ " (r" ++ String.fromInt r.id ++ ")"

view : Model -> Html Msg
view model =
  form_ Submit (model.state == Api.Loading)
  [ div [ class "mainbox" ]
    [ h1 [] [ text <| if model.id == Nothing then "Submit a review" else "Edit review" ]
    , table [ class "formtable" ]
      [ formField "Subject" [ a [ href <| "/v"++String.fromInt model.vid ] [ text model.vntitle ] ]
      , formField ""
        [ inputSelect "" model.rid Release [style "width" "500px" ] <|
          (Nothing, "No release selected")
          :: List.map (\r -> (Just r.id, showrel r)) model.releases
          ++ if model.rid == Nothing || List.any (\r -> Just r.id == model.rid) model.releases then [] else [(model.rid, "Deleted or moved release: r"++Maybe.withDefault "" (Maybe.map String.fromInt model.rid))]
        , br [] []
        , text "You do not have to select a release, but indicating which release your review is based on gives more context."
        ]
      , tr [ class "newpart" ] [ td [ colspan 2 ] [ text "" ] ]
      , formField "Review type"
        [ label [] [ inputRadio "type" (model.full == False) (\_ -> Full False), b [] [ text " Short review" ]
        , text <| " - Recommendation-style, maximum " ++ String.fromInt maxChars ++ " characters." ]
        , br [] []
        , label [] [ inputRadio "type" (model.full == True ) (\_ -> Full True ), b [] [ text " Full review" ]
        , text " - Longer, more detailed." ]
        , if not model.full && model.text.data /= ""
          then span [] [ br [] [], b [ class "standout" ] [ text "Warning: " ], text "existing content from the \"Full review\" mode will be lost when saving this form." ]
          else text ""
        , br [] []
        , b [ class "grayedout" ] [ text "You can always switch between review types later." ]
        ]
      , tr [ class "newpart" ] [ td [ colspan 2 ] [ text "" ] ]
      , formField ""
        [ label [] [ inputCheck "" model.spoiler Spoiler, text " This review contains spoilers." ]
        , br [] []
        , b [ class "grayedout" ] [ text "You do not have to check this option if all spoilers in your review are marked with [spoiler] tags." ]
        ]
      , tr [ class "newpart" ] [ td [ colspan 2 ] [ text "" ] ]
      , formField (if model.full then "sum::Summary" else "sum::Review")
        [ TP.view "sum" model.summary Summary 700 ([rows 5, cols 50] ++ GRE.valSummary)
          [ a [ href "/d9#3" ] [ text "BBCode formatting supported" ] ]
        , div [ style "width" "700px", style "text-align" "right" ]
          [ let
              len = String.length model.summary.data
              lbl = String.fromInt len ++ "/" ++ String.fromInt maxChars
            in if len > maxChars then b [ class "standout" ] [ text lbl ] else text lbl
          ]
        ]
      , if not model.full then text "" else
        formField "text::Full review"
        [ TP.view "text" model.text Text 700 ([rows 15, cols 50, required True] ++ GRE.valText)
          [ a [ href "/d9#3" ] [ text "BBCode formatting supported" ] ]
        ]
      ]
    ]
  , div [ class "mainbox" ]
    [ fieldset [ class "submit" ]
      [ submitButton "Submit" model.state (String.length model.summary.data <= maxChars)
      ]
    ]
  , if model.id == Nothing then text "" else
    div [ class "mainbox" ]
    [ h1 [] [ text "Delete review" ]
    , table [ class "formtable" ] [ formField ""
      [ label [] [ inputCheck "" model.delete Delete, text " Delete this review." ]
      , if not model.delete then text "" else span []
        [ br [] []
        , b [ class "standout" ] [ text "WARNING:" ]
        , text " Deleting this review is a permanent action and can not be reverted!"
        , br [] []
        , br [] []
        , inputButton "Confirm delete" DoDelete []
        , case model.delState of
            Api.Loading -> span [ class "spinner" ] []
            Api.Error e -> b [ class "standout" ] [ text <| Api.showResponse e ]
            Api.Normal  -> text ""
        ]
      ] ]
    ]
  ]
