-- <Leader>dv: show an image, region, tuple or dictionary held in a variable while debugging
-- (HALCON's HImage, HRegion, HObject, HTuple, HDict and OpenCV's cv::Mat).
--
-- The work is done by dap_image_view.py, run inside codelldb's Python: one request per
-- action. See that file for how HALCON gets called without debug symbols. This side only
-- sends the request and shows the result. Windows/MSVC only.
local M = {}

local PYTHON = vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), "dap_image_view.py")

local function cache_file(name) return (vim.fn.stdpath "cache" .. "/" .. name):gsub("\\", "/") end
local IMAGE = cache_file "dap_image_preview.bmp"
local RESULT = cache_file "dap_image_view_result.json"

local function py(value) return vim.json.encode(value) end

-- Python text that yields the helper module, (re)loading it when the file changed. It is
-- kept in sys.modules, so the function addresses it resolves are reused for the session.
local function helper()
  local stat = vim.uv.fs_stat(PYTHON)
  local stamp = tostring(stat and stat.mtime.sec or 0)
  local path = py((PYTHON:gsub("\\", "/")))
  return (
    "(lambda sys, types: sys.modules['nvim_dv'] if getattr(sys.modules.get('nvim_dv'), 'STAMP', None) == %s"
    .. " else (lambda m: (exec(compile(open(%s, encoding='utf-8').read(), %s, 'exec'), m.__dict__),"
    .. " setattr(m, 'STAMP', %s), sys.modules.__setitem__('nvim_dv', m), m)[3])(types.ModuleType('nvim_dv')))"
    .. "(__import__('sys'), __import__('types'))"
  ):format(stamp, path, path, stamp)
end

-- Runs `name(args..., image file, result file)` of the helper module and hands its result
-- (read back from the result file) to `callback`
---@param callback fun(result: table)
local function request(session, name, args, callback)
  os.remove(IMAGE)
  os.remove(RESULT)
  local call = ("%s(%s)"):format(name, table.concat(vim.list_extend(vim.list_extend({}, args), { py(IMAGE), py(RESULT) }), ", "))
  session:evaluate({ expression = "/py " .. helper() .. "." .. call, context = "watch" }, function(err)
    vim.schedule(function()
      local file = io.open(RESULT, "r")
      local text = file and file:read "*a"
      if file then file:close() end
      local ok, result = pcall(vim.json.decode, text or "")
      if ok and type(result) == "table" then
        callback(result)
      else
        callback { ok = false, error = err and tostring(err.message or err) or "the debugger gave no answer" }
      end
    end)
  end)
end

-- Compact JSON to indented lines, keeping the key order (a decode/encode would lose it)
local function pretty_json(json)
  local lines, indent, current, in_string, escaped = {}, 0, "", false, false
  local function flush()
    if current:match "%S" then table.insert(lines, current) end
    current = ("  "):rep(indent)
  end
  for i = 1, #json do
    local c = json:sub(i, i)
    if in_string then
      current = current .. c
      if escaped then
        escaped = false
      elseif c == "\\" then
        escaped = true
      elseif c == '"' then
        in_string = false
      end
    elseif c == '"' then
      in_string = true
      current = current .. c
    elseif c == "{" or c == "[" then
      current = current .. c
      indent = indent + 1
      flush()
    elseif c == "}" or c == "]" then
      indent = indent - 1
      flush()
      current = current .. c
    elseif c == "," then
      current = current .. c
      flush()
    elseif c == ":" then
      current = current .. ": "
    elseif not c:match "%s" then
      current = current .. c
    end
  end
  flush()
  -- an empty container reads better on one line
  local joined = table.concat(lines, "\n"):gsub("([%[{])\n%s*([%]}])", "%1%2")
  return vim.split(joined, "\n")
end

-- Elements of a tuple printed by HTuple::ToString, as text: `[1, "a, b", 2.5]` gives
-- { '1', '"a, b"', '2.5' }; a single value comes without brackets
local function tuple_elements(text)
  local inner = text:match "^%s*%[(.*)%]%s*$"
  if not inner then return { vim.trim(text) } end
  local items, current, in_string, escaped = {}, "", false, false
  for i = 1, #inner do
    local c = inner:sub(i, i)
    if in_string then
      current = current .. c
      if escaped then
        escaped = false
      elseif c == "\\" then
        escaped = true
      elseif c == '"' then
        in_string = false
      end
    elseif c == '"' then
      in_string = true
      current = current .. c
    elseif c == "," then
      table.insert(items, vim.trim(current))
      current = ""
    else
      current = current .. c
    end
  end
  if vim.trim(current) ~= "" then table.insert(items, vim.trim(current)) end
  return items
end

-- A tuple of strings as a Lua list without the quotes: `["a", "b"]` gives { "a", "b" }
local function tuple_strings(text)
  return vim.tbl_map(function(item) return (item:gsub('^"(.*)"$', "%1"):gsub('\\(.)', "%1")) end, tuple_elements(text or "[]"))
end

-- A read-only floating window over the editor, closed with q or <Esc>
local function open_float(lines, title, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  if filetype then vim.bo[buf].filetype = filetype end
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  local longest = 0
  for _, line in ipairs(lines) do
    longest = math.max(longest, vim.fn.strdisplaywidth(line))
  end
  local width = math.min(vim.o.columns - 8, math.max(longest + 2, vim.fn.strdisplaywidth(title) + 4, 40))
  local height = math.min(vim.o.lines - 6, math.max(#lines, 3))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded",
    title = " " .. title .. " ",
  })
  for _, key in ipairs { "q", "<Esc>" } do
    vim.keymap.set("n", key, "<Cmd>close<CR>", { buffer = buf, nowait = true })
  end
  return buf, win
end

-- A short tuple fits in a notification; a long one (a contour's coordinates...) gets a
-- window with one value per line and its index, to scroll and search
local TUPLE_IN_NOTIFICATION = 6
local function show_tuple(text, label)
  local elements = tuple_elements(text)
  if #elements <= TUPLE_IN_NOTIFICATION then
    vim.notify(text, vim.log.levels.INFO, { title = "HTuple: " .. label })
    return
  end
  local digits = #tostring(#elements - 1)
  local lines = {}
  for i, element in ipairs(elements) do
    table.insert(lines, ("%" .. digits .. "d: %s"):format(i - 1, element))
  end
  open_float(lines, ("HTuple %s   %d values   q: close"):format(label, #elements))
end

local show

-- A dictionary as an indented JSON tree in a floating window. The keys holding iconic
-- objects (images, regions) cannot be JSON: they are listed with a marker and <CR> on one
-- shows it.
local function show_dict(session, result, label)
  local keys, types = tuple_strings(result.keys), tuple_strings(result.types)
  local object_keys = {}
  for i, key in ipairs(keys) do
    if types[i] == "object" then table.insert(object_keys, key) end
  end

  local lines = pretty_json(result.json)
  local object_line = {}
  if #object_keys > 0 and lines[#lines] == "}" then
    table.remove(lines)
    if #lines > 1 then lines[#lines] = lines[#lines] .. "," end
    for i, key in ipairs(object_keys) do
      table.insert(lines, ('  %s: "<object: Enter to view>"%s'):format(vim.json.encode(key), i < #object_keys and "," or ""))
      object_line[#lines] = key
    end
    table.insert(lines, "}")
  end

  local title = ("HDict %s   q: close%s"):format(label, #object_keys > 0 and "   Enter: view object" or "")
  local buf, win = open_float(lines, title, "json")
  vim.wo[win].foldmethod = "indent"
  vim.wo[win].foldlevel = 99
  vim.keymap.set("n", "<CR>", function()
    local key = object_line[vim.api.nvim_win_get_cursor(0)[1]]
    if not key then return end
    request(session, "view_dict_object", { ("%d"):format(result.address), py(key) }, function(object)
      show(session, object, ("%s[%s]"):format(label, key))
    end)
  end, { buffer = buf, nowait = true })
end

show = function(session, result, label)
  if not result.ok then
    vim.notify(tostring(result.error), vim.log.levels.WARN, { title = label })
  elseif result.kind == "text" then
    show_tuple(result.text, label)
  elseif result.kind == "dict" then
    show_dict(session, result, label)
  elseif vim.uv.fs_stat(IMAGE) then
    vim.fn.jobstart({ "cmd", "/c", "start", "", IMAGE }, { detach = true })
    if result.note and result.note ~= vim.NIL then vim.notify(result.note, vim.log.levels.INFO, { title = label }) end
  else
    vim.notify("HALCON wrote no image for " .. label, vim.log.levels.ERROR)
  end
end

---@param expr string a variable or expression in the current frame, or "Type@0xADDRESS"
function M.view(expr)
  local session = require("dap").session()
  if not session then
    vim.notify("No debug session", vim.log.levels.WARN)
    return
  end
  if vim.fn.has "win32" == 0 then
    vim.notify("The image viewer only works on Windows (MSVC) for now", vim.log.levels.WARN)
    return
  end
  local function on_result(result) show(session, result, expr) end
  -- "Type@0xADDRESS": an object known only by its address (a raw pointer seen in a watch)
  local type_name, address = expr:match "^%s*([%w_:]+)%s*@%s*(0x%x+)%s*$"
  if type_name then
    request(session, "view_at", { py(type_name), address }, on_result)
  else
    request(session, "view", { py(expr) }, on_result)
  end
end

function M.prompt()
  vim.ui.input({ prompt = "Variable to view: ", default = vim.fn.expand "<cexpr>" }, function(expr)
    if expr and expr ~= "" then M.view(expr) end
  end)
end

return M
