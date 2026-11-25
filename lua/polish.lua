-- show elapsed build time on every ninja progress line (%e), e.g. [12.3s|45/389]
vim.env.NINJA_STATUS = "[%es|%f/%t] "

require("msvc_env").load()

vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("user_unity_compdb_watch", { clear = true }),
  desc = "Keep the root compile_commands.json expanded for clangd",
  callback = function() require("cmake_unity_compdb").watch() end,
})

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

-- AstroNvim only runs :checktime on FocusGained/TermClose/TermLeave, so a file rewritten
-- by another program (Claude in the next pane) kept showing its old content, and stale
-- git signs with it, until a manual :e. Poll instead; 'autoread' reloads unmodified
-- buffers silently and a modified one still asks first.
local checktime_timer = vim.uv.new_timer()
if checktime_timer then
  checktime_timer:start(2000, 2000, vim.schedule_wrap(function()
    -- :checktime is an error in the command-line window and pointless while typing a command
    if vim.fn.getcmdwintype() == "" and vim.api.nvim_get_mode().mode ~= "c" then vim.cmd "silent! checktime" end
  end))
end
