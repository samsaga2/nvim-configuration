-- AstroCore provides a central place to modify mappings, vim options, autocommands, and more!
-- Configuration documentation can be found with `:h astrocore`
-- NOTE: We highly recommend setting up the Lua Language Server (`:LspInstall lua_ls`)
--       as this provides autocomplete and documentation while editing

-- Same command string as AstroNvim's <Leader>gg, so both keys share one lazygit terminal.
-- Hiding it instead of quitting keeps a running push alive.
local function toggle_lazygit() require("astrocore").toggle_term_cmd { cmd = "lazygit ", direction = "float" } end

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

        ["<Leader>m"] = { desc = "CMake" },
        ["<Leader>mg"] = {
          function()
            require("cmake-tools").generate({ bang = false, fargs = {} }, function(result)
              if result:is_ok() then require("cmake_unity_compdb").refresh() end
            end)
          end,
          desc = "CMake: Generate",
        },
        ["<Leader>mb"] = {
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
        ["<Leader>mc"] = { "<cmd>CMakeClean<cr>", desc = "CMake: Clean" },
        ["<Leader>mo"] = { "<cmd>CMakeOpenExecutor<cr>", desc = "CMake: Open Executor" },
        ["<Leader>ms"] = { "<cmd>CMakeSelectBuildDir<cr>", desc = "CMake: Select Build Dir" },
        ["<Leader>mp"] = { "<cmd>CMakeSelectConfigurePreset<cr>", desc = "CMake: Select Configure Preset" },
        ["<Leader>mP"] = { "<cmd>CMakeSelectBuildPreset<cr>", desc = "CMake: Select Build Preset" },
        ["<Leader>mk"] = { "<cmd>CMakeSelectKit<cr>", desc = "CMake: Select Kit" },
        ["<Leader>mt"] = { "<cmd>CMakeSelectBuildType<cr>", desc = "CMake: Select Build Type" },
        ["<Leader>mr"] = { "<cmd>CMakeRun<cr>", desc = "CMake: Run" },
        ["<Leader>ma"] = {
          function()
            local current = table.concat(require("cmake-tools").get_launch_args(), " ")
            vim.ui.input({ prompt = "CMake launch args: ", default = current }, function(input)
              if input then vim.cmd("CMakeLaunchArgs " .. input) end
            end)
          end,
          desc = "CMake: Set Launch Args",
        },
        ["<Leader>mL"] = { "<cmd>CMakeSelectLaunchTarget<cr>", desc = "CMake: Select Launch Target" },
        ["<Leader>mx"] = { "<cmd>CMakeStopExecutor<cr>", desc = "CMake: Cancel Build/Generate" },
        ["<Leader>mX"] = { "<cmd>CMakeStopRunner<cr>", desc = "CMake: Stop Run/Debug" },
        ["<Leader>md"] = { "<cmd>CMakeDebug<cr>", desc = "CMake: Debug" },

        -- the rest of <Leader>d* (and F5/F9/F10/F11) comes from AstroNvim's own dap mappings
        ["<Leader>dt"] = { function() require("dap").terminate() end, desc = "Terminate" },
        ["<Leader>dv"] = {
          function()
            local dap = require("dap")
            local session = dap.session()
            if not session then
              vim.notify("No hay sesión de depuración activa", vim.log.levels.WARN)
              return
            end
            local word = vim.fn.expand("<cexpr>")
            vim.ui.input({ prompt = "Variable a inspeccionar: ", default = word }, function(expr)
              if not expr or expr == "" then return end
              session:evaluate(expr, function(err, result)
                vim.schedule(function()
                  if err then
                    vim.notify("No se pudo evaluar: " .. tostring(err.message or err), vim.log.levels.ERROR)
                    return
                  end
                  local ty = result.type or ""
                  local path = (vim.fn.stdpath("cache") .. "/dap_image_preview.png"):gsub("\\", "/")
                  local write_expr

                  if ty:find("HTuple", 1, true) then
                    session:evaluate(string.format("(const char*)((%s).ToString())", expr), function(err2, result2)
                      vim.schedule(function()
                        if err2 then
                          vim.notify("No se pudo leer el HTuple: " .. tostring(err2.message or err2), vim.log.levels.ERROR)
                        else
                          vim.notify(result2.result, vim.log.levels.INFO, { title = "HTuple: " .. expr })
                        end
                      end)
                    end)
                    return
                  elseif ty:find("HRegion", 1, true) then
                    -- no sabemos el tamaño real de la región: 4096x4096 como lienzo razonable
                    write_expr = string.format(
                      '(void)({ HalconCpp::HImage __dbg_img; HalconCpp::RegionToBin((%s), &__dbg_img, 255, 0, 4096, 4096); __dbg_img.WriteImage("png fastest", 0, "%s"); 0; })',
                      expr,
                      path
                    )
                  elseif ty:find("HImage", 1, true) then
                    write_expr = string.format('(void)((%s).WriteImage("png fastest", 0, "%s"))', expr, path)
                  elseif ty:find("superimage", 1, true) then
                    write_expr = string.format('(void)cv::imwrite("%s", (%s).to_cvmat())', path, expr)
                  else
                    -- asumimos algo compatible con cv::imwrite (cv::Mat u otro InputArray)
                    write_expr = string.format('(void)cv::imwrite("%s", %s)', path, expr)
                  end

                  session:evaluate(write_expr, function(err3)
                    vim.schedule(function()
                      if err3 then
                        vim.notify("No se pudo volcar la imagen: " .. tostring(err3.message or err3), vim.log.levels.ERROR)
                        return
                      end
                      vim.fn.jobstart({ "cmd", "/c", "start", "", path }, { detach = true })
                    end)
                  end)
                end)
              end)
            end)
          end,
          desc = "Debug: view image/region/tuple variable",
        },      },
    },
  },
}
