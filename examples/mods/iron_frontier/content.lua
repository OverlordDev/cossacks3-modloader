-- content.lua — ростер для модлоадера. Описания ЗАМЕСТЯЮ ручные патчи:
-- модлоадер сам правит country.script, unit.script, units.objects, dmscript.global,
-- делает .prop и иконки, подставляет названия в локализацию.
-- Требует ПЕРЕЗАПУСКА игры. Проверка: `.content` в консоли, [content] в modloader.log.
--
-- Согласованность с lib/registry.lua: sid-ы и родители оттуда. registry —
-- источник правды для логики, этот файл — для движка. Расхождение — баг,
-- поэтому ниже sid-ы написаны те же и с комментарием.

-- ═════════════════════════════════════════════════════════════════════════════
-- ФРАНЦИЯ — Grande Armée
-- ═════════════════════════════════════════════════════════════════════════════
-- Родители: kingmusketeer (мушкетёр), grenadier, chasseur (егерь),
--           dragoon18fra (тяжёлая кавалерия), hussar, officer18.
-- Все шесть проверены как члены fra в country.script (2026-09-27).

unit {                                   -- registry: if19line
    sid = "if19line", from = "kingmusketeer", nations = { "fra" },
    base = { maxhp = 100, ["weapon[1].damage"] = 22 },
    prop = { vision = 700 },
    name = { ru = "Линейный мушкетёр", en = "Line Musketeer" },
}

unit {                                   -- registry: if19gren
    sid = "if19gren", from = "grenadier", nations = { "fra" },
    base = { maxhp = 135, ["weapon[1].damage"] = 30 },
    prop = { vision = 650 },
    name = { ru = "Гренадёр", en = "Grenadier" },
}

unit {                                   -- registry: if19jag
    sid = "if19jag", from = "chasseur", nations = { "fra" },
    base = { maxhp = 72, ["weapon[1].damage"] = 16 },
    prop = { vision = 1000 },
    name = { ru = "Егерь", en = "Chasseur" },
}

unit {                                   -- registry: if19cuir
    sid = "if19cuir", from = "dragoon18fra", nations = { "fra" },
    base = { maxhp = 185, ["weapon[1].damage"] = 34 },
    prop = { vision = 800 },
    name = { ru = "Кирасир", en = "Cuirassier" },
}

unit {                                   -- registry: if19huss
    sid = "if19huss", from = "hussar", nations = { "fra" },
    base = { maxhp = 95, ["weapon[1].damage"] = 24 },
    prop = { vision = 950 },
    name = { ru = "Гусар", en = "Hussar" },
}

unit {                                   -- registry: if19off
    sid = "if19off", from = "officer18", nations = { "fra" },
    base = { maxhp = 110, ["weapon[1].damage"] = 18 },
    prop = { vision = 900 },
    name = { ru = "Офицер", en = "Officer" },
}

-- ═════════════════════════════════════════════════════════════════════════════
-- РОССИЯ
-- ═════════════════════════════════════════════════════════════════════════════
-- Родители: musketeer18, grenadier, jagerpor (егерь), cossackdon (казак),
--           hussar, officer18. Все — члены rus.

unit {                                   -- registry: ir19line
    sid = "ir19line", from = "musketeer18", nations = { "rus" },
    base = { maxhp = 105, ["weapon[1].damage"] = 21 },
    prop = { vision = 700 },
    name = { ru = "Рядовой", en = "Musketeer" },
}

unit {                                   -- registry: ir19gren
    sid = "ir19gren", from = "grenadier", nations = { "rus" },
    base = { maxhp = 140, ["weapon[1].damage"] = 29 },
    prop = { vision = 650 },
    name = { ru = "Гренадёр", en = "Grenadier" },
}

unit {                                   -- registry: ir19jag
    sid = "ir19jag", from = "jagerpor", nations = { "rus" },
    base = { maxhp = 70, ["weapon[1].damage"] = 15 },
    prop = { vision = 1050 },
    name = { ru = "Батальонный егерь", en = "Battalion Jager" },
}

unit {                                   -- registry: ir19cos
    sid = "ir19cos", from = "cossackdon", nations = { "rus" },
    base = { maxhp = 100, ["weapon[1].damage"] = 23 },
    prop = { vision = 900 },
    name = { ru = "Казак", en = "Cossack" },
}

unit {                                   -- registry: ir19hus
    sid = "ir19hus", from = "hussar", nations = { "rus" },
    base = { maxhp = 92, ["weapon[1].damage"] = 22 },
    prop = { vision = 980 },
    name = { ru = "Гусар", en = "Hussar" },
}

unit {                                   -- registry: ir19off
    sid = "ir19off", from = "officer18", nations = { "rus" },
    base = { maxhp = 115, ["weapon[1].damage"] = 17 },
    prop = { vision = 900 },
    name = { ru = "Офицер", en = "Officer" },
}

-- ═════════════════════════════════════════════════════════════════════════════
-- ПРУССИЯ
-- ═════════════════════════════════════════════════════════════════════════════
-- Родители: musketeer18pru (фузелёр), grenadierpru, jagerpor, hussarpru, officer18.

unit {                                   -- registry: ip19line
    sid = "ip19line", from = "musketeer18pru", nations = { "pru" },
    base = { maxhp = 100, ["weapon[1].damage"] = 20 },
    prop = { vision = 700 },
    name = { ru = "Фузелёр", en = "Fusilier" },
}

unit {                                   -- registry: ip19gren
    sid = "ip19gren", from = "grenadierpru", nations = { "pru" },
    base = { maxhp = 132, ["weapon[1].damage"] = 28 },
    prop = { vision = 650 },
    name = { ru = "Гренадёр", en = "Grenadier" },
}

unit {                                   -- registry: ip19jag
    sid = "ip19jag", from = "jagerpor", nations = { "pru" },
    base = { maxhp = 68, ["weapon[1].damage"] = 14 },
    prop = { vision = 1050 },
    name = { ru = "Егерь", en = "Jager" },
}

unit {                                   -- registry: ip19hus
    sid = "ip19hus", from = "hussarpru", nations = { "pru" },
    base = { maxhp = 98, ["weapon[1].damage"] = 25 },
    prop = { vision = 950 },
    name = { ru = "Гусар", en = "Hussar" },
}

unit {                                   -- registry: ip19off
    sid = "ip19off", from = "officer18", nations = { "pru" },
    base = { maxhp = 112, ["weapon[1].damage"] = 18 },
    prop = { vision = 900 },
    name = { ru = "Офицер", en = "Officer" },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- ЧЕГО ЗДЕСЬ НЕТ СОЗНАТЕЛЬНО
-- ─────────────────────────────────────────────────────────────────────────────
-- 1) Артиллерия. cannon/howitzer/mortar/multicannon — родные юниты игры, их НЕТ
--    в ростерах наций, поэтому через content.lua они не объявляются. Мод работает
--    с ними напрямую: наводка, выбор снаряда, износ (lib/artillery.lua).
--
-- 2) Офицерские построения и списки ИИ. MODDING.md:173-175 предупреждает:
--    "Не наследуется то, что игра делает по имени родителя вне _unit_InitBase
--    (офицерские построения, списки ИИ) — это патчами". То есть новый мушкетёр
--    появится и нанимается, но в AddOfficersFormationInfExt и gc_ai_unit_* его
--    не будет. Это отдельная задача этапа M4 (нужны патчи в country.script).
--
-- 3) Свои модели. content.lua умеет model { file = "x.glb" } и модлоадер сам
--    конвертирует .glb -> .osm, но .glb нужно делать в Blender. У нас таких
--    файлов нет, поэтому все юниты идут на моделях родителей. Когда появятся
--    модели — здесь добавляется блок model и поле actor у нужных unit.
