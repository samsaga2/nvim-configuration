-- Run the CMake launch target in its own terminal split, next to whatever <Leader>mr is
-- already running: cmake-tools' runner has a single terminal, so a second :CMakeRun just
-- queues its command behind the program still running there.
local M = {}

local launches = 0

local function open_terminal(target, path, args, cwd, env)
  local previous = vim.api.nvim_get_current_win()
  vim.cmd "botright 11split"
  vim.cmd "enew"
  local buf = vim.api.nvim_get_current_buf()
  local command = { path }
  vim.list_extend(command, args)
  local job = vim.fn.jobstart(command, {
    term = true,
    cwd = cwd,
    env = next(env) and env or nil,
    on_exit = function()
      -- like the runner terminal (close_on_exit in plugins/user.lua): gone when the program ends
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
      end)
    end,
  })
  if job <= 0 then
    vim.notify("CMake: could not start " .. path, vim.log.levels.ERROR)
    return
  end
  launches = launches + 1
  vim.bo[buf].buflisted = false -- keep it out of the tabline, like the runner terminal
  pcall(vim.api.nvim_buf_set_name, buf, ("[CMakeRun %d] %s"):format(launches, target))
  if vim.api.nvim_win_is_valid(previous) then vim.api.nvim_set_current_win(previous) end
end

function M.run_in_new_terminal()
  local cmake = require "cmake-tools"
  local target = cmake.get_launch_target()
  if not target then
    vim.notify("CMake: no launch target selected", vim.log.levels.WARN)
    return
  end
  cmake.build({ target = target, fargs = {} }, function(result)
    if not result:is_ok() then return end
    local path = cmake.get_launch_target_path()
    if not path or vim.fn.executable(path) == 0 then
      vim.notify("CMake: " .. target .. " is not an executable that can be run", vim.log.levels.ERROR)
      return
    end
    local config = cmake.get_config()
    local env = require("cmake-tools.environment").get_run_environment(config, target) or {}
    open_terminal(target, path, cmake.get_launch_args() or {}, cmake.get_launch_path(target), env)
  end)
end

return M
