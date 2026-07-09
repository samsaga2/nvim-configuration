---@type LazySpec
return {
  {
    "Exafunction/codeium.nvim",
    opts = {
      virtual_text = {
        enabled = true,
        key_bindings = {
          accept = "<C-l>",
          next = "<C-.>",
        },
      },
    },
  },
  {
    "Civitasv/cmake-tools.nvim",
    opts = {
      cmake_generate_options = { "-G", "Ninja" },
    },
  },
}
