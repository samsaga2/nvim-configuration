-- Customize Treesitter
-- --------------------
-- Treesitter customizations are handled with AstroCore
-- as nvim-treesitter simply provides a download utility for parsers

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    treesitter = {
      highlight = true, -- enable/disable treesitter based highlighting
      indent = true, -- enable/disable treesitter based indentation
      auto_install = true, -- enable/disable automatic installation of detected languages
      ensure_installed = {
        "lua",
        "vim",
        -- add more arguments for adding more treesitter parsers
      },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<C-space>", -- Ctrl + Espacio inicia la selección
          node_incremental = "<C-space>", -- Ctrl + Espacio la expande
          scope_incremental = "<bs>", -- Retroceso (Backspace) expande al ámbito superior
          node_decremental = "<M-space>", -- Alt + Espacio la reduce
        },
      },
    },
  },
}
