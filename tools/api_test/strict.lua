-- Strict-загрузка api/*.lua: в окружении НЕТ events/net/savedata/log/ui/input.
-- Ловит главную ошибку api-модулей: обращение к модовым глобалам на верхнем
-- уровне файла (в игре их нет в базовом окружении — см. 41_status.lua:112).
--
--   lua tools/api_test/strict.lua

local here = arg[0]:match("^(.*)[/\\]") or "."
local root = here .. "/../.."

local EXEC = {}
local strict = {
    string = string, table = table, math = math, os = os, utf8 = utf8,
    coroutine = coroutine, collectgarbage = collectgarbage,
    assert = assert, error = error, ipairs = ipairs, pairs = pairs,
    next = next, pcall = pcall, xpcall = xpcall, select = select,
    tonumber = tonumber, tostring = tostring, type = type,
    rawequal = rawequal, rawget = rawget, rawset = rawset, rawlen = rawlen,
    setmetatable = setmetatable, getmetatable = getmetatable,
    game = {
        exec = function(code, arg) EXEC[#EXEC + 1] = code return "" end,
        eval = function() return "" end,
        evalInt = function() return 0 end,
        evalFloat = function() return 0 end,
        evalBool = function() return false end,
        isInGame = function() return true end,
        mode = function() return "offline" end,
    },
    native = setmetatable({}, { __index = function() return function() end end }),
    mem = {},
    steam = {},
}
strict._G = strict

local names = { "00_schema", "01_state", "02_screens_data", "03_show", "10_profile",
    "11_options", "12_saves", "13_players", "14_map", "15_screens", "17_balance",
    "18_buildings", "19_units", "20_objects", "21_abilities", "22_camera",
    "23_minimap", "24_animation", "25_effects", "26_decals", "27_world",
    "28_object", "29_pathfind", "30_terrain", "31_fow", "32_markers",
    "33_cutscene", "34_dbg", "35_netrec", "36_time", "37_sound", "38_orders",
    "39_formation", "40_weapon", "41_status", "42_targeting", "43_ai",
    "44_scenario", "45_economy", "46_panel", "47_attachments", "48_vision",
    "49_replay", "50_profiler", "51_content", "52_group", "53_behaviour",
    "54_regions", "55_tracks", "56_gui", "57_native_catalog", "58_steam",
    "60_mathx", "61_vec", "62_tablex", "63_stringx", "64_geometry", "65_scheduler",
    "66_rng", "67_query", "68_validate", "69_config", "70_color", "90_call" }

local failed = 0
for _, name in ipairs(names) do
    local chunk, err = loadfile(root .. "/api/" .. name .. ".lua", "t", strict)
    if not chunk then
        failed = failed + 1
        print("LOAD FAIL " .. name .. ": " .. tostring(err))
    else
        local ok, rerr = pcall(chunk)
        if not ok then
            failed = failed + 1
            print("RUN FAIL " .. name .. ": " .. tostring(rerr))
        end
    end
end

local function has(mod, fn)
    local t = strict[mod]
    if type(t) ~= "table" or type(t[fn]) ~= "function" then
        failed = failed + 1
        print("MISSING " .. mod .. "." .. fn)
    end
end
has("status", "installBlocker")
has("economy", "link")
has("scenario", "link")
has("panel", "link")
has("gui", "link")
has("steam", "setMatch")
if type(strict.mods) ~= "table" then
    -- mods даёт C++ в игре; здесь его нет — content порвётся только при вызове
    print("NOTE mods table absent (provided by C++ in game)")
end

print(("strict: %d module(s), %s"):format(#names, failed == 0 and "OK" or failed .. " FAILURES"))
os.exit(failed == 0 and 0 or 1)
