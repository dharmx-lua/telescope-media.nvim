local M = {}

local executable = vim.fn.executable

---@class LogOpts
---@field plugin string name of the log file
---@field level string log level
---@field highlights boolean log file highlights
---@field use_file boolean write log entries into a file
---@field use_quickfix boolean write entries into the quickfix list

---@class FillOpts
---@field mime string character to be displayed when no mime matches are found for current entry
---@field permission string character to be displayed when current entry requires privilege elevation
---@field binary string character to be displayed when current entry is a binary
---@field file string string character to be displayed when current entry handler is the output of the file command
---@field error string character to be displayed when the handler task fails
---@field timeout string character to be displayed when the handler task exceeds the timeout

---@class PreviewOpts
---@field redraw boolean it |:redraw|s pending screen updates now
---@field timeout number number of milliseconds to wait
---@field wait number (approximate) number of milliseconds to wait between polls
---@field fill FillOpts display padded text on various conditions these will allow changing the padding character

---@class UeberzugOpts
---@field xmove number xoffset
---@field ymove number yoffset
---@field warnings boolean display warning messages
---@field suppress_backend_warning boolean suppress warning: https://github.com/dharmx/telescope-media.nvim/issues/9

---@class SharedBackendOpts
---@field move boolean allow rendering gifs
---@field extra_args string[] additional arguments that will be forwarded to the backend

---@class Callbacks
---@field on_confirm_single function when only one entry has been selected
---@field on_confirm_multiple function when more than one entries has been selected

---@class Flags
---@field catimg SharedBackendOpts options for the catimg backend
---@field chafa SharedBackendOpts options for the chafa backend
---@field viu SharedBackendOpts options for the viu backend
---@field ueberzug UeberzugOpts options for the ueberzug backend

---@class MediaConfig
---@field backend "catimg"|"chafa"|"viu"|"ueberzug"|"file"|"jp2a"|string backend choice
---@field cache_path string directory path where all cached images, videos, fonts, etc will be saved
---@field preview_title string title of the preview buffer
---@field results_title string title of the results buffer
---@field prompt_title string title of the prompt buffer
---@field cwd string current working directory
---@field callbacks Callbacks callbacks for various conditions
---@field flags Flags general/backend-specific opts
---@field preview PreviewOpts options related to the preview buffer
---@field log LogOpts logger configuration (developer option)
---@field find_command string[] command that will fetch file lists
---@field hidden boolean show hidden files and directories when true
---@field search_dirs string[] search directories
---@field no_ignore boolean ignore files/directories
---@field no_ignore_parent boolean ignore parent files/directories
---@field follow boolean boolean follow for changes
---@field search_file boolean search in a specific file

---The default telescope-media.nvim configuration table.
---@type MediaConfig
M._defaults = {
  backend = "file",
  flags = {
    catimg = { move = false },
    chafa = { move = false },
    viu = { move = false },
    ueberzug = { xmove = -12, ymove = -3, warnings = true, suppress_backend_warning = false },
  },
  callbacks = {
    on_confirm_single = function(...) require("telescope._extensions.media.lib.canned").single.copy_path(...) end,
    on_confirm_multiple = function(...) require("telescope._extensions.media.lib.canned").multiple.bulk_copy(...) end,
  },
  cache_path = "/tmp/media",
  preview_title = "Preview",
  results_title = "Files",
  prompt_title = "Media",
  cwd = vim.fn.getcwd(),
  preview = {
    check_mime_type = true,
    timeout = 200,
    redraw = false,
    wait = 10,
    fill = {
      mime = "",
      file = "~",
      error = ":",
      binary = "X",
      timeout = "+",
      permission = "╱",
    },
  },
  log = {
    plugin = "telescope-media",
    level = "warn",
    highlights = true,
    use_file = true,
    use_quickfix = false,
  },
}

---@type MediaConfig
M._current = vim.deepcopy(M._defaults)

---@param opts MediaConfig
---@return string[]
local function validate_find_command(opts)
  if opts.find_command then
    if type(opts.find_command) == "function" then return opts.find_command(opts) end
    return opts.find_command
  elseif 1 == executable("rg") then
    return { "rg", "--files", "--color", "never" }
  elseif 1 == executable("fd") then
    return { "fd", "--type", "f", "--color", "never" }
  elseif 1 == executable("fdfind") then
    return { "fdfind", "--type", "f", "--color", "never" }
  elseif 1 == executable("find") then
    return { "find", ".", "-type", "f" }
  elseif 1 == executable("where") then
    return { "where", "/r", ".", "*" }
  end
  error("Invalid command!", vim.log.levels.ERROR)
end

---Merge passed opts with current opts state table
---@param opts MediaConfig
function M.merge(opts)
  opts = vim.F.if_nil(opts, {})
  opts.find_command = validate_find_command(opts)
  M._current = vim.tbl_deep_extend("keep", opts, M._current)
end

---Extend passed opts with current opts state (this will not modify current opts state table)
---@param opts MediaConfig
function M.extend(opts)
  opts.find_command = validate_find_command(opts)
  return vim.tbl_deep_extend("keep", opts, M._current)
end

---Get current opts table (M._current)
---@return MediaConfig
function M.get() return M._current end

return M
