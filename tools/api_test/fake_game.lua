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
EXEC_ARG = {}
function game.exec(code, arg)
    EXEC_LOG[#EXEC_LOG + 1] = code
    EXEC_ARG[#EXEC_ARG + 1] = arg
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

-- Stubs for api/22-26 (camera/minimap/animation/effects/decals).
NATIVE_LOG = {}
local function log(name, ...)
    NATIVE_LOG[#NATIVE_LOG + 1] = { name = name, args = { ... } }
end

-- Машина состояний объекта: нужна object.states()/setState (api/28).
-- SM 9001 принадлежит объекту 100, у него состояния idle/burning/destroyed.
-- Имена НЕ выдуманы "наугад" - api теперь берёт их отсюда и по ним же проверяет
-- setState, поэтому фейк должен вести себя как настоящий движок: IndexOfState
-- для неизвестного имени даёт -1 (а не «портит» объект).
FAKE_SM = {
    [9001] = { "idle", "burning", "destroyed" },
}
native.GetGameObjectStateMachineHandle = function(h) return h == 100 and 9001 or 0 end
native.IsGameObjectByHandle = function(h) return h == 100 or h == 501 or h == 777 or h == 1000 end
native.StateMachineGetVarsCount = function(sm) return #(FAKE_SM[sm] or {}) end
native.StateMachineGetStateNameByInd = function(sm, i)
    local list = FAKE_SM[sm]
    if not list then return "" end
    return list[i + 1] or ""
end
native.StateMachineGetStateIndByName = function(sm, name)
    for i, s in ipairs(FAKE_SM[sm] or {}) do
        if s == name then return i end
    end
    return -1
end
native.GetGameObjectStateNameByHandle = function() return "idle" end
native.GameObjectSwitchToStateByHandle = function(h, name) log("GameObjectSwitchToStateByHandle", h, name) end
native.SetGameObjectOnStateDestroyByHandle = function(h, name) log("SetGameObjectOnStateDestroyByHandle", h, name) end
native.GameObjectCreateProgressStateMachineBehaviour = function(h, f, s)
    log("GameObjectCreateProgressStateMachineBehaviour", h, f, s) return 61
end

-- Группа: center читает кэш, который заполняет GroupCalcCentralPositionByHandle.
-- Без этого натива api/52_group.center падал бы - и БАГ БЫЛ БЫ В API, не в тесте.
-- Центр группы: GroupGetCentralPosition*ByHandle ТОЛЬКО ЧИТАЕТ кэш, который
-- заполняет GroupCalcCentralPositionByHandle. Фейк это повторяет: без вызова
-- calc значения остаются нулевыми (именно так api/52_group.center отдавал
-- (0,0,0) в игре, пока мы не добавили пересчёт).
FAKE_GROUP_CENTER = { 0, 0, 0 }
native.GroupCalcCentralPositionByHandle = function(g)
    FAKE_GROUP_CENTER_CALCS = (FAKE_GROUP_CENTER_CALCS or 0) + 1
    FAKE_GROUP_CENTER = { 55, 0, 66 }
end
native.GroupGetCentralPositionXByHandle = function() return FAKE_GROUP_CENTER[1] end
native.GroupGetCentralPositionYByHandle = function() return FAKE_GROUP_CENTER[2] end
native.GroupGetCentralPositionZByHandle = function() return FAKE_GROUP_CENTER[3] end

-- camera
native.GetCameraAbsolutePosition = function() return 1, 2, 3 end
native.GetCameraPosition = function() return 4, 5, 6 end
native.GetCameraTargetPosition = function() return 7, 8, 9 end
native.SetMainCameraPositionXZ = function(x, z) log("SetMainCameraPositionXZ", x, z) end
native.SetMainCameraRotateXYZ = function(x, y, z) log("SetMainCameraRotateXYZ", x, y, z) end
native.SetMainCameraMoveToTargetXZ = function(x, z) log("SetMainCameraMoveToTargetXZ", x, z) end
native.SetMainCameraMoveToTarget = function(v) log("SetMainCameraMoveToTarget", v) end
native.SetMainCameraMoveToTargetSpeed = function(v) log("SetMainCameraMoveToTargetSpeed", v) end
native.SetCameraElasticTargetObject = function(h) log("SetCameraElasticTargetObject", h) end
native.GetCameraElasticTargetObject = function() return 777 end
native.SetCameraElasticRestrict = function(l, tp, r, b) log("SetCameraElasticRestrict", l, tp, r, b) end
native.GetCameraElasticRestrict = function() return 0, 1, 100, 101 end
native.GetCameraAbsoluteHeightByXZ = function(x, z) return 12.5 end
native.CameraTrackListClear = function() log("CameraTrackListClear") end
native.GetCameraTrackListCount = function() return 2 end
native.AddCameraTrack = function() return 5 end
native.AddCameraTrackPoint = function(n, tx, ty, tz, ex, ey, ez) log("AddCameraTrackPoint", n, tx, ty, tz, ex, ey, ez) end
native.SetCameraCurrentTrackIndex = function(i) log("SetCameraCurrentTrackIndex", i) end
native.GetCameraCurrentTrackIndex = function() return 1 end
native.GetCameraTrackNameByIndex = function(i) return "track" .. i end
-- minimap
native.SetGUIMiniMapVisible = function(v) log("SetGUIMiniMapVisible", v) end
native.GetGUIMiniMapVisible = function() return true end
native.GUIMiniMapUpdate = function() log("GUIMiniMapUpdate") end
native.SetGUIMiniMapTextureSize = function(w, h) log("SetGUIMiniMapTextureSize", w, h) end
native.GetGUIMiniMapTextureWidth = function() return 256 end
native.GetGUIMiniMapTextureHeight = function() return 256 end
native.SetGUIMiniMapPosition = function(x, y, z) log("SetGUIMiniMapPosition", x, y, z) end
native.GetGUIMiniMapPositionX = function() return 10 end
native.GetGUIMiniMapPositionY = function() return 20 end
native.GetGUIMiniMapPositionZ = function() return 0 end
native.SetGUIMinimapZoom = function(z) log("SetGUIMinimapZoom", z) end
native.GetGUIMinimapZoom = function() return 1.5 end
native.SetMiniMapFrustumVisible = function(v) log("SetMiniMapFrustumVisible", v) end
native.GetMiniMapFrustumVisible = function() return true end
native.CreateGUIMiniMapPrimitive = function(n) log("CreateGUIMiniMapPrimitive", n); return 3 end
native.SetGUIMiniMapPrimitivePosition = function(i, x, y) log("SetGUIMiniMapPrimitivePosition", i, x, y) end
native.SetGUIMiniMapPrimitiveDirection = function(i, x, y) log("SetGUIMiniMapPrimitiveDirection", i, x, y) end
native.SetGUIMiniMapPrimitiveTag = function(i, tag) log("SetGUIMiniMapPrimitiveTag", i, tag) end
native.SetGUIMiniMapPrimitiveName = function(i, n) log("SetGUIMiniMapPrimitiveName", i, n) end
native.SetGUIMiniMapPrimitiveBlink = function(i, iv, c) log("SetGUIMiniMapPrimitiveBlink", i, iv, c) end
native.SetGUIMiniMapPrimitiveVisible = function(i, v) log("SetGUIMiniMapPrimitiveVisible", i, v) end
native.GetGUIMiniMapPrimitiveVisible = function(i) return true end
native.RemoveGUIMiniMapPrimitive = function(i) log("RemoveGUIMiniMapPrimitive", i) end
native.GUIMiniMapPrimitivesClear = function() log("GUIMiniMapPrimitivesClear") end
native.GetGUIMiniMapPrimitivesCount = function() return 1 end
native.GetGUIMiniMapPrimitiveIndexOfTag = function(tag) return 3 end
-- animation/model
native.GameObjectSetFrameAnimationByHandle = function(h, n, r) log("anim.play", h, n, r) end
native.GameObjectSwitchToAnimationCyclesByHandle = function(h, n, a, b) log("anim.cycle", h, n, a, b) end
native.GameObjectSwitchToFrameAnimationByHandle = function(h, n, r) log("anim.switch", h, n, r) end
native.GetGameObjectCurrentFrameByHandle = function(h) return 12 end
native.SetGameObjectCurrentFrameByHandle = function(h, f) log("anim.frame", h, f) end
native.GetGameObjectFrameAnimationNameByHandle = function(h) return "attack" end
native.GetGameObjectAnimationCycleNameByHandle = function(h) return "idle" end
native.GetGameObjectAnimationCycleCountFrameByHandle = function(h, n) return 30 end
native.GetGameObjectAnimationCycleLeftFrameByHandle = function(h) return 5 end
native.SetGameObjectActorNameByHandle = function(h, n) log("model.actor", h, n) end
native.SetGameObjectMaterialNameByHandle = function(h, n) log("model.material", h, n) end
native.SetGameObjectScaleByHandle = function(h, x, y, z) log("model.scale", h, x, y, z) end
native.SetGameObjectVisibleByHandle = function(h, v) log("model.show", h, v) end
native.GameObjectRotateAbsoluteByHandle = function(h, x, y, z) log("model.rotate", h, x, y, z) end
native.GameObjectPointToByHandle = function(h, x, y, z, ux, uy, uz) log("model.pointTo", h, x, y, z) end
native.SetGameObjectAnimationCyclesListByHandle = function(h, n) log("model.setCycles", h, n) end
native.GetGameObjectAnimationCyclesListByHandle = function(h) return "lib" end
-- effects
native.EffectCreate = function(h, c, u, p) log("fx.create", h, c); return 11 end
native.EffectCreateWithKey = function(h, c, k, p) log("fx.createKey", h, c, k); return 12 end
native.EffectClear = function(h) log("fx.clear", h) end
native.GameObjectPFXCreateByHandle = function(h, m, k) log("pfx.create", h, m, k) end
native.GameObjectPFXDeleteByHandle = function(h, m, k) log("pfx.delete", h, m, k) end
native.GameObjectPFXClearByHandle = function(h) log("pfx.clear", h) end
native.GameObjectPFXIsCreatedHandle = function(h, m, k) return true end
native.GameObjectPFXSetLifeTimeByHandle = function(h, m, k, s) log("pfx.life", h, m, k, s) end
native.GameObjectPFXScaleByHandle = function(h, m, k, x, y, z) log("pfx.scale", h, m, k, x, y, z) end
native.GameObjectPFXEffectScaleByHandle = function(h, m, k, s) log("pfx.escale", h, m, k, s) end
native.GameObjectPFXInitialVelocityByHandle = function(h, m, k, x, y, z) log("pfx.vel", h, m, k, x, y, z) end
native.GameObjectPFXEnabledByHandle = function(h, m, k, e) log("pfx.enabled", h, m, k, e) end
native.EffectSourcePFXBurst = function(id, t, n) log("fx.burst", id, t, n) end
native.EffectSourcePFXRingExplosion = function(id, t, a, b, n) log("fx.ring", id, t, a, b, n) end
native.EffectFireFXInit = function(id) log("fx.fireInit", id) end
native.EffectFireFXIsotropicExplosion = function(id, a, b, c, n) log("fx.fire", id, a, b, c, n) end
native.EffectHighlightGetOrCreate = function(h, k, v, m) log("fx.hl", h, k, v, m); return 21 end
native.EffectHighlightRemove = function(h, k) log("fx.unhl", h, k) end
-- decals
native.PutDecalByName = function(x, y, n) log("dec.put", x, y, n); return 31 end
native.DestroyDecalByHandle = function(d) log("dec.remove", d) end
native.DecalManagerClear = function() log("dec.clear") end
native.SetDecalPositionByHandle = function(d, x, z) log("dec.move", d, x, z) end
native.GetDecalPositionByHandle = function(d) return 5, 6 end
native.SetDecalVisibleByHandle = function(d, v) log("dec.show", d, v) end
native.GetDecalVisibleByHandle = function(d) return true end
native.SetDecalTexRollAngleByHandle = function(d, a) log("dec.rot", d, a) end
native.GetDecalTexRollAngleByHandle = function(d) return 0.5 end
native.GetDecalNameByHandle = function(d) return "scorch" end
native.GetDecalMaterialNameByHandle = function(d) return "mat" end
native.DecalManagerGetDecalCount = function() return 2 end
native.IsDecalInCircle = function(x, z, r, m) return true end
native.GetPointDecalDistance = function(d, x, z) return 3.5 end

-- EXT2 stubs for api/27-37.
EVT = {}
events = {
    on = function(name, fn) EVT[name] = EVT[name] or {}; EVT[name][#EVT[name] + 1] = fn; return #EVT[name] end,
    off = function(id) end,
}
function fireEvt(name, ...) for _, fn in ipairs(EVT[name] or {}) do fn(...) end end
local FAKE_ALIVE = {}
objects = {
    read = function(h) return { pl = 0, hp = 80 } end,
    pos = function(h) return 11, 22 end,
    list = function() return { 1, 2, 3 } end,
    alive = function(h) return FAKE_ALIVE[h] ~= false end,
    _markDead = function(h) FAKE_ALIVE[h] = false end,
    _markAlive = function(h) FAKE_ALIVE[h] = true end,
}
native.GetPlayerHandleByIndex = function(i) return 100 + i end
native.RayCastHeight = function(x, z) return 7.5 end
native.CreatePlayerGameObjectHandleByHandle = function(ph, r, b, x, y, z) log("world.spawn", ph, r, b, x, y, z); return 501 end
native.SetGameObjectCustomNameByHandle = function(h, n) log("world.name", h, n) end
native.GameObjectRequestToDestroyByHandle = function(h) log("world.destroy", h) end
native.GameObjectDestroyByHandle = function(h) log("world.destroyNow", h) end
native.SetGameObjectPositionByHandle = function(h, x, y, z) log("world.move", h, x, y, z) end
native.GetGameObjectPositionXByHandle = function(h) return 1 end
native.GetGameObjectPositionYByHandle = function(h) return 2 end
native.GetGameObjectPositionZByHandle = function(h) return 3 end
native.GetGameObjectStateNameByHandle = function(h) return "idle" end
native.GameObjectSwitchToStateByHandle = function(h, s) log("obj.state", h, s) end
native.SetGameObjectOnStateDestroyByHandle = function(h, s) log("obj.destroyIn", h, s) end
native.GameObjectCreateProgressStateMachineBehaviour = function(h, f, s, st, en, iv) return 61 end
native.GameObjectCalcPathByHandle = function(h, x, z, t, c) return 0 end
native.GameObjectCalcPathAdvByHandle = function(h, x, z, t, c, a, b, d, s, q) return 0 end
native.GameObjectCalcPathExtByHandle = function(h, a, b, x, z, t, c) return 0 end
native.TopologyGetPathDistance = function(a, b, c, d, i) return 42.5 end
native.GroupGetFindPathByHandle = function(h) return true end
native.RaiseTerrain = function(x, y, r, m, d) log("terr.raise", x, y, d) end
native.LowerTerrain = function(x, y, r, m, d) log("terr.lower", x, y, d) end
native.SmoothTerrain = function(x, y, r, m) log("terr.smooth", x, y) end
native.TerrainUpdate = function(a, b) log("terr.update", a, b) end
native.GetFOWEnable = function() return true end
native.SetFOWEnable = function(v) log("fow.enable", v) end
native.GetFOWLerpFactor = function() return 0.5 end
native.SetFOWLerpFactor = function(v) log("fow.lerp", v) end
native.GetFOWElevation = function() return 1 end
native.SetFOWElevation = function(v) end
native.GetFOWTextured = function() return false end
native.SetFOWTextured = function(v) end
native.SetFOWSmooth = function(a, b, c, d) end
native.FOWBuildFull = function() log("fow.rebuild") end
native.AddFOWObjects = function(h) log("fow.reveal", h) end
native.DelFOWObjects = function(h) end
native.ClearFOWObjects = function() end
native.AddFOWPlayers = function(h) end
native.ClearFOWPlayers = function() end
native.DebugTextWrite = function(id, f, tx, x, y, z, s, r, g, b, a, al, lo) log("dbg.text", id, tx) end
native.DebugTextClean = function(id) log("dbg.clear", id) end
native.DebugTextCount = function() return 1 end
native.DebugTextIndexByID = function(id) return 0 end
native.GetGameObjectBaseNameByHandle = function(h) return "musketeer18" end
native.RayCastTerrain = function(a, b, c, d, e, f) return true, 1, 2, 3 end
native.GetTimeSpeedFactor = function() return FAKE_SPEED or 1 end
native.SetTimeSpeedFactor = function(v) FAKE_SPEED = v end
native.SndGetOrCreateSound = function(tag, lib, ow) return 71 end
native.SndRemoveSound = function(tag, ow) return 1 end
native.SetSndSoundPlaying = function(v, s) log("snd.playing", s, v) end
native.GetSndSoundPlaying = function(s) return true end
native.SetSndSoundPause = function(v, s) end
native.SetSndSoundLoop = function(v, s) end
native.GetSndSoundVolume = function(s) return 0.8 end
native.SetSndSoundVolume = function(v, s) log("snd.vol", s, v) end
native.SetSndSoundSourceName = function(n, s) end
native.GetSndSoundFrequency = function(s) return 440 end
native.SetSndSoundFrequency = function(v, s) end
native.GetSndSoundRadius = function(s) return 10 end
native.SetSndSoundRadius = function(v, s) end
native.SetSndSoundMute = function(v, s) end
function log(msg, a, b, c, d, e, f) NATIVE_LOG[#NATIVE_LOG + 1] = { name = msg, args = { a, b, c, d, e, f } } end

-- EXT3 stubs for api/38-51.
savedata = { _d = {}, set = function(k, v) savedata._d[k] = v end,
             get = function(k) return savedata._d[k] end,
             keys = function() return {} end }
net = { broadcast = function() end, on = function() end, send = function() end }
_G.log = { info = function() end, warn = function() end, error = function() end }
mods = { list = function() return { { id = "my_pack", name = "P", version = "1.2.0",
    loaded = true, shared = true, permissions = { world_spawn = true } } } end }
native.GameObjectPFXInitialPositionByHandle = function(h, m, k, x, y, z) log("pfx.pos", h, m, k) end
native.SetGameObjectTargetObjectByHandle = function(h, tg) log("attach.follow", h, tg) end
native.GameObjectPFXDeleteByHandle = function(h, m, k) end
native.AddFOWObjects = function(h) log("fow.reveal", h) end

-- EXT4 stubs for api/52-57.
native.CreateGroupByPlHandle = function(ph, n) return 801 end
native.GroupAddGameObjectByHandle = function(g, h) log("grp.add", g, h) end
native.GroupRemoveGameObjectByHandle = function(g, h) end
native.GroupClearGameObjectsByHandle = function(g) end
native.GetGroupCountGameObjectsByHandle = function(g) return 2 end
native.GetGroupGOHandleByGOIndexByHandle = function(g, i) return 101 + i end
-- GroupGetCentralPosition*ByHandle и GroupCalcCentralPositionByHandle заданы выше,
-- вместе с кэшем FAKE_GROUP_CENTER - здесь дубли перекрывали бы их.
native.SetGroupStretchFactorByHandle = function(g, f) end
native.GroupGameObjectsGridRebuildByHandle = function(g) log("GroupGameObjectsGridRebuildByHandle", g) end
native.GroupSetDirectPathColPointCancel = function(g, v) end
native.RemoveGroupByHandle = function(g) end
native.GroupGetFindPathByHandle = function(g) return true end
native.BehaviourCreate = function(h, c, u, p) return 901 end
native.BehaviourCreateWithKey = function(h, c, k, p) return 902 end
native.BehaviourDestroy = function(id) end
native.GetOrCreateBehaviourInertia = function(h) return 903 end
native.BehaviourInertiaApplyForce = function(id, a, b, c, d) log("beh.force", id, a) end
native.BehaviourInertiaApplyTorque = function(id, a, b, c) end
native.BehaviourInertiaApplyTranslationAcceleration = function(id, a, b, c, d) end
native.BehaviourInertiaSurfaceBounce = function(id, a, b, c, d, e) end
native.BehaviourInertiaMirrorTranslation = function(id) end
native.AddTrackNode = function(gr, x, y, z, l) return 701 end
native.ConnectTrackNodesByHandle = function(a, b) end
native.OneSideConnectTrackNodesByHandle = function(a, b) end
native.GetTrackNodePathByHandle = function(a, b) return true end
native.GetTrackNodePathLength = function() return 55.5 end
native.GetTrackNodeNeighboursCountByHandle = function(h) return 1 end
native.GetTrackNodeNeighbourHandleByHandleByIndex = function(h, i) return 702 end
native.GetTrackNodePositionByHandle = function(h) return 1, 2, 3 end
native.GetTrackNodeCount = function() return 2 end
native.ClearTrackNodeList = function(gr) end
native.BreakConnectionsByTrackNodes = function(d) end
native.SetGameObjectBVUseTrackNodeByHandle = function(h, v) end
native.DebugDrawLine = function(n, a, b, c, d, e, f, r, g, bb) log("draw.line", n) end
native.DebugDrawBox = function(n, x, y, z, s, r, g, b) end
native.DebugDrawSphere = function(n, x, y, z, r, a, b, c, d, e) end
native.DebugDrawAxis = function(n, x, y, z, a, b, c, r, g, bb) end
native.DebugDrawClean = function(n) end
native.CreateSnapShot = function(v) end
native.CreateSnapShotExt = function(v, f, w, h) log("snap.ext", f) end
native.GetLastCreateSnapShotFileName = function() return "snap.bmp" end
native.BeginPlayingCurrentScenario = function() log("scn.begin") end

-- EXT5 stub: C++ steam table (client).
STEAM_CALLS = {}
steam = {
    available = function() return true end,
    status = function() return "ok" end,
    set = function(k, v) STEAM_CALLS[#STEAM_CALLS + 1] = { k, v }; return true end,
    clear = function() STEAM_CALLS[#STEAM_CALLS + 1] = { "!clear" }; return true end,
    playedWith = function(id) return true end,
    myId = function() return "76561198000000001" end,
}
