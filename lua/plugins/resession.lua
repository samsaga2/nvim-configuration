---@type LazySpec
return {
  {
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
  },
  {
    -- sessions are per git branch (branch_session.lua): AstroNvim's per-folder autosave
    -- is replaced in polish.lua, and its "this folder's session" keys point to the branch's
    "AstroNvim/astrocore",
    ---@type AstroCoreOpts
    opts = {
      autocmds = { resession_auto_save = false },
      mappings = {
        n = {
          ["<Leader>S."] = { function() require("branch_session").load() end, desc = "Load this branch's session" },
          ["<Leader>SS"] = { function() require("branch_session").save() end, desc = "Save this branch's session" },
        },
      },
    },
  },
}
