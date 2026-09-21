-- buildings — здания: что строят, улучшения, очередь; команды игрока; правка логики.
--
-- Всё собрано под интерфейс на CEF: каждая функция отдаёт готовую таблицу (в странице —
-- game.api('buildings.info', handle) и т.д.), команды идут через функции самой игры —
-- те же, что у родных кнопок (_unit_ProduceUnit, _unit_MakeUpgrade), поэтому проверки ресурсов,
-- доступа и сеть работают как у обычного игрока.
--
-- ЧТЕНИЕ
--   buildings.list()                   --> здания своего игрока: { {handle, sid, built, hp, maxhp, x, z, queue}, ... }
--   buildings.list(2)                  --  здания игрока 2
--   buildings.selected()               --> хендл выделенного игроком здания или nil (для HUD на CEF)
--   buildings.info(handle)             --> {
--       handle, sid, country, id, player, hp, maxhp, built, buildprogress,
--       produce  = { {sid, id, available, price = {еда, дерево, камень, золото, железо, уголь}, buildtime, x, y}, ... },
--       upgrades = { {sid, index, available, enabled, level, kind, value, price = {...}, time}, ... },
--       queue    = { {kind = "unit"|"upgrade", sid, amount (-1 — бесконечно), progress}, ... },
--   }
--   available — можно ли заказать прямо сейчас (требования, эпоха, лимиты — как решает игра).
--
-- КОМАНДЫ (как нажатие кнопки игроком — владельцем здания)
--   buildings.produce(handle, "musketeer18", 5)     -- 5 штук; -1 — бесконечно
--   buildings.cancel(handle, "musketeer18", 1)      -- убрать из очереди
--   buildings.upgrade(handle, "upg_sid")
--   buildings.cancelUpgrade(handle, "upg_sid")
--
-- ЛОГИКА (менять одинаково на всех машинах — мод shared, в game.start)
--   buildings.produceList("barracks18")                       --> { "pikeman18", "musketeer18", ... }
--   buildings.setProduceList("barracks18", { "musketeer18", "grenadier18" })
--   buildings.addProduce("barracks18", "grenadier18")
--   buildings.removeProduce("barracks18", "pikeman18")
--   buildings.setUpgrade("upg_sid", "time", 30)            -- поля TCountryUpgrade: price[3], time, value, enabled...
--
-- Типы данных — GAME_STATE.md: TCountry, TCountryFixedProduce, TCountryUpgrade, TObj, TOrder.

buildings = {}

local F, R, S = "\1", "\2", "\3" -- разделители: поле, запись, раздел
local ORDER_PRODUCE, ORDER_UPGRADE = 4, 8 -- gc_obj_order_type_produce / _performupgrade
local ACCESS_OK = 0                       -- gc_result_checkaccesscontrolreq_ok

local function needExec(name)
    if not game.exec then error("buildings." .. name .. ": only server/shared scripts and pages can do this", 3) end
end

local function run(code)
    needExec("run")
    return game.exec(code) or ""
end

local function split(text, sep)
    local out = {}
    for piece in (text .. sep):gmatch("(.-)" .. sep) do out[#out + 1] = piece end
    return out
end

local function num(v) return tonumber((tostring(v or ""):gsub(",", "."))) or 0 end
local function bool(v) return v == "True" or v == "1" end

local function checkHandle(h)
    h = math.tointeger(tonumber(h))
    if not h then error("buildings: handle must be a number", 3) end
    return h
end

local function quote(s)
    return "'" .. tostring(s):gsub("'", "''") .. "'"
end

-- ---------- чтение ----------

function buildings.list(player)
    local p = player
    if p == nil then p = native.GetPlayerIndexInterfaceIO() end
    local text = run(string.format([[
var plHnd : Integer = GetPlayerHandleByIndex(%d);
var s : String;
var i, h : Integer;
var pobj : Pointer;
if plHnd <> 0 then
for i := 0 to GetPlayerGameObjectsCountByHandle(plHnd)-1 do
begin
   h := GetGameObjectHandleByIndex(i, plHnd);
   pobj := _unit_GetTObj(h);
   if (pobj <> nil) and gObjProp[TObj(pobj).cid][TObj(pobj).id].bbuilding and (not TObj(pobj).bdead) then
   begin
      var n : Integer = 0;
      var k : Integer;
      for k := 0 to 11 do
      if TObj(pobj).orders[k].itype <> 0 then n := n + 1;
      s := s + IntToStr(h) + #1 + gObjProp[TObj(pobj).cid][TObj(pobj).id].sid + #1 + BoolToStr(TObj(pobj).bbuilt) + #1 +
           IntToStr(TObj(pobj).hp) + #1 + IntToStr(gPlayer[TObj(pobj).pl].objbase[TObj(pobj).cid][TObj(pobj).id].maxhp) + #1 +
           FloatToStr(GetGameObjectPositionXByHandle(h)) + #1 + FloatToStr(GetGameObjectPositionZByHandle(h)) + #1 +
           IntToStr(n) + #2;
   end;
end;
ML_RET(s);]], p))
    local out = {}
    for _, rec in ipairs(split(text, R)) do
        local f = split(rec, F)
        if #f >= 8 then
            out[#out + 1] = { handle = math.tointeger(num(f[1])), sid = f[2], built = bool(f[3]), hp = num(f[4]),
                              maxhp = num(f[5]), x = num(f[6]), z = num(f[7]), queue = num(f[8]) }
        end
    end
    return out
end

function buildings.selected()
    local text = run([[
var h : Integer;
if gSelectedObjects.GetCount > 0 then h := gSelectedObjects.Get(0);
var pobj : Pointer;
if h <> 0 then pobj := _unit_GetTObj(h);
if (pobj <> nil) and gObjProp[TObj(pobj).cid][TObj(pobj).id].bbuilding then ML_RET(IntToStr(h)) else ML_RET('');]])
    return math.tointeger(tonumber(text))
end

local PRICE = "IntToStr(%s[0])+','+IntToStr(%s[1])+','+IntToStr(%s[2])+','+IntToStr(%s[3])+','+IntToStr(%s[4])+','+IntToStr(%s[5])"
local function price(expr) return PRICE:gsub("%%s", expr) end

local function priceList(text)
    local out = {}
    for v in (text .. ","):gmatch("(.-),") do out[#out + 1] = num(v) end
    return out
end

function buildings.info(handle)
    local h = checkHandle(handle)
    local text = run(string.format([[
var h : Integer = %d;
var pobj : Pointer = _unit_GetTObj(h);
if pobj = nil then begin ML_RET(''); exit; end;
var cid : Integer = TObj(pobj).cid;
var id : Integer = TObj(pobj).id;
var pl : Integer = TObj(pobj).pl;
var plHnd : Integer = GetGameObjectPlayerHandleByHandle(h);
var bsid : String = gObjProp[cid][id].sid;
var s : String = IntToStr(cid) + #1 + IntToStr(id) + #1 + IntToStr(pl) + #1 + bsid + #1 + IntToStr(TObj(pobj).hp) + #1 +
                 IntToStr(gPlayer[pl].objbase[cid][id].maxhp) + #1 + BoolToStr(TObj(pobj).bbuilt) + #1 + FloatToStr(TObj(pobj).buildprogress);
var k, j, i : Integer;
var usid : String;
// что строит
s := s + #3;
var fp : Integer = _country_GetFixedProduceIndexBySID(cid, bsid, False);
if fp >= 0 then
for k := 0 to gc_country_fixedproduce_maxcount-1 do
begin
   usid := gCountry[cid].fixedproduce[fp].build[k].id;
   if usid <> '' then
   begin
      var uid : Integer = _unit_ConvertObjSIDToID(cid, usid);
      s := s + usid + #1 + IntToStr(uid) + #1 + IntToStr(_player_CheckAccessControlRequirements(plHnd, cid, usid)) + #1 +
           %s + #1 + FloatToStr(gPlayer[pl].objbase[cid][uid].buildtime) + #1 +
           IntToStr(gCountry[cid].fixedproduce[fp].build[k].x) + #1 + IntToStr(gCountry[cid].fixedproduce[fp].build[k].y) + #2;
   end;
end;
// улучшения
s := s + #3;
for i := 0 to gc_country_maxupgradeplace-1 do
if gCountry[cid].upgradeplace[i].id = bsid then
for j := 0 to gc_country_upgradeplace_maxcount-1 do
begin
   usid := gCountry[cid].upgradeplace[i].upgrade[j];
   if usid <> '' then
   begin
      var ui : Integer = _country_GetUpgradeIndexByUpgradeID(cid, usid, False);
      if ui >= 0 then
      s := s + usid + #1 + IntToStr(ui) + #1 + IntToStr(_player_CheckAccessControlRequirements(plHnd, cid, usid)) + #1 +
           BoolToStr(gCountry[cid].upgrade[ui].enabled) + #1 + IntToStr(gCountry[cid].upgrade[ui].level) + #1 +
           IntToStr(gCountry[cid].upgrade[ui].itype) + #1 + FloatToStr(gCountry[cid].upgrade[ui].value) + #1 +
           %s + #1 + FloatToStr(gCountry[cid].upgrade[ui].time) + #2;
   end;
end;
// очередь
s := s + #3;
for k := 0 to 11 do
begin
   var ot : Integer = TObj(pobj).orders[k].itype;
   if (ot = gc_obj_order_type_produce) or (ot = gc_obj_order_type_performupgrade) then
   begin
      usid := '';
      if ot = gc_obj_order_type_produce then
      _unit_ConvertObjIDToSID(cid, TObj(pobj).orders[k].info.produceid, usid)
      else
      _country_GetUpgradeSIDByUpgradeID(cid, TObj(pobj).orders[k].info.upgradeid, usid);
      s := s + IntToStr(ot) + #1 + usid + #1 + IntToStr(TObj(pobj).orders[k].info.amount) + #1 +
           FloatToStr(TObj(pobj).orders[k].info.progress) + #2;
   end;
end;
ML_RET(s);]], h, price("gPlayer[pl].objbase[cid][uid].price"), price("gCountry[cid].upgrade[ui].price")))

    if text == "" then error("buildings.info: object " .. h .. " not found", 2) end
    local sections = split(text, S)
    local head = split(sections[1], F)
    local info = {
        handle = h, country = num(head[1]), id = num(head[2]), player = num(head[3]), sid = head[4],
        hp = num(head[5]), maxhp = num(head[6]), built = bool(head[7]), buildprogress = num(head[8]),
        produce = {}, upgrades = {}, queue = {},
    }
    for _, rec in ipairs(split(sections[2] or "", R)) do
        local f = split(rec, F)
        if #f >= 7 then
            info.produce[#info.produce + 1] = { sid = f[1], id = num(f[2]), available = num(f[3]) == ACCESS_OK,
                price = priceList(f[4]), buildtime = num(f[5]), x = num(f[6]), y = num(f[7]) }
        end
    end
    for _, rec in ipairs(split(sections[3] or "", R)) do
        local f = split(rec, F)
        if #f >= 9 then
            info.upgrades[#info.upgrades + 1] = { sid = f[1], index = num(f[2]), available = num(f[3]) == ACCESS_OK,
                enabled = bool(f[4]), level = num(f[5]), kind = num(f[6]), value = num(f[7]),
                price = priceList(f[8]), time = num(f[9]) }
        end
    end
    for _, rec in ipairs(split(sections[4] or "", R)) do
        local f = split(rec, F)
        if #f >= 4 then
            info.queue[#info.queue + 1] = { kind = num(f[1]) == ORDER_PRODUCE and "unit" or "upgrade", sid = f[2],
                amount = num(f[3]), progress = num(f[4]) }
        end
    end
    return info
end

-- ---------- команды игрока ----------

-- Код команды: здание кладётся в общий временный список игры, как выделение при нажатии кнопки.
local function command(h, body)
    local result = run(string.format([[
var h : Integer = %d;
var pobj : Pointer = _unit_GetTObj(h);
if pobj = nil then begin ML_RET('no object'); exit; end;
var cid : Integer = TObj(pobj).cid;
var plHnd : Integer = GetGameObjectPlayerHandleByHandle(h);
gIntegerList.Clear;
gIntegerList.Add(h);
%s]], h, body))
    if result ~= "" and result ~= "True" then
        error("buildings: " .. result, 3)
    end
    return true
end

function buildings.produce(handle, unitSid, amount)
    return command(checkHandle(handle), string.format([[
var usid : String = %s;
if _player_CheckAccessControlRequirements(plHnd, cid, usid) <> gc_result_checkaccesscontrolreq_ok then
begin ML_RET('not available now: ' + usid); exit; end;
var id : Integer = _unit_ConvertObjSIDToID(cid, usid);
if id < 0 then begin ML_RET('unknown unit ' + usid); exit; end;
_unit_ProduceUnit(plHnd, gIntegerList, cid, id, %d, True, True, True);
ML_RET('True');]], quote(unitSid), math.tointeger(tonumber(amount) or 1) or 1))
end

function buildings.cancel(handle, unitSid, amount)
    return command(checkHandle(handle), string.format([[
var usid : String = %s;
var id : Integer = _unit_ConvertObjSIDToID(cid, usid);
if id < 0 then begin ML_RET('unknown unit ' + usid); exit; end;
_unit_ProduceUnit(plHnd, gIntegerList, cid, id, %d, False, True, True);
ML_RET('True');]], quote(unitSid), math.tointeger(tonumber(amount) or 1) or 1))
end

local function upgradeCommand(handle, upgSid, state)
    return command(checkHandle(handle), string.format([[
var usid : String = %s;
if %s and (_player_CheckAccessControlRequirements(plHnd, cid, usid) <> gc_result_checkaccesscontrolreq_ok) then
begin ML_RET('not available now: ' + usid); exit; end;
var ui : Integer = _country_GetUpgradeIndexByUpgradeID(cid, usid, False);
if ui < 0 then begin ML_RET('unknown upgrade ' + usid); exit; end;
_unit_MakeUpgrade(plHnd, gIntegerList, ui, %s, True);
ML_RET('True');]], quote(upgSid), state and "True" or "False", state and "True" or "False"))
end

function buildings.upgrade(handle, upgSid) return upgradeCommand(handle, upgSid, true) end
function buildings.cancelUpgrade(handle, upgSid) return upgradeCommand(handle, upgSid, false) end

-- ---------- логика: что строят здания, улучшения ----------

-- Все места (нация, номер списка), где есть здание bsid: { {country, fp}, ... }.
local function producePlaces(bsid)
    local text = run(string.format([[
var s, b : String;
var c, fp : Integer;
for c := 0 to gc_MaxCountryCount-1 do
begin
   b := %s;
   fp := _country_GetFixedProduceIndexBySID(c, b, False);
   if fp >= 0 then s := s + IntToStr(c) + ',' + IntToStr(fp) + ';';
end;
ML_RET(s);]], quote(bsid)))
    local out = {}
    for c, fp in text:gmatch("(%d+),(%d+);") do out[#out + 1] = { country = tonumber(c), fp = tonumber(fp) } end
    if #out == 0 then error("buildings: no building '" .. tostring(bsid) .. "' produces anything", 3) end
    return out
end

local SLOTS = 24 -- gc_country_fixedproduce_maxcount

function buildings.produceList(bsid)
    local p = producePlaces(bsid)[1]
    local out = {}
    for k = 0, SLOTS - 1 do
        local sid = state.get(string.format("gCountry[%d].fixedproduce[%d].build[%d].id", p.country, p.fp, k))
        if sid ~= "" then out[#out + 1] = sid end
    end
    return out
end

-- Новый список у всех наций с этим зданием. Позиции кнопок (x, y) — сеткой 6 в ряд, как у игры.
function buildings.setProduceList(bsid, list)
    needExec("setProduceList")
    if #list > SLOTS then error("buildings.setProduceList: at most " .. SLOTS .. " units", 2) end
    for _, p in ipairs(producePlaces(bsid)) do
        for k = 0, SLOTS - 1 do
            local base = string.format("gCountry[%d].fixedproduce[%d].build[%d]", p.country, p.fp, k)
            state.set(base .. ".id", list[k + 1] or "")
            if list[k + 1] then
                state.set(base .. ".x", k % 6)
                state.set(base .. ".y", k // 6)
            end
        end
    end
end

function buildings.addProduce(bsid, unitSid)
    local list = buildings.produceList(bsid)
    for _, s in ipairs(list) do if s == unitSid then return end end
    list[#list + 1] = unitSid
    buildings.setProduceList(bsid, list)
end

function buildings.removeProduce(bsid, unitSid)
    local list, out = buildings.produceList(bsid), {}
    for _, s in ipairs(list) do if s ~= unitSid then out[#out + 1] = s end end
    buildings.setProduceList(bsid, out)
end

-- Поле улучшения у всех наций, где оно есть: "time", "value", "price[3]", "enabled", "level".
function buildings.setUpgrade(upgSid, field, value)
    needExec("setUpgrade")
    local text = run(string.format([[
var s, u : String;
var c, ui : Integer;
for c := 0 to gc_MaxCountryCount-1 do
begin
   u := %s;
   ui := _country_GetUpgradeIndexByUpgradeID(c, u, False);
   if ui >= 0 then s := s + IntToStr(c) + ',' + IntToStr(ui) + ';';
end;
ML_RET(s);]], quote(upgSid)))
    local n = 0
    for c, ui in text:gmatch("(%d+),(%d+);") do
        local sep = field:sub(1, 1) == "[" and "" or "."
        state.set(string.format("gCountry[%s].upgrade[%s]", c, ui) .. sep .. field, value)
        n = n + 1
    end
    if n == 0 then error("buildings.setUpgrade: unknown upgrade '" .. tostring(upgSid) .. "'", 2) end
end
