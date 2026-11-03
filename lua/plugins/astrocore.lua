--if true then return {} end -- WARN: REMOVE THIS LINE TO ACTIVATE THIS FILE

-- AstroCore provides a central place to modify mappings, vim options, autocommands, and more!
-- Configuration documentation can be found with `:h astrocore`
-- NOTE: We highly recommend setting up the Lua Language Server (`:LspInstall lua_ls`)
--       as this provides autocomplete and documentation while editing

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
      diagnostics = { virtual_text = true, virtual_lines = false }, -- diagnostic settings on startup
      highlighturl = true, -- highlight URLs at start
      notifications = true, -- enable notifications at start
    },
    -- Diagnostics configuration (for vim.diagnostics.config({...})) when diagnostics are on
    diagnostics = {
      virtual_text = true,
      underline = true,
    },
    -- passed to `vim.filetype.add`
    filetypes = {
      -- see `:h vim.filetype.add` for usage
      extension = {
        foo = "fooscript",
      },
      filename = {
        [".foorc"] = "fooscript",
      },
      pattern = {
        [".*/etc/foo/.*"] = "fooscript",
      },
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
      n = {
        -- second key is the lefthand side of the map

        -- navigate buffer tabs
        ["<A-Right>"] = { function() require("astrocore.buffer").nav(vim.v.count1) end, desc = "Next buffer" },
        ["<A-Left>"] = { function() require("astrocore.buffer").nav(-vim.v.count1) end, desc = "Previous buffer" },

        -- navigate git hunks
        ["<A-Down>"] = { function() require("gitsigns.actions").next_hunk() end, desc = "Next git hunk" },
        ["<A-Up>"] = { function() require("gitsigns.actions").prev_hunk() end, desc = "Previous git hunk" },

        ["<leader>g"] = { name = "Git" },
        ["<leader>gl"] = { function() Snacks.picker.git_log_file() end, desc = "Git log (current file)" },
        ["<leader>gL"] = { function() Snacks.picker.git_log_line() end, desc = "Git log (current line)" },

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

        ["<leader>m"] = { name = "CMake" },
        ["<leader>mg"] = {
          function()
            require("cmake-tools").generate({ bang = false, fargs = {} }, function(result)
              if result:is_ok() then require("cmake_unity_compdb").refresh() end
            end)
          end,
          desc = "CMake: Generate",
        },
        ["<leader>mb"] = {
          function()
            local uv = vim.uv or vim.loop
            local start = uv.hrtime()
            require("cmake-tools").build({ bang = false, fargs = {} }, function(result)
              if result:is_ok() then require("cmake_unity_compdb").refresh() end
              local elapsed = (uv.hrtime() - start) / 1e9
              vim.notify(
                string.format("CMake build: %.1fs", elapsed),
                result:is_ok() and vim.log.levels.INFO or vim.log.levels.ERROR
              )
            end)
          end,
          desc = "CMake: Build",
        },
        ["<leader>mc"] = { "<cmd>CMakeClean<cr>", desc = "CMake: Clean" },
        ["<leader>mo"] = { "<cmd>CMakeOpenExecutor<cr>", desc = "CMake: Open Executor" },
        ["<leader>ms"] = { "<cmd>CMakeSelectBuildDir<cr>", desc = "CMake: Select Build Dir" },
        ["<leader>mp"] = { "<cmd>CMakeSelectConfigurePreset<cr>", desc = "CMake: Select Configure Preset" },
        ["<leader>mP"] = { "<cmd>CMakeSelectBuildPreset<cr>", desc = "CMake: Select Build Preset" },
        ["<leader>mk"] = { "<cmd>CMakeSelectKit<cr>", desc = "CMake: Select Kit" },
        ["<leader>mt"] = { "<cmd>CMakeSelectBuildType<cr>", desc = "CMake: Select Build Type" },
        ["<leader>mr"] = { "<cmd>CMakeRun<cr>", desc = "CMake: Run" },
        ["<leader>ma"] = {
          function()
            local current = table.concat(require("cmake-tools").get_launch_args(), " ")
            vim.ui.input({ prompt = "CMake launch args: ", default = current }, function(input)
              if input then vim.cmd("CMakeLaunchArgs " .. input) end
            end)
          end,
          desc = "CMake: Set Launch Args",
        },
        ["<leader>mL"] = { "<cmd>CMakeSelectLaunchTarget<cr>", desc = "CMake: Select Launch Target" },
        ["<leader>mx"] = { "<cmd>CMakeStopExecutor<cr>", desc = "CMake: Cancel Build/Generate" },
        ["<leader>mX"] = { "<cmd>CMakeStopRunner<cr>", desc = "CMake: Stop Run/Debug" },
        ["<leader>md"] = { "<cmd>CMakeDebug<cr>", desc = "CMake: Debug" },

        ["<leader>d"] = { name = "Debug" },
        ["<leader>db"] = { function() require("dap").toggle_breakpoint() end, desc = "Toggle breakpoint" },
        ["<leader>dc"] = { function() require("dap").continue() end, desc = "Continue/Start" },
        ["<leader>do"] = { function() require("dap").step_over() end, desc = "Step over" },
        ["<leader>di"] = { function() require("dap").step_into() end, desc = "Step into" },
        ["<leader>dO"] = { function() require("dap").step_out() end, desc = "Step out" },
        ["<leader>dt"] = { function() require("dap").terminate() end, desc = "Terminate" },
        ["<leader>du"] = { function() require("dapui").toggle() end, desc = "Toggle Debug UI" },

        ["<leader>q"] = { name = "Session" },
        ["<leader>qs"] = { function() require("persistence").load() end, desc = "Load session (cwd)" },
        ["<leader>qS"] = { function() require("persistence").select() end, desc = "Select session" },
        ["<leader>ql"] = { function() require("persistence").load({ last = true }) end, desc = "Load last session" },
        ["<leader>qd"] = { function() require("persistence").stop() end, desc = "Don't save current session" },
      },
    },
  },
}
