-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.pack.cmake" },
  { import = "astrocommunity.pack.json" },
  { import = "astrocommunity.pack.yaml" },
  -- only the language server: the full python pack adds black/isort, which would rewrite
  -- the project's shared scripts on save, and a test adapter that scans the whole repo
  { import = "astrocommunity.pack.python.basedpyright" },
  -- import/override with your plugins folder
  { import = "astrocommunity.file-explorer.oil-nvim", enabled = true },
  { import = "astrocommunity.colorscheme.tokyonight-nvim", enabled = true },
  { import = "astrocommunity.motion.leap-nvim" },
  { import = "astrocommunity.motion.mini-surround" },
  { import = "astrocommunity.motion.mini-ai" },
  { import = "astrocommunity.test.neotest" },
}
