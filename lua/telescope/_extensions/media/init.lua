local present, telescope = pcall(require, "telescope")

if not present then
  vim.api.nvim_notify("This plugin requires telescope.nvim!", vim.log.levels.ERROR, {
    title = "telescope-media.nvim",
    prompt_title = "telescope-media.nvim",
    icon = " ",
  })
  return
end

local if_nil = vim.F.if_nil

local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local tconf = require("telescope.config")

local actions_state = require("telescope.actions.state")
local make_entry = require("telescope.make_entry")

local MediaPreviewer = require("telescope._extensions.media.preview")
local config = require("telescope._extensions.media.core.config")
local log = require("telescope._extensions.media.core.log")

---Picker function.
---@param opts MediaConfig telescope-media.nvim configuration table.
local function media(opts)
  opts = if_nil(opts, {})
  opts.flags = if_nil(opts.flags, {})
  opts.flags.ueberzug = if_nil(opts.flags.ueberzug, {})
  -- TODO: Remove if fixed. See #9.
  if opts.backend == "ueberzug" and not opts.flags.ueberzug.supress_backend_warning then
    local message = {
      "# See issue `#9`.\n",
      "**Ueberzug** might not work properly.",
      "Consider using a different backend instead.",
    }

    vim.notify_once(table.concat(message, "\n"), vim.log.levels.WARN, {
      title = "telescope-media.nvim",
      prompt_title = "telescope-media.nvim",
      icon = " ",
    })
  end

  opts.attach_mappings = if_nil(opts.attach_mappings, function()
    actions.select_default:replace(function(prompt_buffer)
      local current_picker = actions_state.get_current_picker(prompt_buffer)
      local selections = current_picker:get_multi_selection()

      log.debug("media(): picker window has been closed")
      actions.close(prompt_buffer)
      if #selections < 2 then
        log.debug("media(): selections are lesser than 2 - calling Callbacks.on_confirm_single...")
        opts.callbacks.on_confirm_single(actions_state.get_selected_entry()) -- handle single selections
      else
        log.debug("media(): selections are greater than 2 - calling Callbacks.on_confirm_multiple...")
        selections = vim.tbl_map(function(item) return item[1] end, selections)
        opts.callbacks.on_confirm_muliple(selections) -- handle multiple selections
      end
    end)
    return true
  end)

  opts = config.extend(opts) -- merge and return new value

  -- Adapted from https://github.com/nvim-telescope/telescope.nvim/blob/0c12735d5aff6a48ffd8111bf144dc2ff44e5975/lua/telescope/builtin/__files.lua#L243-L355 {{{
  local command = opts.find_command[1]
  if opts.search_dirs then
    for key, value in pairs(opts.search_dirs) do
      opts.search_dirs[key] = vim.fn.expand(value)
    end
  end

  if command == "fd" or command == "fdfind" or command == "rg" then
    if opts.hidden then opts.find_command[#opts.find_command + 1] = "--hidden" end
    if opts.no_ignore then opts.find_command[#opts.find_command + 1] = "--no-ignore" end
    if opts.no_ignore_parent then opts.find_command[#opts.find_command + 1] = "--no-ignore-parent" end
    if opts.follow then opts.find_command[#opts.find_command + 1] = "-L" end
    if opts.search_file then
      if command == "rg" then
        opts.find_command[#opts.find_command + 1] = "-g"
        opts.find_command[#opts.find_command + 1] = "*" .. opts.search_file .. "*"
      else
        ---@diagnostic disable-next-line: assign-type-mismatch
        opts.find_command[#opts.find_command + 1] = opts.search_file
      end
    end
    if opts.search_dirs then
      if command ~= "rg" and not opts.search_file then opts.find_command[#opts.find_command + 1] = "." end
      vim.list_extend(opts.find_command, opts.search_dirs)
    end
  elseif command == "find" then
    if not opts.hidden then
      table.insert(opts.find_command, { "-not", "-path", "*/.*" })
      opts.find_command = vim.tbl_flatten(opts.find_command)
    end
    if opts.no_ignore ~= nil then
      vim.notify("The 'no_ignore' key is not available for the 'find' command in 'find_files'.")
    end
    if opts.no_ignore_parent ~= nil then
      vim.notify("The 'no_ignore_parent' key is not available for the 'find' command in 'find_files'.")
    end
    if opts.follow then table.insert(opts.find_command, 2, "-L") end
    if opts.search_file then
      table.insert(opts.find_command, "-name")
      table.insert(opts.find_command, "*" .. opts.search_file .. "*")
    end
    if opts.search_dirs then
      table.remove(opts.find_command, 2)
      for _, value in pairs(opts.search_dirs) do
        table.insert(opts.find_command, 2, value)
      end
    end
  end
  -- }}}

  opts.entry_maker = make_entry.gen_from_file(opts) -- supports devicons
  local picker = pickers.new(opts, {
    prompt_title = "Media",
    finder = finders.new_oneshot_job(opts.find_command, opts),
    previewer = MediaPreviewer.new(opts),
    sorter = tconf.values.file_sorter(opts),
  })

  log.debug("media(): picker has been opened")
  picker:find()
end

return telescope.register_extension({
  setup = config.merge,
  exports = { media = media },
})
