---@type LazySpec
return {
  "dchinmay2/clangd_extensions.nvim",
  lazy = true,
  dependencies = {
    "AstroNvim/astrocore",
    opts = {
      autocmds = {
        clangd_extensions = {
          {
            event = "LspAttach",
            desc = "Load clangd_extensions and its keymaps when clangd attaches",
            callback = function(args)
              if assert(vim.lsp.get_client_by_id(args.data.client_id)).name ~= "clangd" then return end
              require "clangd_extensions"
              require("astrocore").set_mappings({
                n = {
                  ["<Leader>lt"] = { "<Cmd>ClangdTypeHierarchy<CR>", desc = "Type hierarchy" },
                  ["<Leader>lT"] = { "<Cmd>ClangdAST<CR>", desc = "AST of the node under the cursor" },
                  ["<Leader>lk"] = { "<Cmd>ClangdSymbolInfo<CR>", desc = "Symbol info" },
                  ["<Leader>lm"] = { "<Cmd>ClangdMemoryUsage<CR>", desc = "clangd memory usage" },
                },
              }, { buffer = args.buf })
            end,
          },
        },
      },
    },
  },
}
