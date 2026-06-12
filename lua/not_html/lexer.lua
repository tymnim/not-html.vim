local M = {}

local breaking = {
  ["{"] = true, ["}"] = true, ["("] = true, [")"] = true,
  ["~"] = true, [","] = true, [":"] = true,
  [" "] = true, ["\n"] = true, ["\r"] = true, ["\t"] = true,
}

local structural = {
  ["{"] = true, ["}"] = true, ["("] = true, [")"] = true,
  ["~"] = true, [","] = true, [":"] = true,
  ["\n"] = true, ["\n\n"] = true,
}

function M.lex(input)
  local tokens = {}
  local current = {}
  local i = 1
  local len = #input

  while i <= len do
    local ch = input:sub(i, i)

    if ch == "\\" and i < len then
      current[#current + 1] = input:sub(i + 1, i + 1)
      i = i + 2
    elseif ch == "\n" then
      if #current > 0 then
        tokens[#tokens + 1] = table.concat(current)
        current = {}
      end
      local j = i + 1
      while j <= len do
        local c = input:sub(j, j)
        if c == " " or c == "\t" or c == "\r" then
          j = j + 1
        else
          break
        end
      end
      if j <= len and input:sub(j, j) == "\n" then
        while j <= len do
          local c = input:sub(j, j)
          if c == "\n" or c == " " or c == "\t" or c == "\r" then
            j = j + 1
          else
            break
          end
        end
        tokens[#tokens + 1] = "\n\n"
        i = j
      else
        tokens[#tokens + 1] = "\n"
        i = j
      end
    elseif breaking[ch] then
      if #current > 0 then
        tokens[#tokens + 1] = table.concat(current)
        current = {}
      end
      if ch ~= " " and ch ~= "\r" and ch ~= "\t" then
        tokens[#tokens + 1] = ch
      end
      i = i + 1
    else
      current[#current + 1] = ch
      i = i + 1
    end
  end

  if #current > 0 then
    tokens[#tokens + 1] = table.concat(current)
  end

  local result = {}
  local text_parts = {}

  local function flush_text()
    if #text_parts > 0 then
      result[#result + 1] = table.concat(text_parts, " ")
      text_parts = {}
    end
  end

  for _, tok in ipairs(tokens) do
    if structural[tok] then
      flush_text()
      result[#result + 1] = tok
    else
      text_parts[#text_parts + 1] = tok
    end
  end
  flush_text()

  return result
end

return M
