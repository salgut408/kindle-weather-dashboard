-- parse-nfl.lua — DATA LAYER: decode ESPN NFL scoreboard into KEY=VALUE lines
-- appended to data.env. Emits NFL_WEEK, NFL_N and NFL_G1..NFL_GN preformatted
-- game lines, ordered live -> upcoming -> final.
-- usage: luajit parse-nfl.lua <DASH_ROOT> <COUNT>
local root = arg[1] or "/mnt/us/dashboard"
local N = tonumber(arg[2] or "4")
package.path = root .. "/assets/?.lua;" .. package.path
local json = require("json")

local f = io.open(root .. "/cache/nfl.json", "r")
if not f then os.exit(2) end
local raw = f:read("*a"); f:close()
local ok, data = pcall(json.decode, raw)
if not ok or type(data) ~= "table" then os.exit(3) end

local function S(x) return type(x) == "string" and x or "" end
local function tbl(x) return type(x) == "table" and x or {} end

local games = {}
for _, e in ipairs(tbl(data.events)) do
  local comp = tbl(e.competitions)[1]
  local st = tbl(tbl(e.status).type)
  if comp and type(comp.competitors) == "table" then
    local home, away
    for _, c in ipairs(comp.competitors) do
      if c.homeAway == "home" then home = c elseif c.homeAway == "away" then away = c end
    end
    if home and away then
      local hA = S(tbl(home.team).abbreviation)
      local aA = S(tbl(away.team).abbreviation)
      local state = S(st.state)                 -- pre / in / post
      local detail = S(st.shortDetail)
      local line
      if state == "pre" then
        -- "11/15 - 1:00 PM EST" -> "11/15  1:00 PM"
        local when = detail:gsub(" %- ", "  "):gsub(" E[SD]T", ""):gsub(" [PMC][SD]T", "")
        line = string.format("%s @ %s   %s", aA, hA, when)
      else
        local status = (state == "post") and "FINAL" or string.upper(detail)
        line = string.format("%s %s    %s %s    %s", aA, S(away.score), hA, S(home.score), status)
      end
      games[#games + 1] = { state = state, date = S(e.date), line = line }
    end
  end
end

local rank = { ["in"] = 1, pre = 2, post = 3 }
table.sort(games, function(a, b)
  local ra, rb = rank[a.state] or 9, rank[b.state] or 9
  if ra ~= rb then return ra < rb end
  if a.state == "post" then return a.date > b.date end  -- most recent finals first
  return a.date < b.date                                -- soonest upcoming first
end)

local out = {}
out[#out + 1] = 'NFL_WEEK="WEEK ' .. tostring(tbl(data.week).number or "") .. '"'
local n = math.min(N, #games)
out[#out + 1] = "NFL_N=" .. n
for i = 1, n do
  out[#out + 1] = string.format('NFL_G%d="%s"', i, (games[i].line:gsub('"', "")))
end
io.write(table.concat(out, "\n"), "\n")
