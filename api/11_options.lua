-- options — опции проекта: графика и звук движка (то, что пишется в настройки видео).
--
--   options.get("SSAOEnable")               --> true
--   options.get("ShadowMap")                --> "sm4096"
--   options.set("SSAOEnable", false)        -- только сервер/консоль/страницы
--   options.set("Sound.Master", 0.5)
--
-- Имена опций — в data/gui/menu.inc/showsettings.inc и _gui_GetSettingsValues
-- (data/scripts/lib/gui.script). Опции булевы или строковые; громкость — дробная.
-- Чтение (get) — shared (везде, нативы Get*); запись (set) — server/shared/страница
-- (на client нет Set*-нативов — ошибка "options.set: server only").

options = {}

-- Какие опции булевы, а какие дробные. Остальные читаются строкой.
options.BOOL = { FXAAEnable = true, SSAOEnable = true, ShadowMapEnabled = true }
options.FLOAT = {
    ["Sound.Master"] = true, svgMusic = true, svgSFX = true, svgAmbient = true, svgInterface = true,
}

-- options.get(name): прочитать опцию. Парам: name — имя опции. Возврат: bool/number/string
-- (bool — из BOOL, дробное — из FLOAT, остальное — строкой). Сторона: shared (везде).
-- Ошибок своих не кидает (неизвестное имя — ответ натива, обычно "").
function options.get(name)
    if options.BOOL[name] then return native.GetProjectOptionAsBoolean(name) end
    if options.FLOAT[name] then return native.GetProjectOptionAsFloat(name) end
    return native.GetProjectOptionAsString(name)
end

-- options.set(name, value): записать опцию. Парам: name — имя; value — bool/number/string
-- (bool — SetBoolean, число из FLOAT — SetFloat, прочее число — SetInteger, иначе — SetString).
-- Сторона: server/shared/страница. Ошибки: "options.set: server only" на client.
function options.set(name, value)
    if not native.SetProjectOptionAsBoolean then
        error("options.set: server only (client scripts cannot change engine options)", 2)
    end
    if type(value) == "boolean" then return native.SetProjectOptionAsBoolean(name, value) end
    if type(value) == "number" and options.FLOAT[name] then return native.SetProjectOptionAsFloat(name, value) end
    if type(value) == "number" then return native.SetProjectOptionAsInteger(name, math.floor(value)) end
    return native.SetProjectOptionAsString(name, tostring(value))
end
