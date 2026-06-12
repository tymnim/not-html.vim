local M = {}

local void_set = {}
for _, tag in ipairs({
  "area", "base", "br", "col", "embed", "hr", "img",
  "input", "link", "meta", "source", "track", "wbr",
}) do
  void_set[tag] = true
end

local function is_ws(ch)
  return ch == " " or ch == "\n" or ch == "\r" or ch == "\t"
end

-- Tokenizer -------------------------------------------------------------------

local function tokenize(input)
  local tokens = {}
  local i = 1
  local len = #input
  local text_buf = {}

  local function flush_text()
    if #text_buf > 0 then
      local raw = table.concat(text_buf)
      local trimmed = raw:match("^%s*(.-)%s*$")
      if trimmed ~= "" then
        tokens[#tokens + 1] = { type = "text", content = trimmed }
      else
        local _, nl_count = raw:gsub("\n", "")
        if nl_count >= 2 then
          tokens[#tokens + 1] = { type = "blank" }
        end
      end
      text_buf = {}
    end
  end

  local function skip_ws()
    while i <= len and is_ws(input:sub(i, i)) do
      i = i + 1
    end
  end

  local function read_tag_name()
    local start = i
    while i <= len do
      local ch = input:sub(i, i)
      if is_ws(ch) or ch == ">" or ch == "/" then break end
      i = i + 1
    end
    return input:sub(start, i - 1):lower()
  end

  local function read_attr_name()
    local start = i
    while i <= len do
      local ch = input:sub(i, i)
      if is_ws(ch) or ch == "=" or ch == ">" or ch == "/" then break end
      i = i + 1
    end
    return input:sub(start, i - 1)
  end

  local function read_attr_value()
    skip_ws()
    if i > len then return "" end

    local ch = input:sub(i, i)
    if ch == '"' or ch == "'" then
      local quote = ch
      i = i + 1
      local start = i
      while i <= len and input:sub(i, i) ~= quote do
        i = i + 1
      end
      local val = input:sub(start, i - 1)
      if i <= len then i = i + 1 end
      return val
    end

    local start = i
    while i <= len do
      ch = input:sub(i, i)
      if is_ws(ch) or ch == ">" then break end
      i = i + 1
    end
    return input:sub(start, i - 1)
  end

  local function read_attrs()
    local attrs = {}
    while i <= len do
      skip_ws()
      if i > len then break end
      local ch = input:sub(i, i)

      if ch == ">" then
        i = i + 1
        return attrs, false
      elseif ch == "/" then
        if i < len and input:sub(i + 1, i + 1) == ">" then
          i = i + 2
          return attrs, true
        end
        i = i + 1
      else
        local name = read_attr_name()
        if name == "" then break end
        skip_ws()
        if i <= len and input:sub(i, i) == "=" then
          i = i + 1
          local value = read_attr_value()
          attrs[#attrs + 1] = { name, value }
        else
          attrs[#attrs + 1] = { name, "" }
        end
      end
    end
    return attrs, false
  end

  while i <= len do
    local ch = input:sub(i, i)

    if ch == "<" then
      flush_text()

      if input:sub(i, i + 3) == "<!--" then
        local close = input:find("-->", i + 4, true)
        if close then
          local raw = input:sub(i + 4, close - 1)
          local content = raw:match("^%s*(.-)%s*$")
          tokens[#tokens + 1] = { type = "comment", content = content }
          i = close + 3
        else
          i = len + 1
        end
      elseif input:sub(i, i + 1) == "<!" then
        local after = input:sub(i + 2)
        local dtype = after:match("^[Dd][Oo][Cc][Tt][Yy][Pp][Ee]%s+(.-)%s*>")
        if dtype then
          tokens[#tokens + 1] = { type = "doctype", content = dtype:lower() }
        end
        local close = input:find(">", i + 2, true)
        i = close and (close + 1) or (len + 1)
      elseif input:sub(i, i + 1) == "</" then
        i = i + 2
        local tag = read_tag_name()
        local close = input:find(">", i, true)
        i = close and (close + 1) or (len + 1)
        tokens[#tokens + 1] = { type = "close", tag = tag }
      else
        i = i + 1
        local tag = read_tag_name()
        local attrs, self_closing = read_attrs()

        if self_closing or void_set[tag] then
          tokens[#tokens + 1] = { type = "selfclose", tag = tag, attrs = attrs }
        else
          tokens[#tokens + 1] = { type = "open", tag = tag, attrs = attrs }
        end
      end
    else
      text_buf[#text_buf + 1] = ch
      i = i + 1
    end
  end

  flush_text()
  return tokens
end

-- Tree builder ----------------------------------------------------------------

function M.parse(input)
  local tokens = tokenize(input)

  local root = { tag = "__root__", attrs = {}, children = {} }
  local stack = { root }

  for _, tok in ipairs(tokens) do
    local top = stack[#stack]

    if tok.type == "selfclose" then
      top.children[#top.children + 1] = {
        type = "node", tag = tok.tag, attrs = tok.attrs, children = {},
      }
    elseif tok.type == "open" then
      local frame = { tag = tok.tag, attrs = tok.attrs, children = {} }
      stack[#stack + 1] = frame
    elseif tok.type == "close" then
      if #stack > 1 then
        local frame = table.remove(stack)
        local parent = stack[#stack]
        parent.children[#parent.children + 1] = {
          type = "node", tag = frame.tag, attrs = frame.attrs, children = frame.children,
        }
      end
    elseif tok.type == "text" then
      top.children[#top.children + 1] = { type = "text", content = tok.content }
    elseif tok.type == "blank" then
      top.children[#top.children + 1] = { type = "blank" }
    elseif tok.type == "comment" then
      local children = {}
      if tok.content:find("\n") then
        for line in tok.content:gmatch("[^\n]+") do
          local trimmed = line:match("^%s*(.-)%s*$")
          if trimmed ~= "" then
            children[#children + 1] = { type = "text", content = trimmed }
          end
        end
      end
      if #children == 0 then
        children = { { type = "text", content = tok.content } }
      end
      top.children[#top.children + 1] = {
        type = "node", tag = "!", attrs = {}, children = children,
      }
    elseif tok.type == "doctype" then
      top.children[#top.children + 1] = {
        type = "node", tag = "!doctype", attrs = { { tok.content, "" } }, children = {},
      }
    end
  end

  while #stack > 1 do
    local frame = table.remove(stack)
    local parent = stack[#stack]
    parent.children[#parent.children + 1] = {
      type = "node", tag = frame.tag, attrs = frame.attrs, children = frame.children,
    }
  end

  return root.children
end

return M
