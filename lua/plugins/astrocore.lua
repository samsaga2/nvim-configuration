-- AstroCore provides a central place to modify mappings, vim options, autocommands, and more!
-- Configuration documentation can be found with `:h astrocore`
-- NOTE: We highly recommend setting up the Lua Language Server (`:LspInstall lua_ls`)
--       as this provides autocomplete and documentation while editing

-- Same command string as AstroNvim's <Leader>gg, so both keys share one lazygit terminal.
-- Hiding it instead of quitting keeps a running push alive.
local function toggle_lazygit() require("astrocore").toggle_term_cmd { cmd = "lazygit ", direction = "float" } end

local function timed_build(build_opts, label)
  local start = vim.uv.hrtime()
  require("cmake-tools").build(build_opts, function(result)
    vim.notify(
      string.format("%s: %.1fs", label, (vim.uv.hrtime() - start) / 1e9),
      result:is_ok() and vim.log.levels.INFO or vim.log.levels.ERROR
    )
  end)
end

-- Builds only the library/executable the current file belongs to. :CMakeBuildCurrentFile
-- does the same but compares paths as plain strings, and on Windows the code model mixes
-- "\" and "/", so it never finds the owner.
local function build_current_file_target()
  local file = vim.fs.normalize(vim.api.nvim_buf_get_name(0)):lower()
  local all = require("cmake-tools").get_config():build_targets_with_sources()
  local names = {}
  for _, source in ipairs(all.data and all.data.sources or {}) do
    if vim.fs.normalize(source.path):lower() == file and not vim.list_contains(names, source.name) then
      table.insert(names, source.name)
    end
  end
  if #names == 0 then
    vim.notify("CMake: this file does not belong to any target of the current preset", vim.log.levels.WARN)
  elseif #names == 1 then
    timed_build({ target = names[1], fargs = {} }, "CMake build " .. names[1])
  else
    vim.ui.select(names, { prompt = "Target to build" }, function(name)
      if name then timed_build({ target = name, fargs = {} }, "CMake build " .. name) end
    end)
  end
end

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    -- Configure core features of AstroNvim
    features = {
      large_buf = { size = 1024 * 256, lines = 10000 }, -- set global limits for large files for disabling features like treesitter
      autopairs = true, -- enable autopairs at start
      cmp = true, -- enable completion at start
      -- inline diagnostics off on start; toggle with <Leader>uv (text) / <Leader>uV (lines)
      diagnostics = { virtual_text = false, virtual_lines = false },
      highlighturl = true, -- highlight URLs at start
      notifications = true, -- enable notifications at start
    },
    -- Diagnostics configuration (for vim.diagnostics.config({...})) when diagnostics are on
    diagnostics = {
      virtual_text = true,
      underline = true,
    },
    -- vim options can be configured here
    options = {
      opt = { -- vim.opt.<key>
        relativenumber = true, -- sets vim.opt.relativenumber
        number = true, -- sets vim.opt.number
        spell = false, -- sets vim.opt.spell
        signcolumn = "yes", -- sets vim.opt.signcolumn to yes
        wrap = false, -- sets vim.opt.wrap
      },
      g = { -- vim.g.<key>
        -- configure global vim variables (vim.g)
        -- NOTE: `mapleader` and `maplocalleader` must be set in the AstroNvim opts or before `lazy.setup`
        -- This can be found in the `lua/lazy_setup.lua` file
      },
    },
    -- Mappings can be configured through AstroCore as well.
    -- NOTE: keycodes follow the casing in the vimdocs. For example, `<Leader>` must be capitalized
    mappings = {
      -- first key is the mode
      t = {
        ["<A-g>"] = { toggle_lazygit, desc = "Toggle lazygit" },
      },
      n = {
        -- second key is the lefthand side of the map

        ["<A-g>"] = { toggle_lazygit, desc = "Toggle lazygit" },

        -- navigate buffer tabs
        ["<A-Right>"] = { function() require("astrocore.buffer").nav(vim.v.count1) end, desc = "Next buffer" },
        ["<A-Left>"] = { function() require("astrocore.buffer").nav(-vim.v.count1) end, desc = "Previous buffer" },

        -- navigate git hunks
        ["<A-Down>"] = { function() require("gitsigns.actions").next_hunk() end, desc = "Next git hunk" },
        ["<A-Up>"] = { function() require("gitsigns.actions").prev_hunk() end, desc = "Previous git hunk" },

        -- same actions on Alt+hjkl: Tabby (xterm.js) rewrites Alt+arrows into Ctrl+arrows on Linux
        ["<A-l>"] = { function() require("astrocore.buffer").nav(vim.v.count1) end, desc = "Next buffer" },
        ["<A-h>"] = { function() require("astrocore.buffer").nav(-vim.v.count1) end, desc = "Previous buffer" },
        ["<A-j>"] = { function() require("gitsigns.actions").next_hunk() end, desc = "Next git hunk" },
        ["<A-k>"] = { function() require("gitsigns.actions").prev_hunk() end, desc = "Previous git hunk" },

        ["<Leader>gl"] = { function() Snacks.picker.git_log_file() end, desc = "Git log (current file)" },
        ["<Leader>gL"] = { function() Snacks.picker.git_log_line() end, desc = "Git log (current line)" },
        -- blame lived on gl/gL in AstroNvim, taken by the logs above
        ["<Leader>gk"] = { function() require("gitsigns").blame_line { full = true } end, desc = "Git blame (current line)" },
        ["<Leader>gK"] = { function() require("gitsigns").blame() end, desc = "Git blame (whole file)" },

        -- mappings seen under group name "Buffer"
        ["<Leader>bd"] = {
          function()
            require("astroui.status.heirline").buffer_picker(
              function(bufnr) require("astrocore.buffer").close(bufnr) end
            )
          end,
          desc = "Close buffer from tabline",
        },

        -- tables with just a `desc` key will be registered with which-key if it's installed
        -- this is useful for naming menus
        -- ["<Leader>b"] = { desc = "Buffers" },

        -- setting a mapping to false will disable it
        -- ["<C-S>"] = false,

        ["<Leader>o"] = { "<cmd>LspClangdSwitchSourceHeader<cr>", desc = "Switch between source/header" },

        -- :restart refuses to run with unsaved buffers; the session is saved on exit and
        -- restored on start (polish.lua), so the open files come back
        ["<Leader>pr"] = { "<cmd>wall<cr><cmd>restart<cr>", desc = "Restart Neovim (reload config)" },

        ["<Leader>m"] = { desc = "CMake" },
        ["<Leader>mg"] = {
          function()
            -- generating does not rewrite the root compile_commands.json, so the watcher
            -- in cmake_unity_compdb would not notice the new entries
            require("cmake-tools").generate({ bang = false, fargs = {} }, function(result)
              if result:is_ok() then require("cmake_unity_compdb").refresh() end
            end)
          end,
          desc = "Generate",
        },
        ["<Leader>mb"] = {
          function() timed_build({ bang = false, fargs = {} }, "CMake build") end,
          desc = "Build",
        },
        ["<Leader>mf"] = { build_current_file_target, desc = "Build the current file's target" },
        ["<Leader>mc"] = { "<cmd>CMakeClean<cr>", desc = "Clean" },
        ["<Leader>mo"] = { "<cmd>CMakeOpenExecutor<cr>", desc = "Open build panel" },
        -- kit, build type, build dir and build preset have no mapping on purpose: the
        -- project is driven by CMakePresets.json (their :CMakeSelect* commands remain)
        ["<Leader>ms"] = { desc = "Select" },
        ["<Leader>msp"] = { "<cmd>CMakeSelectConfigurePreset<cr>", desc = "Configure preset" },
        ["<Leader>msb"] = { "<cmd>CMakeSelectBuildTarget<cr>", desc = "Target to build" },
        ["<Leader>msr"] = { "<cmd>CMakeSelectLaunchTarget<cr>", desc = "Executable to run/debug" },
        ["<Leader>mr"] = { "<cmd>CMakeRun<cr>", desc = "Run" },
        ["<Leader>mR"] = {
          function() require("cmake_run_extra").run_in_new_terminal() end,
          desc = "Run in a new terminal (alongside others)",
        },
        ["<Leader>ma"] = {
          function()
            local current = table.concat(require("cmake-tools").get_launch_args(), " ")
            vim.ui.input({ prompt = "CMake launch args: ", default = current }, function(input)
              if input then vim.cmd("CMakeLaunchArgs " .. input) end
            end)
          end,
          desc = "Launch arguments",
        },
        ["<Leader>mx"] = {
          function()
            -- a build/generate in progress wins; otherwise stop what runs from the build dir
            local build_job = require("cmake-tools.quickfix").job
            if build_job and not build_job.is_shutdown then
              vim.cmd "CMakeStopExecutor"
            else
              require("cmake_run_extra").stop_programs()
            end
          end,
          desc = "Stop (build, else the running programs)",
        },
        ["<Leader>md"] = {
          function()
            vim.g.dap_break_on_exceptions = false
            vim.cmd "CMakeDebug"
          end,
          desc = "Debug",
        },
        ["<Leader>mD"] = {
          function()
            vim.g.dap_break_on_exceptions = true
            vim.cmd "CMakeDebug"
          end,
          desc = "Debug, break on exceptions",
        },

        -- the rest of <Leader>d* (and F5/F9/F10/F11) comes from AstroNvim's own dap mappings
        ["<Leader>dt"] = { function() require("dap").terminate() end, desc = "Terminate" },
        ["<Leader>dv"] = {
          function() require("dap_image_view").prompt() end,
          desc = "View image/region/tuple variable",
        },
      },
    },
  },
}
