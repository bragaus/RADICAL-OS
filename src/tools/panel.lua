------------------------------------------------------------------------------------------
-- src/tools/panel.lua — PERMANENT re-export shim.                                         --
--                                                                                        --
-- panel.lua was promoted to a molecule (git mv -> src/molecules/panel.lua). This shim     --
-- keeps every existing `require("src.tools.panel")` consumer working unchanged; both      --
-- call forms survive it (panel(opts) via __call and panel.build(opts)) because it         --
-- returns the SAME table. Retiring it would require a coordinated consumer sweep, which    --
-- is intentionally out of scope — this shim is permanent.                                 --
------------------------------------------------------------------------------------------

return require("src.molecules.panel")
