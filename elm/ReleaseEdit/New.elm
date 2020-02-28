module ReleaseEdit.New exposing (main)

import Browser
import ReleaseEdit.Main as Main
import Gen.ReleaseEdit as GRE

main : Program GRE.New Main.Model Main.Msg
main = Browser.element
  { init   = \n -> (Main.new n, Cmd.none)
  , view   = Main.view
  , update = Main.update
  , subscriptions = Main.sub
  }
