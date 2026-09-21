-- Тест событий. Просто играй: зайди в меню, начни партию, построй/найми, отдай приказы,
-- повоюй, дай кому-то умереть и снеси здание. Каждое сработавшее событие молча получает
-- галочку; F8 — отчёт в консоль, в конце партии отчёт печатается сам.
-- Как выполнить каждое событие — подсказка в списке ниже.

local CHECKS = {
    { "game.menu",         "выйти в главное меню" },
    { "game.prepare",      "начать партию (генерация карты)" },
    { "game.start",        "партия загрузилась" },
    { "game.tick",         "идёт партия" },
    { "game.end",          "выйти из партии" },
    { "unit.spawn",        "нанять юнита" },
    { "unit.death",        "юнит погиб" },
    { "unit.destroy",      "тело юнита исчезло" },
    { "unit.damage",       "юнит получил урон (любой)" },
    { "building.spawn",    "поставить здание" },
    { "building.death",    "разрушить здание" },
    { "building.destroy",  "руины здания исчезли" },
    { "player.order",      "любой приказ ПКМ" },
}
-- виды приказов и урона — отдельные галочки
local ORDER_KINDS = { "move", "attack", "attackpoint", "guard", "build", "enter", "gather", "patrol" }
local OPTIONAL = { ["order:guard"] = true, ["order:patrol"] = true, ["order:attackpoint"] = true, ["order:enter"] = true }

local passed = {}   -- имя -> {count, detail}
local extra = {}    -- события, которых нет в списке (тоже покажем)
local known = {}
for _, c in ipairs(CHECKS) do known[c[1]] = true end

local function mark(name, detail)
    local p = passed[name]
    if p then p.count = p.count + 1 return end
    passed[name] = { count = 1, detail = detail or "" }
end

local function report()
    local ok, total, lines = 0, 0, {}
    local function row(name, hint, optional)
        total = total + 1
        local p = passed[name]
        if p then
            ok = ok + 1
            lines[#lines + 1] = string.format("  [+] %-22s x%-6d %s", name, p.count, p.detail)
        else
            lines[#lines + 1] = string.format("  [ ] %-22s %s%s", name, hint, optional and "  (необязательно)" or "")
        end
    end
    for _, c in ipairs(CHECKS) do row(c[1], c[2]) end
    for _, k in ipairs(ORDER_KINDS) do row("order:" .. k, "приказ " .. k, OPTIONAL["order:" .. k]) end
    row("damage:melee/shot", "урон от юнита юниту")
    row("damage:building", "урон по зданию")

    log.info("========== EVENT TEST ==========")
    for _, l in ipairs(lines) do log.info(l) end
    local names = {}
    for n in pairs(extra) do names[#names + 1] = n end
    table.sort(names)
    if #names > 0 then log.info("  другие события: " .. table.concat(names, ", ")) end
    local missing = {}
    for _, c in ipairs(CHECKS) do if not passed[c[1]] then missing[#missing + 1] = c[1] end end
    if #missing == 0 then
        log.info(string.format("  ТЕСТ ПРОЙДЕН: основные события все (%d/%d с видами)", ok, total))
    else
        log.warn(string.format("  НЕ ПРОШЛИ (%d): %s   — всего %d/%d", #missing, table.concat(missing, ", "), ok, total))
    end
    log.info("================================")
end

-- любое событие — галочка по имени
events.on("*", function(name)
    if known[name] then mark(name) else extra[name] = true end
end)

-- подробности: первое срабатывание запоминает, что пришло
local function isBuilding(h)
    if not units or not game.exec then return nil end
    local ok, info = pcall(units.info, h)
    return ok and info and info.sid or nil
end

for _, kind in ipairs({ "unit", "building" }) do
    for _, ev in ipairs({ "spawn", "death", "destroy" }) do
        events.on(kind .. "." .. ev, function(name, handle, basename)
            if passed[name] and passed[name].detail == "" then
                passed[name].detail = string.format("хендл %s, %s", tostring(handle), tostring(basename))
            end
        end)
    end
end

local buildingHandles = {}
events.on("building.spawn", function(_, h) buildingHandles[h] = true end)

events.on("unit.damage", function(name, attacker, target, damage)
    if passed[name] and passed[name].detail == "" then
        passed[name].detail = string.format("%d -> %d, урон %d", attacker, target, damage)
    end
    if buildingHandles[target] then mark("damage:building", "по зданию " .. target)
    else mark("damage:melee/shot", string.format("%d -> %d, %d", attacker, target, damage)) end
end)

events.on("player.order", function(name, order)
    mark("order:" .. order.kind, string.format("цель=%d x=%.0f z=%.0f", order.target, order.x, order.z))
    if passed[name] and passed[name].detail == "" then passed[name].detail = order.kind end
end)

events.on("game.end", function() report() end)
input.bind("F8", report)

log.info("event_test: играй как обычно, F8 — отчёт по событиям")
