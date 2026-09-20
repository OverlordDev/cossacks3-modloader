#include "pch.h"
#include "GraphicsTab.h"
#include "NativeCall.h"
#include "PostFx.h"

#include "imgui.h"

#include <string>
#include <vector>

namespace
{
    // ---------- нативы одним значением ----------

    bool CallNative(const char* name, const std::vector<NativeCall::Value>& args, NativeCall::Value* out)
    {
        const NativeCall::Signature* sig = NativeCall::Find(name);
        if (!sig || !sig->error.empty() || sig->params.size() != args.size())
            return false;
        std::string error;
        return NativeCall::Invoke(*sig, args, out, &error);
    }

    float GetFloat(const char* name)
    {
        NativeCall::Value r;
        return CallNative(name, {}, &r) ? r.f : 0.0f;
    }

    int GetInt(const char* name)
    {
        NativeCall::Value r;
        return CallNative(name, {}, &r) ? r.i : 0;
    }

    void SetFloat(const char* name, float value)
    {
        NativeCall::Value v;
        v.type = NativeCall::Type::Float;
        v.f = value;
        NativeCall::Value r;
        CallNative(name, { v }, &r);
    }

    void SetInt(const char* name, int value)
    {
        NativeCall::Value v;
        v.type = NativeCall::Type::Int;
        v.i = value;
        NativeCall::Value r;
        CallNative(name, { v }, &r);
    }

    void SetFloats(const char* name, std::initializer_list<float> values)
    {
        std::vector<NativeCall::Value> args;
        for (float f : values)
        {
            NativeCall::Value v;
            v.type = NativeCall::Type::Float;
            v.f = f;
            args.push_back(v);
        }
        NativeCall::Value r;
        CallNative(name, args, &r);
    }

    std::string GetString(const char* name)
    {
        NativeCall::Value r;
        return CallNative(name, {}, &r) ? r.s : std::string();
    }

    void SetString(const char* name, const std::string& value)
    {
        NativeCall::Value v;
        v.type = NativeCall::Type::String;
        v.s = value;
        NativeCall::Value r;
        CallNative(name, { v }, &r);
    }

    void SetBool(const char* name, bool value)
    {
        NativeCall::Value v;
        v.type = NativeCall::Type::Bool;
        v.b = value;
        NativeCall::Value r;
        CallNative(name, { v }, &r);
    }

    // Тени, SSAO и FXAA движок берёт из настроек игры, а не из Set*-нативов (см. GfxApi.cpp).
    bool GetOption(const char* option)
    {
        NativeCall::Value v;
        v.type = NativeCall::Type::String;
        v.s = option;
        NativeCall::Value r;
        return CallNative("GetProjectOptionAsBoolean", { v }, &r) && r.b;
    }

    void SetSwitch(const char* nativeName, const char* option, bool value)
    {
        SetBool(nativeName, value);
        NativeCall::Value name, on;
        name.type = NativeCall::Type::String;
        name.s = option;
        on.type = NativeCall::Type::Bool;
        on.b = value;
        NativeCall::Value r;
        CallNative("SetProjectOptionAsBoolean", { name, on }, &r);
    }

    // Фокус и угол наклона движок обратно не отдаёт (у геттеров var-параметры), поэтому помним их
    // сами. Значения по умолчанию — как ставит сама игра: фокус 400, наклон -32.
    //
    // Держать их приходится силой: состояние OnResize (data/gui/menu.inc/onresize.inc) при каждом
    // изменении размера окна и на старте партии жёстко возвращает 400 и -32. Поэтому, если игрок
    // что-то подвинул, повторяем установку каждый кадр (g_keepCamera).
    float g_focal = 400.0f;
    float g_tilt = -32.0f;
    bool g_keepCamera = false;

    // ---------- поля пресета ----------

    float Field(const char* name)
    {
        PostFx::Value v;
        std::string error;
        return PostFx::Get(-1, name, &v, &error) ? static_cast<float>(v.number) : 0.0f;
    }

    void SetField(const char* name, float value)
    {
        PostFx::Value v;
        v.type = PostFx::Type::Float;
        v.number = value;
        std::string error;
        PostFx::Set(-1, name, v, &error);
        PostFx::Apply(-1, &error); // без этого изменения не доедут до шейдеров
    }

    // Ползунок поверх поля пресета: значение читаем у движка, пишем только при изменении.
    bool FieldSlider(const char* label, const char* field, float min, float max, const char* hint = nullptr)
    {
        float value = Field(field);
        bool changed = ImGui::SliderFloat(label, &value, min, max, "%.3f");
        if (changed)
            SetField(field, value);
        if (hint && ImGui::IsItemHovered())
            ImGui::SetTooltip("%s\n(%s)", hint, field);
        return changed;
    }

    // ---------- Copy as Lua ----------

    std::string Num(float v)
    {
        char buf[32];
        sprintf_s(buf, "%.4g", v);
        return buf;
    }

    std::string LuaSnippet()
    {
        std::string s;
        s += "gfx.preset{ brightness = " + Num(Field("ContrastBright")) +
             ", saturation = " + Num(Field("ContrastSaturate")) +
             ", contrast = " + Num(Field("ContrastContrast")) +
             ", bloom = " + Num(Field("TMBlurOpacity")) +
             ", hdr = " + Num(Field("TMHDRIntencity")) +
             ", vignetteInner = " + Num(Field("ContrastVignetteInner")) +
             ", vignetteOuter = " + Num(Field("ContrastVignetteOuter")) +
             ", ssaoRange = " + Num(Field("SSAORange")) +
             ", ssaoPower = " + Num(Field("SSAOMultiplier")) + " }\n";
        s += std::string("gfx.post{ ssao = ") + (GetOption("SSAOEnable") ? "true" : "false") +
             ", dof = " + (GetInt("GetDOFEnable") ? "true" : "false") + " }\n";
        s += std::string("gfx.render{ fxaa = ") + (GetOption("FXAAEnable") ? "true" : "false") + " }\n";
        s += std::string("gfx.shadows{ enabled = ") + (GetOption("ShadowMapEnabled") ? "true" : "false") +
             ", size = " + std::to_string(GetInt("GetShadowMapSize")) + " }\n";
        s += "gfx.camera{ focal = { " + Num(g_focal) + ", " + Num(g_focal) + ", 0.5 }, freeRotation = { " +
             Num(g_tilt) + ", " + Num(g_tilt) + ", " + Num(g_tilt) + ", " + Num(g_tilt) +
             ", 1, 1, 10, 0.15 } }\n";
        s += std::string("gfx.fog{ enabled = ") + (GetInt("GetFogEnable") ? "true" : "false") +
             ", density = " + Num(GetFloat("GetCameraDynFogDensity")) +
             ", power = " + Num(GetFloat("GetCameraDynFogPower")) + " }\n";
        return s;
    }
}

void GraphicsTab::Draw()
{
    int count = PostFx::Count();
    if (count <= 0)
    {
        ImGui::TextDisabled("Post-processing is not loaded yet — start a game.");
        return;
    }

    // ---------- пресет ----------
    int current = PostFx::Current();
    std::string preview = PostFx::Name(-1);
    if (ImGui::BeginCombo("Preset", preview.c_str()))
    {
        for (int i = 0; i < count; ++i)
        {
            std::string name = PostFx::Name(i);
            if (ImGui::Selectable((name + "##" + std::to_string(i)).c_str(), i == current))
                SetInt("SetCurrentHDRIndex", i);
        }
        ImGui::EndCombo();
    }
    ImGui::SameLine();
    ImGui::TextDisabled("(?)");
    if (ImGui::IsItemHovered())
        ImGui::SetTooltip("Presets come from data/posteffects/posteffects.lib.\n"
                          "A mod can add its own through assets/data/posteffects/posteffects.lib.");

    ImGui::TextDisabled("Changes are live and not saved — use Copy as Lua to keep them in a mod.");

    // ---------- цвет ----------
    ImGui::SeparatorText("Colour");
    FieldSlider("Brightness", "ContrastBright", 0.5f, 2.0f);
    FieldSlider("Saturation", "ContrastSaturate", 0.0f, 2.0f, "0 — чёрно-белое, 1 — как в игре");
    FieldSlider("Contrast", "ContrastContrast", 0.5f, 2.0f);

    // ---------- свечение ----------
    ImGui::SeparatorText("Bloom / HDR");
    FieldSlider("Bloom", "TMBlurOpacity", 0.0f, 0.5f, "Сила свечения ярких мест");
    FieldSlider("HDR intensity", "TMHDRIntencity", 0.5f, 4.0f);
    FieldSlider("Bright max", "TMBrightMax", 0.5f, 4.0f);
    FieldSlider("Blur offset", "BlurOffset", 0.0f, 0.02f, "Радиус размытия для свечения");

    // ---------- виньетка ----------
    ImGui::SeparatorText("Vignette");
    FieldSlider("Inner", "ContrastVignetteInner", 0.0f, 2.0f, "Где начинается затемнение по краям");
    FieldSlider("Outer", "ContrastVignetteOuter", 0.0f, 3.0f);
    FieldSlider("Fade", "ContrastVignetteAdjust", 0.5f, 2.0f);

    // ---------- эффекты ----------
    ImGui::SeparatorText("Effects");
    bool ssao = GetOption("SSAOEnable");
    if (ImGui::Checkbox("SSAO", &ssao))
        SetSwitch("SetSSAOEnable", "SSAOEnable", ssao);
    ImGui::SameLine();
    bool fxaa = GetOption("FXAAEnable");
    if (ImGui::Checkbox("FXAA", &fxaa))
        SetSwitch("SetFXAAEnable", "FXAAEnable", fxaa);
    ImGui::SameLine();
    bool dof = GetInt("GetDOFEnable") != 0;
    if (ImGui::Checkbox("DOF", &dof))
        SetBool("SetDOFEnable", dof);

    if (ssao)
    {
        FieldSlider("SSAO range", "SSAORange", 1.0f, 64.0f, "Радиус затенения в углах и щелях");
        FieldSlider("SSAO power", "SSAOMultiplier", 100.0f, 20000.0f);
        FieldSlider("SSAO cap", "SSAOCap", 0.0f, 2.0f);
    }
    if (dof)
    {
        FieldSlider("Focal length", "FocalLength", 16.0f, 1024.0f);
        FieldSlider("Near", "FocalDNear", 16.0f, 2048.0f);
        FieldSlider("Far", "FocalDFar", 16.0f, 2048.0f);
    }

    // ---------- тени ----------
    ImGui::SeparatorText("Shadows");
    bool shadows = GetOption("ShadowMapEnabled");
    if (ImGui::Checkbox("Shadows##on", &shadows))
        SetSwitch("SetShadowEnabled", "ShadowMapEnabled", shadows);
    if (shadows)
    {
        static const int kSizes[] = { 1024, 2048, 4096, 8192 };
        int size = GetInt("GetShadowMapSize");
        if (ImGui::BeginCombo("Shadow map", std::to_string(size).c_str()))
        {
            for (int s : kSizes)
                if (ImGui::Selectable(std::to_string(s).c_str(), s == size))
                    SetInt("SetShadowMapSize", s);
            ImGui::EndCombo();
        }
    }

    // ---------- туман ----------
    ImGui::SeparatorText("Fog");
    bool fog = GetInt("GetFogEnable") != 0;
    if (ImGui::Checkbox("Fog##on", &fog))
        SetBool("SetFogEnable", fog);
    if (fog)
    {
        float density = GetFloat("GetCameraDynFogDensity");
        if (ImGui::SliderFloat("Density", &density, 0.0f, 5.0f, "%.2f"))
            SetFloat("SetCameraDynFogDensity", density);
        float power = GetFloat("GetCameraDynFogPower");
        if (ImGui::SliderFloat("Power", &power, 0.0f, 4.0f, "%.2f"))
            SetFloat("SetCameraDynFogPower", power);
    }

    // ---------- камера ----------
    // Фокус и углы наклона движок обратно не отдаёт (у геттеров var-параметры), поэтому помним
    // их сами. Стартовые значения — как в data/cameras/camera.cfg: зума нет, наклон всегда -32.
    ImGui::SeparatorText("Camera");

    // Поле зрения. Игра меняет его так же (Ctrl+колесо — «скриншотный» зум).
    if (ImGui::SliderFloat("Field of view (focal)", &g_focal, 150.0f, 900.0f, "%.0f"))
    {
        g_keepCamera = true;
        SetFloats("SetCameraFocalLengthInfo", { g_focal, g_focal, 0.5f });
    }
    if (ImGui::IsItemHovered())
        ImGui::SetTooltip("400 — как в игре. Меньше — шире обзор, больше — ближе и площе.");

    // Наклон. Игра ставит все четыре угла одинаковыми, делаем так же.
    if (ImGui::SliderFloat("Tilt", &g_tilt, -85.0f, -5.0f, "%.0f°"))
    {
        g_keepCamera = true;
        SetFloats("SetCameraFreeRotationInfo", { g_tilt, g_tilt, g_tilt, g_tilt, 1.0f, 1.0f, 10.0f, 0.15f });
    }
    if (ImGui::IsItemHovered())
        ImGui::SetTooltip("-32° — как в игре. Ближе к нулю — вид почти от земли.");

    // Расстояние до земли: именно им игра зумит по + и -.
    float distance = GetFloat("GetCameraElasticDistance");
    if (ImGui::SliderFloat("Distance", &distance, 10.0f, 400.0f, "%.0f"))
        SetFloat("SetCameraElasticDistance", distance);

    ImGui::Checkbox("Keep against the game", &g_keepCamera);
    if (ImGui::IsItemHovered())
        ImGui::SetTooltip("Игра возвращает фокус 400 и наклон -32 при каждом OnResize.\n"
                          "С галочкой модлоадер ставит их обратно каждый кадр.");

    if (ImGui::Button("Stop camera"))
    {
        // Камера умеет ехать и вращаться сама; эти две останавливают.
        NativeCall::Value r;
        CallNative("SetCameraElasticMoveTurnOff", {}, &r);
        CallNative("SetCameraElasticRotationTurnOff", {}, &r);
    }
    ImGui::SameLine();
    if (ImGui::Button("Reset camera"))
    {
        g_keepCamera = false;
        g_focal = 400.0f;
        g_tilt = -32.0f;
        SetString("SetCameraPropertiesFromFile", GetString("GetCameraPropertieFileName"));
    }
    ImGui::SameLine();
    ImGui::TextDisabled("перечитать data/cameras/camera.cfg");

    // ---------- перенос в мод ----------
    ImGui::SeparatorText("");
    if (ImGui::Button("Copy as Lua"))
        ImGui::SetClipboardText(LuaSnippet().c_str());
    ImGui::SameLine();
    ImGui::TextDisabled("вставить в client.lua мода");
}

// Каждый кадр из Overlay: возвращаем свои значения после того, как игра их сбросила.
void GraphicsTab::Tick()
{
    if (!g_keepCamera)
        return;
    SetFloats("SetCameraFocalLengthInfo", { g_focal, g_focal, 0.5f });
    SetFloats("SetCameraFreeRotationInfo", { g_tilt, g_tilt, g_tilt, g_tilt, 1.0f, 1.0f, 10.0f, 0.15f });
}
