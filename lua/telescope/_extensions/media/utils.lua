---@module "telescope._extensions.media.utils"

local M = {}

local Job = require("plenary.job")
local fn = vim.fn

local function Task(options)
  local task = Job:new(vim.tbl_extend("keep", options, {
    interactive = false,
    enable_handlers = false,
    enable_recording = false,
  }))
  task:start()
  return task
end

function M.magick(input_path, output_path, opts, after)
  opts = vim.tbl_extend("keep", opts, {
    quality = "20%",
    blurred = "0.06",
    interlace = "Plane",
    frame = "[0]",
  })
  return Task({
    command = "convert",
    args = {
      "-strip",
      "-interlace",
      opts.interlace,
      "-gaussian-blur",
      opts.blurred,
      "-quality",
      opts.quality,
      input_path .. opts.frame,
      output_path,
    },
    on_exit = function(self, code, signal) after(self, code, signal) end,
  })
end

function M.fontimage(font_path, output_path, opts, after)
  opts = vim.tbl_extend("keep", opts, {
    fill = "#000000",
    background = "#FFFFFF",
    pointsize = "100",
    text_lines = {
      [[A B C D E F G H I J K L M N O P Q]],
      [[a b c d e f g h i j k l m n o p q]],
      [[0123456789.:,; (*!?') ff fl fi !=]],
      [[The quick brown fox jumps. >= <==]],
    },
  })
  return Task({
    command = "convert",
    args = {
      "-size",
      "3000x1500",
      "xc:" .. opts.background,
      "-gravity",
      "center",
      "-pointsize",
      opts.pointsize,
      "-font",
      font_path,
      "-fill",
      opts.fill,
      "-annotate",
      "+0+0",
      table.concat(opts.text_lines, "\n"),
      "-flatten",
      output_path,
    },
    on_exit = after,
  })
end

function M.ffmpeg(input_path, output_path, opts, after)
  opts = vim.tbl_extend("keep", opts, {
    map_start = "0:v",
    map_finish = "0:V?",
    loglevel = "8",
  })
  return Task({
    command = "ffmpeg",
    args = {
      "-i",
      input_path,
      "-map",
      opts.map_start,
      "-map",
      opts.map_finish,
      "-c",
      "copy",
      "-v",
      opts.loglevel,
      output_path,
    },
    on_exit = after,
  })
end

function M.ffmpegthumbnailer(input_path, output_path, opts, after)
  opts = vim.tbl_extend("keep", opts, {})
  return Task({
    command = "ffmpegthumbnailer",
    args = {
      "-i",
      input_path,
      "-o",
      output_path,
      "-s",
      "0",
    },
    on_exit = after,
  })
end

function M.pdftoppm(pdf_path, output_path, opts, after)
  opts = vim.tbl_extend("keep", opts, {
    scale_to_x = "-1",
    scale_to_y = "-1",
    first_page_to_print = "1",
    last_page_to_print = "1",
  })
  return Task({
    command = "pdftoppm",
    args = {
      "-f",
      opts.first_page_to_print,
      "-l",
      opts.last_page_to_print,
      "-scale-to-x",
      opts.scale_to_x,
      "-scale-to-y",
      opts.scale_to_y,
      "-singlefile",
      "-jpeg",
      "-tiffcompression",
      "jpeg",
      pdf_path,
      fn.fnamemodify(output_path, ":r"),
    },
    on_exit = after,
  })
end

function M.epubthumbnailer(input_path, output_path, opts, after)
  opts = vim.tbl_extend("keep", opts, { size = "2000" })
  return Task({
    command = "epub-thumbnailer",
    args = {
      input_path,
      output_path,
      opts.size,
    },
    on_exit = after,
  })
end

function M.ebookmeta(input_path, output_path, opts, after)
  opts = vim.tbl_extend("keep", opts, { size = "2000" })
  return Task({
    command = "ebook-meta",
    args = {
      "--get-cover",
      input_path,
      output_path,
    },
    on_exit = after,
  })
end

function M.zipinfo(input_path, after)
  return Task({
    command = "zipinfo",
    args = { "-1", input_path },
    enable_recording = true,
    enable_handlers = true,
    on_exit = after,
  })
end

function M.unzip(output_directory, zip_path, zip_item, after)
  return Task({
    command = "unzip",
    args = { "-d", output_directory, zip_path, zip_item },
    on_exit = after,
  })
end

return M

---vim:filetype=lua