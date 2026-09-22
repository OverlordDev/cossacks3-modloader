-- Снимок мира у этого игрока. Раз в cfg.interval секунд ИГРОВОГО времени (GetGameTime — время
-- симуляции, одно на всех в сетевой игре) считаем отпечаток и отправляем хосту.
-- Хост сравнивает отпечатки с одинаковым временем (server.lua) и присылает вердикт.
--
-- Отпечаток — не один хеш, а набор по частям: "p2.pos" (позиции юнитов игрока 2), "p2.hp",
-- "p0.res" и т.д. Так по расхождению видно, ЧТО разошлось, а не только что разошлось.
-- Хеш юнитов — сумма хешей отдельных юнитов, поэтому порядок обхода не важен.

local cfg = {
    interval = 5,       -- секунд игрового времени между сверками
    chunk = 6000,       -- байт на одно сообщение с подробностями (лимит сети 8 КБ)
}

local nextT = nil
local want = nil        -- хост попросил подробный список юнитов этого игрока
local verdicts = { ok = 0, bad = 0 }

local M32 = 0xFFFFFFFF
local function mix(h, v)
    v = math.tointeger(v) or 0
    h = ((h ~ (v & M32)) * 16777619) & M32
    return ((h ~ (h >> 15)) * 2246822519) & M32
end
local function q(f) return math.floor((tonumber(f) or 0) * 100 + 0.5) end   -- float -> целое, точность 0.01
local function b(v) return v and 1 or 0 end

local RES = { "food", "wood", "stone", "gold", "iron", "coal" }

local function unitOf(h)
    local hp = objects.get(h, "hp")
    if hp == nil then return nil end                     -- не юнит/здание (ресурсы, деревья)
    local x, z = objects.pos(h)
    return {
        uid = objects.get(h, "uid") or 0,
        cid = objects.get(h, "cid") or 0,
        id = objects.get(h, "id") or 0,
        hp = hp,
        dead = b(objects.get(h, "bdead")),
        x = q(x), z = q(z),
        ord = objects.get(h, "orders[0].itype") or 0,
        trg = objects.get(h, "trghnd") or 0,
    }
end

local function snapshot(detailPlayer)
    local c, detail = {}, {}
    for i = 0, 15 do
        local list = objects.list(i)
        if #list > 0 then
            local n, sHp, sPos, sOrd, sType = 0, 0, 0, 0, 0
            for _, h in ipairs(list) do
                local u = unitOf(h)
                if u then
                    n = n + 1
                    local k = mix(0, u.uid)
                    sType = (sType + mix(mix(k, u.cid), u.id)) & M32
                    sHp = (sHp + mix(mix(k, u.hp), u.dead)) & M32
                    sPos = (sPos + mix(mix(k, u.x), u.z)) & M32
                    sOrd = (sOrd + mix(mix(k, u.ord), u.trg)) & M32
                    if detailPlayer == i then
                        detail[#detail + 1] = string.format("%d: тип %d/%d hp=%d%s x=%.2f z=%.2f приказ=%d цель=%d",
                            u.uid, u.cid, u.id, u.hp, u.dead == 1 and " мёртв" or "", u.x / 100, u.z / 100, u.ord, u.trg)
                    end
                end
            end
            local p = "p" .. i
            c[p .. ".count"], c[p .. ".types"], c[p .. ".hp"], c[p .. ".pos"], c[p .. ".orders"] = n, sType, sHp, sPos, sOrd
            local ok, pl = pcall(player, i)
            if ok and pl then
                local r = 0
                for _, key in ipairs(RES) do
                    local okv, v = pcall(function() return pl[key] end)
                    r = mix(r, okv and q(v) or 0)
                end
                c[p .. ".res"] = r
            end
        end
    end
    return c, detail
end

local function sendDetail(t, p, detail)
    local parts, cur, size = {}, {}, 0
    for _, line in ipairs(detail) do
        if size + #line + 1 > cfg.chunk and #cur > 0 then
            parts[#parts + 1] = table.concat(cur, "\n")
            cur, size = {}, 0
        end
        cur[#cur + 1] = line
        size = size + #line + 1
    end
    parts[#parts + 1] = table.concat(cur, "\n")
    for k, s in ipairs(parts) do
        net.send("dw.detail", { t = t, p = p, part = k, parts = #parts, s = s })
    end
end

events.on("game.start", function()
    nextT, want = nil, nil
    verdicts.ok, verdicts.bad = 0, 0
    if game.mode() == "offline" then
        log.info("одиночная игра: сравнивать не с кем, отпечаток — по Ctrl+Shift+D")
    end
end)

events.on("game.tick", function()
    if game.mode() == "offline" then return end
    local t = native.GetGameTime()
    if not t then return end
    local slot = math.floor(t / cfg.interval)
    if not nextT then nextT = slot + 1; return end
    if slot < nextT then return end
    nextT = slot + 1
    local key = string.format("%.3f", t)
    local p = want
    want = nil
    local c, detail = snapshot(p)
    net.send("dw.fp", { t = key, c = c })
    if p then sendDetail(key, p, detail) end
end)

net.on("dw.want", function(data) want = tonumber(data) end)
net.on("dw.ok", function() verdicts.ok = verdicts.ok + 1 end)
net.on("dw.report", function(text)
    verdicts.bad = verdicts.bad + 1
    for line in tostring(text):gmatch("[^\n]+") do log.error(line) end
end)

-- Свой отпечаток прямо сейчас — сравнить глазами или проверить, что мод живой.
input.bind("Ctrl+Shift+D", function()
    if not game.isInGame() then return end
    local t0 = os.clock()
    local c = snapshot()
    local ms = (os.clock() - t0) * 1000
    local keys = {}
    for k in pairs(c) do keys[#keys + 1] = k end
    table.sort(keys)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = string.format("%s=%08X", k, c[k]) end
    log.info(string.format("время %.3f, снимок %.1f мс; сверок без расхождений: %d, с расхождением: %d",
        native.GetGameTime() or 0, ms, verdicts.ok, verdicts.bad))
    log.info(table.concat(out, "  "))
end)
