-- show elapsed build time on every ninja progress line (%e), e.g. [12.3s|45/389]
vim.env.NINJA_STATUS = "[%es|%f/%t] "

require("msvc_env").load()

vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("user_unity_compdb_watch", { clear = true }),
  desc = "Keep the root compile_commands.json expanded for clangd",
  callback = function() require("cmake_unity_compdb").watch() end,
})

-- Loading a session resizes every window to the saved layout scaled to the current screen,
-- and shrinking the bottom window hands the spare rows to the command line: 'cmdheight'
-- came back as 3, 21, 40... And since the saved screen height is "lines - cmdheight", each
-- restart made it worse. Put the height back after every load.
do
  local cmdheight_before_load
  local resession = require "resession"
  resession.add_hook("pre_load", function() cmdheight_before_load = vim.o.cmdheight end)
  resession.add_hook("post_load", function()
    if cmdheight_before_load then vim.o.cmdheight = cmdheight_before_load end
  end)
end

-- AstroNvim's resession autosaves a session per directory on exit but never
-- restores it by itself; do it when nvim starts with no file arguments
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("user_restore_dirsession", { clear = true }),
  desc = "Restore this directory's session if nvim was opened with no file arguments",
  nested = true,
  callback = function()
    -- a headless nvim (scripts, checks) must not touch the session of the real one:
    -- it would restore it into a tiny screen and save it back on exit
    if #vim.api.nvim_list_uis() == 0 then
      pcall(vim.api.nvim_del_augroup_by_name, "resession_auto_save")
      return
    end
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
