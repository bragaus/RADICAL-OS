------------------------------------------------------------------------------------------
-- src/tools/icons.lua — PERMANENT re-export shim of src/atoms/icon.lua.                  --
--                                                                                        --
-- The SVG loader moved to the atoms layer. This shim keeps every existing consumer that   --
-- does `local Icon = require("src.tools.icons")` working unchanged: atoms/icon is         --
-- callable as the legacy Icon(name, opts) (string first arg -> natural size when size is   --
-- omitted, exactly as before) as well as the atom form icon{ name=, color=, size= }.      --
-- Retiring this shim would be a coordinated consumer sweep — out of scope; keep it.        --
------------------------------------------------------------------------------------------

return require("src.atoms.icon")
