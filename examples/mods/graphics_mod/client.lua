-- Графика целиком из Lua: таблица gfx. Всё, что здесь меняется, видит только этот компьютер —
-- на ход партии не влияет, в сетевой игре другим игрокам мод не нужен.
--
-- Каждая группа работает одинаково:
--   gfx.fog{ density = 2.0 }   -- записать
--   gfx.fog()                  -- прочитать всё: { enabled = true, density = 2.0, ... }
-- Группы: post, render, camera, fog, clouds, sky, shadows, light, time, water, wind, terrain.
-- Тени, SSAO и FXAA пишутся ещё и в настройки самой игры — иначе движок вернёт своё значение.
-- Любой натив графики доступен и напрямую: gfx.SetShadowMapSize(4096).

-- Профиль — обычная таблица. gfx.apply применяет её целиком.
local profiles = {
    { name = "cinematic", settings = {
        -- preset — номер записи в data/posteffects/posteffects.lib (0 default, 1 winter, 2 desaturate).
        post    = { preset = 0, ssao = true, dof = true },
        camera  = { dof = true, depth = 220 },
        fog     = { enabled = true, density = 1.6, power = 1.2, start = 400, finish = 3000 },
        shadows = { enabled = true, size = 4096 },
        clouds  = { visible = true, speed = 1.4, fog = 0.7 },
        sky     = { visible = true, flareAngle = 30 },
        render  = { fxaa = true },
        -- preset — то, чего нет в настройках игры: сила bloom, насыщенность, виньетка.
        preset  = { bloom = 0.12, hdr = 1.8, saturation = 1.25, contrast = 1.05,
                    vignetteInner = 0.65, vignetteOuter = 1.5 },
    } },
    { name = "battle", settings = {
        -- Чёткая картинка без размытия: в бою важнее читаемость, чем красота.
        post    = { preset = 0, ssao = true, dof = false },
        camera  = { dof = false },
        fog     = { enabled = true, density = 0.6, power = 1.0 },
        shadows = { enabled = true, size = 2048 },
        clouds  = { speed = 0.6, fog = 0.2 },
        render  = { fxaa = true },
        -- в бою — чуть резче и без виньетки, чтобы по краям экрана всё было видно
        preset  = { bloom = 0.04, hdr = 1.4, saturation = 1.1, contrast = 1.0,
                    vignetteInner = 0.9, vignetteOuter = 1.9 },
    } },
    { name = "winter", settings = {
        post    = { preset = 1, ssao = true, dof = false },
        fog     = { enabled = true, density = 2.2, power = 1.4 },
        clouds  = { visible = true, speed = 2.0, fog = 0.9 },
        shadows = { enabled = true, size = 4096 },
    } },
    { name = "performance", settings = {
        -- Всё лишнее выключено — для слабых машин и больших замесов.
        post    = { ssao = false, dof = false },
        camera  = { dof = false },
        fog     = { enabled = false },
        shadows = { enabled = false },
        clouds  = { active = false },
        render  = { fxaa = false },
        preset  = { bloom = 0, ssao = false, dof = false },
    } },
}

local vanilla, vanillaPreset  -- снимок настроек до вмешательства (один раз за партию)
local current = 0

local function apply(index)
    local p = profiles[index]
    local settings = {}
    for group, options in pairs(p.settings) do
        if group ~= "preset" then settings[group] = options end
    end
    gfx.apply(settings)
    if p.settings.preset then gfx.preset(p.settings.preset) end
    log.info("graphics: " .. p.name)
end

events.on("game.start", function()
    vanilla = gfx.snapshot()      -- чтобы было куда вернуться
    vanillaPreset = gfx.preset()  -- пост-обработка хранится отдельно
    current = 0
end)

events.on("game.end", function() vanilla, vanillaPreset = nil, nil end)

-- F7 — следующий профиль по кругу.
input.bind("F7", function()
    if not game.isInGame() then return end
    current = current % #profiles + 1
    apply(current)
end)

-- F8 — вернуть то, что было до мода.
input.bind("F8", function()
    if not vanilla then return end
    gfx.apply(vanilla)
    gfx.preset(vanillaPreset)
    current = 0
    log.info("graphics: vanilla restored")
end)

-- Плавная смена дня и ночи: light.presets содержит light0..light3, переход — за blendTime мс.
-- gfx.light.list() вернёт все доступные пресеты света.
local night = false
input.bind("F10", function()
    if not game.isInGame() then return end
    night = not night
    gfx.light{ blendTime = 4000, blendTo = night and "light1" or "light0" }
    log.info("light: " .. (night and "night" or "day"))
end)
