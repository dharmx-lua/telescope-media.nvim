local P = require("plenary.path")
local J = require("plenary.job")

local utils = require("telescope.utils")
local bview = require("telescope.previewers.buffer_previewer")
local putil = require("telescope.previewers.utils")

local Uz = require("telescope._extensions.media.lib.ueberzug")
local scope = require("telescope._extensions.media.core.scope")
local rifle = require("telescope._extensions.media.core.rifle")
local util = require("telescope._extensions.media.util")
local log = require("telescope._extensions.media.core.log")

local fb = rifle.file_backends
local ib = rifle.image_backends

local NULL = vim.NIL
local ERROR = vim.log.levels.ERROR

local fnamemod = vim.fn.fnamemodify
local fs_access = vim.loop.fs_access
local if_nil = vim.F.if_nil
local set_lines = vim.api.nvim_buf_set_lines
local set_option = vim.api.nvim_buf_set_option

-- NOTE: Using treesitter in previews causes: https://github.com/neovim/neovim/issues/21416

---Display a dialog text in the middle of the previewer buffer.
---@param buffer number buffer id.
---@param window number window id.
---@param message string message to be display.
---@param fill string character to pad the message text with.
local function dialog(buffer, window, message, fill)
  pcall(putil.set_preview_message, buffer, window, message, fill)
end

---Sets previewer contents. And displays a error message dialog if
---the content has problems or if the contents cannot be set entirely.
---@param command table a command and its arguments.
---@param buffer number previewer buffer id.
---@param opts table configuration opts.
---@param extension? string filetype.
---@return false
local function try_capture(command, buffer, opts, extension)
  local task = J:new(command)
  local ok, result, code = pcall(J.sync, task, opts.preview.timeout, opts.preview.wait, opts.preview.redraw)
  if ok then -- if the job finishes within given time then
    if code == 0 then -- check if the job finishes successfully
      pcall(set_lines, buffer, 0, -1, false, result) -- set the preview buffer to the job's stdout
      set_option(buffer, "filetype", if_nil(extension, "text"))
    else
      dialog(buffer, opts.preview.winid, "PREVIEWER ERROR", opts.preview.fill.error)
    end
  else
    dialog(buffer, opts.preview.winid, "PREVIEWER TIMED OUT", opts.preview.fill.timeout)
  end
  return false
end

---Display metadata of a file.
---@param buffer number previewer buffer id.
---@param extension string filetype.
---@param absolute string filepath.
---@param opts table configuration opts.
---@return boolean
local function display_metadata(buffer, extension, absolute, opts)
  if not opts.preview.check_mime_type then return true end

  local mime = utils.get_os_command_output(fb.file + { "--brief", "--mime-type", absolute })[1]
  local mimetype = vim.split(mime, "/", { plain = true })
  local window = opts.preview.winid
  local fill_binary = opts.preview.fill.binary
  local fill_file = opts.preview.fill.file

  -- switches for different mime types
  if fb.readelf and vim.tbl_contains({ "x-executable", "x-pie-executable", "x-sharedlib" }, mimetype[2]) then
    return try_capture(fb.readelf + absolute, buffer, opts)
  elseif
    -- Huge list of archive filetypes/extensions. {{{
    vim.tbl_contains({
      "a",
      "ace",
      "alz",
      "arc",
      "arj",
      "bz",
      "bz2",
      "cab",
      "cpio",
      "deb",
      "gz",
      "jar",
      "lha",
      "lz",
      "lzh",
      "lzma",
      "lzo",
      "rpm",
      "rz",
      "t7z",
      "tar",
      "tbz",
      "tbz2",
      "tgz",
      "tlz",
      "txz",
      "tZ",
      "tzo",
      "war",
      "xpi",
      "xz",
      "Z",
      "zip",
    }, extension)
    -- }}}
  then
    local command = rifle.orders(absolute, "bsdtar", "atool")
    if command then return try_capture(command, buffer, opts) end
  elseif extension == "rar" and fb.unrar then
    return try_capture(fb.unrar + absolute, buffer, opts)
  elseif extension == "7z" and fb["7z"] then
    return try_capture(fb["7z"] + absolute, buffer, opts)
  elseif extension == "pdf" and fb.exiftool then
    return try_capture(fb.exiftool + absolute, buffer, opts)
  elseif extension == "torrent" then
    local command = rifle.orders(absolute, "transmission-show", "aria2c")
    if command then return try_capture(command, buffer, opts) end
  elseif vim.tbl_contains({ "odt", "sxw", "ods", "odp" }, extension) then
    local command = rifle.orders(absolute, "odt2txt", "pandoc")
    if command then return try_capture(command, buffer, opts) end
  elseif extension == "xlsx" and fb.xlsx2csv then
    return try_capture(fb.xlsx2csv + absolute, buffer, opts)
  elseif util.any(mime, "wordprocessingml%.document$", "/epub%+zip$", "/x%-fictionbook%+xml$") and fb.pandoc then
    return try_capture(fb.pandoc + absolute, buffer, opts, "markdown")
  elseif util.any(mime, "text/rtf$", "msword$") and fb.catdoc then
    return try_capture(fb.catdoc + absolute, buffer, opts)
  elseif util.any(mimetype[2], "ms%-excel$") and fb.xls2csv then
    return try_capture(fb.xls2csv + absolute, buffer, opts)
  elseif util.any(mime, "message/rfc822$") and fb.mu then
    return try_capture(fb.mu + absolute, buffer, opts)
  elseif util.any(mime, "^image/vnd%.djvu") then
    local command = rifle.orders(absolute, "djvutxt", "exiftool")
    if command then return util.termopen(buffer, command) end
  elseif util.any(mime, "^image/") and fb.exiftool then
    return try_capture(fb.exiftool + absolute, buffer, opts)
  elseif util.any(mime, "^audio/", "^video/") then
    local command = rifle.orders(absolute, "mediainfo", "exiftool")
    if command then return util.termopen(buffer, command) end
  elseif extension == "md" then
    if fb.glow then return util.termopen(buffer, fb.glow + absolute) end
    return true
  elseif vim.tbl_contains({ "htm", "html", "xhtml", "xhtm" }, extension) then
    local command = rifle.orders(absolute, "lynx", "w3m", "elinks", "pandoc")
    if command then return try_capture(command, buffer, opts, "markdown") end
    return true
  elseif extension == "ipynb" and fb.jupyter then
    return try_capture(fb.jupyter + absolute, buffer, opts, "markdown")
  elseif mimetype[2] == "json" or extension == "json" then
    local command = rifle.orders(absolute, "jq", "python")
    if command then return try_capture(command, buffer, opts, "json") end
    return true
  elseif vim.tbl_contains({ "dff", "dsf", "wv", "wvc" }, extension) then
    local command = rifle.orders(absolute, "mediainfo", "exiftool")
    if command then return try_capture(command, buffer, opts) end
  elseif mimetype[1] == "text" or vim.tbl_contains({ "lua" }, extension) then
    return true
  end

  -- last line of defence
  if fb.file then
    local results = utils.get_os_command_output(fb.file + absolute)[1]
    dialog(buffer, window, vim.split(results, ": ", { plain = true })[2], fill_binary)
    return false
  end

  dialog(buffer, window, "CANNOT PREVIEW FILE", fill_file)
  return false
end

---Callback for handling know filetypes i.e. filetypes detected by the `filetype_detect`
---function from the `telescope.previewer.utils` module.
---@param filepath string path to the current selection.
---@param buffer number buffer id of the previewer.
---@param opts table hook configuration opts.
---@return boolean
local function filetype_hook(filepath, buffer, opts)
  local extension = fnamemod(filepath, ":e"):lower()
  local absolute = fnamemod(filepath, ":p")
  local handler = scope.supports[extension] -- look for a supported handler for the filetype

  if handler then
    local file_cachepath
    local backend = opts.backend
    local flags = if_nil(opts.flags[backend], {})
    local extra_args = if_nil(flags.extra_args, {})
    -- generate the cache path if the handler is a image type i.e.
    -- * GIF -> 1 Frame -> PNG ✓
    -- * PDF -> 1 Page -> PNG ✓
    -- * TTF -> Rendered -> PNG ✓
    -- * LUA -> Text -> LUA ❌
    if
      extension == "gif"
      and vim.tbl_contains(rifle.allows_gifs, backend)
      and flags
      and flags.move -- if backend supports animated GIFs then do not generate a cache path
    then
      file_cachepath = absolute
    elseif opts.backend == "file" then -- if images do not support any backends then use `file` command
      log.debug("define_preview(): file backend is being used.")
      return display_metadata(buffer, extension, absolute, opts)
    else
      log.debug("define_preview(): sending to handler")
      file_cachepath = handler(absolute, opts.cache_path, opts)
    end

    -- display a failure dialog if all else fails
    if file_cachepath == NULL then
      log.debug("define_preview(): file_cachepath is nil")
      return display_metadata(buffer, extension, absolute, opts)
    end

    -- special handling for ueberzug
    -- current height (lines) of the terminal for ueberzug
    local geometry = util.preview_geometry(opts)
    if opts.backend == "ueberzug" then
      log.debug("define_preview(): ueberzug started for displaying file_cachepath i.e. " .. file_cachepath)
      opts._ueberzug:send({
        path = file_cachepath,
        x = geometry.x + flags.xmove,
        y = geometry.y + flags.ymove,
        width = geometry.w,
        height = geometry.h,
      })
      dialog(buffer, opts.preview.winid, " ", " ")
      return false
    else
      if not ib[backend] then
        local message = {
          "# `" .. backend .. "` could not be found.\n",
          "Following are the possible reasons.",
          "- Binary is not in `$PATH`",
          "- Has not been registered into the `rifle.bullets` table.",
        }

        vim.notify(table.concat(message, "\n"), ERROR)
        log.warn("filetype_hook(): " .. table.concat(message, " "))
        return display_metadata(buffer, extension, absolute, opts)
      end

      local parsed_extra_args = util.parse_args(extra_args, geometry, opts) -- user args
      local total_args = ib[backend] + vim.tbl_flatten({
        parsed_extra_args,
        file_cachepath
      }) -- merged default and user args
      log.debug("filetype_hook(): arguments generated for " .. backend .. ": " .. table.concat(total_args, " "))
      -- open the neovim terminal inside of the preview buffer and run the generated backend command
      util.open_term(buffer, total_args)
      return false
    end
  end
  -- fallback to `file` command if a handler does not exist
  return display_metadata(buffer, extension, absolute, opts)
end

local MediaPreview = utils.make_default_callable(function(opts)
  opts.cache_path = P:new(opts.cache_path)
  scope.load_caches(opts.cache_path)
  local fill_perm = opts.preview.fill.permission

  -- prepare ueberzug
  local uz_opts = if_nil(opts.flags["ueberzug"], {})
  if opts.backend == "ueberzug" then
    opts._ueberzug = Uz:new(os.tmpname(), not uz_opts.warnings)
    opts._ueberzug:listen() -- start ueberzug
  end

  -- add hooks
  opts.preview.filetype_hook = filetype_hook
  opts.preview.mime_hook = filetype_hook
  opts.preview.msg_bg_fillchar = opts.preview.fill.mime

  return bview.new_buffer_previewer({
    define_preview = function(self, entry, status)
      local entry_full = (string.format("%s/%s", entry.cwd, entry.value):gsub("//", "/"))
      local function read_access_callback(_, permission)
        if permission then
          -- TODO: Is there a nicer way of doing this?
          opts.preview.winid = status.preview_win
          opts.winid = status.preview_win -- why?
          bview.file_maker(entry_full, self.state.bufnr, opts)
          return
        end
        dialog(self.state.bufnr, self.state.winid, "INSUFFICIENT PERMISSIONS", fill_perm)
      end
      fs_access(entry_full, "R", vim.schedule_wrap(read_access_callback))
      if opts.backend == "ueberzug" then
        log.debug("define_preview(): ueberzug window is now hidden.")
        opts._ueberzug:hide()
      end
    end,
    setup = function(self)
      scope.cleanup(opts.cache_path)
      log.debug("setup(): removed non-cache files")
      return if_nil(self.state, {})
    end,
    teardown = function()
      if opts.backend == "ueberzug" and opts._ueberzug then
        opts._ueberzug:kill() -- closing the preview will kill the ueberzug process
        opts._ueberzug = nil
        log.info("teardown(): killed ueberzug process.")
      end
    end,
  })
end)

return MediaPreview
