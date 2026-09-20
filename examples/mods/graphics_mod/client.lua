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

-- ---------------------------------------------------------------------------
-- Время суток
-- ---------------------------------------------------------------------------
-- В data/env/lights/light.presets лежат готовые пресеты освещения (light0..light3), а движок умеет
-- переходить между ними плавно: gfx.light{ blendTo = ..., blendTime = миллисекунды }.
-- Берём их в том порядке, в каком их отдаёт игра, и под каждый подгоняем туман, облака и цвет.

-- Настроение фаз: на сколько менять туман и картинку. Ключ — номер пресета света.
local moods = {
    [0] = { name = "полдень", fog = { density = 0.8, power = 1.0 }, clouds = { fog = 0.25, speed = 0.8 },
            preset = { saturation = 1.2, hdr = 1.5, bloom = 0.08 } },
    [1] = { name = "ночь",    fog = { density = 2.6, power = 1.5 }, clouds = { fog = 0.9,  speed = 1.6 },
            preset = { saturation = 0.85, hdr = 1.1, bloom = 0.16 } },
    [2] = { name = "рассвет", fog = { density = 1.8, power = 1.3 }, clouds = { fog = 0.6,  speed = 1.2 },
            preset = { saturation = 1.3, hdr = 1.9, bloom = 0.18 } },
    [3] = { name = "закат",   fog = { density = 1.4, power = 1.2 }, clouds = { fog = 0.5,  speed = 1.0 },
            preset = { saturation = 1.35, hdr = 2.0, bloom = 0.2 } },
}

local cycle = { on = false, patterns = {}, index = 1, nextAt = 0, seconds = 40 }

local function applyPhase(index, blendMs)
    local pattern = cycle.patterns[index]
    if not pattern then return end
    gfx.light{ blendTime = blendMs, blendTo = pattern }

    local mood = moods[index - 1]
    if mood then
        gfx.fog(mood.fog)
        gfx.clouds(mood.clouds)
        gfx.preset(mood.preset)
        log.info(("время суток: %s (%s)"):format(mood.name, pattern))
    else
        log.info("время суток: " .. pattern)
    end
end

local function nextPhase(blendMs)
    cycle.index = cycle.index % #cycle.patterns + 1
    cycle.nextAt = os.clock() + cycle.seconds
    applyPhase(cycle.index, blendMs)
end

events.on("game.start", function()
    cycle.patterns = gfx.light.list()
    cycle.on = false
    cycle.index = 1
end)

events.on("game.tick", function()
    if cycle.on and #cycle.patterns > 0 and os.clock() >= cycle.nextAt then
        nextPhase(cycle.seconds * 800) -- переход занимает почти всю фазу, поэтому смены не видно
    end
end)

-- F10 — запустить или остановить смену времени суток.
input.bind("F10", function()
    if not game.isInGame() then return end
    if #cycle.patterns == 0 then
        log.warn("нет пресетов света (data/env/lights/light.presets)")
        return
    end
    cycle.on = not cycle.on
    log.info("время суток: " .. (cycle.on and "идёт" or "остановлено"))
    if cycle.on then -- начинаем с текущей фазы, а не с перескока на следующую
        cycle.nextAt = os.clock() + cycle.seconds
        applyPhase(cycle.index, 2000)
    end
end)

-- F11 — следующая фаза сразу, переход за 2 секунды. Удобно показывать.
input.bind("F11", function()
    if not game.isInGame() or #cycle.patterns == 0 then return end
    nextPhase(2000)
end)

-- ---------------------------------------------------------------------------
-- Камера
-- ---------------------------------------------------------------------------
-- В ванили камера жёсткая: фокус 400 без зума, наклон всегда -32 градуса (data/cameras/camera.cfg).
-- Кинематографичная: чем ближе подлетаешь, тем положе угол и уже поле зрения — как в новых RTS.
local cinematicCamera = false

input.bind("F12", function()
    if not game.isInGame() then return end
    cinematicCamera = not cinematicCamera
    if cinematicCamera then
        gfx.camera{
            -- {минимальный фокус, максимальный, степень} — появляется настоящий зум
            focal = { 260, 900, 1.0 },
            -- {угол при низкой камере (мин, макс), при высокой (мин, макс), степень,
            --  мин. и макс. расстояние до цели, коэффициент высоты}
            -- Внизу почти горизонт, вверху вид сверху — наклон меняется сам при зуме.
            freeRotation = { -14, -14, -62, -62, 1.0, 1, 10, 0.15 },
            zoomSpeed = 1.4,
            dof = true,
        }
        gfx.camera.stop() -- на всякий случай: чтобы камера никуда не уезжала сама
        log.info("камера: кинематографичная (F12 — вернуть обычную)")
    else
        -- Вернуть ванильную: перечитать профиль камеры из файла игры — там все исходные значения.
        gfx.camera{ profile = gfx.camera().profile, dof = false }
        log.info("камера: обычная")
    end
end)
