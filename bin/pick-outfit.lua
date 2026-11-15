-- pick-outfit.lua — SELECTION LAYER: weather situation -> character outfit.
-- Pure Lua (runs on the Kindle's luajit and on the Mac for testing). Reads the
-- weather values from data.env + the outfit catalog (manifest.tsv), applies the
-- rules in "Weather Character Outfit System", and prints `CHAR_IMG="..."` (plus
-- a couple of debug vars) to stdout for dashboard.sh to append to data.env.
--
-- It is independent of rendering: it only decides WHICH image, never draws.
--
-- usage: luajit pick-outfit.lua <DASH_ROOT> [data.env path]
-- tunables via env: WIND_THRESH HARD_WIND HARD_WIND_SHIFT OUTFIT_HISTORY_N
--                   OUTFIT_STABILITY_HOURS OUTFIT_NO_RANDOM(for deterministic tests)

local root    = arg[1] or "/mnt/us/dashboard"
local env_in  = arg[2] or (root .. "/cache/data.env")

local function getenv_n(name, default)
  local v = tonumber(os.getenv(name) or "")
  if v == nil then return default else return v end
end
local WIND_THRESH    = getenv_n("WIND_THRESH", 16)
local HARD_WIND      = getenv_n("HARD_WIND", 28)
local HARD_SHIFT     = getenv_n("HARD_WIND_SHIFT", 1)
local HISTORY_N      = getenv_n("OUTFIT_HISTORY_N", 5)
local STABILITY_SEC  = getenv_n("OUTFIT_STABILITY_HOURS", 3) * 3600
local NO_RANDOM      = (os.getenv("OUTFIT_NO_RANDOM") == "1")  -- deterministic tests

local CACHE   = root .. "/cache"
local HISTF   = CACHE .. "/outfit_history"   -- newline list of recent ids
local STATEF  = CACHE .. "/outfit_state"     -- SIG / ID / FILE / TS

-- ---------- helpers ----------
local function exists(p) local f = io.open(p, "r"); if f then f:close(); return true end return false end
local function readfile(p) local f = io.open(p, "r"); if not f then return nil end local s = f:read("*a"); f:close(); return (s:gsub("\r", "")) end  -- tolerate CRLF manifests/env
local function writefile(p, s) local f = io.open(p, "w"); if not f then return end f:write(s); f:close() end

-- read a KEY=VALUE env file into a table (handles optional quotes)
local function read_env(p)
  local t, s = {}, readfile(p)
  if not s then return t end
  for line in s:gmatch("[^\n]+") do
    local k, v = line:match('^([%w_]+)=(.*)$')
    if k then v = v:gsub('^"(.*)"$', "%1"); t[k] = v end
  end
  return t
end

-- ---------- weather -> situation ----------
local BANDS = { "very_very_cold","very_cold","cold","chilly","cool","mild","warm","hot","very_hot" }
local function band_for(feels)
  if feels <  0 then return "very_very_cold"
  elseif feels < 15 then return "very_cold"
  elseif feels < 30 then return "cold"
  elseif feels < 40 then return "chilly"
  elseif feels < 50 then return "cool"
  elseif feels < 60 then return "mild"
  elseif feels < 70 then return "warm"
  elseif feels < 85 then return "hot"
  else return "very_hot" end
end
local function colder(band)
  for i, b in ipairs(BANDS) do if b == band then return BANDS[math.max(1, i - 1)] end end
  return band
end
local function is_rain(c) return (c >= 51 and c <= 67) or (c >= 80 and c <= 82) end
local function is_snow(c) return (c >= 71 and c <= 77) or (c >= 85 and c <= 86) end
local function is_clear(c) return c == 0 or c == 1 end

-- ---------- load manifest ----------
local function load_manifest(path)
  local s = readfile(path)
  if not s then return nil, "no manifest at " .. path end
  local rows = {}
  for line in s:gmatch("[^\n]+") do
    if not line:match("^#") and not line:match("^id\t") then
      local c = {}
      for field in (line .. "\t"):gmatch("([^\t]*)\t") do c[#c + 1] = field end
      if #c >= 9 then
        rows[#rows + 1] = {
          id = c[1], band = c[2],
          rain = c[3] == "1", snow = c[4] == "1", wind = c[5] == "1",
          sun = c[6] == "1", night = c[7] == "1",
          weight = tonumber(c[8]) or 1, file = c[9],
        }
      end
    end
  end
  return rows
end

-- ---------- history (ring buffer of ids) ----------
local function load_history()
  local t, s = {}, readfile(HISTF)
  if s then for id in s:gmatch("[^\n]+") do t[#t + 1] = id end end
  return t
end
local function save_history(list, newid)
  local out = { newid }
  for _, id in ipairs(list) do
    if id ~= newid and #out < HISTORY_N then out[#out + 1] = id end
  end
  writefile(HISTF, table.concat(out, "\n") .. "\n")
end
local function in_list(list, id) for _, x in ipairs(list) do if x == id then return true end end return false end

-- ---------- main ----------
local w = read_env(env_in)
local feels = tonumber(w.CUR_FEELS) or tonumber(w.CUR_TEMP)
local wind  = tonumber(w.CUR_WIND) or 0
local code  = tonumber(w.CUR_CODE) or -1
local isday = tonumber(w.CUR_ISDAY) or 1

if feels == nil then
  io.stderr:write("pick-outfit: no feels-like/temp — skipping character\n")
  print('CHAR_IMG=""'); os.exit(0)   -- graceful: dashboard just omits the character
end

local manifest, merr = load_manifest(root .. "/assets/character/manifest.tsv")
if not manifest then io.stderr:write("pick-outfit: " .. tostring(merr) .. "\n"); print('CHAR_IMG=""'); os.exit(0) end

-- situation
local band = band_for(feels)
if HARD_SHIFT == 1 and wind >= HARD_WIND then band = colder(band) end
local snow  = is_snow(code)
local rain  = is_rain(code)
local windy = wind >= WIND_THRESH
local sunny = is_clear(code) and isday == 1
local night = isday == 0

-- situation signature: changing any of these can change the outfit
local sig = string.format("%s|%d%d%d%d%d", band,
  snow and 1 or 0, rain and 1 or 0, windy and 1 or 0, sunny and 1 or 0, night and 1 or 0)

-- STABILITY: same situation + within window + file still there => keep last outfit
local st = read_env(STATEF)
if st.SIG == sig and st.FILE and exists(root .. "/" .. st.FILE) then
  local age = os.time() - (tonumber(st.TS) or 0)
  if age < STABILITY_SEC then
    print('CHAR_IMG="' .. st.FILE .. '"')
    print('CHAR_ID="' .. (st.ID or "") .. '"')
    print('CHAR_BAND="' .. band .. '"')
    os.exit(0)
  end
end

-- build candidate pool (rain/snow take priority; wind is a preference)
local pool = {}
local function add_where(pred) for _, r in ipairs(manifest) do if pred(r) then pool[#pool + 1] = r end end end
if snow then
  add_where(function(r) return r.snow end)
elseif rain then
  add_where(function(r) return r.rain end)
else
  add_where(function(r) return r.band == band end)
  if windy then add_where(function(r) return r.band == "special" and r.wind end) end
end
-- fallback if a band somehow has no art
if #pool == 0 then add_where(function(r) return r.band == band end) end
if #pool == 0 then print('CHAR_IMG=""'); os.exit(0) end

-- keep only outfits whose file actually exists; graceful if some are missing
local present = {}
for _, r in ipairs(pool) do if exists(root .. "/" .. r.file) then present[#present + 1] = r end end
if #present == 0 then io.stderr:write("pick-outfit: no outfit files on disk\n"); print('CHAR_IMG=""'); os.exit(0) end
pool = present

-- score: suitability for the active modifiers (+ weight)
local function score(r)
  local s = r.weight
  if snow and r.snow then s = s + 2 end
  if rain and r.rain then s = s + 2 end
  if windy and r.wind then s = s + 1 end
  if sunny and r.sun then s = s + 1 end
  if night and r.night then s = s + 1 end
  return s
end

-- variety: drop recently-used ids, unless that empties the pool (graceful)
local history = load_history()
local candidates = {}
for _, r in ipairs(pool) do if not in_list(history, r.id) then candidates[#candidates + 1] = r end end
if #candidates == 0 then
  -- fewer suitable outfits than history → reuse, but still avoid the IMMEDIATE repeat
  local last = history[1]
  for _, r in ipairs(pool) do if r.id ~= last then candidates[#candidates + 1] = r end end
  if #candidates == 0 then candidates = pool end
end

-- weighted-random by score (deterministic in tests)
local chosen
if NO_RANDOM then
  local best = candidates[1]
  for _, r in ipairs(candidates) do if score(r) > score(best) then best = r end end
  chosen = best
else
  math.randomseed(os.time() + (tonumber((os.clock() * 1e6)) or 0))
  local total = 0
  for _, r in ipairs(candidates) do total = total + score(r) end
  local pick = math.random() * total
  for _, r in ipairs(candidates) do pick = pick - score(r); if pick <= 0 then chosen = r; break end end
  chosen = chosen or candidates[#candidates]
end

-- persist state + history, then emit
writefile(STATEF, string.format("SIG=%s\nID=%s\nFILE=%s\nTS=%d\n", sig, chosen.id, chosen.file, os.time()))
save_history(history, chosen.id)

print('CHAR_IMG="' .. chosen.file .. '"')
print('CHAR_ID="' .. chosen.id .. '"')
print('CHAR_BAND="' .. band .. '"')
