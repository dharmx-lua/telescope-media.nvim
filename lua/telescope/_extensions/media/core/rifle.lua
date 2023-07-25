local M = {}

---Backeds that supports playing GIFs by default.
M.allows_gifs = {
  "catimg",
  "chafa",
  "viu",
}

---A backend and args key value pair. Only image backends will be stored here.
---The arguments will be passed when said backends are called.
---
---Example:
---```lua
---{
---  jp2a = { "jp2a", "--colors" } 
---}
---```
---The first argument is not optional.
M.image_backends = {
  ["jp2a"] = { "jp2a", "--colors" },
  ["chafa"] = { "chafa" },
  ["viu"] = { "viu" },
  ["catimg"] = { "catimg" },
}

---A backend and args key value pair. Only file backends will be stored here.
---The arguments will be passed when said backends are called.
---
---Example:
---```lua
---{
---  ["jq"] = {
---    "jq",
---    "--color-output",
---    "--raw-output",
---    "--monochrome-output",
---    "."
---  },
---}
---```
---The first `jq[1]` element is not optional.
M.file_backends = {
  -- webpages
  ["w3m"] = { "w3m", "-no-mouse", "-dump" },
  ["lynx"] = { "lynx", "-dump" },
  ["elinks"] = { "elinks", "-dump" },

  -- markdowns
  ["glow"] = { "glow", "--style=auto" },
  ["pandoc"] = { "pandoc", "--standalone", "--to=markdown" },

  -- torrents
  ["transmission-show"] = { "transmission-show", "--unsorted" },
  ["aria2c"] = { "aria2c", "--show-file" },

  -- jsons
  ["jq"] = { "jq", "--color-output", "--raw-output", "--monochrome-output", "." },
  ["python"] = { "python", "-m", "json.tool" },

  -- odt, xlsx and other document formats
  ["odt2txt"] = { "odt2txt" },
  ["xlsx2csv"] = { "xlsx2csv" },
  ["jupyter"] = { "jupyter", "nbconvert", "--to", "markdown", "--stdout" },

  -- images and videos metadata
  ["mediainfo"] = { "mediainfo" },
  ["exiftool"] = { "exiftool" },

  -- uncategorized
  ["catdoc"] = { "catdoc" },
  ["mu"] = { "mu", "view" },
  ["xls2csv"] = { "xls2csv" },
  ["djvutxt"] = { "djvutxt" },

  -- archives
  ["bsdtar"] = { "bsdtar", "--list", "--file" },
  ["atool"] = { "atool", "--list" },
  ["unrar"] = { "unrar", "lt", "-p-" },
  ["7z"] = { "7z", "l", "-p" },

  -- binaries
  ["readelf"] = { "readelf", "--wide", "--demangle=auto", "--all" },
  ["file"] = { "file", "--no-pad", "--dereference" },
}

-- {{{
---Goes through a series of backends and sees if they are executable and defined.
---The first hit will be returned.
---@param extras string an extra argument.
---@param ... string backends.
---@return string[]|nil
function M.orders(extras, ...)
  local binaries = { ... }
  for _, binary in ipairs(binaries) do
    local bullet = M.file_backends[binary]
    if bullet then return bullet + extras end
  end
end

---Metatables for a backends.backend table.
local file_image_submetas = {}

---Allow table addition. This adds element(s) from a table or a string to
---the `backend.backends` table using the addition expression.
---
---```lua
---{ "backend", "option1" } + { "option2", "value" } -> { "backend", "option1", "option2", "value" }
---{ "backend", "option1" } + "option2" -> { "backend", "option1", "option2" }
---```
---
---@param this table `backends` table where the given values i.e. to `backends.backend` will be appended.
---@param item table|string element(s) that will be appended to the passed `backends.backend` table.
---@return table
function file_image_submetas._add(this, item)
  if type(item) == "table" then return vim.tbl_flatten({ this, item }) end
  if type(item) == "string" then
    local copy = vim.deepcopy(this)
    table.insert(copy, item)
    return setmetatable(copy, { __add = file_image_submetas._add, __sub = file_image_submetas._sub })
  end
  error("Only string and list are allowed.", vim.log.levels.ERROR)
end

---Allow table subtraction. This removes element(s) from a table or a string
---from the `backend.backends` table using the subtraction expression.
---
---```lua
---{ "backend", "option1", "option2", "value" } - { "option2", "value" } -> { "backend", "option1" }
---{ "backend", "option1", "option2" } - "option2" -> { "backend", "option1" }
---```
---
---@param this table `backends` table where the given values i.e. to `backends.backend` will be appended.
---@param item table|string element(s) that will be appended to the passed `backends.backend` table.
---@return table
function file_image_submetas._sub(this, item)
  local copy = vim.deepcopy(this)
  if type(item) == "string" then item = { item } end
  if type(item) == "table" then
    for _, value in ipairs(item) do
      for index, arg in ipairs(copy) do
        if arg == value then table.remove(copy, index) end
      end
    end
    return setmetatable(copy, { __add = file_image_submetas._add, __sub = file_image_submetas._sub })
  end
  error("Only string and list are allowed.", vim.log.levels.ERROR)
end

---Backend table binder. Attaches `__add`, `__sub` and `__call` metatables to
---the passed table of `backends.backend` element. Caveat: Metatables will be attached
---only if said `backends.backend[1]` is in `$PATH` and executable.
---The backend will be removed otherwise.
---Example of a `backends` table:
---
---```lua
---M.image_backends = { -- metatables will not be added to this (outer) table
---  ["jp2a"] = { "jp2a", "--colors" }, -- metatables will be added here
---  ["chafa"] = { "chafa" }, -- metatables will be added here
---  ["viu"] = { "viu" },
---  ["catimg"] = { "catimg" },
---}
---```
---@param map table table that needs to be binded with metatable(s).
local function set_submeta(map)
  for command, args in pairs(map) do
    -- do not attach metatables + remove it if backend is non-executable
    if vim.fn.executable(args[1]) ~= 1 then
      map[command] = nil
    else
      map[command] = setmetatable(args, {
        __add = file_image_submetas._add,
        __sub = file_image_submetas._sub,
        __call = file_image_submetas._call,
      })
    end
  end
end

---Backend metatable definitions only for GIF backends.
---They are needed to be handled differently.
local gif_meta_store = {
  ---Handles new GIF backend registration.
  ---@param self table GIF backend definitions.
  ---@param new string new backend command.
  __call = function(self, new)
    if not vim.tbl_contains(self, new) then table.insert(self, new) end
  end,
}

---Metatables for a `backends` table.
---Example of a `backends` table:
---
---```lua
---M.image_backends = { -- metatables will be added to this (outer) table
---  ["jp2a"] = { "jp2a", "--colors" }, -- metatables will not be added here
---  ["catimg"] = { "catimg" },
---}
---```
local file_image_meta_store = {
  ---A convenience function for adding new file and image backends.
  ---@param self table backends table.
  ---@param new string|table backend definition. The `new[1]` will be taken as the key.
  __call = function(self, new)
    local new_type = type(new)
    if new_type == "string" then
      self[new] = { new }
    elseif new_type == "table" and #new > 0 then
      self[new[1]] = new
    else
      error("only arrays and string (without spaces) are allowed. new: " .. vim.inspect(new))
    end
  end,
  ---Attaches the sub-metatables to the `backends.new_backend` table automatically.
  ---@param this table the backends table.
  ---@param key string the new backend command.
  ---@param value table the new backends arguments.
  __newindex = function(this, key, value)
    rawset(this, key, setmetatable(value, {
      __add = file_image_submetas._add,
      __sub = file_image_submetas._sub,
      __call = file_image_submetas._call,
    }))
  end,
}

-- Bind sub metatables.
set_submeta(M.image_backends)
set_submeta(M.file_backends)

-- Bind metatables.
setmetatable(M.allows_gifs, gif_meta_store)
setmetatable(M.image_backends, file_image_meta_store)
setmetatable(M.file_backends, file_image_meta_store)

return M
-- }}}
