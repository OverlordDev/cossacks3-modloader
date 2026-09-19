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
            // вертикальная синхронизация
            "SetVSyncMode", "GetVSyncMode",
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
            if p.get and not (onlySettable and not p.set) then
                -- вне партии часть нативов падает (сцены ещё нет) — такие ключи просто пропускаем
                local ok, value = pcall(gfx[p.get])
                if ok then out[key] = value end
            end
        end
        return out
    end
    local function write(t)
        for key, value in pairs(t) do
            local p = props[key]
            if not p then error("gfx." .. name .. ": unknown option '" .. tostring(key) .. "'", 3) end
            if not p.set then error("gfx." .. name .. ": '" .. key .. "' is read-only", 3) end
            if p.list then gfx[p.set](table.unpack(value)) else gfx[p.set](value) end
        end
        return g
    end
    setmetatable(g, { __call = function(_, t) if t == nil then return read() end return write(t) end })
    groups[name] = { set = write, read = read }
    gfx[name] = g
end

-- Пост-обработка: bloom/HDR, контраст, виньетка, SSAO, DOF, гамма.
-- preset — номер записи в data/posteffects/posteffects.lib (0 default, 1 winter, 2 desaturate).
defgroup("post", {
    preset  = { get = "GetCurrentHDRIndex",  set = "SetCurrentHDRIndex" },
    preset2 = { get = "GetCurrentPHDRIndex", set = "SetCurrentPHDRIndex" },
    ssao    = { get = "GetSSAOEnable",       set = "SetSSAOEnable" },
    dof     = { get = "GetDOFEnable",        set = "SetDOFEnable" },
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
    height       = { get = "GetCameraHeightTarget" },
}, {
    fovOf   = function(focal, dimension) return gfx.GetCameraFieldOfViewByFocalLength(focal, dimension) end,
    focalOf = function(fov, dimension)   return gfx.GetCameraFocalLengthByFieldOfView(fov, dimension) end,
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
    enabled     = { get = "GetShadowEnabled",         set = "SetShadowEnabled" },
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
