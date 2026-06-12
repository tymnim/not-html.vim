local M = {}

local function parse_attributes(tokens, pos)
  local attrs = {}

  while pos <= #tokens do
    local tok = tokens[pos]

    if tok == ")" then
      return attrs, pos + 1
    elseif tok == "," then
      pos = pos + 1
    elseif tok == ":" or tok == "{" or tok == "}" or tok == "~" or tok == "(" then
      return nil, "Unexpected " .. tok .. " in attribute context"
    else
      local name = tok
      pos = pos + 1
      if pos <= #tokens and tokens[pos] == ":" then
        pos = pos + 1
        if pos > #tokens then
          return nil, "Unexpected end of input: expected attribute value"
        end
        local value = tokens[pos]
        if value == ")" or value == "(" or value == "{" or value == "}"
          or value == "~" or value == ":" or value == "," then
          return nil, "Expected attribute value, got " .. value
        end
        attrs[#attrs + 1] = { name, value }
        pos = pos + 1
      else
        attrs[#attrs + 1] = { name, "" }
      end
    end
  end

  return nil, "Unexpected end of input: expected )"
end

local parse_elements

local function parse_body(tokens, pos)
  local children, new_pos, err = parse_elements(tokens, pos)
  if not children then
    return nil, nil, err
  end
  if new_pos > #tokens then
    return nil, nil, "Unexpected end of input: expected }"
  end
  if tokens[new_pos] ~= "}" then
    return nil, nil, "Expected }, got " .. tokens[new_pos]
  end
  return children, new_pos + 1, nil
end

local function parse_element(tokens, pos)
  if pos > #tokens then
    return nil, nil, "Unexpected end of input: expected tag name after ~"
  end

  local tag_name = tokens[pos]
  pos = pos + 1
  local attrs = {}
  local children = {}

  if pos <= #tokens and tokens[pos] == "(" then
    local a, result = parse_attributes(tokens, pos + 1)
    if not a then
      return nil, nil, result
    end
    attrs = a
    pos = result
  end

  if pos <= #tokens and tokens[pos] == "{" then
    local c, new_pos, err = parse_body(tokens, pos + 1)
    if not c then
      return nil, nil, err
    end
    children = c
    pos = new_pos
  end

  return { type = "node", tag = tag_name, attrs = attrs, children = children }, pos, nil
end

parse_elements = function(tokens, pos)
  local elements = {}

  while pos <= #tokens do
    local tok = tokens[pos]

    if tok == "}" then
      return elements, pos, nil
    elseif tok == "\n\n" then
      elements[#elements + 1] = { type = "blank" }
      pos = pos + 1
    elseif tok == "\n" then
      pos = pos + 1
    elseif tok == "~" then
      local el, new_pos, err = parse_element(tokens, pos + 1)
      if not el then
        return nil, nil, err
      end
      elements[#elements + 1] = el
      pos = new_pos
    elseif tok == "(" or tok == ")" or tok == ":" or tok == "," then
      return nil, nil, "Unexpected token: " .. tok
    else
      elements[#elements + 1] = { type = "text", content = tok }
      pos = pos + 1
    end
  end

  return elements, pos, nil
end

function M.parse(tokens)
  local elements, pos, err = parse_elements(tokens, 1)
  if not elements then
    return nil, err
  end
  while pos <= #tokens and (tokens[pos] == "\n" or tokens[pos] == "\n\n") do
    pos = pos + 1
  end
  if pos <= #tokens then
    if tokens[pos] == "}" then
      return nil, "Unexpected } without matching {"
    end
    return nil, "Unexpected token at top level: " .. tokens[pos]
  end
  return elements, nil
end

return M
