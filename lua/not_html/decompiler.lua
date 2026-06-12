local M = {}

local function escape_text(text)
  return text
    :gsub("\\", "\\\\")
    :gsub("~", "\\~")
    :gsub("{", "\\{")
    :gsub("}", "\\}")
    :gsub("%(", "\\(")
    :gsub("%)", "\\)")
    :gsub(":", "\\:")
    :gsub(",", "\\,")
end

local function escape_attr_value(value)
  return value
    :gsub("\\", "\\\\")
    :gsub("~", "\\~")
    :gsub(":", "\\:")
    :gsub(",", "\\,")
    :gsub("%(", "\\(")
    :gsub("%)", "\\)")
    :gsub("{", "\\{")
    :gsub("}", "\\}")
end

local function is_boolean_attr(name, value)
  return value == "" or value == name
end

local function format_attrs(attrs)
  if #attrs == 0 then
    return ""
  end
  local parts = {}
  for _, attr in ipairs(attrs) do
    if is_boolean_attr(attr[1], attr[2]) then
      parts[#parts + 1] = attr[1]
    else
      parts[#parts + 1] = attr[1] .. ": " .. escape_attr_value(attr[2])
    end
  end
  return "(" .. table.concat(parts, ", ") .. ")"
end

local function is_single_text(children)
  return #children == 1 and children[1].type == "text"
end

local function render_inline(children)
  local parts = {}
  for _, child in ipairs(children) do
    if child.type == "text" then
      parts[#parts + 1] = escape_text(child.content)
    else
      local sig = "~" .. child.tag .. format_attrs(child.attrs)
      if #child.children == 0 then
        parts[#parts + 1] = sig
      else
        parts[#parts + 1] = sig .. " { " .. render_inline(child.children) .. " }"
      end
    end
  end
  return table.concat(parts, " ")
end

local render_node

local function render_nodes(nodes, indent)
  local lines = {}
  for _, node in ipairs(nodes) do
    lines[#lines + 1] = render_node(node, indent)
  end
  return table.concat(lines, "\n")
end

render_node = function(node, indent)
  if node.type == "blank" then
    return ""
  end

  local prefix = string.rep(" ", indent)

  if node.type == "text" then
    return prefix .. escape_text(node.content)
  end

  local sig = prefix .. "~" .. node.tag .. format_attrs(node.attrs)

  if #node.children == 0 then
    return sig
  end

  if is_single_text(node.children) then
    return sig .. " { " .. escape_text(node.children[1].content) .. " }"
  end

  return sig .. " {\n" .. render_nodes(node.children, indent + 2) .. "\n" .. prefix .. "}"
end

function M.decompile(elements)
  return render_nodes(elements, 0)
end

return M
