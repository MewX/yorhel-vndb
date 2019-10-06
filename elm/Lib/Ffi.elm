-- Elm 0.19: "We've removed all Native modules and plugged all XSS vectors,
--            it's now impossible to talk with Javascript other than with ports!"
-- Me: "Oh yeah? I'll just run sed over the generated Javascript!"

-- This module is a hack to work around the lack of an FFI (Foreign Function
-- Interface) in Elm. The functions in this module are stubs, their
-- implementations are replaced by the Makefile with calls to
-- window.elmFfi_<name> and the actual implementations are in 1-ffi.js.
--
-- Use sparingly, all of this will likely break in future Elm versions.
module Lib.Ffi exposing (..)

import Html exposing (Attribute)
import Html.Attributes exposing (title)

-- Set the innerHTML attribute of a node
innerHtml : String -> Attribute msg
innerHtml = always (title "")
