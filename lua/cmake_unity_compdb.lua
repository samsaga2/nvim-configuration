-- Expand CMake Unity Build compile_commands.json entries into one entry per
-- real source file, so clangd can parse/navigate files that only exist inside
-- a unity_N_cxx.cxx batch. Reuses the exact flags CMake already generated for
-- the batch (same defines/includes as the real build), it does not reconfigure
-- or recompile anything.
local M = {}

function M.refresh()
  local ok_ct, cmake_tools = pcall(require, "cmake-tools")
  if not ok_ct then return end

  local build_dir = cmake_tools.get_build_directory()
  if not build_dir or build_dir == "" then return end

  local ok_read, lines = pcall(vim.fn.readfile, build_dir .. "/compile_commands.json")
  if not ok_read then return end

  local ok_json, entries = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
  if not ok_json or type(entries) ~= "table" then return end

  local expanded = {}
  for _, entry in ipairs(entries) do
    table.insert(expanded, entry)
    if entry.file and entry.file:match("[/\\]Unity[/\\]unity_[^/\\]+%.cxx$") then
      local ok_unity, unity_lines = pcall(vim.fn.readfile, entry.file)
      if ok_unity then
        for _, line in ipairs(unity_lines) do
          local inc = line:match('#include%s+"(.-)"')
          if inc then
            local new_entry = vim.deepcopy(entry)
            new_entry.file = inc
            new_entry.output = nil
            new_entry.command = entry.command:gsub("(%-c%s+)%S+%s*$", "%1" .. inc:gsub("%%", "%%%%"))
            table.insert(expanded, new_entry)
          end
        end
      end
    end
  end

  -- nothing to do when the root file already is this expansion (keeps repeated calls quiet)
  local target = vim.fn.getcwd() .. "/compile_commands.json"
  local content = vim.fn.json_encode(expanded)
  local ok_current, current = pcall(vim.fn.readfile, target)
  if ok_current and table.concat(current, "\n") == content then return end

  vim.fn.writefile({ content }, target)
  vim.notify(string.format("compile_commands.json: %d entradas (unity expandido)", #expanded), vim.log.levels.INFO)
end

-- The project's own build copies the unexpanded compile_commands.json over the root one on
-- every build (also the builds behind Run/Debug, and failed ones). Expanding only after a
-- successful <Leader>mb left clangd guessing flags most of the time, e.g. showing code
-- under a per-target define as disabled. Watch the root file and re-expand it whenever
-- something else rewrites it.
local poll
function M.watch()
  if poll or vim.fn.filereadable(vim.fn.getcwd() .. "/CMakeLists.txt") == 0 then return end
  poll = vim.uv.new_fs_poll()
  if not poll then return end
  poll:start(vim.fn.getcwd() .. "/compile_commands.json", 2000, function(err)
    if not err then vim.schedule(M.refresh) end
  end)
  -- the file may already be stale from a build made before nvim started
  vim.defer_fn(M.refresh, 3000)
end

return M
