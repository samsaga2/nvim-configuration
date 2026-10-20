---@type LazySpec
return {
  {
    "Exafunction/codeium.nvim",
    opts = {
      virtual_text = {
        enabled = true,
      },
    },
  },
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
    },
  },
}
