---@type LazySpec
return {
  "stevearc/resession.nvim",
  opts = function(_, opts)
    -- resession's default list without "cmdheight": a session saved while the command
    -- line happened to be tall (it was 21 lines once) brought that height back on every
    -- start, and saving again kept it forever
    opts.options = {
      "binary",
      "bufhidden",
      "buflisted",
      "diff",
      "filetype",
      "modifiable",
      "previewwindow",
      "readonly",
      "scrollbind",
      "winfixheight",
      "winfixwidth",
    }
  end,
}
