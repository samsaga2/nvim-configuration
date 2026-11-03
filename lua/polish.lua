-- show elapsed build time on every ninja progress line (%e), e.g. [12.3s|45/389]
vim.env.NINJA_STATUS = "[%es|%f/%t] "

-- persistence.nvim never auto-restores on its own; do it when nvim starts
-- with no file args (e.g. plain `nvim` in the project dir)
vim.api.nvim_create_autocmd("VimEnter", {
  desc = "Restore last session if nvim was opened with no file arguments",
  nested = true,
  callback = function()
    if vim.fn.argc() == 0 then require("persistence").load() end
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "cpp", "c" },
  desc = "Disable diagnostics for C/C++ files by default",
  callback = function(args)
    vim.defer_fn(function()
      pcall(vim.diagnostic.enable, false, { bufnr = args.buf })
    end, 0)
  end,
})
