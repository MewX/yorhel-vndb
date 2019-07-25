module CharEdit.New exposing (main)

import Browser
import Lib.Gen exposing (CharEditVnrels, CharEditVns)
import CharEdit.Main as Main


type alias Flags =
  { vnrels : List CharEditVnrels
  , vns    : List CharEditVns
  }

main : Program Flags Main.Model Main.Msg
main = Browser.element
  { init   = \f -> (Main.new f.vns f.vnrels, Cmd.none)
  , view   = Main.view
  , update = Main.update
  , subscriptions = always Sub.none
  }
