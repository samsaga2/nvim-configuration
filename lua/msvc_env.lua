-- Load the VS2022 x64 developer environment (INCLUDE/LIB/PATH...) into nvim's
-- own process, so CMake/Ninja started from nvim find the MSVC toolchain no
-- matter which shell nvim was launched from. cmake-tools' executor only
-- inherits nvim's environment, it cannot run vcvars itself.
local M = {}

-- Which Visual Studio to load, as a vswhere version range:
-- VS2022 = "[17.0,18.0)", VS 2026 = "[18.0,19.0)". Change only this line.
local vs_version_range = "[18.0,19.0)"

local vswhere = "C:\\Program Files (x86)\\Microsoft Visual Studio\\Installer\\vswhere.exe"

-- Appended, not prepended: the toolchain (cl, link, rc, mt) is found either
-- way, and nothing nvim already resolves (Mason's clangd, cmake) gets shadowed
-- by the copies VS ships.
local function append_new_path_entries(new_path)
  local current = vim.env.PATH or ""
  local seen = {}
  for entry in current:gmatch("[^;]+") do
    seen[entry:lower()] = true
  end
  local added = {}
  for entry in new_path:gmatch("[^;]+") do
    if not seen[entry:lower()] then
      seen[entry:lower()] = true
      table.insert(added, entry)
    end
  end
  if #added > 0 then vim.env.PATH = current .. ";" .. table.concat(added, ";") end
end

local function apply(set_output)
  for line in set_output:gmatch("[^\r\n]+") do
    local key, value = line:match("^([^=]+)=(.*)$")
    if key then
      if key:upper() == "PATH" then
        -- other plugins (mason) change PATH while vcvars runs: merge, don't overwrite
        append_new_path_entries(value)
      elseif vim.env[key] ~= value then
        vim.env[key] = value
      end
    end
  end
end

function M.load()
  -- already inside a developer shell: keep whatever toolchain it selected
  if vim.fn.has("win32") == 0 or vim.env.VSCMD_VER or vim.fn.executable(vswhere) == 0 then return end

  -- several Visual Studio versions are installed side by side: pick exactly one
  local find = { vswhere, "-version", vs_version_range, "-latest", "-property", "installationPath" }
  vim.system(find, { text = true }, function(found)
    local root = vim.trim(found.stdout or "")
    if found.code ~= 0 or root == "" then return end

    local vcvars = root .. "\\VC\\Auxiliary\\Build\\vcvars64.bat"
    vim.system({ "cmd", "/c", "call", vcvars, ">nul", "2>&1", "&&", "set" }, { text = true }, function(env)
      vim.schedule(function()
        if env.code ~= 0 or not (env.stdout or ""):find("VSCMD_VER=", 1, true) then
          vim.notify("No se pudo cargar el entorno de Visual Studio (vcvars64.bat)", vim.log.levels.WARN)
          return
        end
        apply(env.stdout)
      end)
    end)
  end)
end

return M
