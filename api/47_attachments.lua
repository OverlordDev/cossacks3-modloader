-- attachments — составные объекты: дым из труб, флаги, оружие, фонари.
--
-- Эффект на объекте со смещением (PFX InitialPosition), следование за целью
-- (SetGameObjectTargetObject) и автоуборка при смерти объекта.
-- Визуал — везде; привязка следования меняет мир — server/shared.
--
--   attach.effect(h, "smoke_mgr", "chimney", { pos = {0, 3, 0}, scale = 1.5, lifetime = 30 })
--   attach.follow(flagH, poleH)       -- флаг следует за шестом (server/shared)
--   attach.unfollow(flagH)
--   attach.free(h)                    -- снять все эффекты привязки с объекта
--
-- Менеджеры PFX — из data/pfx. Смещение pos — локальные метры от центра объекта.

attach = {}

local bound = {}   -- [h] = { {manager, key}, ... }
local sub = nil

local function checkHandle(h, where)
    h = math.tointeger(tonumber(h))
    if not h or h == 0 then error("attach." .. where .. ": handle must be a non-zero number", 3) end
    return h
end

local function inGame(where)
    if not game.isInGame() then
        error("attach." .. where .. ": no active game (check game.isInGame())", 3)
    end
end

local function ensureTick()
    if sub then return end
    sub = events.on("game.tick", function()
        for h in pairs(bound) do
            local ok, o = pcall(objects.read, h)
            if not ok or not o or o.bdead then
                bound[h] = nil
            end
        end
        if not next(bound) and sub then events.off(sub) sub = nil end
    end)
end

-- Эффект-привязка: дым/огонь/свет на объекте со смещением и масштабом.
-- opts = { pos = {x,y,z}, vel = {x,y,z}, scale = s, lifetime = t, enabled = true }.
function attach.effect(h, manager, key, opts)
    inGame("effect")
    h = checkHandle(h, "effect")
    if type(manager) ~= "string" or manager == "" then
        error("attach.effect: manager must be a non-empty string", 2)
    end
    if type(key) ~= "string" or key == "" then
        error("attach.effect: key must be a non-empty string", 2)
    end
    opts = opts or {}
    native.GameObjectPFXCreateByHandle(h, manager, key)
    if opts.pos then
        native.GameObjectPFXInitialPositionByHandle(h, manager, key,
            opts.pos[1] or 0, opts.pos[2] or 0, opts.pos[3] or 0)
    end
    if opts.vel then
        native.GameObjectPFXInitialVelocityByHandle(h, manager, key,
            opts.vel[1] or 0, opts.vel[2] or 0, opts.vel[3] or 0)
    end
    if opts.scale then
        local s = opts.scale
        if type(s) == "number" then
            native.GameObjectPFXScaleByHandle(h, manager, key, s, s, s)
        else
            native.GameObjectPFXScaleByHandle(h, manager, key, s[1] or 1, s[2] or 1, s[3] or 1)
        end
    end
    if opts.lifetime then
        native.GameObjectPFXSetLifeTimeByHandle(h, manager, key, opts.lifetime)
    end
    if opts.enabled == false then
        native.GameObjectPFXEnabledByHandle(h, manager, key, false)
    end
    bound[h] = bound[h] or {}
    bound[h][#bound[h] + 1] = { manager, key }
    ensureTick()
end

-- Объект следует за целью (флаг за шестом, люлька за БПЛА).
function attach.follow(h, target)
    if not game.exec then
        error("attach.follow: only server/shared scripts can link objects", 2)
    end
    inGame("follow")
    native.SetGameObjectTargetObjectByHandle(checkHandle(h, "follow"), checkHandle(target, "follow"))
end

-- Отвязать объект от цели (пара к follow, target = 0). h — хендл. Сторона: только server/shared.
function attach.unfollow(h)
    if not game.exec then
        error("attach.unfollow: only server/shared scripts can link objects", 2)
    end
    inGame("unfollow")
    native.SetGameObjectTargetObjectByHandle(checkHandle(h, "unfollow"), 0)
end

-- Снять все эффекты-привязки с объекта (сам объект живёт).
function attach.free(h)
    inGame("free")
    h = checkHandle(h, "free")
    for _, e in ipairs(bound[h] or {}) do
        pcall(native.GameObjectPFXDeleteByHandle, h, e[1], e[2])
    end
    bound[h] = nil
end
