module RelEdit.New exposing (main)

import Browser
import RelEdit.Main as Main


type alias Flags =
  { id       : Int
  , title    : String
  , original : String
  }

main : Program Flags Main.Model Main.Msg
main = Browser.element
  { init   = \f -> (Main.new f.id f.title f.original, Cmd.none)
  , view   = Main.view
  , update = Main.update
  , subscriptions = always Sub.none
  }
