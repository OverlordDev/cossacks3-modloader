-- Подставная игра для проверки api/*.lua без запуска Cossacks 3.
--
-- Эмулирует то, на чём стоит библиотека: game.eval*, game.exec (как их понимает модлоадер) и
-- несколько нативов. Состояние — обычная таблица FAKE, пути вида gMap.players[2].name
-- разбираются по ней.

FAKE = {
    gProfile = { name = "Illia", sndmaster = 0.75, sndmusic = 0.5, bclipmouse = true, igamespeed = 2, lang = "ru" },
    gProfileTmp = { name = "Illia", sndmaster = 0.75 },
    gMap = {
        name = "random", gamestage = 1, brating = false,
        settings = {
            gen = { mapsize = 1, season = 0, terraintype = 2, relieftype = 1,
                    resourcestart = 3, resourcemines = 2, randkey0 = 11, randkey1 = 22 },
            additional = { peacetime = 10, teams = 1 },
        },
        players = {},
    },
}
for i = 0, 11 do
    FAKE.gMap.players[i] = { id = i, name = "p" .. i, team = i % 2, color = i, bexists = i < 3,
                             bai = i > 0, bhuman = i == 0, startx = i * 1.5, starty = 0 }
end

-- Баланс: один тип юнита (нация 4, номер 12) и его статы у каждого игрока.
FAKE.gObjProp = { [4] = { [12] = { sid = "rus_strelets", vision = 800, radius = 1.5 } } }
FAKE.gPlayer = {}
for p = 0, 11 do
    FAKE.gPlayer[p] = { objbase = { [4] = { [12] = {
        sid = "rus_strelets", maxhp = 100, speed = 2.5,
        price = { [0] = 10, 20, 0, 5, 0, 0, 0 },
        weapon = { [0] = { damage = 10, radiusmax = 400, pause = 1.2 } },
    } } } }
end

local function lookup(path, assign)
    local node, key = FAKE, nil
    local head, rest = path:match("^%s*([%a_][%w_]*)(.*)$")
    local parts = { head }
    for token in rest:gmatch("[%.%[][^%.%[]*") do parts[#parts + 1] = token end
    for i, p in ipairs(parts) do
        local k = p
        if p:sub(1, 1) == "." then k = p:sub(2) elseif p:sub(1, 1) == "[" then k = tonumber(p:match("%d+")) end
        if i == #parts and assign ~= nil then node[k] = assign.value return end
        node = node[k]
        -- Поля, которых нет в подставном состоянии, игра отдала бы нулём/пустым — так же и тут.
        if node == nil then return nil end
    end
    return node
end

local function pascal(part)
    local fn, arg = part:match("^%s*(%a+)%((.*)%)%s*$")
    if fn == "IntToStr" then return tostring(math.floor(lookup(arg) or 0)) end
    -- В русской локали FloatToStr ставит запятую — проверяем, что api это переваривает.
    if fn == "FloatToStr" then return (tostring(lookup(arg) or 0):gsub("%.", ",")) end
    if fn == "BoolToStr" then return lookup(arg) and "True" or "False" end
    return tostring(lookup(part) or "")
end

game = {}
function game.eval(expr)
    local out = {}
    for part in (expr .. "+#1+"):gmatch("(.-)%+#1%+") do out[#out + 1] = pascal(part) end
    return table.concat(out, "\1")
end
function game.evalInt(p) return math.floor(lookup(p)) end
function game.evalFloat(p) return lookup(p) + 0.0 end
function game.evalBool(p) return lookup(p) and true or false end
function game.isInGame() return true end

EXEC_LOG = {}
function game.exec(code, arg)
    EXEC_LOG[#EXEC_LOG + 1] = code
    if code:find("gObjProp%[c%]%[u%]%.sid") then -- balance: цикл по всем типам
        return "4,12,rus_strelets;"
    end
    local path, rhs = code:match("^(.-) := (.-);$")
    if not path then return "" end
    local value
    if rhs == "StrToInt(ML_ARG)" then value = tonumber(arg)
    elseif rhs == "StrToInt(ML_ARG) / 1000000" then value = tonumber(arg) / 1000000
    elseif rhs == "(ML_ARG = '1')" then value = arg == "1"
    elseif rhs == "ML_ARG" then value = arg
    end
    lookup(path, { value = value })
    return ""
end

SAVES = { { "autosave", "20.09.26 12:40" }, { "megacool", "07.09.26 22:27" } }
native = {
    UserGetProfileSavesCount = function() return #SAVES end,
    UserGetProfileSaveByIndex = function(i) return SAVES[i + 1][1] end,
    UserGetProfileSaveDateByIndex = function(i) return SAVES[i + 1][2] end,
    UserGetProfileReplaysCount = function() return 0 end,
    UserProfileLoadMap = function(name) LOADED = name end,
    UserProfileDeleteMap = function(name) DELETED = name end,
    GetProjectOptionAsBoolean = function() return true end,
    GetProjectOptionAsString = function() return "sm4096" end,
    GetProjectOptionAsFloat = function() return 0.5 end,
    GetPlayerIndexInterfaceIO = function() return 0 end,
}
function player(i) return { food = 100, wood = 200, stone = 300, gold = 400, iron = 500, coal = 600 } end
