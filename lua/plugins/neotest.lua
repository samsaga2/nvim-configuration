-- Test tree and runner for Google Test (neotest + neotest-gtest); the community pack
-- (community.lua) adds the <Leader>T mappings.

-- visioinspect2 names most test sources tests_*.cpp; the adapter only knows test_* / *_test
local function is_gtest_source(path)
  local name = vim.fs.basename(path)
  return name:match "^tests?_.+%.cpp$" ~= nil or name:match "_test%.cpp$" ~= nil
end

-- Only descend into the top-level tests/ folder: the whole repository (and out/) is far too
-- big to scan for test files.
local function only_tests_dir(_, rel_path)
  local rel = rel_path:gsub("\\", "/")
  return rel == "tests" or vim.startswith(rel, "tests/")
end

local function same_path(a, b) return vim.fs.normalize(a):lower() == vim.fs.normalize(b):lower() end

-- Points each source folder at its executable, using what ctest knows about the build
-- directory selected in cmake-tools: every test runs in <build>/<rel>, which mirrors the
-- sources in <root>/<rel>. Replaces doing :ConfigureGtest by hand for every folder.
local function map_gtest_executables(build_dir, ctest_json)
  local neotest = require "neotest"
  local GlobalRegistry = require "neotest-gtest.executables.global_registry"
  local mapped, unmapped = 0, {}
  for _, adapter_id in ipairs(neotest.state.adapter_ids()) do
    local root = adapter_id:match "^neotest%-gtest:(.+)$"
    local tree = root and neotest.state.positions(adapter_id)
    if tree then
      local registry = GlobalRegistry:for_dir(root)
      for _, test in ipairs(vim.json.decode(ctest_json).tests) do
        local exe = test.command and test.command[1]
        local workdir
        for _, prop in ipairs(test.properties or {}) do
          if prop.name == "WORKING_DIRECTORY" then workdir = vim.fs.normalize(prop.value) end
        end
        local rel = workdir and exe and vim.fs.relpath(build_dir, workdir)
        local source_dir = rel and vim.fs.joinpath(root, rel)
        local node_id
        if source_dir then
          for _, node in tree:iter_nodes() do
            local data = node:data()
            if data.type == "dir" and same_path(data.id, source_dir) then node_id = data.id end
          end
        end
        if node_id then
          registry:update_executable(node_id, exe)
          mapped = mapped + 1
        else
          table.insert(unmapped, test.name)
        end
      end
    end
  end
  local msg = string.format("neotest: %d test executables mapped from %s", mapped, build_dir)
  if #unmapped > 0 then msg = msg .. "\nwithout test sources: " .. table.concat(unmapped, ", ") end
  vim.schedule(function() vim.notify(msg, mapped > 0 and vim.log.levels.INFO or vim.log.levels.WARN) end)
end

local function configure_gtest_from_ctest()
  local config = require("cmake-tools").get_config()
  if not config:has_build_directory() then
    vim.notify("neotest: no CMake build directory, generate the project first", vim.log.levels.WARN)
    return
  end
  local build_dir = vim.fs.normalize(config:build_directory_path())
  vim.system({ "ctest", "--test-dir", build_dir, "--show-only=json-v1" }, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify("neotest: ctest --show-only failed in " .. build_dir, vim.log.levels.ERROR)
        return
      end
      -- neotest only looks for tests once something asks for them: open the summary and
      -- wait until the test files are in its tree
      local neotest = require "neotest"
      neotest.summary.open()
      local function discovered()
        for _, adapter_id in ipairs(neotest.state.adapter_ids()) do
          local tree = vim.startswith(adapter_id, "neotest-gtest:") and neotest.state.positions(adapter_id)
          if tree then
            for _, node in tree:iter_nodes() do
              if node:data().type == "file" then return true end
            end
          end
        end
        return false
      end
      local attempts = 0
      local function map_when_discovered()
        if discovered() then
          -- the registry saves to disk through nio, so it must run in a nio task
          require("nio").run(function() map_gtest_executables(build_dir, result.stdout) end)
          -- unfold only the tests/ folder (one line per test executable) and put the cursor
          -- in the tree, ready for `r`
          for _, adapter_id in ipairs(neotest.state.adapter_ids()) do
            local root = adapter_id:match "^neotest%-gtest:(.+)$"
            if root then
              local tests_dir = vim.fs.joinpath(root, "tests"):gsub("/", "\\")
              neotest.summary:expand(tests_dir, false)
            end
          end
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neotest-summary" then
              vim.api.nvim_set_current_win(win)
            end
          end
        elseif attempts < 150 then
          attempts = attempts + 1
          vim.defer_fn(map_when_discovered, 200)
        else
          vim.notify("neotest: no test files found under " .. vim.fn.getcwd(), vim.log.levels.WARN)
        end
      end
      map_when_discovered()
    end)
  end)
end

---@type LazySpec
return {
  "nvim-neotest/neotest",
  dependencies = {
    "alfaix/neotest-gtest",
    {
      "AstroNvim/astrocore",
      opts = {
        autocmds = {
          neotest_output_close = {
            {
              event = "FileType",
              pattern = "neotest-output",
              desc = "Close the neotest output window with q or Esc",
              callback = function(args)
                for _, key in ipairs { "q", "<Esc>" } do
                  vim.keymap.set("n", key, "<Cmd>close<CR>", { buffer = args.buf, nowait = true, desc = "Close output" })
                end
              end,
            },
          },
        },
        mappings = {
          n = {
            ["<Leader>Tc"] = {
              configure_gtest_from_ctest,
              desc = "Map test executables from CMake",
            },
          },
        },
      },
    },
  },
  opts = function(_, opts)
    if vim.fn.has "win32" == 1 then
      -- Two Windows bugs of neotest-gtest, patched without touching the plugin:
      -- its project root comes out as C:/x while neotest's test ids are C:\x\..., so every
      -- test looks outside the project; and it names each project's settings file after
      -- the project path keeping the "C:", which is not a valid file name.
      local gtest_utils = require "neotest-gtest.utils"
      local normalize_path = gtest_utils.normalize_path
      gtest_utils.normalize_path = function(path) return (normalize_path(path):gsub("/", "\\")) end
      local encode_path = gtest_utils.encode_path
      gtest_utils.encode_path = function(path) return (encode_path(path):gsub(":", "%%2")) end
    end
    opts.adapters = opts.adapters or {}
    local gtest = require("neotest-gtest").setup {
      is_test_file = is_gtest_source,
      filter_dir = only_tests_dir,
    }
    -- The adapter runs every executable from the project root; run it from its own folder
    -- instead, like ctest does (the tests read their data relative to it). The debug
    -- strategy is a separate nvim-dap launch config, so it gets the folder too.
    local build_spec = gtest.build_spec
    gtest.build_spec = function(args)
      local specs = build_spec(args)
      for _, spec in ipairs(specs or {}) do
        local exe = spec.command and spec.command[1]
        if exe then
          spec.cwd = vim.fs.dirname(exe)
          if type(spec.strategy) == "table" then spec.strategy.cwd = spec.cwd end
        end
        for _, case in ipairs(vim.tbl_get(spec, "context", "isolated_cases") or {}) do
          if case.command and case.command[1] then case.cwd = vim.fs.dirname(case.command[1]) end
        end
      end
      return specs
    end
    table.insert(opts.adapters, gtest)
  end,
}
