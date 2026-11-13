local clock_timer

---@type LazySpec
return {
  "rebelot/heirline.nvim",
  opts = function(_, opts)
    local status = require "astroui.status"
    local clock = status.component.builder {
      { provider = function() return os.date "%H:%M" end },
      padding = { left = 1, right = 1 },
    }
    -- just before the last component (the right-hand mode block)
    table.insert(opts.statusline, #opts.statusline, clock)

    -- the statusline only redraws on editor events: tick it so the minute changes while idle
    if not clock_timer then
      clock_timer = vim.uv.new_timer()
      clock_timer:start(10000, 10000, vim.schedule_wrap(function() vim.cmd.redrawstatus() end))
    end
  end,
}
