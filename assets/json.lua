-- json.lua : minimal, dependency-free JSON decoder
-- Sufficient for Open-Meteo responses. null decodes to json.null (a sentinel),
-- so arrays keep their length instead of developing holes.
local json = {}
json.null = setmetatable({}, { __tostring = function() return "null" end })

local function skipws(s, i)
  local _, e = s:find("^[ \t\r\n]*", i)
  return e + 1
end

local decode_value

local function perr(i, msg) error(("json: %s at byte %d"):format(msg, i)) end

local function decode_string(s, i)
  i = i + 1 -- skip opening quote
  local buf = {}
  while true do
    local c = s:sub(i, i)
    if c == "" then perr(i, "unterminated string") end
    if c == '"' then return table.concat(buf), i + 1 end
    if c == "\\" then
      local n = s:sub(i + 1, i + 1)
      if n == "n" then buf[#buf + 1] = "\n"
      elseif n == "t" then buf[#buf + 1] = "\t"
      elseif n == "r" then buf[#buf + 1] = "\r"
      elseif n == "b" then buf[#buf + 1] = "\b"
      elseif n == "f" then buf[#buf + 1] = "\f"
      elseif n == "/" then buf[#buf + 1] = "/"
      elseif n == "\\" then buf[#buf + 1] = "\\"
      elseif n == '"' then buf[#buf + 1] = '"'
      elseif n == "u" then
        local cp = tonumber(s:sub(i + 2, i + 5), 16) or 0
        i = i + 4
        if cp < 0x80 then
          buf[#buf + 1] = string.char(cp)
        elseif cp < 0x800 then
          buf[#buf + 1] = string.char(0xC0 + math.floor(cp / 0x40), 0x80 + cp % 0x40)
        else
          buf[#buf + 1] = string.char(0xE0 + math.floor(cp / 0x1000),
            0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
        end
      else buf[#buf + 1] = n end
      i = i + 2
    else
      buf[#buf + 1] = c
      i = i + 1
    end
  end
end

local function decode_number(s, i)
  local _, e = s:find("^%-?%d+%.?%d*[eE]?[%+%-]?%d*", i)
  return tonumber(s:sub(i, e)), e + 1
end

local function decode_array(s, i)
  local arr = {}
  i = skipws(s, i + 1)
  if s:sub(i, i) == "]" then return arr, i + 1 end
  while true do
    local v
    v, i = decode_value(s, i)
    arr[#arr + 1] = v
    i = skipws(s, i)
    local c = s:sub(i, i)
    if c == "]" then return arr, i + 1 end
    if c ~= "," then perr(i, "expected ',' in array") end
    i = skipws(s, i + 1)
  end
end

local function decode_object(s, i)
  local obj = {}
  i = skipws(s, i + 1)
  if s:sub(i, i) == "}" then return obj, i + 1 end
  while true do
    if s:sub(i, i) ~= '"' then perr(i, "expected string key") end
    local k
    k, i = decode_string(s, i)
    i = skipws(s, i)
    if s:sub(i, i) ~= ":" then perr(i, "expected ':'") end
    local v
    v, i = decode_value(s, skipws(s, i + 1))
    obj[k] = v
    i = skipws(s, i)
    local c = s:sub(i, i)
    if c == "}" then return obj, i + 1 end
    if c ~= "," then perr(i, "expected ',' in object") end
    i = skipws(s, i + 1)
  end
end

decode_value = function(s, i)
  i = skipws(s, i)
  local c = s:sub(i, i)
  if c == '"' then return decode_string(s, i)
  elseif c == "{" then return decode_object(s, i)
  elseif c == "[" then return decode_array(s, i)
  elseif c == "t" then return true, i + 4
  elseif c == "f" then return false, i + 5
  elseif c == "n" then return json.null, i + 4
  else return decode_number(s, i) end
end

function json.decode(s)
  local v = decode_value(s, 1)
  return v
end

return json
