---@type LazySpec
return {
  {
    "Civitasv/cmake-tools.nvim",
    init = function()
      -- the Run/Debug terminal is a listed buffer, so the tabline shows it as one more
      -- tab besides its split; it gets its name after it opens, hence BufFilePost too
      vim.api.nvim_create_autocmd({ "TermOpen", "BufFilePost" }, {
        group = vim.api.nvim_create_augroup("cmake_runner_unlisted", { clear = true }),
        callback = function(args)
          if vim.api.nvim_buf_get_name(args.buf):find("[CMakeTools]", 1, true) then vim.bo[args.buf].buflisted = false end
        end,
      })
    end,
    opts = {
      cmake_generate_options = {},
      cmake_compile_commands_options = {
        action = "none", -- handled ourselves in cmake_unity_compdb.lua (expands unity batches too)
      },
      cmake_runner = {
        opts = {
          close_on_exit = true, -- close the Run/Debug terminal window as soon as the program exits
        },
      },
      cmake_dap_configuration = {
        type = "codelldb", -- cppvsdbg's handshake only works from inside VS Code itself (see plugins/dap.lua)
      },
    },
  },
}
