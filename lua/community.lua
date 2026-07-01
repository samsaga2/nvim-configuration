-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  { import = "astrocommunity.pack.lua" },
  -- import/override with your plugins folder
  { import = "astrocommunity.file-explorer.oil", enabled = true },
  { import = "astrocommunity.colorscheme.tokyoknight", enabled = true },
  { import = "astrocommunity.completion.codeium-nvim" },
}
