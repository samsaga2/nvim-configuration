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

-- One session per git branch (branch_session.lua), restored when nvim starts with no file
-- arguments and saved on exit. It replaces AstroNvim's per-folder autosave (disabled in
-- plugins/resession.lua). A headless nvim (scripts, checks) touches no session: it would
-- restore one into a tiny screen and save it back on exit.
local session_group = vim.api.nvim_create_augroup("user_branch_session_lifecycle", { clear = true })
vim.api.nvim_create_autocmd("VimEnter", {
  group = session_group,
  desc = "Restore this branch's session if nvim was opened with no file arguments",
  nested = true,
  callback = function()
    if #vim.api.nvim_list_uis() == 0 then return end
    local branch_session = require "branch_session"
    branch_session.setup()
    if vim.fn.argc() == 0 then branch_session.load() end
  end,
})
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = session_group,
  desc = "Save this branch's session, and the last one (<Leader>Sl)",
  callback = function()
    if #vim.api.nvim_list_uis() == 0 or not require("astrocore.buffer").is_valid_session() then return end
    require("branch_session").save()
    require("resession").save("Last Session", { notify = false })
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
