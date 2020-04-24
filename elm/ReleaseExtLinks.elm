-- Helper for VNWeb::Releases::Lib::release_extlinks_()
module ReleaseExtLinks exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Browser
import Lib.Api as Api
import Lib.DropDown as DD

type alias Links = List (String, String, Maybe String)
type alias Model = { lnk : Links, dd : DD.Config Bool }

main : Program (String,Links) Model Bool
main = Browser.element
  { init   = \(id,l) ->
      let dd = DD.init ("relextlink_"++id) identity
      in ({ lnk = l, dd = { dd | hover = True }  }, Cmd.none)
  , view   = view
  , update = \b m -> ({ m | dd = DD.toggle m.dd b }, Cmd.none)
  , subscriptions = \model -> DD.sub model.dd
  }

view : Model -> Html Bool
view model =
  div [ class "elm_dd_noarrow", class "elm_dd_left", class "elm_dd_relextlink" ]
  [ DD.view model.dd Api.Normal
    (span [ class "fake_link" ] [ text <|  String.fromInt (List.length model.lnk), abbr [ class "icons external", title "External link" ] [] ])
    (\_ -> [ ul [ class "rllinks_dd" ] <| List.map (\(lbl,url,price) ->
      li [] [ a [ href url ] [ Maybe.withDefault (text "") (Maybe.map (\p -> span [] [ text p ]) price), text lbl ] ]
    ) model.lnk ])
  ]
