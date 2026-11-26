-- Breakpoints (conditional ones and logpoints too) kept across restarts, one file per
-- working directory and git branch (a line number means something else on another
-- branch). nvim-dap only holds them in memory: every <Leader>pr lost them.
--
-- The plugin stores and restores; the saving is done here, from nvim-dap's own state,
-- after every change and on save/exit: its store function kept breakpoints deleted from
-- the debug panel, and it only saves on its own toggle, not when edits move a breakpoint.

local function bps_file() return require("persistent-breakpoints.utils").get_bps_path() end

-- The plugin's file is per folder; add the branch (branch_session.lua) to its name
local function per_branch_paths()
  local utils = require "persistent-breakpoints.utils"
  local per_folder = utils.get_bps_path
  utils.get_bps_path = function() return (per_folder():gsub("%.json$", require("branch_session").key() .. ".json")) end
  return per_folder
end

-- After the branch is known or changed: this branch's breakpoints replace the others. The
-- first time on a branch it starts from the folder's ones (what existed before branches).
local function switch_breakpoints(per_folder, startup)
  local utils = require "persistent-breakpoints.utils"
  local stored = require "persistent-breakpoints.inmemory"
  local path = bps_file()
  if not vim.uv.fs_stat(path) and vim.uv.fs_stat(per_folder()) then vim.uv.fs_copyfile(per_folder(), path) end
  if package.loaded["dap"] and not startup then
    require("persistent-breakpoints.api").reload_breakpoints() -- clears nvim-dap's, loads the new ones
  else
    -- nvim-dap not running yet: files read from now on (the session restore) get these
    stored.bps = utils.load_bps(path)
    stored.changed = false
  end
end

local function save()
  local stored = require("persistent-breakpoints.inmemory")
  local current = require("dap.breakpoints").get()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    -- a loaded buffer had its breakpoints restored on BufReadPost: what nvim-dap holds now
    -- is the truth for it, including "none left"
    if name ~= "" and vim.api.nvim_buf_is_loaded(buf) then stored.bps[name] = current[buf] end
  end
  require("persistent-breakpoints.utils").write_bps(bps_file(), stored.bps)
end

-- runs `change` on nvim-dap, then saves
local function changing(change)
  return function(...)
    change(require "dap", ...)
    save()
  end
end

local function ask(prompt, then_do)
  return function()
    vim.ui.input({ prompt = prompt }, function(text)
      if text and text ~= "" then changing(then_do)(text) end
    end)
  end
end

local toggle = changing(function(dap) dap.toggle_breakpoint() end)
local conditional = ask("Condition: ", function(dap, condition) dap.set_breakpoint(condition) end)

---@type LazySpec
return {
  {
    "Weissle/persistent-breakpoints.nvim",
    -- not lazy: it must be set up before the session restores the open files
    lazy = false,
    config = function()
      local per_folder = per_branch_paths()
      require("persistent-breakpoints").setup {} -- loads the saved table, no autocmds of its own
      local group = vim.api.nvim_create_augroup("user_persistent_breakpoints", { clear = true })
      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "BranchSessionLeave",
        desc = "Save the breakpoints of the branch being left",
        callback = function()
          if package.loaded["dap"] then save() end
        end,
      })
      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "BranchSessionEnter",
        desc = "Use the breakpoints of the branch",
        callback = function(args) switch_breakpoints(per_folder, args.data and args.data.startup) end,
      })
      vim.api.nvim_create_autocmd("BufReadPost", {
        group = group,
        desc = "Restore the saved breakpoints of the file",
        callback = function(args)
          -- only for files that have some, so opening a file does not load nvim-dap
          local saved = require("persistent-breakpoints.inmemory").bps[vim.api.nvim_buf_get_name(args.buf)]
          if saved and not vim.tbl_isempty(saved) then require("persistent-breakpoints.api").load_breakpoints() end
        end,
      })
      vim.api.nvim_create_autocmd({ "BufWritePost", "VimLeavePre" }, {
        group = group,
        desc = "Save the breakpoints, at the lines they moved to",
        callback = function()
          if package.loaded["dap"] then save() end
        end,
      })
      vim.api.nvim_create_autocmd("DirChanged", {
        group = group,
        desc = "Switch to the breakpoints of the new working directory",
        callback = function() require("persistent-breakpoints.api").reload_breakpoints() end,
      })
    end,
  },
  {
    "AstroNvim/astrocore",
    ---@type AstroCoreOpts
    opts = {
      mappings = {
        n = {
          -- AstroNvim's breakpoint keys, redone to save after the change
          ["<F9>"] = { toggle, desc = "Debugger: Toggle Breakpoint" },
          ["<F21>"] = { conditional, desc = "Debugger: Conditional Breakpoint" }, -- Shift+F9
          ["<Leader>db"] = { toggle, desc = "Toggle Breakpoint (F9)" },
          ["<Leader>dC"] = { conditional, desc = "Conditional Breakpoint (S-F9)" },
          ["<Leader>dB"] = { changing(function(dap) dap.clear_breakpoints() end), desc = "Clear Breakpoints" },
          -- a logpoint prints instead of stopping; codelldb fills in {expressions}
          ["<Leader>dl"] = {
            ask("Log message ({expr} prints a value): ", function(dap, message) dap.set_breakpoint(nil, nil, message) end),
            desc = "Logpoint",
          },
        },
      },
    },
  },
}
