#include "pch.h"
#include "GfxApi.h"

#include <cstring>
#include <set>
#include <string>

namespace
{
    // Нативы графики, разрешённые клиентским скриптам как gfx.<Name>.
    // Всё здесь меняет только картинку у этого игрока: ход партии не зависит от этих значений,
    // поэтому мод может включать их без сервера и без рассинхрона.
    // Нативов с var-параметрами тут нет — NativeCall их не умеет (см. NativeCall.cpp).
    const std::set<std::string, std::less<>>& Allowed()
    {
        static const std::set<std::string, std::less<>> kNames = {
            // пост-обработка (пресеты из data/posteffects/posteffects.lib)
            "SetCurrentHDRIndex", "GetCurrentHDRIndex", "SetCurrentPHDRIndex", "GetCurrentPHDRIndex",
            "SetDOFEnable", "GetDOFEnable", "SetSSAOEnable", "GetSSAOEnable",
            // камера
            "SetCameraDynamicDOF", "GetCameraDynamicDOF", "SetCameraDepthOfView", "GetCameraDepthOfView",
            "SetCameraDynamicFocalLength", "GetCameraDynamicFocalLength", "SetCameraFocalLengthInfo",
            "GetCameraFieldOfViewByFocalLength", "GetCameraFocalLengthByFieldOfView",
            "SetCameraMouseRotateFactor", "GetCameraMouseRotateFactor",
            "SetCameraMouseDistanceSpeed", "GetCameraMouseDistanceSpeed", "SetCameraSceneScale",
            "SetCameraElasticTargetAngle", "GetCameraElasticTargetAngle",
            "SetCameraElasticTargetDistance", "GetCameraElasticTargetDistance",
            "SetCameraPropertiesFromFile", "GetCameraPropertieFileName",
            "SetCameraBounded", "GetCameraBounded", "SetCameraAutoRayCast", "GetCameraAutoRayCast",
            "SetCameraControlMouseWheelRotate", "GetCameraControlMouseWheelRotate",
            "SetCameraControlMouseWheelDistance", "GetCameraControlMouseWheelDistance",
            "GetCameraHeightTarget",
            "SetCameraFreeRotationInfo", "GetCameraFreeRotationMode", "SetCameraRestrictInfo",
            "SetCameraElasticRotateFactor", "SetCameraElasticVRotateFactor", "SetCameraElasticMoveFactor",
            "SetCameraElasticMoveTurnOff", "SetCameraElasticRotationTurnOff",
            "SetCameraElasticDistance", "GetCameraElasticDistance", "GetCameraDistanceToTargetObject",
            "SetCameraControlMode", "GetCameraControlMode", "SetCameraDistToGroups", "GetCameraDistToGroups",
            // туман
            "SetFogEnable", "GetFogEnable",
            "SetCameraDynFogDepth", "GetCameraDynFogDepth", "SetCameraDynFogStart", "GetCameraDynFogStart",
            "SetCameraDynFogEnd", "GetCameraDynFogEnd", "SetCameraDynFogDensity", "GetCameraDynFogDensity",
            "SetCameraDynFogPower", "GetCameraDynFogPower", "SetCameraDynFogOffset", "GetCameraDynFogOffset",
            // облака и небо
            "SetCloudsVisible", "GetCloudsVisible", "SetCloudsActive", "GetCloudsActive",
            "SetCloudsHorizont", "GetCloudsHorizont", "SetCloudsHeight", "GetCloudsHeight",
            "SetCloudsFogDensity", "GetCloudsFogDensity", "SetCloudsSpeedFactor", "GetCloudsSpeedFactor",
            "SetSkyDomeVisible", "GetSkyDomeVisible", "SetSkyDomeActive", "GetSkyDomeActive",
            "SetLensFlareAngle", "GetLensFlareAngle", "SetLensFlareZOffset", "GetLensFlareZOffset",
            "SetLensFlareFileName", "GetLensFlareFileName",
            // свет (пресеты из data/env/lights/light.presets)
            "SetLightPattern", "SetLightPatternByIndex", "GetLightPatternsCount", "GetLightPatternID",
            "SetBlendToLightPattern", "GetBlendToLightPattern",
            "SetBlendToLightPatternInterval", "GetBlendToLightPatternInterval",
            // тени
            "SetShadowEnabled", "GetShadowEnabled", "SetShadowMapSize", "GetShadowMapSize",
            "SetShadowMapScaleHeight", "GetShadowMapScaleHeight", "SetShadowMapAddHeight", "GetShadowMapAddHeight",
            "SetShadowMapLightDepth", "GetShadowMapLightDepth", "SetShadowMapPolygonOffset",
            // время суток и сезон
            "SetTimeSpeedFactor", "GetTimeSpeedFactor", "GetCurrentTime", "GetTotalTime",
            "SetGameTime", "GetGameTime", "GetRealTime", "SetSeasonType", "GetSeasonType",
            "SetDateTimeManagerEnabled", "GetDateTimeManagerEnabled", "SetFOWDateTime", "GetFOWDateTime",
            // вода
            "SetCurrentWaterName", "GetCurrentWaterName", "SetCurrentWaterIndex", "GetCurrentWaterIndex",
            "GetCurrentWaterOffset",
            // ветер (гнёт траву и деревья, двигает облака)
            "SetAirWindVector", "SetAirWindVectorTarget", "SetAirWindRandom", "GetAirWindRandom",
            "SetAirWindIntervalTarget", "GetAirWindIntervalTarget",
            // земля
            "SetTerrainVisible", "GetTerrainVisible", "SetTerrainBordersVisible", "GetTerrainBordersVisible",
            "SetTerrainBordersEnabled", "GetTerrainBordersEnabled", "SetTerrainBordersStep", "GetTerrainBordersStep",
            "SetTerrainColorMode", "GetTerrainColorMode", "SetTerrainColorData",
            // частицы и подсветка юнитов
            "SetPFXPerlinPFXManagerBrightness", "GetPFXPerlinPFXManagerBrightness",
            "SetPFXPerlinPFXManagerGamma", "GetPFXPerlinPFXManagerGamma",
            "SetHighlightRenderSettings",
            // сглаживание и отсечение невидимого
            "SetFXAAEnable", "GetFXAAEnable", "SetAntiAliasing", "GetAntiAliasing",
            "SetVisibilityCulling", "GetVisibilityCulling",
            "SetObjectBasedVisibilityCulling", "GetObjectBasedVisibilityCulling",
            // вертикальная синхронизация
            "SetVSyncMode", "GetVSyncMode",
            // настройки видео самой игры: тени, SSAO и FXAA движок берёт отсюда, а не только из Set*-нативов
            "SetProjectOptionAsBoolean", "GetProjectOptionAsBoolean",
            "SetProjectOptionAsInteger", "GetProjectOptionAsInteger",
            "SetProjectOptionAsString", "GetProjectOptionAsString",
            "SetProjectOptionAsFloat", "GetProjectOptionAsFloat",
        };
        return kNames;
    }
}

bool GfxApi::IsGraphicsNative(const char* name)
{
    return name && Allowed().count(std::string_view(name)) != 0;
}

// Обёртки: каждая группа вызывается как gfx.<группа>{ключ = значение} для записи и gfx.<группа>()
// для чтения. Значения-списки ({min, max, power}) раскладываются в аргументы натива.
const char* GfxApi::Prelude()
{
    return R"lua(
local groups = {}

local function defgroup(name, props, extra)
    local g = extra or {}
    local function read(onlySettable)
        local out = {}
        for key, p in pairs(props) do
            local getter = p.read or (p.get and gfx[p.get])
            if getter and not (onlySettable and not (p.set or p.apply)) then
                -- вне партии часть нативов падает (сцены ещё нет) — такие ключи просто пропускаем
                local ok, value = pcall(getter)
                if ok then out[key] = value end
            end
        end
        return out
    end
    local function write(t)
        for key, value in pairs(t) do
            local p = props[key]
            if not p then error("gfx." .. name .. ": unknown option '" .. tostring(key) .. "'", 3) end
            if p.apply then p.apply(value)
            elseif not p.set then error("gfx." .. name .. ": '" .. key .. "' is read-only", 3)
            elseif p.list then gfx[p.set](table.unpack(value))
            else gfx[p.set](value) end
        end
        return g
    end
    setmetatable(g, { __call = function(_, t) if t == nil then return read() end return write(t) end })
    groups[name] = { set = write, read = read }
    gfx[name] = g
end

-- Настройки видео самой игры (окно «Настройки»). Тени, SSAO и FXAA движок берёт отсюда: если
-- поменять только Set*Enable-натив, игра вернёт своё значение и эффект «не включится».
-- Полный список ключей — в data/scripts/lib/gui.script, _gui_GetSettingsValues.
function gfx.option(name, value)
    if value == nil then return gfx.GetProjectOptionAsString(name) end
    if type(value) == "boolean" then return gfx.SetProjectOptionAsBoolean(name, value) end
    if type(value) == "number" then return gfx.SetProjectOptionAsInteger(name, value) end
    return gfx.SetProjectOptionAsString(name, value)
end

-- Переключатель, который нужно ставить и нативом, и в настройках игры.
local function switch(native, optionName)
    return {
        read  = function() return gfx.GetProjectOptionAsBoolean(optionName) end,
        apply = function(v)
            gfx["Set" .. native](v)
            gfx.SetProjectOptionAsBoolean(optionName, v)
        end,
    }
end

-- Пост-обработка: bloom/HDR, контраст, виньетка, SSAO, DOF, гамма.
-- preset — номер записи в data/posteffects/posteffects.lib (0 default, 1 winter, 2 desaturate).
defgroup("post", {
    preset  = { get = "GetCurrentHDRIndex",  set = "SetCurrentHDRIndex" },
    preset2 = { get = "GetCurrentPHDRIndex", set = "SetCurrentPHDRIndex" },
    ssao    = switch("SSAOEnable", "SSAOEnable"),
    dof     = { get = "GetDOFEnable",        set = "SetDOFEnable" },
})

-- Сглаживание и отсечение невидимого.
defgroup("render", {
    fxaa          = switch("FXAAEnable", "FXAAEnable"),
    antialiasing  = { get = "GetAntiAliasing", set = "SetAntiAliasing" }, -- строка, см. настройки игры
    culling       = { get = "GetVisibilityCulling", set = "SetVisibilityCulling" },
    objectCulling = { get = "GetObjectBasedVisibilityCulling", set = "SetObjectBasedVisibilityCulling" },
})

defgroup("camera", {
    dof          = { get = "GetCameraDynamicDOF",                 set = "SetCameraDynamicDOF" },
    depth        = { get = "GetCameraDepthOfView",                set = "SetCameraDepthOfView" },
    dynamicFocal = { get = "GetCameraDynamicFocalLength",         set = "SetCameraDynamicFocalLength" },
    focal        = {                                              set = "SetCameraFocalLengthInfo", list = true },
    sceneScale   = {                                              set = "SetCameraSceneScale", list = true },
    angle        = { get = "GetCameraElasticTargetAngle",         set = "SetCameraElasticTargetAngle" },
    distance     = { get = "GetCameraElasticTargetDistance",      set = "SetCameraElasticTargetDistance" },
    rotateSpeed  = { get = "GetCameraMouseRotateFactor",          set = "SetCameraMouseRotateFactor" },
    zoomSpeed    = { get = "GetCameraMouseDistanceSpeed",         set = "SetCameraMouseDistanceSpeed" },
    bounded      = { get = "GetCameraBounded",                    set = "SetCameraBounded" },
    autoRayCast  = { get = "GetCameraAutoRayCast",                set = "SetCameraAutoRayCast" },
    wheelRotate  = { get = "GetCameraControlMouseWheelRotate",    set = "SetCameraControlMouseWheelRotate" },
    wheelZoom    = { get = "GetCameraControlMouseWheelDistance",  set = "SetCameraControlMouseWheelDistance" },
    profile      = { get = "GetCameraPropertieFileName",          set = "SetCameraPropertiesFromFile" },
    controlMode  = { get = "GetCameraControlMode",                set = "SetCameraControlMode" },
    distToGroups = { get = "GetCameraDistToGroups",               set = "SetCameraDistToGroups" },
    elasticDist  = { get = "GetCameraElasticDistance",            set = "SetCameraElasticDistance" },
    -- {minHeightMinAngle, minHeightMaxAngle, maxHeightMinAngle, maxHeightMaxAngle,
    --  anglePower, minDistToTarget, maxDistToTarget, maxHeightLerp}
    freeRotation = {                                              set = "SetCameraFreeRotationInfo", list = true },
    -- {leftX, rightX, forwardY, backwardY, heightTargetMin, sphereHeight, sphereHeightMin,
    --  sphereLength, sphereLengthMin}
    restrict     = {                                              set = "SetCameraRestrictInfo", list = true },
    height       = { get = "GetCameraHeightTarget" },
    toTarget     = { get = "GetCameraDistanceToTargetObject" },
    freeMode     = { get = "GetCameraFreeRotationMode" },
}, {
    fovOf   = function(focal, dimension) return gfx.GetCameraFieldOfViewByFocalLength(focal, dimension) end,
    focalOf = function(fov, dimension)   return gfx.GetCameraFocalLengthByFieldOfView(fov, dimension) end,
    -- Заставить камеру ехать/вращаться саму: это команды движения, а не «плавность».
    -- Останавливают её stop-функции ниже.
    spin    = function(factor)  gfx.SetCameraElasticRotateFactor(factor) end,
    tiltBy  = function(factor)  gfx.SetCameraElasticVRotateFactor(factor) end,
    glide   = function(factor)  gfx.SetCameraElasticMoveFactor(factor) end,
    stop    = function()
        gfx.SetCameraElasticMoveTurnOff()
        gfx.SetCameraElasticRotationTurnOff()
    end,
})

defgroup("fog", {
    enabled = { get = "GetFogEnable",             set = "SetFogEnable" },
    density = { get = "GetCameraDynFogDensity",   set = "SetCameraDynFogDensity" },
    power   = { get = "GetCameraDynFogPower",     set = "SetCameraDynFogPower" },
    start   = { get = "GetCameraDynFogStart",     set = "SetCameraDynFogStart" },
    finish  = { get = "GetCameraDynFogEnd",       set = "SetCameraDynFogEnd" },   -- end — ключевое слово Lua
    offset  = { get = "GetCameraDynFogOffset",    set = "SetCameraDynFogOffset" },
    depth   = { get = "GetCameraDynFogDepth",     set = "SetCameraDynFogDepth" },
})

defgroup("clouds", {
    visible = { get = "GetCloudsVisible",     set = "SetCloudsVisible" },
    active  = { get = "GetCloudsActive",      set = "SetCloudsActive" },
    height  = { get = "GetCloudsHeight",      set = "SetCloudsHeight" },
    horizon = { get = "GetCloudsHorizont",    set = "SetCloudsHorizont" },
    fog     = { get = "GetCloudsFogDensity",  set = "SetCloudsFogDensity" },
    speed   = { get = "GetCloudsSpeedFactor", set = "SetCloudsSpeedFactor" },
})

defgroup("sky", {
    visible    = { get = "GetSkyDomeVisible",     set = "SetSkyDomeVisible" },
    active     = { get = "GetSkyDomeActive",      set = "SetSkyDomeActive" },
    flareAngle = { get = "GetLensFlareAngle",     set = "SetLensFlareAngle" },
    flareZ     = { get = "GetLensFlareZOffset",   set = "SetLensFlareZOffset" },
    flare      = { get = "GetLensFlareFileName",  set = "SetLensFlareFileName" },
})

defgroup("shadows", {
    enabled     = switch("ShadowEnabled", "ShadowMapEnabled"),
    size        = { get = "GetShadowMapSize",         set = "SetShadowMapSize" },
    scaleHeight = { get = "GetShadowMapScaleHeight",  set = "SetShadowMapScaleHeight" },
    addHeight   = { get = "GetShadowMapAddHeight",    set = "SetShadowMapAddHeight" },
    lightDepth  = { get = "GetShadowMapLightDepth",   set = "SetShadowMapLightDepth" },
    polygonOffset = {                                 set = "SetShadowMapPolygonOffset", list = true },
})

-- Освещение: pattern — мгновенно, blendTo — плавный переход за blendTime миллисекунд.
defgroup("light", {
    pattern   = {                                    set = "SetLightPattern" },
    index     = {                                    set = "SetLightPatternByIndex" },
    blendTo   = { get = "GetBlendToLightPattern",    set = "SetBlendToLightPattern" },
    blendTime = { get = "GetBlendToLightPatternInterval", set = "SetBlendToLightPatternInterval" },
}, {
    list = function()
        local out = {}
        for i = 0, gfx.GetLightPatternsCount() - 1 do out[#out + 1] = gfx.GetLightPatternID(i) end
        return out
    end,
})

defgroup("time", {
    game        = { get = "GetGameTime",                set = "SetGameTime" },
    speed       = { get = "GetTimeSpeedFactor",         set = "SetTimeSpeedFactor" },
    season      = { get = "GetSeasonType",              set = "SetSeasonType" },
    dayNight    = { get = "GetDateTimeManagerEnabled",  set = "SetDateTimeManagerEnabled" },
    fogOfWarDay = { get = "GetFOWDateTime",             set = "SetFOWDateTime" },
    current     = { get = "GetCurrentTime" },
    total       = { get = "GetTotalTime" },
    real        = { get = "GetRealTime" },
})

defgroup("water", {
    name   = { get = "GetCurrentWaterName",   set = "SetCurrentWaterName" },
    index  = { get = "GetCurrentWaterIndex",  set = "SetCurrentWaterIndex" },
    offset = { get = "GetCurrentWaterOffset" },
})

defgroup("wind", {
    vector   = {                                set = "SetAirWindVector", list = true },
    target   = {                                set = "SetAirWindVectorTarget", list = true },
    random   = { get = "GetAirWindRandom",      set = "SetAirWindRandom" },
    interval = { get = "GetAirWindIntervalTarget", set = "SetAirWindIntervalTarget" },
})

defgroup("terrain", {
    visible        = { get = "GetTerrainVisible",         set = "SetTerrainVisible" },
    borders        = { get = "GetTerrainBordersEnabled",  set = "SetTerrainBordersEnabled" },
    bordersVisible = { get = "GetTerrainBordersVisible",  set = "SetTerrainBordersVisible" },
    bordersStep    = { get = "GetTerrainBordersStep",     set = "SetTerrainBordersStep" },
    colorMode      = { get = "GetTerrainColorMode",       set = "SetTerrainColorMode" },
}, {
    setColor = function(x, y, r, g, b, a) gfx.SetTerrainColorData(x, y, r, g, b, a) end,
})

-- Частицы (дым, огонь, пыль): имя менеджера — из data/pfx.
gfx.pfx = {
    brightness = function(manager, value)
        if value == nil then return gfx.GetPFXPerlinPFXManagerBrightness(manager) end
        gfx.SetPFXPerlinPFXManagerBrightness(manager, value)
    end,
    gamma = function(manager, value)
        if value == nil then return gfx.GetPFXPerlinPFXManagerGamma(manager) end
        gfx.SetPFXPerlinPFXManagerGamma(manager, value)
    end,
}

-- Подсветка выделенных юнитов.
function gfx.highlight(t)
    gfx.SetHighlightRenderSettings(t.size, t.dir[1], t.dir[2], t.dir[3], t.textures,
                                   t.scaling and true or false, t.visible and true or false)
end

function gfx.vsync(on)
    if on == nil then return gfx.GetVSyncMode() == "vsmSync" end
    gfx.SetVSyncMode(on and "vsmSync" or "vsmNoSync")
end

-- Пресет пост-обработки живьём: bloom, насыщенность, виньетка, SSAO, DOF, цветокоррекция по LUT.
-- Этого нет в настройках игры и нет в нативах: нативы умеют только выбрать пресет по номеру.
-- Имена полей — ровно как в data/posteffects/posteffects.lib, плюс короткие псевдонимы ниже.
local alias = {
    brightness    = "ContrastBright",
    saturation    = "ContrastSaturate",
    contrast      = "ContrastContrast",
    vignetteInner = "ContrastVignetteInner",
    vignetteOuter = "ContrastVignetteOuter",
    vignetteFade  = "ContrastVignetteAdjust",
    bloom         = "TMBlurOpacity",
    bloomPasses   = "HDRNumPasses",
    blurPasses    = "BlurNumPasses",
    blurOffset    = "BlurOffset",
    hdr           = "TMHDRIntencity",
    brightMax     = "TMBrightMax",
    tint          = "TMMulColor",
    dof           = "DOFEnable",
    focal         = "FocalLength",
    focalNear     = "FocalDNear",
    focalFar      = "FocalDFar",
    ssao          = "SSAOEnable",
    ssaoRange     = "SSAORange",
    ssaoPower     = "SSAOMultiplier",
    ssaoCap       = "SSAOCap",
    ssaoColor     = "SSAOColor",
    fxaa          = "FXAAEnable",
    gamma         = "GammaEnabled",
    gammaFade     = "GammaFade",
    lut           = "GammaTexName",   -- текстура цветокоррекции
    enabled       = "Enabled",
}

local function fxName(key)
    return alias[key] or key
end

-- gfx.preset{ saturation = 1.3, bloom = 0.1 }   — изменить текущий пресет и показать сразу
-- gfx.preset()                                  — прочитать все поля текущего
-- Вторым аргументом можно указать номер пресета: gfx.preset({...}, 1)
function gfx.preset(values, index)
    if values == nil then
        local out = {}
        for _, f in ipairs(gfx.fx.fields()) do out[f.name] = gfx.fx.get(f.name, index) end
        return out
    end
    for key, value in pairs(values) do gfx.fx.set(fxName(key), value, index) end
    gfx.fx.apply(index)
    return gfx
end

-- Сколько пресетов, какой сейчас и как называется.
function gfx.presets()
    local count, current, name = gfx.fx.info()
    return count, current, name
end

-- Список всех пресетов: { [0] = "default", [1] = "winter", ... } — вместе с теми, что принёс мод.
function gfx.presetNames()
    local names = {}
    local count = gfx.fx.info()
    for i = 0, count - 1 do names[i] = gfx.fx.name(i) end
    return names
end

-- Переключиться на пресет по имени или номеру: gfx.usePreset("mlCinematic").
-- Именно переключить, а не «перелить»: gfx.preset(values, i) правит пресет номер i, но текущим
-- его не делает, и движок продолжит рисовать прежним.
function gfx.usePreset(which)
    local index = which
    if type(which) == "string" then
        index = nil
        local count = gfx.fx.info()
        for i = 0, count - 1 do
            if gfx.fx.name(i) == which then index = i break end
        end
        if not index then error("gfx.usePreset: no preset named '" .. which .. "'", 2) end
    end
    gfx.SetCurrentHDRIndex(index)
    return index
end

-- Снимок настроек: сохранить перед экспериментом и вернуть обратно через gfx.apply.
-- Только то, что можно записать обратно (height, current и прочее «только чтение» сюда не попадает).
function gfx.snapshot()
    local out = {}
    for name, g in pairs(groups) do out[name] = g.read(true) end
    return out
end

-- Целый профиль сразу: gfx.apply{ fog = {...}, shadows = {...}, post = {...} }
function gfx.apply(profile)
    for name, options in pairs(profile) do
        local g = groups[name] or error("gfx.apply: unknown group '" .. tostring(name) .. "'", 2)
        g.set(options)
    end
end
)lua";
}
