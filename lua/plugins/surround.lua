-- vim-surround style keys for mini.surround (ys / ds / cs, S in visual) instead
-- of the community pack's longer gz* prefix.
---@type LazySpec
return {
  {
    "AstroNvim/astrocore",
    opts = {
      mappings = {
        n = { ["gz"] = false }, -- the pack's group label, no longer used
        x = { ["S"] = false }, -- leap-backward in visual gives way to "surround selection"
      },
    },
  },
  {
    "echasnovski/mini.surround",
    -- replaces the pack's key list, which would also bind `add` in visual mode
    -- (a visual `ys` would make every `y` wait for a second key)
    keys = function()
      return {
        { "ys", desc = "Add surrounding" },
        { "ds", desc = "Delete surrounding" },
        { "cs", desc = "Replace surrounding" },
        { "S", [[:<C-u>lua MiniSurround.add('visual')<CR>]], mode = "x", silent = true, desc = "Surround selection" },
      }
    end,
    opts = {
      mappings = {
        add = "ys",
        delete = "ds",
        replace = "cs",
        find = "",
        find_left = "",
        highlight = "",
        update_n_lines = "",
        suffix_last = "",
        suffix_next = "",
      },
      search_method = "cover_or_next",
    },
    config = function(_, opts)
      require("mini.surround").setup(opts)
      vim.keymap.del("x", "ys")
      vim.keymap.set("n", "yss", "ys_", { remap = true, desc = "Add surrounding to line" })
    end,
  },
}
