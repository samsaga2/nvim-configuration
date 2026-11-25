-- Attach to a running process chosen from a fuzzy list. nvim-dap's own pick_process goes
-- through vim.ui.select, which here is the built-in "type a number" prompt.
local function attach_to_process()
  local processes = require("dap.utils").get_processes()
  -- the CMake launch target's processes first: that is nearly always the one wanted
  local ok, target = pcall(function() return require("cmake-tools").get_launch_target() end)
  target = ok and type(target) == "string" and target:lower() or nil
  local function is_target(p) return target ~= nil and p.name:lower():find(target, 1, true) ~= nil end
  table.sort(processes, function(a, b)
    if is_target(a) ~= is_target(b) then return is_target(a) end
    if a.name:lower() ~= b.name:lower() then return a.name:lower() < b.name:lower() end
    return a.pid < b.pid
  end)
  local select = Snacks and Snacks.picker and Snacks.picker.select or vim.ui.select
  select(processes, {
    prompt = "Attach to process",
    format_item = function(p) return ("%s  (pid %d)"):format(p.name, p.pid) end,
  }, function(process)
    if not process then return end
    -- attaching reads the symbols of every loaded module first: with the app's PDB that
    -- is a long silent wait, so say when it starts and when it is done
    local dap = require "dap"
    local label = ("%s (pid %d)"):format(process.name, process.pid)
    local started = vim.uv.hrtime()
    vim.notify("Attaching to " .. label .. ": loading symbols, this can take a while…")
    dap.listeners.after.event_initialized["attach_notice"] = function()
      dap.listeners.after.event_initialized["attach_notice"] = nil
      vim.notify(("Attached to %s in %.0fs; it keeps running until a breakpoint"):format(label, (vim.uv.hrtime() - started) / 1e9))
    end
    dap.run {
      type = "codelldb",
      request = "attach",
      name = "Attach to " .. process.name,
      pid = process.pid,
      initCommands = { "settings set plugin.symbol-file.pdb.reader native" },
    }
  end)
end

---@type LazySpec
return {
  {
    "mfussenegger/nvim-dap",
    dependencies = { "igorlfs/nvim-dap-view" },
    config = function()
      local dap = require("dap")

      -- codelldb: cppvsdbg needs a proprietary "handshake" only VS Code's own client can
      -- answer (nvim-dap has no handler for it, session disconnects instantly) - codelldb
      -- is plain DAP and its bundled LLDB reads MSVC .pdb files fine. Installed via Mason.
      --
      -- This build of codelldb never flushes its "Listening on port" announcement when
      -- stdout is piped (verified: it does open the TCP port, just doesn't print it), so
      -- we can't read the port back. Use a fixed port instead and let nvim-dap's own
      -- connect retries (dap/session.lua, ~14 tries) wait for it to come up.
      local codelldb_port = "24568"
      dap.adapters.codelldb = function(on_adapter)
        local extension = vim.fn.stdpath("data") .. "/mason/packages/codelldb/extension/"
        local handle, pid_or_err
        local is_win = vim.fn.has("win32") == 1
        local adapter = extension .. (is_win and "adapter/codelldb.exe" or "adapter/codelldb")
        local liblldb = extension .. (is_win and "lldb/bin/liblldb.dll" or "lldb/lib/liblldb.so")
        handle, pid_or_err = vim.uv.spawn(adapter, {
          args = { "--port", codelldb_port, "--liblldb", liblldb },
          detached = true,
        }, function(code)
          if handle then handle:close() end
          if code ~= 0 then
            vim.schedule(function() vim.notify("codelldb exited with code " .. code, vim.log.levels.ERROR) end)
          end
        end)
        assert(handle, "Error running codelldb: " .. tostring(pid_or_err))
        on_adapter({
          type = "server",
          host = "127.0.0.1",
          port = codelldb_port,
          -- nvim-dap warns "Debug adapter didn't respond" if launch/attach has not finished
          -- in 4 s; with the app's 500 MB PDB an attach takes minutes loading symbols
          options = { initialize_timeout_sec = 900 },
        })
      end

      -- Break on C++ exceptions, on demand (vim.g.dap_break_on_exceptions, set by <Leader>mD
      -- and toggled by <Leader>dx). codelldb's own "cpp_throw" filter never fires on MSVC
      -- binaries (verified); a breakpoint on the MSVC runtime's throw function does.
      -- On Linux the filter works, so it is used there.
      local function apply_exception_breakpoints(session)
        local enabled = vim.g.dap_break_on_exceptions == true
        if vim.fn.has "win32" == 1 then
          local breakpoints = enabled and { { name = "_CxxThrowException" } } or {}
          session:request("setFunctionBreakpoints", { breakpoints = breakpoints }, function() end)
        else
          session:set_exception_breakpoints(enabled and { "cpp_throw" } or {})
        end
      end
      dap.defaults.codelldb.exception_breakpoints = {}
      dap.listeners.after.event_initialized["break_on_exceptions"] = apply_exception_breakpoints
      vim.api.nvim_create_user_command("DapToggleBreakOnExceptions", function()
        vim.g.dap_break_on_exceptions = not vim.g.dap_break_on_exceptions
        local session = dap.session()
        if session then apply_exception_breakpoints(session) end
        vim.notify("Break on exceptions: " .. (vim.g.dap_break_on_exceptions and "on" or "off"))
      end, { desc = "Toggle breaking on C++ exceptions" })

      -- the stopped line only had an icon in the sign column, easy to lose: tint the whole line
      vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })
      local stopped = vim.fn.sign_getdefined("DapStopped")[1] or { text = "→", texthl = "DiagnosticWarn" }
      vim.fn.sign_define("DapStopped", { text = stopped.text, texthl = stopped.texthl, linehl = "DapStoppedLine" })
    end,
  },
  {
    -- one panel below the code, with a tab per view, instead of nvim-dap-ui's six panels
    "igorlfs/nvim-dap-view",
    lazy = true,
    opts = {
      winbar = {
        -- "console" puts the program's output in a tab too, instead of a second window
        sections = { "scopes", "watches", "threads", "breakpoints", "exceptions", "repl", "console" },
        default_section = "scopes",
        controls = { enabled = true },
      },
      windows = { size = 0.3 },
      -- open with the debug session and close when it ends, like nvim-dap-ui did here
      auto_toggle = true,
    },
  },
  -- replaced by nvim-dap-view; AstroNvim's mappings that used it are redone below
  { "rcarriga/nvim-dap-ui", enabled = false },
  {
    "AstroNvim/astrocore",
    ---@type AstroCoreOpts
    opts = {
      mappings = {
        n = {
          ["<Leader>du"] = { function() require("dap-view").toggle() end, desc = "Toggle Debugger UI" },
          ["<Leader>dh"] = { "<Cmd>DapViewHover<CR>", desc = "Debugger Hover" },
          ["<Leader>da"] = { attach_to_process, desc = "Attach to Process" },
          ["<Leader>dD"] = {
            function() require("dap").disconnect { terminateDebuggee = false } end,
            desc = "Detach (process keeps running)",
          },
          ["<Leader>dx"] = {
            function()
              require "dap" -- the command is created when nvim-dap loads
              vim.cmd "DapToggleBreakOnExceptions"
            end,
            desc = "Toggle Break on Exceptions",
          },
          ["<Leader>dE"] = {
            function()
              vim.ui.input({ prompt = "Watch expression: " }, function(expr)
                if expr and expr ~= "" then vim.cmd("DapViewWatch " .. expr) end
              end)
            end,
            desc = "Watch Expression",
          },
        },
        v = {
          ["<Leader>dh"] = { ":DapViewHover<CR>", desc = "Debugger Hover (selection)" },
          ["<Leader>dE"] = { ":DapViewWatch<CR>", desc = "Watch Selection" },
        },
      },
    },
  },
}
