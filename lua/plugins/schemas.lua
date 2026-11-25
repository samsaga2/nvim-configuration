-- The community json/yaml packs add the SchemaStore schemas through `on_new_config`, an old
-- nvim-lspconfig hook that Neovim 0.11+ (vim.lsp.config) never calls, so jsonls/yamlls start
-- without any schema. `before_init` does run: inject them there.

-- SchemaStore's YAML file patterns compiled once; a few are not valid globs for vim.glob
-- (e.g. "**/conjure/**.yml") and are skipped
local compiled_yaml_matchers
local function yaml_schema_matchers()
  if not compiled_yaml_matchers then
    compiled_yaml_matchers = {}
    for url, patterns in pairs(require("schemastore").yaml.schemas()) do
      for _, pattern in ipairs(type(patterns) == "table" and patterns or { patterns }) do
        local ok, lpeg = pcall(vim.glob.to_lpeg, pattern:find "/" and pattern or "**/" .. pattern)
        if ok then table.insert(compiled_yaml_matchers, { url = url, lpeg = lpeg }) end
      end
    end
  end
  return compiled_yaml_matchers
end

---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@type AstroLSPOpts
  opts = {
    ---@diagnostic disable: missing-fields
    config = {
      jsonls = {
        before_init = function(_, config)
          config.settings = config.settings or {}
          config.settings.json = config.settings.json or {}
          config.settings.json.schemas = require("schemastore").json.schemas()
        end,
      },
      yamlls = {
        before_init = function(_, config)
          config.settings = config.settings or {}
          config.settings.yaml = config.settings.yaml or {}
          config.settings.yaml.schemas = require("schemastore").yaml.schemas()
        end,
        -- On Windows yamlls never matches a glob (not even "*.yml"), only an exact
        -- "C:/..." path. So do the matching here and hand it each opened file's own path.
        on_attach = function(client, bufnr)
          local path = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))
          if vim.fn.has "win32" == 0 or path == "" then return end
          local schemas = client.settings.yaml.schemas
          local matched = false
          for _, matcher in ipairs(yaml_schema_matchers()) do
            if matcher.lpeg:match(path) then
              local current = schemas[matcher.url]
              current = type(current) == "table" and current or { current }
              if not vim.list_contains(current, path) then table.insert(current, path) end
              schemas[matcher.url] = current
              matched = true
            end
          end
          if matched then client:notify("workspace/didChangeConfiguration", { settings = client.settings }) end
        end,
      },
    },
  },
}
