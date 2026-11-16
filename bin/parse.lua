-- parse.lua — DATA LAYER: decode cached NWS JSON (obs/hourly/daily) into a flat
-- KEY=VALUE "data.env" for the renderer + the outfit picker. Emits the same keys
-- the Open-Meteo version did, so render.sh and pick-outfit.lua are unchanged.
-- usage: luajit parse.lua <DASH_ROOT> <HOURLY_COUNT>
local root     = arg[1] or "/mnt/us/dashboard"
local hours_n  = tonumber(arg[2] or "6")
package.path   = root .. "/assets/?.lua;" .. package.path
local json     = require("json")

local function readjson(p)
  local f = io.open(p, "r"); if not f then return nil end
  local s = f:read("*a"); f:close()
  local ok, d = pcall(json.decode, s)
  if ok then return d end
end
local obs    = readjson(root .. "/cache/obs.json")
local hourly = readjson(root .. "/cache/hourly.json")
local daily  = readjson(root .. "/cache/daily.json")
if not (obs and hourly and daily) then io.stderr:write("parse: missing NWS cache\n"); os.exit(2) end

local function num(x, d) if type(x) == "number" then return x else return d end end
local function round(x) if type(x) ~= "number" then return "" end return math.floor(x + 0.5) end
local function c2f(c) if type(c) ~= "number" then return nil end return c * 9 / 5 + 32 end
local function kmh2mph(k) if type(k) ~= "number" then return 0 end return k * 0.621371 end
local function compass(deg)
  if type(deg) ~= "number" then return "" end
  local dirs = { "N","NE","E","SE","S","SW","W","NW" }
  return dirs[(math.floor((deg + 22.5) / 45) % 8) + 1]
end
local function utf8(cp)
  if cp < 0x80 then return string.char(cp) end
  return string.char(0xE0 + math.floor(cp/0x1000), 0x80 + math.floor(cp/0x40)%0x40, 0x80 + cp%0x40)
end

-- NWS "shortForecast" text -> {label, wmo_code, day_glyph, night_glyph}
local function classify(txt)
  txt = string.lower(txt or "")
  local function has(p) return txt:find(p, 1, true) ~= nil end
  if has("thunder")                           then return "THUNDERSTORM", 95, 0xE31D, 0xE31D
  elseif has("snow") or has("flurr") or has("sleet") or has("wintry") or has("ice")
                                              then return "SNOW", 73, 0xE31A, 0xE31A
  elseif has("freezing")                      then return "FREEZING RAIN", 66, 0xE318, 0xE318
  elseif has("rain") or has("shower") or has("drizzle")
                                              then return "RAIN", 61, 0xE318, 0xE318
  elseif has("fog") or has("haze") or has("mist") or has("smoke")
                                              then return "FOG", 45, 0xE313, 0xE313
  elseif has("partly") or has("mostly sunny") or has("mostly clear")
                                              then return "PARTLY CLOUDY", 2, 0xE302, 0xE32B
  elseif has("mostly cloudy") or has("overcast") or has("cloudy")
                                              then return "CLOUDY", 3, 0xE312, 0xE312
  elseif has("clear") or has("sunny") or has("fair")
                                              then return "CLEAR", 0, 0xE30D, 0xE32B
  else return "—", 3, 0xE33D, 0xE33D end
end

-- local tz offset (hours) parsed from an NWS startTime like ...T22:00:00-06:00
local function tz_offset(iso)
  local sign, h = iso:match("([%+%-])(%d%d):%d%d$")
  if not sign then return 0 end
  local off = tonumber(h); if sign == "-" then off = -off end
  return off
end
-- "2026-11-15T22:00:00-06:00" -> "10PM"
local function hour_label(iso)
  local h = tonumber(iso:match("T(%d%d):"))
  if not h then return "" end
  local ap = h < 12 and "AM" or "PM"
  local h12 = h % 12; if h12 == 0 then h12 = 12 end
  return string.format("%d%s", h12, ap)
end
-- weekday abbrev from an ISO date (its own local day)
local function weekday(iso)
  local y, m, d = iso:match("^(%d+)%-(%d+)%-(%d+)")
  if not y then return "" end
  return string.upper(os.date("!%a", os.time({ year = y, month = m, day = d, hour = 12 })))
end

-- convert a UTC ISO time (e.g. 2026-11-15T22:29:00+00:00) to local "H:MM AM/PM"
local function utc_to_local(iso, tzh)
  local h, m = iso:match("T(%d%d):(%d%d)")
  if not h then return "" end
  local mins = (tonumber(h) * 60 + tonumber(m) + tzh * 60) % 1440
  local hh = math.floor(mins / 60); local mm = mins % 60
  local ap = hh < 12 and "AM" or "PM"; local h12 = hh % 12; if h12 == 0 then h12 = 12 end
  return string.format("%d:%02d %s", h12, mm, ap)
end

-- ---------- build output ----------
local out = {}
local function put(k, v) out[#out + 1] = k .. "=" .. tostring(v) end
local function putq(k, v) out[#out + 1] = k .. '="' .. tostring(v):gsub('"', "") .. '"' end

local op = obs.properties or {}
local hp = (hourly.properties or {}).periods or {}
local dp = (daily.properties or {}).periods or {}
local tzh = tz_offset((hp[1] or {}).startTime or "-06:00")
local now_day = (hp[1] or {}).isDaytime   -- NWS tells us day/night for the current hour

-- current conditions (observed)
local t_c = num((op.temperature or {}).value)
local feels_c = num((op.windChill or {}).value) or num((op.heatIndex or {}).value)
local cond_txt = (hp[1] or {}).shortForecast or op.textDescription or ""
local label, code, gday, gnight = classify(cond_txt)
put("CUR_TEMP",  round(c2f(t_c) or 0))
put("CUR_FEELS", round(c2f(feels_c) or c2f(t_c) or 0))
put("CUR_HUM",   round(num((op.relativeHumidity or {}).value, 0)))
put("CUR_WIND",  round(kmh2mph(num((op.windSpeed or {}).value, 0))))
putq("CUR_WDIR", compass(num((op.windDirection or {}).value)))
putq("CUR_COND", label)
put("CUR_CODE",  code)
put("CUR_ISDAY", now_day and 1 or 0)
putq("CUR_ICON", utf8(now_day and gday or gnight))
putq("CUR_TIME", os.date("%-I:%M %p"))
putq("CUR_DATE", string.upper(os.date("%a %-d %b")))

-- today's hi/lo from the next 24 hourly periods (robust, always available)
do
  local hi, lo, pmax
  for i = 1, math.min(24, #hp) do
    local t = num(hp[i].temperature)
    if t then hi = (hi and math.max(hi, t)) or t; lo = (lo and math.min(lo, t)) or t end
    local pp = num((hp[i].probabilityOfPrecipitation or {}).value, 0)
    pmax = (pmax and math.max(pmax, pp)) or pp
  end
  put("TODAY_HI", round(hi)); put("TODAY_LO", round(lo)); put("TODAY_POP", round(pmax or 0))
end

-- sunrise / sunset (NWS has none) — from cached sun.json (UTC), converted to local
do
  local sun = readjson(root .. "/cache/sun.json")
  local r = sun and sun.results
  if r then
    if r.sunrise then putq("SUNRISE", utc_to_local(r.sunrise, tzh)) end
    if r.sunset  then putq("SUNSET",  utc_to_local(r.sunset,  tzh)) end
  end
end

-- hourly row: next N
do
  local T, P, PP = {}, {}, {}
  for i = 1, math.min(hours_n, #hp) do
    T[#T+1]  = hour_label(hp[i].startTime or "")
    P[#P+1]  = round(num(hp[i].temperature, 0))
    PP[#PP+1] = round(num((hp[i].probabilityOfPrecipitation or {}).value, 0))
  end
  put("HOURLY_N", #T)
  putq("H_TIME", table.concat(T, " "))
  putq("H_TEMP", table.concat(P, " "))
  putq("H_POP",  table.concat(PP, " "))
end

-- 5-day: pair each daytime period (high) with the following night (low)
do
  local DY, HI, LO, DP = {}, {}, {}, {}
  local i = 1
  while i <= #dp and #DY < 5 do
    local p = dp[i]
    if p.isDaytime then
      local hi = round(num(p.temperature))
      local pop = num((p.probabilityOfPrecipitation or {}).value, 0)
      local lo = ""
      local np = dp[i + 1]
      if np and not np.isDaytime then
        lo = round(num(np.temperature))
        pop = math.max(pop, num((np.probabilityOfPrecipitation or {}).value, 0))
        i = i + 2
      else i = i + 1 end
      DY[#DY+1] = weekday(p.startTime or ""); HI[#HI+1] = hi; LO[#LO+1] = lo; DP[#DP+1] = round(pop)
    else i = i + 1 end
  end
  put("DAILY_N", #DY)
  putq("D_DAY", table.concat(DY, " "))
  putq("D_HI",  table.concat(HI, " "))
  putq("D_LO",  table.concat(LO, " "))
  putq("D_POP", table.concat(DP, " "))
end

io.write(table.concat(out, "\n"), "\n")
