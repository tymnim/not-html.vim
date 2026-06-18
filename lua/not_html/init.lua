local lexer = require("not_html.lexer")
local parser = require("not_html.parser")
local renderer = require("not_html.renderer")
local html_parser = require("not_html.html_parser")
local decompiler = require("not_html.decompiler")

local M = {}

M.config = {
  enabled = true,
}

local function compile(input)
  local tokens = lexer.lex(input)
  local elements, err = parser.parse(tokens)
  if not elements then
    return nil, err
  end
  return renderer.render(elements), nil
end

local function decompile(input)
  local elements = html_parser.parse(input)
  return decompiler.decompile(elements)
end

M.compile = compile
M.decompile = decompile

function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)

  local group = vim.api.nvim_create_augroup("NotHtml", { clear = true })

  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = group,
    pattern = { "*.html", "*.htm" },
    callback = function(args)
      local buf = args.buf
      local file = args.match

      vim.bo[buf].buflisted = true
      vim.bo[buf].buftype = ""
      vim.bo[buf].swapfile = true

      if vim.fn.filereadable(file) == 0 then
        vim.b[buf].not_html = true
        vim.bo[buf].filetype = "nothtml"
        vim.bo[buf].modified = false
        return
      end

      local html = table.concat(vim.fn.readfile(file), "\n")

      if not M.config.enabled or html == "" then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(html, "\n"))
        vim.b[buf].not_html = true
        vim.bo[buf].modified = false
        return
      end

      local ok, result = pcall(decompile, html)
      if ok and result then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(result, "\n"))
        vim.bo[buf].filetype = "nothtml"
      else
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(html, "\n"))
        vim.bo[buf].filetype = "html"
        if not ok then
          vim.notify("not_html: decompile failed: " .. tostring(result), vim.log.levels.WARN)
        end
      end

      vim.bo[buf].modified = false
    end,
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = { "*.html", "*.htm" },
    callback = function(args)
      local buf = args.buf
      if vim.b[buf].not_html and vim.bo[buf].filetype ~= "nothtml" then
        vim.bo[buf].filetype = "nothtml"
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = group,
    pattern = { "*.html", "*.htm" },
    callback = function(args)
      local buf = args.buf
      local file = args.match
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local content = table.concat(lines, "\n")

      if not M.config.enabled or vim.bo[buf].filetype ~= "nothtml" then
        vim.fn.writefile(lines, file)
        vim.bo[buf].modified = false
        return
      end

      local result, err = compile(content)
      if result then
        vim.fn.writefile(vim.split(result, "\n"), file)
        vim.bo[buf].modified = false
      else
        vim.notify("not_html: compile failed: " .. (err or "unknown"), vim.log.levels.ERROR)
      end
    end,
  })

  vim.api.nvim_create_user_command("NotHtmlToggle", function()
    M.config.enabled = not M.config.enabled
    vim.notify("not_html: " .. (M.config.enabled and "enabled" or "disabled"))
  end, {})

  vim.api.nvim_create_user_command("NotHtmlCompile", function()
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local result, err = compile(table.concat(lines, "\n"))
    if result then
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(result, "\n"))
      vim.b[buf].not_html = nil
      vim.bo[buf].filetype = "html"
    else
      vim.notify("not_html: " .. (err or "unknown error"), vim.log.levels.ERROR)
    end
  end, {})

  vim.api.nvim_create_user_command("NotHtmlDecompile", function()
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local result = decompile(table.concat(lines, "\n"))
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(result, "\n"))
    vim.b[buf].not_html = true
    vim.bo[buf].filetype = "nothtml"
  end, {})
end

return M
