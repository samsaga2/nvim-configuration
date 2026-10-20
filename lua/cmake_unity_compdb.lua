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

  vim.fn.writefile({ vim.fn.json_encode(expanded) }, vim.fn.getcwd() .. "/compile_commands.json")
  vim.notify(string.format("compile_commands.json: %d entradas (unity expandido)", #expanded), vim.log.levels.INFO)
end

return M
