-- options — опции проекта: графика и звук движка (то, что пишется в настройки видео).
--
--   options.get("SSAOEnable")               --> true
--   options.get("ShadowMap")                --> "sm4096"
--   options.set("SSAOEnable", false)        -- только сервер/консоль/страницы
--
-- Имена опций — в data/gui/menu.inc/showsettings.inc и _gui_GetSettingsValues
-- (data/scripts/lib/gui.script). Опции булевы или строковые; громкость — дробная.

options = {}

-- Какие опции булевы, а какие дробные. Остальные читаются строкой.
options.BOOL = { FXAAEnable = true, SSAOEnable = true, ShadowMapEnabled = true }
options.FLOAT = {
    ["Sound.Master"] = true, svgMusic = true, svgSFX = true, svgAmbient = true, svgInterface = true,
}

function options.get(name)
    if options.BOOL[name] then return native.GetProjectOptionAsBoolean(name) end
    if options.FLOAT[name] then return native.GetProjectOptionAsFloat(name) end
    return native.GetProjectOptionAsString(name)
end

function options.set(name, value)
    if not native.SetProjectOptionAsBoolean then
        error("options.set: server only (client scripts cannot change engine options)", 2)
    end
    if type(value) == "boolean" then return native.SetProjectOptionAsBoolean(name, value) end
    if type(value) == "number" and options.FLOAT[name] then return native.SetProjectOptionAsFloat(name, value) end
    if type(value) == "number" then return native.SetProjectOptionAsInteger(name, math.floor(value)) end
    return native.SetProjectOptionAsString(name, tostring(value))
end
