-- Copy this file to ~/.wezterm.lua. It only forwards to the real configuration,
-- which is versioned next to the Neovim one (see the README of this repository).
local wezterm = require "wezterm"

local nvim_config_dir
if wezterm.target_triple:find("windows", 1, true) then
  nvim_config_dir = os.getenv "LOCALAPPDATA" .. "\\nvim"
else
  nvim_config_dir = (os.getenv "XDG_CONFIG_HOME" or (wezterm.home_dir .. "/.config")) .. "/nvim"
end

local config_file = nvim_config_dir .. "/wezterm/wezterm.lua"
-- files loaded with dofile are not watched: without this, edits would need a manual reload
wezterm.add_to_config_reload_watch_list(config_file)
return dofile(config_file)
