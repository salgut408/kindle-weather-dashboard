-- parse.lua — DATA LAYER: decode cached Open-Meteo JSON into flat KEY=VALUE
-- lines (a shell-sourceable "data.env") for the renderer. Keeps all data
-- shaping out of the view layer.
-- usage: luajit parse.lua <DASH_ROOT> <HOURLY_COUNT>

local root = arg[1] or "/mnt/us/dashboard"
local hours_n = tonumber(arg[2] or "6")
package.path = root .. "/assets/?.lua;" .. package.path
local json = require("json")

local f = io.open(root .. "/cache/weather.json", "r")
if not f then io.stderr:write("parse: no cache file\n"); os.exit(2) end
local raw = f:read("*a"); f:close()

local ok, data = pcall(json.decode, raw)
if not ok or type(data) ~= "table" or type(data.current) ~= "table" then
  io.stderr:write("parse: bad json\n"); os.exit(3)
end

-- helpers ------------------------------------------------------------------
local function num(x, d) if type(x) == "number" then return x else return d end end
local function round(x)
  if type(x) ~= "number" then return "" end
  return math.floor(x + 0.5)
end
local off = num(data.utc_offset_seconds, 0)
local function ldate(ts, fmt) return os.date("!" .. fmt, ts + off) end

-- WMO weather code -> short uppercase label
local WX = {
  [0]="CLEAR",[1]="MAINLY CLEAR",[2]="PARTLY CLOUDY",[3]="OVERCAST",
  [45]="FOG",[48]="RIME FOG",
  [51]="LIGHT DRIZZLE",[53]="DRIZZLE",[55]="HEAVY DRIZZLE",
  [56]="FREEZING DRIZZLE",[57]="FREEZING DRIZZLE",
  [61]="LIGHT RAIN",[63]="RAIN",[65]="HEAVY RAIN",
  [66]="FREEZING RAIN",[67]="FREEZING RAIN",
  [71]="LIGHT SNOW",[73]="SNOW",[75]="HEAVY SNOW",[77]="SNOW GRAINS",
  [80]="RAIN SHOWERS",[81]="RAIN SHOWERS",[82]="HEAVY SHOWERS",
  [85]="SNOW SHOWERS",[86]="SNOW SHOWERS",
  [95]="THUNDERSTORM",[96]="THUNDERSTORM",[99]="THUNDERSTORM",
}
local function wx(code) return WX[code] or "—" end

-- UTF-8 encode a codepoint (for Nerd Font weather glyphs)
local function utf8(cp)
  if cp < 0x80 then return string.char(cp) end
  if cp < 0x800 then
    return string.char(0xC0 + math.floor(cp/0x40), 0x80 + cp%0x40)
  end
  return string.char(0xE0 + math.floor(cp/0x1000),
                     0x80 + math.floor(cp/0x40) % 0x40,
                     0x80 + cp % 0x40)
end

-- WMO code (+ day/night) -> Nerd Font weather glyph codepoint
local function wxicon(c, day)
  if c == 0 or c == 1 then return day == 1 and 0xE30D or 0xE32B  -- clear
  elseif c == 2 then return 0xE302                               -- partly cloudy
  elseif c == 3 then return 0xE312                               -- overcast
  elseif c == 45 or c == 48 then return 0xE313                   -- fog
  elseif c >= 51 and c <= 57 then return 0xE31B                  -- drizzle
  elseif c >= 61 and c <= 67 then return 0xE318                  -- rain
  elseif c >= 71 and c <= 77 then return 0xE31A                  -- snow
  elseif c >= 80 and c <= 82 then return 0xE319                  -- rain showers
  elseif c >= 85 and c <= 86 then return 0xE31A                  -- snow showers
  elseif c >= 95 then return 0xE31D                              -- thunderstorm
  else return 0xE33D end                                         -- default: cloud
end

-- output -------------------------------------------------------------------
local out = {}
local function put(k, v) out[#out + 1] = k .. "=" .. tostring(v) end
local function putq(k, v) out[#out + 1] = k .. '="' .. tostring(v):gsub('"', "") .. '"' end

local cur = data.current
put("CUR_TEMP",  round(num(cur.temperature_2m, 0)))
put("CUR_FEELS", round(num(cur.apparent_temperature, 0)))
put("CUR_HUM",   round(num(cur.relative_humidity_2m, 0)))
put("CUR_WIND",  round(num(cur.wind_speed_10m, 0)))
putq("CUR_COND", wx(num(cur.weather_code, -1)))
putq("CUR_ICON", utf8(wxicon(num(cur.weather_code, -1), num(cur.is_day, 1))))
put("CUR_CODE",  num(cur.weather_code, -1))   -- raw WMO code (for outfit picker)
put("CUR_ISDAY", num(cur.is_day, 1))          -- 1 day / 0 night
local cts = num(cur.time, os.time())
putq("CUR_TIME", ldate(cts, "%-I:%M %p"))
putq("CUR_DATE", string.upper(ldate(cts, "%a %-d %b")))

local d = data.daily
if type(d) == "table" and type(d.time) == "table" then
  put("TODAY_HI",  round(num((d.temperature_2m_max or {})[1])))
  put("TODAY_LO",  round(num((d.temperature_2m_min or {})[1])))
  put("TODAY_POP", round(num((d.precipitation_probability_max or {})[1], 0)))
end

-- hourly: start at the first slot >= current time
local h = data.hourly
if type(h) == "table" and type(h.time) == "table" then
  local start = 1
  for i = 1, #h.time do
    if num(h.time[i], 0) >= cts then start = i; break end
  end
  local T, P, PP = {}, {}, {}
  for k = 0, hours_n - 1 do
    local i = start + k
    if h.time[i] then
      T[#T + 1]  = ldate(num(h.time[i], 0), "%-I%p")
      P[#P + 1]  = round(num((h.temperature_2m or {})[i], 0))
      PP[#PP + 1] = round(num((h.precipitation_probability or {})[i], 0))
    end
  end
  put("HOURLY_N", #T)
  putq("H_TIME", table.concat(T, " "))
  putq("H_TEMP", table.concat(P, " "))
  putq("H_POP",  table.concat(PP, " "))
end

-- daily 5-day
if type(d) == "table" and type(d.time) == "table" then
  local DY, HI, LO, DP = {}, {}, {}, {}
  for i = 1, #d.time do
    DY[#DY + 1] = string.upper(ldate(num(d.time[i], 0), "%a"))
    HI[#HI + 1] = round(num((d.temperature_2m_max or {})[i], 0))
    LO[#LO + 1] = round(num((d.temperature_2m_min or {})[i], 0))
    DP[#DP + 1] = round(num((d.precipitation_probability_max or {})[i], 0))
  end
  put("DAILY_N", #DY)
  putq("D_DAY", table.concat(DY, " "))
  putq("D_HI",  table.concat(HI, " "))
  putq("D_LO",  table.concat(LO, " "))
  putq("D_POP", table.concat(DP, " "))
end

io.write(table.concat(out, "\n"), "\n")
