-- Дымовой тест стенда вне игры: грузим harness + обе половины мода в песочнице
-- с настоящими чистыми api-модулями (mathx/vec/tablex/stringx/geometry/rng/validate/color)
-- и прогоняем раздел util по-настоящему.
--
-- Запуск (из tools/api_test):  lua.exe smoke_ast.lua <путь-к-моду>

local apiDir, modDir = ...
assert(apiDir and modDir, "usage: smoke_ast.lua <api-dir> <mod-dir>")

local G = {}
local function stub(t)
  return setmetatable(t or {}, { __index = function() return function() return nil end end })
end

-- Стандартная библиотека — нужна и api-модулям, и кейсам.
for _, n in ipairs({ "assert", "error", "ipairs", "next", "pairs", "pcall", "xpcall", "select",
    "tonumber", "tostring", "type", "unpack", "rawequal", "rawget", "rawlen", "rawset",
    "setmetatable", "getmetatable", "load", "loadstring", "dofile", "collectgarbage",
    "math", "table", "string", "os", "coroutine", "utf8" }) do
  G[n] = _G[n]
end

-- База: всё, что нужно при ЗАГРУЗКЕ файлов мода.
G.game    = { exec = function() return "" end, isInGame = function() return false end,
              mode = function() return "offline" end, side = function() return "shared" end }
G.input   = { bind = function() end }
G.events  = { on = function() return 1 end, off = function() end, hook = function() end }
G.log     = { info = function() end, warn = function() end, error = function() end }
G.net     = { on = function() end, send = function() end, broadcast = function() end }
G.savedata = { get = function() return nil end, set = function() end, keys = function() return {} end }
G.native  = stub()

-- Состоятельный фейковый ui. Раньше здесь был stub(), и КАЖДЫЙ вызов ui.* отдавал
-- nil, из-за чего кейсы visual.gui / visual.panel падали с "api вернул nil" —
-- то есть smoke молча не проверял самые опасные байтовые API (имена элементов,
-- parent, координаты). Счётчик хендлей + реестр позволяют этим кейсам
-- реально отработать и поймать, например, регресс с точкой в имени.
local uiNext, uiReg = 100, {}
local function uiKey(kind, opts)
  -- Имя элемента — часть КОНТРАКТА: игра отклоняет имя с точкой
  -- (реальный баг 2026-09-27: os.clock() давал "lbl67.328" -> ui.text failed).
  -- Фейк повторяет это поведение, чтобы регресс ловился без запуска игры.
  local nm = opts.name
  if type(nm) == "string" and nm:find("[^%w_%-]") then
    error(string.format("ui.%s: недопустимое имя '%s' (точка/пробел)", kind, nm), 2)
  end
  uiNext = uiNext + 1
  local h = uiNext
  uiReg[h] = { kind = kind, name = nm, x = opts.x or 0, y = opts.y or 0,
               w = opts.w or 0, h = opts.h or 0, text = opts.text or "",
               parent = opts.parent or 0, onClick = opts.onClick, visible = true }
  return h
end
G.ui = {
  container = function(o) return uiKey("container", o) end,
  button    = function(o) return uiKey("button", o) end,
  text      = function(o) return uiKey("text", o) end,
  image     = function(o) return uiKey("image", o) end,
  onClick   = function(h, fn) if uiReg[h] then uiReg[h].onClick = fn end end,
  find      = function(name) for h, e in pairs(uiReg) do if e.name == name then return h end end end,
  setPosition = function(h, x, y) if uiReg[h] then uiReg[h].x, uiReg[h].y = x, y end end,
  getPosition = function(h) local e = uiReg[h]; return e and e.x or 0, e and e.y or 0 end,
  setText     = function(h, s) if uiReg[h] then uiReg[h].text = s end end,
  getText     = function(h) local e = uiReg[h]; return e and e.text or nil end,
  setVisible  = function(h, v) if uiReg[h] then uiReg[h].visible = v end end,
  isVisible   = function(h) local e = uiReg[h]; return e and e.visible ~= false end,
  remove      = function(h) uiReg[h] = nil end,
  -- Реестр: тесты в tools/api_test и внешние проверки могут до него дотянуться.
  _reg        = uiReg,
}
G.player  = function() return setmetatable({ index = 0 }, { __index = function() return 0 end }) end
G.G       = stub()
G.state   = stub()
G.objects = stub()
G.mods    = { list = function() return {} end }
G.show    = function() end
G.require = nil   -- ставим ниже

-- Окружения модов: shared (есть game.exec) и client (нет).
-- ВАЖНО: api-модули достают events/log/native через rawget(_ENV, ...), поэтому
-- базовые таблицы кладём НАСТОЯЩИМИ полями env, а не через __index.
local sharedEnv, clientEnv
for _, name in ipairs({ "shared", "client" }) do
  local env = {}
  for k, v in pairs(G) do env[k] = v end
  setmetatable(env, { __index = G })
  env._G = env
  env._ENV = env
  if name == "shared" then sharedEnv = env else clientEnv = env end
end

-- require: загружает файл мода в нужное окружение, кэш как в модлоадере.
local loaded = {}
local function mkRequire(env, base)
  return function(name)
    local key = base .. ":" .. name
    if loaded[key] then return loaded[key] end
    local path = modDir .. "/" .. name .. ".lua"
    local fh = assert(io.open(path, "rb"), "cannot open " .. path)
    local code = fh:read("*a"); fh:close()
    local chunk = assert(load(code, "@" .. name .. ".lua", "t", env))
    local res = chunk()
    if res == nil then res = true end
    loaded[key] = res
    return res
  end
end
sharedEnv.require = mkRequire(sharedEnv, "shared")
clientEnv.require = mkRequire(clientEnv, "client")

-- Настоящие чистые api-модули — грузим в ОБЕ среды, они им не нужны.
-- 65_scheduler тоже можно: events у нас есть (заглушка).
for _, name in ipairs({ "60_mathx", "61_vec", "62_tablex", "63_stringx", "64_geometry",
                        "65_scheduler", "66_rng", "68_validate", "70_color",
                        "46_panel", "56_gui" }) do
  local path = apiDir .. "/" .. name .. ".lua"
  local fh = io.open(path, "rb")
  if fh then
    local code = fh:read("*a"); fh:close()
    for _, env in ipairs({ sharedEnv, clientEnv }) do
      local chunk = load(code, "@" .. name, "t", env)
      local ok, err
      if chunk then
        ok, err = pcall(chunk)
      else
        ok, err = false, "load failed for " .. name
      end
      if not ok then print("!! не загрузился " .. name .. ": " .. tostring(err)) end
    end
  end
end

-- Общие счётчики, чтобы видеть, что кейсы вообще регистрируются.
local function loadFile(env, path)
  local fh = assert(io.open(path, "rb"), "cannot open " .. path)
  local code = fh:read("*a"); fh:close()
  local chunk, err = load(code, "@" .. path, "t", env)
  if not chunk then error("syntax error in " .. path .. ": " .. tostring(err), 0) end
  return chunk()
end

local okShared, errShared = pcall(loadFile, sharedEnv, modDir .. "/shared.lua")
print("shared.lua загружен: " .. tostring(okShared) .. (okShared and "" or ("  -> " .. tostring(errShared))))
local okClient, errClient = pcall(loadFile, clientEnv, modDir .. "/client.lua")
print("client.lua загружен: " .. tostring(okClient) .. (okClient and "" or ("  -> " .. tostring(errClient))))

if not okShared or not okClient then os.exit(1) end

-- Считаем кейсы.
local function count(env, H)
  local n, bySection = 0, {}
  for _, c in ipairs(H.cases) do
    n = n + 1
    bySection[c.section] = (bySection[c.section] or 0) + 1
  end
  return n, bySection
end

local Hs, Hc = sharedEnv.require("harness"), clientEnv.require("harness")
-- require уже отдаст закешированный harness соответствующей среды
local ns, bs = count(sharedEnv, Hs)
local nc, bc = count(clientEnv, Hc)
print(string.format("кейсов: shared %d, client %d, всего %d", ns, nc, ns + nc))
local secs = {}
for s in pairs(bs) do secs[s] = true end
for s in pairs(bc) do secs[s] = true end
local list = {}
for s in pairs(secs) do list[#list + 1] = s end
table.sort(list)
for _, s in ipairs(list) do
  print(string.format("   %-8s shared %2d, client %2d", s, bs[s] or 0, bc[s] or 0))
end

-- Дубликаты id — источник путаницы в отчёте.
local seen, dup = {}, {}
for _, env in ipairs({ sharedEnv, clientEnv }) do
  for _, c in ipairs(env.require("harness").cases) do
    local k = c.here .. ":" .. c.id
    if seen[k] then dup[#dup + 1] = k end
    seen[k] = true
  end
end
if #dup > 0 then
  print("!! ДУБЛИ id: " .. table.concat(dup, ", "))
else
  print("дубликатов id нет")
end

-- Кейсы без раздела из H.SECTIONS (потеряются в отчёте).
local known = {}
for _, s in ipairs(Hs.SECTIONS) do known[s.id] = true end
local unknown = {}
for _, env in ipairs({ sharedEnv, clientEnv }) do
  for _, c in ipairs(env.require("harness").cases) do
    if not known[c.section] then unknown[#unknown + 1] = c.id .. " -> " .. tostring(c.section) end
  end
end
if #unknown > 0 then
  print("!! НЕИЗВЕСТНЫЕ РАЗДЕЛЫ: " .. table.concat(unknown, ", "))
else
  print("все кейсы в известных разделах")
end

-- Настоящий прогон разделов вне игры. Всё, что needs game, обязано аккуратно
-- превратиться в skip — иначе кейс упал бы мимо pcall-обвязки прибора.
local sections = { "env", "util", "read", "world", "combat", "fow", "flow", "net", "visual", "steam" }
for _, side in ipairs({ { "shared", sharedEnv, Hs }, { "client", clientEnv, Hc } }) do
  for _, sec in ipairs(sections) do
    local res = side[3].run(sec, { risky = true, quiet = true })
    if not res then
      print(string.format("%-7s (%s): прогон не удался", sec, side[1]))
    else
      local c = res.counts
      print(string.format("%-7s (%s): ok %2d, fail %d, error %d, skip %2d",
        sec, side[1], c.ok, c.fail, c.error, c.skip))
      for _, r in ipairs(res.records) do
        if r.status == "fail" or r.status == "error" then
          print(string.format("      [%s] %s: %s", r.status, r.id, r.msg))
        end
      end
    end
  end
end

-- Итог: ни один кейс не должен прибирать нагрузку извне pcall (прогон не падает).
print("прогон всех разделов завершился без падения — обвязка pcall исправна")
