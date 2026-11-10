-- Fix: which-key's popup could render with almost no height when the cursor
-- was near the bottom of the screen (its default `no_overlap` shrinks the
-- popup to avoid the cursor instead of just covering it).
---@type LazySpec
return {
  "folke/which-key.nvim",
  opts = {
    win = {
      no_overlap = false,
      height = { min = 4, max = 25 },
    },
  },
}
