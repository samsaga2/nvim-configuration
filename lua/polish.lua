-- show elapsed build time on every ninja progress line (%e), e.g. [12.3s|45/389]
vim.env.NINJA_STATUS = "[%es|%f/%t] "

-- AstroNvim's resession autosaves a session per directory on exit but never
-- restores it by itself; do it when nvim starts with no file arguments
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("user_restore_dirsession", { clear = true }),
  desc = "Restore this directory's session if nvim was opened with no file arguments",
  nested = true,
  callback = function()
    if vim.fn.argc() == 0 then
      require("resession").load(vim.uv.cwd(), { dir = "dirsession", silence_errors = true })
    end
  end,
})
