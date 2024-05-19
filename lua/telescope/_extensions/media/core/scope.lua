local M = {}

local P = require("plenary.path")
local sha = require("telescope._extensions.media.lib.sha")
local engine = require("telescope._extensions.media.core.engine")
local log = require("telescope._extensions.media.core.log")
local scandir = require("plenary.scandir")

local V = vim.fn
local U = vim.loop
local if_nil = vim.F.if_nil
local NULL = vim.NIL

M.caches = {}

M.handlers = {}

M.supports = setmetatable({}, {
  __call = function(self) return vim.tbl_keys(self) end,
})

function M.load_caches(cache_path)
  if cache_path:is_dir() then
    local files = V.readdir(cache_path.filename)
    for _, file in ipairs(files) do
      M.caches[file] = true
    end
    log.info("load_caches(): all caches are loaded.")
  else
    cache_path:mkdir({ parents = true, exists_ok = true })
    log.info("load_caches(): cache path does not exist. created.")
  end
end

function M.cleanup(cache_path)
  scandir.scan_dir(cache_path.filename, {
    add_dirs = true,
    hidden = true,
    on_insert = function(path)
      local stem = V.fnamemodify(path, ":t:r")
      if #stem ~= 128 then
        path = P:new(path)
        if path:exists() then path:rm() end
      end
    end,
  })
end

local function encode_opts(filepath, cache_path, opts)
  if opts.alias then filepath = opts.alias end
  ---@diagnostic disable-next-line: param-type-mismatch
  local encoded_path = sha.sha512(U.fs_stat(filepath).ino .. filepath):upper() .. ".jpg"
  local cached_path = cache_path.filename .. "/" .. encoded_path
  log.debug("encode_options(): created cache entry: " .. cached_path .. " from: " .. filepath)
  return if_nil(M.caches[encoded_path] and cached_path, false), encoded_path, cached_path
end

function M.handlers.image_handler(image_path, cache_path, opts)
  local in_cache, sha_path, cached_path = encode_opts(image_path, cache_path, opts)
  if in_cache then return in_cache end
  engine.magick(image_path, cached_path, opts, function() M.caches[sha_path] = true end)
  return image_path
end

function M.handlers.font_handler(font_path, cache_path, opts)
  local in_cache, sha_path, cached_path = encode_opts(font_path, cache_path, opts)
  if in_cache then return in_cache end
  engine.fontmagick(font_path, cached_path, opts, function(self, _)
    if self.code == 0 then M.caches[sha_path] = true end
  end)
  return NULL
end

function M.handlers.video_handler(video_path, cache_path, opts)
  local in_cache, sha_path, cached_path = encode_opts(video_path, cache_path, opts)
  if in_cache then return in_cache end
  engine.ffmpeg(video_path, cached_path, opts, function(_, code, _)
    if code == 0 then
      M.caches[sha_path] = true
    else
      engine.ffmpegthumbnailer(video_path, cached_path, opts, function(_, _code, _)
        if _code == 0 then M.caches[sha_path] = true end
      end)
    end
  end)
  return NULL
end

function M.handlers.gif_handler(gif_path, cache_path, opts)
  local in_cache, sha_path, cached_path = encode_opts(gif_path, cache_path, opts)
  if in_cache then return in_cache end
  opts.index = "[0]"
  engine.magick(gif_path, cached_path, opts, function(_, code, _)
    if code == 0 then M.caches[sha_path] = true end
  end)
  return NULL
end

function M.handlers.audio_handler(audio_path, cache_path, opts)
  local in_cache, sha_path, cached_path = encode_opts(audio_path, cache_path, opts)
  if in_cache then return in_cache end
  engine.ffmpeg(audio_path, cached_path, opts, function(_, code, _)
    if code == 0 then M.caches[sha_path] = true end
  end)
  return NULL
end

function M.handlers.pdf_handler(pdf_path, cache_path, opts)
  local in_cache, sha_path, cached_path = encode_opts(pdf_path, cache_path, opts)
  if in_cache then return in_cache end
  engine.pdftoppm(pdf_path, cached_path, opts, function(_, code, _)
    if code == 0 then M.caches[sha_path] = true end
  end)
  return NULL
end

function M.handlers.epub_handler(epub_path, cache_path, opts)
  local in_cache, sha_path, cached_path = encode_opts(epub_path, cache_path, opts)
  if in_cache then return in_cache end
  engine.epubthumbnailer(epub_path, cached_path, opts, function(_, code, _)
    if code == 0 then
      M.caches[sha_path] = true
    else
      engine.ebookmeta(epub_path, cached_path, opts, function(_, child_code, _)
        if child_code == 0 then M.caches[sha_path] = true end
      end)
    end
  end)
  return NULL
end

M.supports["pdf"] = M.handlers.pdf_handler

M.supports["gif"] = M.handlers.gif_handler
M.supports["eps"] = M.handlers.gif_handler

M.supports["epub"] = M.handlers.epub_handler
M.supports["mobi"] = M.handlers.epub_handler
M.supports["fb2"] = M.handlers.epub_handler

M.supports["png"] = M.handlers.image_handler
M.supports["jpeg"] = M.handlers.image_handler
M.supports["svg"] = M.handlers.image_handler
M.supports["webp"] = M.handlers.image_handler
M.supports["jpg"] = M.handlers.image_handler
M.supports["bmp"] = M.handlers.image_handler
M.supports["jiff"] = M.handlers.image_handler
M.supports["ai"] = M.handlers.image_handler

M.supports["otf"] = M.handlers.font_handler
M.supports["ttf"] = M.handlers.font_handler
M.supports["woff"] = M.handlers.font_handler
M.supports["woff2"] = M.handlers.font_handler

M.supports["mp4"] = M.handlers.video_handler
M.supports["mkv"] = M.handlers.video_handler
M.supports["flv"] = M.handlers.video_handler
M.supports["3gp"] = M.handlers.video_handler
M.supports["wmv"] = M.handlers.video_handler
M.supports["mov"] = M.handlers.video_handler
M.supports["webm"] = M.handlers.video_handler
M.supports["mpg"] = M.handlers.video_handler
M.supports["mpeg"] = M.handlers.video_handler
M.supports["avi"] = M.handlers.video_handler
M.supports["ogg"] = M.handlers.video_handler

M.supports["aa"] = M.handlers.audio_handler
M.supports["aac"] = M.handlers.audio_handler
M.supports["aiff"] = M.handlers.audio_handler
M.supports["alac"] = M.handlers.audio_handler
M.supports["mp3"] = M.handlers.audio_handler
M.supports["opus"] = M.handlers.audio_handler
M.supports["oga"] = M.handlers.audio_handler
M.supports["mogg"] = M.handlers.audio_handler
M.supports["wav"] = M.handlers.audio_handler
M.supports["cda"] = M.handlers.audio_handler
M.supports["wma"] = M.handlers.audio_handler

return M
