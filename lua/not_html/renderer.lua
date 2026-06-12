local M = {}

local void_set = {}
for _, tag in ipairs({
  "area", "base", "br", "col", "embed", "hr", "img",
  "input", "link", "meta", "source", "track", "wbr",
}) do
  void_set[tag] = true
end

local function render_attributes(attrs)
  if #attrs == 0 then
    return ""
  end
  local parts = {}
  for _, attr in ipairs(attrs) do
    if attr[2] == "" then
      parts[#parts + 1] = attr[1]
    else
      parts[#parts + 1] = attr[1] .. '="' .. attr[2] .. '"'
    end
  end
  return " " .. table.concat(parts, " ")
end

local function get_text_content(children)
  local parts = {}
  for _, child in ipairs(children) do
    if child.type == "text" then
      parts[#parts + 1] = child.content
    end
  end
  return table.concat(parts, " ")
end

local function render_element(el, indent)
  local prefix = string.rep(" ", indent)

  if el.type == "blank" then
    return ""
  end

  if el.type == "text" then
    return prefix .. el.content
  end

  if el.tag == "!doctype" then
    local parts = {}
    for _, attr in ipairs(el.attrs) do
      parts[#parts + 1] = attr[1]
    end
    return prefix .. "<!DOCTYPE " .. table.concat(parts, " ") .. ">"
  end

  if el.tag == "!" then
    local texts = {}
    for _, child in ipairs(el.children) do
      if child.type == "text" then
        texts[#texts + 1] = child.content
      end
    end
    if #texts <= 1 then
      return prefix .. "<!-- " .. (texts[1] or "") .. " -->"
    end
    local lines = {}
    for _, t in ipairs(texts) do
      lines[#lines + 1] = prefix .. "  " .. t
    end
    return prefix .. "<!--\n" .. table.concat(lines, "\n") .. "\n" .. prefix .. "-->"
  end

  local attr_str = render_attributes(el.attrs)

  if void_set[el.tag] and #el.children == 0 then
    return prefix .. "<" .. el.tag .. attr_str .. "/>"
  end

  if #el.children == 0 then
    return prefix .. "<" .. el.tag .. attr_str .. "></" .. el.tag .. ">"
  end

  local child_lines = {}
  for _, child in ipairs(el.children) do
    child_lines[#child_lines + 1] = render_element(child, indent + 2)
  end

  return prefix .. "<" .. el.tag .. attr_str .. ">\n"
    .. table.concat(child_lines, "\n") .. "\n"
    .. prefix .. "</" .. el.tag .. ">"
end

function M.render(elements)
  local parts = {}
  for _, el in ipairs(elements) do
    parts[#parts + 1] = render_element(el, 0)
  end
  return table.concat(parts, "\n")
end

return M
