-- Проверка загрузки iron_frontier без игры: требуем только те API, которые
-- мод использует при загрузке, и смотрим, что require-цепочка цела и
-- манифест/контент согласованы.
--
-- Отличие от smoke_ast: там мод ЗАПУСКАЕТ кейсы. Здесь нужно только доказать,
-- что файл грузится, require работает, sid-ы из content.lua совпадают с
-- registry, и ни один модуль не падает на старте.

local modDir = ...
assert(modDir, "укажи путь к моду")

local G = {}
for _, n in ipairs({ "assert", "error", "ipairs", "next", "pairs", "pcall", "select",
                     "tonumber", "tostring", "type", "unpack", "rawequal", "rawget", "rawlen",
                     "rawset", "setmetatable", "getmetatable", "load", "loadstring", "dofile",
                     "collectgarbage", "math", "table", "string", "os", "coroutine", "utf8" }) do
  G[n] = _G[n]
end

local LOG = {}
G.log = {
  info  = function(s) LOG[#LOG + 1] = "I " .. tostring(s) end,
  warn  = function(s) LOG[#LOG + 1] = "W " .. tostring(s) end,
  error = function(s) LOG[#LOG + 1] = "E " .. tostring(s) end,
}
local BINDS, HANDLERS = {}, {}
G.input = { bind = function(k, fn) BINDS[#BINDS + 1] = k end }
G.events = {
  on = function(name, fn)
    HANDLERS[#HANDLERS + 1] = { event = name, fn = fn }
    return #HANDLERS
  end,
  off = function() end,
  hook = function() end,
  emit = function(name, ...)
    for _, h in ipairs(HANDLERS) do
      if h.event == name then h.fn(name, ...) end
    end
  end,
}
-- Фейковые input/net для shared-окружения.
--
-- В игре input ЕСТЬ ТОЛЬКО в client-окружении (AI_MODDING_REFERENCE §4.12).
-- В shared их нет, и обращение к input роняет мод при загрузке:
--   "iron_frontier/shared.lua:80: attempt to index a nil value (global 'input')"
-- Проверено 2026-09-27. Поэтому здесь shared-окружение БЕЗ input, а net.on
-- только записывает подписки — так тест ловит именно эту ошибку.
G.input = nil                      -- НЕ задаём для shared; см. ниже
G.net = {
  on = function(name, fn) NET_ON[#NET_ON + 1] = { event = name, fn = fn } end,
  send = function(name, data) NET_SENT[#NET_SENT + 1] = { event = name, data = data } end,
  broadcast = function() end,
}
NET_ON, NET_SENT = {}, {}
G.savedata = { get = function() return nil end, set = function() end, keys = function() return {} end }

-- Мир: 6 юнитов наших sid + 1 здание + 1 чужой юнит.
-- ВАЖНО: в объекте НЕТ поля sid. В реальной схеме TObj (api/00_schema.lua:811)
-- такого поля нет вообще, sid лежит в gObjProp и достаётся через query.scan.
-- Если фейк добавит sid в объект, тест перестанет ловить именно ту ошибку,
-- из-за которой census молча находил 0 юнитов в игре.
local NEXT = 1000
local OBJ, BYSID = {}, {}
local function add(sid, bbuilding, hp)
  NEXT = NEXT + 1
  OBJ[NEXT] = { handle = NEXT, cid = 4, id = NEXT % 7, bdead = false, hp = hp or 100,
                player = 0, x = 10, z = 20, _sid = sid, _building = bbuilding or false }
  BYSID[sid] = BYSID[sid] or {}
  table.insert(BYSID[sid], NEXT)
  return NEXT
end
add("if19line"); add("if19line"); add("if19gren"); add("if19jag")
add("ir19hus"); add("cannon")            -- родное орудие
add("musketeer18")                       -- чужой юнит: роль по умолчанию
add("castle", true)                      -- здание: должно быть отброшено

local function alive(h)
  local o = OBJ[h]
  return (o ~= nil) and not o.bdead
end

-- То, что реально отдаёт objects.read: полей sid и bbuilding тут нет.
G.objects = {
  list = function()
    local out = {}
    for h in pairs(OBJ) do if alive(h) then out[#out + 1] = h end end
    table.sort(out)
    return out
  end,
  read = function(h)
    local o = alive(h) and OBJ[h] or nil
    if not o then return nil end
    return { handle = o.handle, cid = o.cid, id = o.id, hp = o.hp, pl = o.player,
             bdead = o.bdead, x = o.x, z = o.z }     -- БЕЗ sid и bbuilding
  end,
  alive = function(h) return alive(h) end,
  pos = function(h) return alive(h) and OBJ[h].x or nil, alive(h) and OBJ[h].z or nil end,
}
G.units = {
  info = function(h)
    local o = alive(h) and OBJ[h] or nil
    if not o then return nil end
    return { handle = h, sid = o._sid, player = o.player, hp = o.hp, maxhp = 100,
             x = o.x, z = o.z, dead = o.bdead }
  end,
}

-- query.scan: единственный источник sid. building=false отсекает здания.
G.query = {
  scan = function(opts)
    if SCAN_ON then
      SCAN_CALLS[#SCAN_CALLS + 1] = opts
    end
    local out = {}
    for h in pairs(OBJ) do
      local o = OBJ[h]
      if alive(h) then
        local isB = o._building
        if opts.building == true and not isB then          -- только здания
        elseif opts.building == false and isB then         -- только не-здания
        else
          out[#out + 1] = { handle = h, x = o.x, z = o.z, hp = o.hp,
                            player = o.player, sid = o._sid }
        end
      end
    end
    table.sort(out, function(a, b) return a.handle < b.handle end)
    return out
  end,
}
SCAN_CALLS, SCAN_ON = {}, true
G.balance = {
  set = function(sid, field, value)
    BALANCE[#BALANCE + 1] = { sid = sid, field = field, value = value }
  end,
  setProp = function(sid, field, value)
    BALANCE[#BALANCE + 1] = { sid = sid, field = field, value = value, prop = true }
  end,
  refresh = function() end,
}
BALANCE = {}

G.game = {
  exec = function() return "" end,
  isInGame = function() return true end,
  mode = function() return "host" end,
  side = function() return "shared" end,
}
G.mod = { id = "iron_frontier", version = "0.1.0", side = "server" }
G.player = function() return { index = 0 } end
G.require = nil

-- Окружения shared и client — как в LuaHost.cpp.
-- Разница принципиальна: input есть только в client.
local sharedEnv, clientEnv
for _, name in ipairs({ "shared", "client" }) do
  local env = {}
  for k, v in pairs(G) do env[k] = v end
  setmetatable(env, { __index = G })
  env._G = env; env._ENV = env
  if name == "shared" then
    sharedEnv = env
    env.input = nil            -- на сервере клавиш нет — ловим обращение к ним
  else
    clientEnv = env
    env.input = { bind = function(k, fn) BINDS[#BINDS + 1] = k end }
    -- В игре у клиента НЕТ game.exec: код, меняющий и читающий игру через
    -- game.exec, на клиенте не работает. Это надо воспроизводить, иначе тест
    -- не заметит, что census на клиенте считает то, что не может считать.
    env.game = { isInGame = function() return true end,
                 mode = function() return "host" end,
                 side = function() return "client" end }
  end
end

local function mkRequire(env)
  local cache = {}
  return function(name)
    local key = name
    if cache[key] then return cache[key] end
    local path = modDir .. "/" .. name .. ".lua"
    local fh = io.open(path, "rb")
    if not fh then error("cannot open " .. path, 2) end
    local code = fh:read("*a"); fh:close()
    local chunk = assert(load(code, "@" .. name .. ".lua", "t", env), "load " .. name)
    local res = chunk()
    if res == nil then res = true end
    cache[key] = res
    return res
  end
end
sharedEnv.require = mkRequire(sharedEnv)
clientEnv.require = mkRequire(clientEnv)

-- ── Загрузка ────────────────────────────────────────────────────────────────
local fails = 0
local function step(name, fn)
  local ok, err = pcall(fn)
  if ok then print(string.format("  OK    %s", name))
  else fails = fails + 1; print(string.format("  FAIL  %s\n        %s", name, tostring(err))) end
end

print("=== iron_frontier: загрузка ===")

local manifest
step("manifest.lua", function()
  local fh = assert(io.open(modDir .. "/manifest.lua", "rb"))
  local code = fh:read("*a"); fh:close()
  manifest = assert(load(code, "@manifest.lua", "t", sharedEnv))()
end)
step("манифест: поля", function()
  assert(manifest.id == "iron_frontier", "id")
  assert(manifest.shared == "shared.lua", "shared")
  assert(manifest.client == "client.lua", "client")
  assert(manifest.multiplayer == "required", "multiplayer")
end)

local IF, C
step("shared.lua", function() IF = sharedEnv.require("shared") end)
step("client.lua", function() clientEnv.require("client") end)

-- ── Поведение ────────────────────────────────────────────────────────────────
print("=== поведение ===")

step("game.start регистрирует баланс", function()
  BALANCE = {}
  sharedEnv.events.emit("game.start")
  assert(#BALANCE > 0, "balance.set ни разу не вызван")
end)

step("shared НЕ обращается к input", function()
  -- input в shared-окружении nil, поэтому сам факт загрузки доказывает,
  -- что shared.lua не биндит клавиши (иначе падение на input:80).
  assert(sharedEnv.input == nil, "в тесте input должен отсутствовать в shared")
  for _, h in ipairs(HANDLERS) do
    assert(h.event ~= "input.bind", "shared не должен подписываться на клавиши")
  end
end)

step("net: клиент просит баланс, shared отвечает", function()
  NET_SENT = {}
  local before = #BALANCE
  -- ищем обработчик if.rebalance, зарегистрированный shared-стороной
  local handler
  for _, h in ipairs(NET_ON) do
    if h.event == "if.rebalance" then handler = h.fn end
  end
  assert(handler, "shared не зарегистрировал net.on('if.rebalance')")
  handler("if.rebalance", 12345)          -- как будто пришло от игрока 12345
  assert(#BALANCE > before, "обработчик не переприменил баланс")
end)

step("баланс покрывает все 17 типов", function()
  local seen = {}
  for _, b in ipairs(BALANCE) do seen[b.sid] = true end
  local R = sharedEnv.require("lib/registry")
  for _, u in ipairs(R.UNITS) do
    assert(seen[u.sid], "нет balance.set для " .. u.sid)
  end
end)

step("перепись находит 7 юнитов, здание отброшено", function()
  C = sharedEnv.require("lib/census")
  C.rescan()
  local r = C.snapshot()
  -- 7 не-зданий: 6 наших/чужих юнитов + cannon; castle — здание, его не считаем
  assert(r.units == 7, "юнитов " .. r.units .. ", ожидалось 7")
end)

step("census берёт sid из query.scan, а не из objects.read", function()
  -- objects.read принципиально не отдаёт sid — если бы census брала его оттуда,
  -- нашлось бы 0. Здесь проверяем, что query.scan действительно вызывается.
  SCAN_CALLS = {}
  C.rescan()
  assert(#SCAN_CALLS > 0, "query.scan не вызван — census не сможет узнать sid")
  local o = OBJ[BYSID.if19line[1]]
  assert(o.sid == nil, "фейк objects.read не должен содержать sid")
end)

step("роли назначены верно", function()
  local R = sharedEnv.require("lib/registry")
  local h = BYSID.if19line[1]
  assert(C.role(h) == "line", "if19line -> " .. tostring(C.role(h)))
  assert(C.role(BYSID.if19gren[1]) == "guard", "if19gren")
  assert(C.role(BYSID.if19jag[1]) == "skirmisher", "if19jag")
  assert(C.role(BYSID.ir19hus[1]) == "cavalry_light", "ir19hus")
  assert(C.role(BYSID.cannon[1]) == "artillery", "cannon")
  -- чужой юнит без записи в registry -> по умолчанию line
  assert(C.role(BYSID.musketeer18[1]) == "line", "мушкетёр18 по умолчанию")
end)

step("isArty различает орудия", function()
  assert(C.isArty(BYSID.cannon[1]) == true, "cannon — орудие")
  assert(C.isArty(BYSID.if19line[1]) == false, "мушкетёр — не орудие")
end)

step("client НЕ умеет считать census (нет game.exec)", function()
  -- query.scan ходит в игру через game.exec, которого на клиенте нет.
  -- Значит клиент только принимает снимок по сети — это надо проверять,
  -- иначе census на клиенте вернёт пустоту без единой ошибки.
  assert(clientEnv.game.exec == nil, "в client-окружении game.exec должен отсутствовать")
  local Cc = clientEnv.require("lib/census")
  assert(Cc.canScan() == false, "client не должен считать census сам")
  Cc.rescan()
  assert(Cc.snapshot().units == 0, " census на клиенте обязан быть пустым")
  -- приём снимка по сети
  assert(Cc.accept({ units = 7, byRole = { line = 3 }, census = { if19line = 3 },
                     summary = "line=3" }) == true, "снимок не принят")
  assert(Cc.snapshot().units == 7, "снимок по сети не сохранился")
  assert(Cc.line():find("юнитов 7") ~= nil, "строка состава не собралась: " .. Cc.line())
end)

step("смерть выбрасывает из кэша после пересчёта", function()
  -- Состав строится из query.scan, а не из событий: событие может не прийти.
  -- Поэтому проверяем именно rescan — он сверяется с движком и чистит кэш.
  local h = BYSID.if19line[1]
  local before = C.snapshot().units
  assert(before == 7, "до смерти " .. before)
  OBJ[h].bdead = true
  sharedEnv.events.emit("unit.death", h)
  C.rescan()
  assert(C.snapshot().units == before - 1, "юнит не убрался после пересчёта")
  assert(C.known(h) == false, "хендль остался в кэше")
end)

step("здание не получает роль", function()
  -- castle был отброшен при rescan: хендля нет в кэше
  assert(C.known(BYSID.castle[1]) == false, "здание попало в кэш")
end)

step("save.afterload пересобирает", function()
  OBJ[BYSID.if19line[2]].bdead = true
  sharedEnv.events.emit("save.afterload")
  -- после rescan мёртвый хендль вычищен, живые на месте
  assert(C.known(BYSID.if19line[2]) == false, "мёртвый остался в кэше")
  assert(C.known(BYSID.if19gren[1]) == true, "живой выпал из кэша")
end)

step("game.tick + rescan не ломает кэш", function()
  for _ = 1, 301 do sharedEnv.events.emit("game.tick") end   -- один полный цикл
  assert(C.known(BYSID.if19gren[1]) == true, "живой выпал после тика")
end)

step("content.lua: sid совпадают с registry", function()
  local R = sharedEnv.require("lib/registry")
  local fh = assert(io.open(modDir .. "/content.lua", "rb"))
  local con = fh:read("*a"); fh:close()
  local declared = {}
  -- sid вида if19line / ir19hus / ip19jag: ДВЕ буквы, ДВЕ цифры, буквы.
  -- В шаблонах Lua %a — только буквы, %d — только цифры, поэтому порядок важен.
  for sid in con:gmatch('sid%s*=%s*"(%a%a%d%d%a+)"') do declared[sid] = true end
  for _, u in ipairs(R.UNITS) do
    assert(declared[u.sid], "юнит " .. u.sid .. " есть в registry, но не объявлен в content.lua")
  end
  local n = 0
  for _ in pairs(declared) do n = n + 1 end
  assert(n == #R.UNITS, "в content.lua " .. n .. " объявлений, в registry " .. #R.UNITS)
end)

step("content.lua: from — член своей нации", function()
  local fh = assert(io.open(modDir .. "/content.lua", "rb"))
  local con = fh:read("*a"); fh:close()
  local function words(s)
    local t = {}
    for w in s:gmatch("%S+") do t[#t + 1] = w end
    return t
  end
  -- Ростеры, выгруженные из country.script (см. разведку M0).
  local roster = {
    fra = words("chasseur kingmusketeer dragoon18fra grenadier hussar officer18"),
    rus = words("musketeer18 grenadier jagerpor cossackdon hussar officer18"),
    pru = words("musketeer18pru grenadierpru jagerpor hussarpru officer18"),
  }
  local function has(list, v)
    for _, x in ipairs(list) do if x == v then return true end end
    return false
  end
  for sid, from, nat in con:gmatch('sid%s*=%s*"(%w+)",%s*from%s*=%s*"(%w+)",%s*nations%s*=%s*{%s*"(%w+)"') do
    local list = roster[nat]
    assert(list, "неизвестная нация " .. nat .. " (у " .. sid .. ")")
    assert(has(list, from), "родитель " .. from .. " не член нации " .. nat ..
                            " — Content.cpp выдаст предупреждение (" .. sid .. ")")
  end
end)

-- ── Итог ─────────────────────────────────────────────────────────────────────
print("")
if fails == 0 then
  print(string.format("ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ (%d привязок клавиш, %d строк лога)", #BINDS, #LOG))
  os.exit(0)
end
print(string.format("ПРОВАЛОВ: %d", fails))
for _, l in ipairs(LOG) do print("  " .. l) end
os.exit(1)
