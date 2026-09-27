-- registry.lua — ЕДИНЫЙ источник правды по ростеру и ролям.
--
-- Почему отдельный файл: одно и то же знание нужно трём местам — content.lua
-- (описание для модлоадера), shared-логике (мораль, доктрина, артиллерия) и
-- клиентскому UI (панель). Если это писать в трёх местах, через месяц они
-- разойдутся. Здесь лежит голый факт, потребители берут своё.
--
-- ВАЖНО про lockstep: файл только читается, поведения не имеет. Любая запись
-- в state/мир обязана идти из shared.lua и быть детерминированной.

local R = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Роли
-- ─────────────────────────────────────────────────────────────────────────────
-- formation:  в каком строю юunit теряет бой (line = только в линии/каре)
-- morale:     насколько сильно проседает при потерях
-- steady:     скорость восстановления морали (1 = эталон)
R.ROLE = {
    line = {
        name = "Линейная пехота",
        formation = "line",        -- главная сила: максимум огня в линии
        moraleLoss = 1.0,          -- теряет мораль обычным темпом
        steady = 1.0,
        canSquare = true,          -- умеет каре против кавалерии
    },
    guard = {
        name = "Гвардия",
        formation = "line",
        moraleLoss = 0.6,          -- гвардия держится заметно лучше
        steady = 1.4,
        canSquare = true,
    },
    skirmisher = {
        name = "Лёгкая пехота",
        formation = "skirmish",    -- вне строя: в линии бесполезна
        moraleLoss = 1.6,          -- в свалке бежит первой
        steady = 0.8,
        canSquare = false,
    },
    cavalry_heavy = {
        name = "Тяжёлая кавалерия",
        formation = "cavalry",
        moraleLoss = 1.2,
        steady = 0.7,              -- удар и паника связаны
        canSquare = false,
    },
    cavalry_light = {
        name = "Лёгкая кавалерия",
        formation = "cavalry",
        moraleLoss = 1.4,
        steady = 1.1,
        canSquare = false,
    },
    artillery = {
        name = "Артиллерия",
        formation = "artillery",   -- своя колонна, не стреляет в развёрнутом виде
        moraleLoss = 2.0,          -- расчёт бежит при первом попадании
        steady = 0.6,
        canSquare = false,
    },
    engineer = {
        name = "Сапёры",
        formation = "skirmish",
        moraleLoss = 1.0,
        steady = 1.0,
        canSquare = false,
    },
    officer = {
        name = "Офицер",
        formation = "skirmish",
        moraleLoss = 0.4,          -- офицер почти не паникует
        steady = 2.0,
        canSquare = false,
        aura = 260,                -- радиус ауры в шагах
    },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Ростер
-- ─────────────────────────────────────────────────────────────────────────────
-- sid       — новый тип юнита (обязательно латиница, строчные)
-- from      — родитель из игры: даёт модель, анимации, иконку, клетку найма.
--             Content.cpp предупредит, если родитель не член целевой нации.
-- nation    — fra (Франция) / rus (Россия) / pru (Пруссия)
-- role      — ключ из R.ROLE
-- hp        — TObjBase.maxhp
-- dmg       — TObjBase["weapon[1].damage"] (musket = 20 в игре, у нас своя линейка)
-- speed     — множитель скорости
-- vision    — TObjProp.vision
-- price     — TObjBase["price[0]"] (золото)
--
-- Цифры — исторический порядок величин, не точная реконструкция. Правятся
-- после прогона (см. план, этап M9 «баланс»).
R.UNITS = {
    -- ── Франция: Grande Armée ───────────────────────────────────────────────
    { sid = "if19line", nation = "fra", from = "kingmusketeer", role = "line",
      name = { ru = "Линейный мушкетёр", en = "Line Musketeer" },
      hp = 100, dmg = 22, speed = 1.0, vision = 700, price = 90 },
    { sid = "if19gren", nation = "fra", from = "grenadier", role = "guard",
      name = { ru = "Гренадёр", en = "Grenadier" },
      hp = 135, dmg = 30, speed = 0.95, vision = 650, price = 140 },
    { sid = "if19jag", nation = "fra", from = "chasseur", role = "skirmisher",
      name = { ru = "Егерь", en = "Chasseur" },
      hp = 72, dmg = 16, speed = 1.35, vision = 1000, price = 110 },
    { sid = "if19cuir", nation = "fra", from = "dragoon18fra", role = "cavalry_heavy",
      name = { ru = "Кирасир", en = "Cuirassier" },
      hp = 185, dmg = 34, speed = 1.15, vision = 800, price = 260 },
    { sid = "if19huss", nation = "fra", from = "hussar", role = "cavalry_light",
      name = { ru = "Гусар", en = "Hussar" },
      hp = 95, dmg = 24, speed = 1.6, vision = 950, price = 200 },
    { sid = "if19off", nation = "fra", from = "officer18", role = "officer",
      name = { ru = "Офицер", en = "Officer" },
      hp = 110, dmg = 18, speed = 1.4, vision = 900, price = 150 },

    -- ── Россия ──────────────────────────────────────────────────────────────
    { sid = "ir19line", nation = "rus", from = "musketeer18", role = "line",
      name = { ru = "Рядовой", en = "Musketeer" },
      hp = 105, dmg = 21, speed = 1.0, vision = 700, price = 85 },
    { sid = "ir19gren", nation = "rus", from = "grenadier", role = "guard",
      name = { ru = "Гренадёр", en = "Grenadier" },
      hp = 140, dmg = 29, speed = 0.92, vision = 650, price = 135 },
    { sid = "ir19jag", nation = "rus", from = "jagerpor", role = "skirmisher",
      name = { ru = "Батальонный егерь", en = "Battalion Jager" },
      hp = 70, dmg = 15, speed = 1.4, vision = 1050, price = 105 },
    { sid = "ir19cos", nation = "rus", from = "cossackdon", role = "cavalry_light",
      name = { ru = "Казак", en = "Cossack" },
      hp = 100, dmg = 23, speed = 1.55, vision = 900, price = 190 },
    { sid = "ir19hus", nation = "rus", from = "hussar", role = "cavalry_light",
      name = { ru = "Гусар", en = "Hussar" },
      hp = 92, dmg = 22, speed = 1.65, vision = 980, price = 205 },
    { sid = "ir19off", nation = "rus", from = "officer18", role = "officer",
      name = { ru = "Офицер", en = "Officer" },
      hp = 115, dmg = 17, speed = 1.4, vision = 900, price = 145 },

    -- ── Пруссия ─────────────────────────────────────────────────────────────
    { sid = "ip19line", nation = "pru", from = "musketeer18pru", role = "line",
      name = { ru = "Фузелёр", en = "Fusilier" },
      hp = 100, dmg = 20, speed = 1.05, vision = 700, price = 90 },
    { sid = "ip19gren", nation = "pru", from = "grenadierpru", role = "guard",
      name = { ru = "Гренадёр", en = "Grenadier" },
      hp = 132, dmg = 28, speed = 0.98, vision = 650, price = 130 },
    { sid = "ip19jag", nation = "pru", from = "jagerpor", role = "skirmisher",
      name = { ru = "Егерь", en = "Jager" },
      hp = 68, dmg = 14, speed = 1.45, vision = 1050, price = 100 },
    { sid = "ip19hus", nation = "pru", from = "hussarpru", role = "cavalry_light",
      name = { ru = "Гусар", en = "Hussar" },
      hp = 98, dmg = 25, speed = 1.6, vision = 950, price = 200 },
    { sid = "ip19off", nation = "pru", from = "officer18", role = "officer",
      name = { ru = "Офицер", en = "Officer" },
      hp = 112, dmg = 18, speed = 1.4, vision = 900, price = 150 },
}

-- Индексы для быстрого поиска. Строим один раз, только чтение.
R.bySid = {}
R.byRole = {}
R.ARTILLERY_SIDS = {}   -- родные орудия игры, которые мод усиливает
for _, u in ipairs(R.UNITS) do
    R.bySid[u.sid] = u
    R.byRole[u.role] = R.byRole[u.role] or {}
    table.insert(R.byRole[u.role], u)
end

-- Родные орудия игры (cannon/howitzer/mortar/multicannon). Они не в ростере
-- наций, поэтому не объявляются через content.lua — мод работает с ними
-- напрямую, добавляя выбор снаряда, износ и наводку (см. lib/artillery.lua).
for _, sid in ipairs({ "cannon", "howitzer", "mortar", "multicannon", "framegun" }) do
    R.ARTILLERY_SIDS[sid] = true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Запросы
-- ─────────────────────────────────────────────────────────────────────────────

-- Роль по sid. Для ЧУЖИХ юнитов (старая пехота, здания) возвращается "line",
-- чтобы модуль морали работал и на них, а не падал на nil.
function R.roleOf(sid)
    local u = R.bySid[sid]
    if u then return u.role end
    if R.ARTILLERY_SIDS[sid] then return "artillery" end
    return "line"
end

-- true, если это орудие (наше или родное).
function R.isArtillery(sid)
    return R.ARTILLERY_SIDS[sid] == true
end

-- Описание роли с запасным вариантом — чтобы вызывающий код не проверял nil.
function R.roleDef(role)
    return R.ROLE[role] or R.ROLE.line
end

-- Все sid данной нации — для клиентского UI и отчётов.
function R.sidsOf(nation)
    local out = {}
    for _, u in ipairs(R.UNITS) do
        if u.nation == nation then out[#out + 1] = u.sid end
    end
    return out
end

return R
