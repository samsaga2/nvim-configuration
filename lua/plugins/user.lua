---@type LazySpec
return {
  {
    "Civitasv/cmake-tools.nvim",
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
        type = "codelldb", -- cppvsdbg's handshake only works from inside VS Code itself
        -- the native PDB reader is faster than LLDB's DIA-based one on large
        -- binaries (ours is huge: HALCON/Qt/Boost/CUDA/libtorch)
        initCommands = { "settings set plugin.symbol-file.pdb.reader native" },
      },
    },
  },
}
