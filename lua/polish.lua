-- show elapsed build time on every ninja progress line (%e), e.g. [12.3s|45/389]
vim.env.NINJA_STATUS = "[%es|%f/%t] "

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "cpp", "c" },
  desc = "Disable diagnostics for C/C++ files by default",
  callback = function(args)
    vim.defer_fn(function()
      pcall(vim.diagnostic.enable, false, { bufnr = args.buf })
    end, 0)
  end,
})
