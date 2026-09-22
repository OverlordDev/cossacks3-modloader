-- units — юниты: выделение, состояние, очередь приказов.
--
--   units.selected()          --> { handle, ... } — что выделил игрок (юниты и здания)
--   units.info(handle)        --> {handle, sid, player, hp, maxhp, x, z, dead} или nil
--   units.orders(handle)      --> { {type, target, x, z}, ... } — очередь приказов, [1] — текущий
--
-- type — имя из игры (_misc_GetUnitOrderTypeByIndex): move, attackobj, attackpoint, gainres, patrol,
-- guard, build, repair, gotomine, produce, performupgrade ...
--
-- СОБЫТИЯ ПРИКАЗОВ (game.on / events.on)
--   events.on("player.order", function(event, order)
--       -- order = {kind, target, x, z, group}
--       --   kind: "move" | "attack" | "attackpoint" | "guard" | "build" | "enter" | "gather" | "patrol"
--       --   target — хендл цели (attack, guard, build, enter, gather), x/z — точка (move, attackpoint,
--       --   patrol), group — хендл группы (move: событие на каждую выделенную группу)
--       return true -- приказ не отдаётся
--   end)
--
--   events.on("unit.order", function(event, handle, type, target, x, z)
--       -- ЛЮБОЙ приказ любому юниту: игрока, ИИ, из сети, из скриптов (встроено в _unit_AddOrder)
--       -- type — как в units.orders: "move", "attackobj", "gainres", "build" ...
--       return true -- приказ не добавится. Отменять — только в shared-моде одинаково на всех машинах,
--   end)           -- иначе партия разойдётся.
--
-- player.order приходит на машине игрока, который кликнул, до того как приказ ушёл в игру и в сеть:
-- кто выполняет — units.selected().

units = {}

local F, R = "\1", "\2"

local function run(code)
    if not game.exec then error("units: only server/shared scripts and pages can do this", 3) end
    return game.exec(code) or ""
end

local function split(text, sep)
    local out = {}
    if text == "" then return out end
    for piece in (text .. sep):gmatch("(.-)" .. sep) do out[#out + 1] = piece end
    return out
end

local function num(v) return tonumber((tostring(v or ""):gsub(",", "."))) or 0 end

local function checkHandle(h)
    h = math.tointeger(tonumber(h))
    if not h then error("units: handle must be a number", 3) end
    return h
end

function units.selected()
    local out = {}
    for _, v in ipairs(split(run([[
var s : String;
var i : Integer;
for i := 0 to gSelectedObjects.GetCount-1 do s := s + IntToStr(gSelectedObjects.Get(i)) + #1;
ML_RET(s);]]), F)) do
        if v ~= "" then out[#out + 1] = math.tointeger(tonumber(v)) end
    end
    return out
end

function units.info(handle)
    local h = checkHandle(handle)
    local f = split(run(string.format([[
var h : Integer = %d;
var pobj : Pointer = _unit_GetTObj(h);
if pobj = nil then begin ML_RET(''); exit; end;
var cid : Integer = TObj(pobj).cid;
var id : Integer = TObj(pobj).id;
var pl : Integer = TObj(pobj).pl;
ML_RET(gObjProp[cid][id].sid + #1 + IntToStr(pl) + #1 + IntToStr(TObj(pobj).hp) + #1 +
       IntToStr(gPlayer[pl].objbase[cid][id].maxhp) + #1 + FloatToStr(GetGameObjectPositionXByHandle(h)) + #1 +
       FloatToStr(GetGameObjectPositionZByHandle(h)) + #1 + BoolToStr(TObj(pobj).bdead));]], h)), F)
    if #f < 7 then return nil end
    return { handle = h, sid = f[1], player = num(f[2]), hp = num(f[3]), maxhp = num(f[4]),
             x = num(f[5]), z = num(f[6]), dead = f[7] == "True" }
end

function units.orders(handle)
    local h = checkHandle(handle)
    local out = {}
    for _, rec in ipairs(split(run(string.format([[
var h : Integer = %d;
var pobj : Pointer = _unit_GetTObj(h);
if pobj = nil then begin ML_RET(''); exit; end;
var s, t : String;
var i : Integer;
for i := 0 to 11 do
if TObj(pobj).orders[i].itype <> gc_obj_order_type_none then
begin
   t := '';
   _misc_GetUnitOrderTypeByIndex(TObj(pobj).orders[i].itype, t);
   s := s + t + #1 + IntToStr(TObj(pobj).orders[i].info.trg) + #1 + FloatToStr(TObj(pobj).orders[i].info.x) + #1 +
        FloatToStr(TObj(pobj).orders[i].info.y) + #2;
end;
ML_RET(s);]], h)), R)) do
        local f = split(rec, F)
        if #f >= 4 then
            out[#out + 1] = { type = f[1], target = math.tointeger(num(f[2])), x = num(f[3]), z = num(f[4]) }
        end
    end
    return out
end
