---@diagnostic disable: need-check-nil
local J = require("plenary.job")
local P = require("plenary.path")

local SIGKILL = 9

---@class Ueberzug
---@field fifo Path path to the fifo file
---@field task Job the ueberzug process
local Uz = {}

---@class TailOpts
---@field on_stdout function
---@field on_start function
---@field on_exit function
---@field on_stderr function

---File watcher function. This requires `tail`.
---@param fifo string fifo file
---@param opts TailOpts?
---@return Job
local function tail(fifo, opts)
  opts = vim.F.if_nil(opts, {})
  return J:new({
    command = "tail",
    args = {
      "--silent",
      "--follow",
      fifo,
    },
    on_stdout = opts.on_stdout,
    on_start = opts.on_start,
    on_exit = opts.on_exit,
    on_stderr = opts.on_stderr,
  })
end

---Create a new ueberzug instance
---@param fifo string
---@param silent boolean
---@return table
function Uz:new(fifo, silent)
  ---@type Path
  ---@diagnostic disable-next-line: cast-local-type
  fifo = P:new(fifo)
  fifo:touch({ parents = true })

  local args = { "layer", "--parser", "json" }
  if silent then table.insert(args, 1, "--silent") end
  local ueberzug_task = J:new({
    command = "ueberzug",
    args = args,
    -- tail --follow fifo | ueberzug --silent
    -- writer acts as a pipe
    writer = tail(fifo.filename),
    on_exit = vim.schedule_wrap(function(this, code, signal)
      local errors = vim.trim(table.concat(this:stderr_result(), "\n"))
      if errors ~= "" and not silent then
        local error_message = "```\n" .. errors .. "\n```"
        vim.notify(string.format("# ueberzug exited with code `%s` and signal `%s`.\n%s", code, signal, error_message))
      end
    end),
  })

  self.__index = self
  return setmetatable({ fifo = fifo, task = ueberzug_task }, self)
end

---Start the ueberzug process
function Uz:listen() self.task:start() end

---Remove the fifo file
function Uz:clean() self.fifo:rm() end

---Kill the ueberzug process
function Uz:kill()
  assert(self.task, "Ueberzug task is not running!")
  ---@diagnostic disable-next-line: param-type-mismatch
  vim.loop.kill(self.task.writer.pid, SIGKILL)
  self:clean()
end

---Send a payload to ueberzug this will be used to display messages.
---@param message table<string, string|number> payload that is to be sent to ueberzug
function Uz:send(message)
  local defaults = {
    action = "add",
    identifier = "media",
    x = 0,
    y = 0,
    width = 100,
    height = 50,
  }
  assert(type(message) == "table")
  if message.action ~= "remove" then message = vim.tbl_extend("keep", message, defaults) end
  self.fifo:write(vim.json.encode(message) .. "\n", "a")
end

---Hide the ueberzug window
function Uz:hide()
  self:send({
    action = "remove",
    identifier = "media",
  })
end

return Uz
