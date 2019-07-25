module ProdEdit.New exposing (main)

import Browser
import ProdEdit.Main as Main

main : Program () Main.Model Main.Msg
main = Browser.element
  { init   = always (Main.new, Cmd.none)
  , view   = Main.view
  , update = Main.update
  , subscriptions = always Sub.none
  }
