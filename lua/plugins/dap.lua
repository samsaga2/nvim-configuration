---@type LazySpec
return {
  "mfussenegger/nvim-dap",
  dependencies = { "rcarriga/nvim-dap-ui", "nvim-neotest/nvim-nio", "theHamsta/nvim-dap-virtual-text" },
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
      on_adapter({ type = "server", host = "127.0.0.1", port = codelldb_port })
    end

    require("nvim-dap-virtual-text").setup()

    local dapui = require("dapui")
    dapui.setup()
    dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
    dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
    dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end
  end,
}
