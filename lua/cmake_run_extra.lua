-- Running and stopping programs of the CMake project beyond what cmake-tools' single
-- runner terminal allows: several at once (<Leader>mR), and stopping any of them (<Leader>mx).
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

-- Runs the launch target in its own terminal split, next to whatever <Leader>mr is already
-- running: a second :CMakeRun would queue its command behind the program still running in
-- the runner's only terminal.
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

-- Running programs whose executable lives under `dir`, as { pid, name, started }.
local function programs_under(dir, callback)
  dir = vim.fs.normalize(dir):lower()
  local function inside(path) return vim.startswith(vim.fs.normalize(path):lower(), dir .. "/") end
  if vim.fn.has "win32" == 1 then
    local script = "Get-CimInstance Win32_Process | Where-Object ExecutablePath | ForEach-Object {"
      .. " '{0}|{1}|{2}|{3}' -f $_.ProcessId, $_.Name, $_.CreationDate.ToString('HH:mm'), $_.ExecutablePath }"
    vim.system({ "powershell", "-NoProfile", "-Command", script }, { text = true }, function(result)
      local found = {}
      for line in (result.stdout or ""):gmatch "[^\r\n]+" do
        local pid, name, started, path = line:match "^(%d+)|([^|]*)|([^|]*)|(.*)$"
        if pid and inside(path) then table.insert(found, { pid = tonumber(pid), name = name, started = started }) end
      end
      vim.schedule(function() callback(found) end)
    end)
  else
    local found = {}
    for entry in vim.fs.dir "/proc" do
      local path = entry:match "^%d+$" and vim.uv.fs_readlink("/proc/" .. entry .. "/exe")
      if path and inside(path) then
        table.insert(found, { pid = tonumber(entry), name = vim.fs.basename(path), started = "" })
      end
    end
    callback(found)
  end
end

local function kill_tree(program)
  -- uv.kill ends a single process on Windows; its children would keep running
  local command = vim.fn.has "win32" == 1 and { "taskkill", "/PID", tostring(program.pid), "/T", "/F" }
    or { "kill", tostring(program.pid) }
  vim.system(command, { text = true }, function(result)
    vim.schedule(function()
      local label = ("%s (pid %d)"):format(program.name, program.pid)
      if result.code == 0 then
        vim.notify("Stopped " .. label)
      else
        vim.notify("Could not stop " .. label .. ": " .. vim.trim(result.stderr or ""), vim.log.levels.ERROR)
      end
    end)
  end)
end

-- Stops the programs started from the build directory, however they were started.
-- :CMakeStopRunner only kills the direct children of the runner terminal: nothing started
-- with run_in_new_terminal, nothing whose terminal buffer was closed (on Windows the
-- program outlives it), and no grandchildren.
---@param dir? string defaults to the CMake build directory
function M.stop_programs(dir)
  dir = dir or tostring(require("cmake-tools").get_config():build_directory_path())
  programs_under(dir, function(programs)
    if #programs == 0 then
      vim.notify "CMake: no program from the build directory is running"
    elseif #programs == 1 then
      kill_tree(programs[1])
    else
      local choices = vim.list_extend({ { all = true } }, programs)
      local select = Snacks and Snacks.picker and Snacks.picker.select or vim.ui.select
      select(choices, {
        prompt = "Stop which program?",
        format_item = function(p)
          if p.all then return "All of them" end
          return ("%s  (pid %d, started %s)"):format(p.name, p.pid, p.started)
        end,
      }, function(choice)
        if not choice then return end
        for _, program in ipairs(choice.all and programs or { choice }) do
          kill_tree(program)
        end
      end)
    end
  end)
end

return M
