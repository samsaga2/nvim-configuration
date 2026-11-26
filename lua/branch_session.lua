-- One session per git branch: the files, splits and cursors of each branch come back when
-- the repository is switched to it, from anywhere (lazygit, Claude, a terminal).
--
-- The session is named "<cwd>@<branch>". The branch is watched through the repository's
-- HEAD file; on a change, the old branch's session is saved and the new one's loaded. A
-- load closes every window, so the switch waits until the current window is an ordinary
-- one (not lazygit's float, not a terminal), no debug session runs and nothing is unsaved.
--
-- Other per-branch state (the breakpoints) follows through two User autocmds:
-- BranchSessionLeave before the switch (still on the old branch), BranchSessionEnter after.
local M = {}

local state = {
  branch = nil, ---@type string? the branch the session belongs to
  pending = nil, ---@type string? a branch the repository moved to, not switched to yet
  warned = nil, ---@type string? the pending branch already warned about
  poll = nil,
}

local function git(args, callback)
  local command = vim.list_extend({ "git", "-C", vim.uv.cwd() }, args)
  local function parse(result) return result.code == 0 and vim.trim(result.stdout) or nil end
  if callback then
    vim.system(command, { text = true }, function(result) vim.schedule(function() callback(parse(result)) end) end)
  else
    return parse(vim.system(command, { text = true }):wait())
  end
end

local function read_branch(callback)
  git({ "rev-parse", "--abbrev-ref", "HEAD" }, function(branch)
    if branch ~= "HEAD" then return callback(branch) end
    git({ "rev-parse", "--short", "HEAD" }, function(sha) callback(sha and ("detached-" .. sha)) end)
  end)
end

-- Suffix that tells this branch's files apart: "@R_D_new_labels_ui", or "" outside git.
-- Branch names hold "/" and "&", which session and breakpoint file names cannot.
function M.key() return state.branch and ("@" .. state.branch:gsub("[^%w%._%-]", "_")) or "" end

function M.session_name() return vim.uv.cwd() .. M.key() end

local function session_exists(name)
  return vim.uv.fs_stat(require("resession.util").get_session_file(name, "dirsession")) ~= nil
end

function M.save()
  if require("astrocore.buffer").is_valid_session() then
    require("resession").save(M.session_name(), { dir = "dirsession", notify = false })
  end
end

-- Startup: this branch's session, or the folder's one (what was open before) the first time
function M.load()
  local name = M.session_name()
  if not session_exists(name) then name = vim.uv.cwd() end
  require("resession").load(name, { dir = "dirsession", silence_errors = true, attach = false })
end

---@return boolean can, string? until when it has to wait, when the user should know
local function can_switch()
  if package.loaded.dap and require("dap").session() then return false, "the debug session ends" end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and vim.bo[buf].modified then return false, "your changes are saved" end
  end
  -- silently later: lazygit's float or a terminal is in use, the switch would close it
  if vim.api.nvim_win_get_config(0).relative ~= "" or vim.bo.buftype == "terminal" then return false end
  return true
end

local function try_switch()
  local branch = state.pending
  if not branch then return end
  local can, until_when = can_switch()
  if not can then
    if until_when and state.warned ~= branch then
      state.warned = branch
      vim.notify(("Now on branch %s: its session will be restored once %s"):format(branch, until_when), vim.log.levels.WARN)
    end
    return
  end
  state.pending, state.warned = nil, nil
  vim.api.nvim_exec_autocmds("User", { pattern = "BranchSessionLeave" })
  M.save()
  state.branch = branch
  -- before the load, so the files it opens get the new branch's state
  vim.api.nvim_exec_autocmds("User", { pattern = "BranchSessionEnter" })
  local restored = session_exists(M.session_name())
  if restored then
    require("resession").load(M.session_name(), { dir = "dirsession", silence_errors = true, attach = false })
  end
  vim.notify(("Branch %s: %s"):format(branch, restored and "its session restored" or "first time here, files kept open"))
end

local function check_branch()
  read_branch(function(branch)
    if not branch then return end
    if branch == state.branch then
      state.pending = nil -- moved away and back before the switch happened
    else
      state.pending = branch
      try_switch()
    end
  end)
end

-- Reads the branch (synchronously: names depend on it from the first file opened) and
-- starts watching it. Outside a git repository it does nothing and names stay per folder.
function M.setup()
  if #vim.api.nvim_list_uis() == 0 then return end -- scripts and checks keep their hands off
  local branch = git { "rev-parse", "--abbrev-ref", "HEAD" }
  if not branch then return end
  if branch == "HEAD" then branch = "detached-" .. (git { "rev-parse", "--short", "HEAD" } or "unknown") end
  state.branch = branch

  local head = git { "rev-parse", "--absolute-git-dir" }
  if head then
    state.poll = vim.uv.new_fs_poll()
    state.poll:start(head .. "/HEAD", 1000, function() vim.schedule(check_branch) end)
  end
  vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter", "BufWritePost", "FocusGained" }, {
    group = vim.api.nvim_create_augroup("user_branch_session", { clear = true }),
    desc = "Switch to the new branch's session once it can be done",
    callback = function()
      -- scheduled: run from inside this autocmd, the session load would open its files
      -- without their own autocmds (no breakpoints, filetype or LSP for them)
      if state.pending then vim.schedule(try_switch) end
    end,
  })
  -- per-branch state set up before this (at plugin load) still used the folder's names
  vim.api.nvim_exec_autocmds("User", { pattern = "BranchSessionEnter", data = { startup = true } })
end

return M
