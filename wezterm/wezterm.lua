-- WezTerm configuration, loaded from ~/.wezterm.lua through wezterm/loader.lua
local wezterm = require "wezterm"
local mux = wezterm.mux
local config = {}

local is_windows = wezterm.target_triple:find("windows", 1, true) ~= nil

config.font_size = 10.0
config.hide_tab_bar_if_only_one_tab = true

config.front_end = "OpenGL"
config.max_fps = 60
config.animation_fps = 1

config.keys = {
  { key = "Space", mods = "CTRL|SHIFT", action = wezterm.action.ShowLauncherArgs { flags = "FUZZY|LAUNCH_MENU_ITEMS" } },
}

if is_windows then
  config.default_prog = { "powershell.exe", "-NoLogo" }
  config.default_cwd = "c:\\dev"

  -- Cascadia ships with Windows; elsewhere WezTerm's bundled default font is used
  config.font = wezterm.font_with_fallback {
    { family = "Cascadia Mono", weight = "DemiBold" },
  }

  local VS2022 = "C:\\Program Files\\Microsoft Visual Studio\\2022\\Community"
  local VS18 = "C:\\Program Files\\Microsoft Visual Studio\\18\\Community"
  local PROJECT_DIR = "C:\\dev\\visioinspect2"

  -- PowerShell with the x64 developer environment of one Visual Studio install;
  -- `then_run` is an optional command to start in it. Selected by install path,
  -- not by instance id: ids change with every reinstall of Visual Studio.
  local function dev_powershell(vs_root, then_run)
    local command = "&{Import-Module '"
      .. vs_root
      .. "\\Common7\\Tools\\Microsoft.VisualStudio.DevShell.dll'; Enter-VsDevShell -VsInstallPath '"
      .. vs_root
      .. "' -SkipAutomaticLocation -Arch amd64}"
    if then_run then command = command .. "; " .. then_run end
    return { "powershell.exe", "-NoExit", "-Command", command }
  end

  config.launch_menu = {
    { label = "PowerShell", args = { "powershell.exe", "-NoLogo" } },
    { label = "Símbolo del sistema", args = { "cmd.exe" } },
    { label = "Developer PowerShell for VS 2022", args = dev_powershell(VS2022) },
    {
      label = "Developer Command Prompt for VS 2022",
      args = { "cmd.exe", "/k", VS2022 .. "\\Common7\\Tools\\VsDevCmd.bat" },
    },
    { label = "Developer PowerShell for VS 18", args = dev_powershell(VS18) },
    {
      label = "Developer Command Prompt for VS 18",
      args = { "cmd.exe", "/k", VS18 .. "\\Common7\\Tools\\VsDevCmd.bat" },
    },
    { label = "WSL: archlinux", args = { "wsl.exe", "-d", "archlinux" } },
  }

  -- project workspace in a new tab: nvim (VS 18 developer shell) on the left, claude on the right
  table.insert(config.keys, {
    key = "D",
    mods = "CTRL|SHIFT",
    action = wezterm.action_callback(function(window)
      -- the `cwd` of spawn_tab/split is not honoured here (panes open in default_cwd),
      -- so each shell changes directory itself before starting its program
      local enter_project = "Set-Location '" .. PROJECT_DIR .. "'; "
      local _, nvim_pane = window:mux_window():spawn_tab {
        cwd = PROJECT_DIR,
        args = dev_powershell(VS18, enter_project .. "nvim"),
      }
      nvim_pane:split {
        direction = "Right",
        size = 0.35,
        cwd = PROJECT_DIR,
        args = { "powershell.exe", "-NoLogo", "-NoExit", "-Command", enter_project .. "claude" },
      }
      nvim_pane:activate()
    end),
  })
end

wezterm.on("gui-startup", function(cmd)
  local _, _, window = mux.spawn_window(cmd or {})

  local gui_win = window:gui_window()
  if gui_win then gui_win:maximize() end
end)

return config
