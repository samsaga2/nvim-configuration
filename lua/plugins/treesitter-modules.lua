---@type LazySpec
return {
  "MeanderingProgrammer/treesitter-modules.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  opts = {
    incremental_selection = {
      enable = true,
      -- disable the plugin's own default binds (gnn/grn/grc/grm); we bind our
      -- own below so a single key repeats the expand/shrink, Emacs-style
      keymaps = {
        init_selection = false,
        node_incremental = false,
        scope_incremental = false,
        node_decremental = false,
      },
    },
  },
  config = function(_, opts)
    require("treesitter-modules").setup(opts)
    local ts = require("treesitter-modules")
    -- start the selection (smallest node) from normal mode
    vim.keymap.set("n", "<leader>v", ts.init_selection, { desc = "Expand selection (treesitter)" })
    -- once selecting, keep expanding with either <leader>v or a bare "v"
    vim.keymap.set("x", "<leader>v", ts.node_incremental, { desc = "Expand selection further" })
    vim.keymap.set("x", "v", ts.node_incremental, { desc = "Expand selection further" })
    -- shrink back a level with either <leader>V or a bare "V"
    vim.keymap.set("x", "<leader>V", ts.node_decremental, { desc = "Shrink selection" })
    vim.keymap.set("x", "V", ts.node_decremental, { desc = "Shrink selection" })
  end,
}
