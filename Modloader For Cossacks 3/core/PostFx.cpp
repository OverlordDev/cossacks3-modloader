#include "pch.h"
#include "PostFx.h"
#include "Engine.h"
#include "GameApi.h"

namespace
{
    // Смещения полей TXPHDRItem. Сняты с загрузчика .lib (sub_5D570C): там каждое имя из
    // posteffects.lib кладётся ровно в это поле, поэтому имена совпадают с файлом один в один.
    constexpr uintptr_t VaItemByIndex   = 0x5D618C; // (eax = коллекция, edx = номер) -> пресет или nil
    constexpr uintptr_t VaApplyItem     = 0x5D3FB8; // (eax = пресет, edx = TXPHDR, cl = 1) — перелить в шейдеры
    constexpr uintptr_t VaSetGammaTex   = 0x5D56EC; // (eax = пресет, edx = имя) — имя LUT + сброс загруженной
    constexpr uintptr_t VaGetRenderTree = 0x7101F0; // (eax = проект) -> дерево рендера

    constexpr uintptr_t OffProject       = 0x4C;  // движок скриптов -> проект
    constexpr uintptr_t OffTreeHdrOwner  = 0x148; // дерево рендера -> владелец пост-обработки
    constexpr uintptr_t OffOwnerHdrColl  = 0x68;  // владелец -> TXPHDRCollection
    constexpr uintptr_t OffCollList      = 0x04;  // коллекция -> список пресетов
    constexpr uintptr_t OffCollIndex     = 0x08;  // коллекция -> номер текущего пресета
    constexpr uintptr_t OffCollHdr       = 0x0C;  // коллекция -> TXPHDR (то, что рисует)
    constexpr uintptr_t OffListCount     = 0x0C;  // список -> количество
    constexpr uintptr_t OffItemName      = 0x04;  // пресет -> имя (Delphi-строка)

    struct Layout
    {
        const char* name;
        uint16_t offset;
        PostFx::Type type;
        int count;
    };

    // Порядок — как в posteffects.lib, чтобы список читался рядом с файлом.
    const Layout kLayout[] = {
        { "Enabled",                0x08, PostFx::Type::Bool,   1 },
        { "BlurOffset",             0x0C, PostFx::Type::Float,  1 },
        { "BlurNumPasses",          0x10, PostFx::Type::Int,    1 },
        { "HDRNumPasses",           0x14, PostFx::Type::Int,    1 },
        { "ContrastBright",         0x18, PostFx::Type::Float,  1 },
        { "ContrastSaturate",       0x1C, PostFx::Type::Float,  1 },
        { "ContrastContrast",       0x20, PostFx::Type::Float,  1 },
        { "ContrastAvgLumR",        0x24, PostFx::Type::Float,  1 },
        { "ContrastAvgLumG",        0x28, PostFx::Type::Float,  1 },
        { "ContrastAvgLumB",        0x2C, PostFx::Type::Float,  1 },
        { "ContrastAfterBlur",      0x30, PostFx::Type::Float,  1 },
        { "ContrastVignetteInner",  0x34, PostFx::Type::Float,  1 },
        { "ContrastVignetteOuter",  0x38, PostFx::Type::Float,  1 },
        { "ContrastVignetteAdjust", 0x3C, PostFx::Type::Float,  1 },
        { "TMBlurOpacity",          0x40, PostFx::Type::Float,  1 },
        { "TMHDRIntencity",         0x44, PostFx::Type::Float,  1 },
        { "TMMulColor",             0x48, PostFx::Type::Vector, 4 },
        { "TMBrightMax",            0x58, PostFx::Type::Float,  1 },
        { "DOFEnable",              0x5C, PostFx::Type::Bool,   1 },
        { "FocalLength",            0x60, PostFx::Type::Float,  1 },
        { "FocalDNear",             0x64, PostFx::Type::Float,  1 },
        { "FocalDFar",              0x68, PostFx::Type::Float,  1 },
        { "HDRFilterColor",         0x6C, PostFx::Type::Vector, 4 },
        { "HDRFilterStart",         0x7C, PostFx::Type::Float,  1 },
        { "HDRFilterEnd",           0x80, PostFx::Type::Float,  1 },
        { "HDRSmoothStart",         0x84, PostFx::Type::Float,  1 },
        { "HDRSmoothEnd",           0x88, PostFx::Type::Float,  1 },
        { "ContrastEnabled",        0x8C, PostFx::Type::Bool,   1 },
        { "TwoSideHDREnabled",      0x8D, PostFx::Type::Bool,   1 },
        { "SecondHDRIndex",         0x90, PostFx::Type::Int,    1 },
        { "GammaEnabled",           0x94, PostFx::Type::Bool,   1 },
        { "GammaFade",              0x98, PostFx::Type::Float,  1 },
        { "GammaTexName",           0x9C, PostFx::Type::String, 1 },
        { "SSAOEnable",             0xA4, PostFx::Type::Bool,   1 },
        { "SSAODepthMul",           0xA8, PostFx::Type::Float,  1 },
        { "SSAODepthTolerance",     0xAC, PostFx::Type::Float,  1 },
        { "SSAOCap",                0xB0, PostFx::Type::Float,  1 },
        { "SSAOMultiplier",         0xB4, PostFx::Type::Float,  1 },
        { "SSAORange",              0xB8, PostFx::Type::Float,  1 },
        { "SSAOToneHDRIntMul",      0xBC, PostFx::Type::Float,  1 },
        { "SSAOColor",              0xC0, PostFx::Type::Vector, 3 },
        { "FXAAEnable",             0xCC, PostFx::Type::Bool,   1 },
    };

    const Layout* Find(const std::string& name)
    {
        for (const Layout& f : kLayout)
            if (name == f.name)
                return &f;
        return nullptr;
    }

    uint8_t* FieldPtr(uint8_t* item, const Layout& f) { return item + f.offset; }

    uint8_t* Collection()
    {
        uint8_t* engine = Engine::ScriptEngine();
        if (!engine)
            return nullptr;
        uint8_t* project = *reinterpret_cast<uint8_t**>(engine + OffProject);
        if (!project)
            return nullptr;

        void* fn = GameApi::Addr(VaGetRenderTree);
        uint8_t* tree;
        __asm
        {
            mov eax, project
            call fn
            mov tree, eax
        }
        if (!tree)
            return nullptr;
        uint8_t* owner = *reinterpret_cast<uint8_t**>(tree + OffTreeHdrOwner);
        return owner ? *reinterpret_cast<uint8_t**>(owner + OffOwnerHdrColl) : nullptr;
    }

    uint8_t* ItemAt(uint8_t* collection, int index)
    {
        if (!collection)
            return nullptr;
        void* fn = GameApi::Addr(VaItemByIndex);
        uint8_t* item;
        __asm
        {
            mov eax, collection
            mov edx, index
            call fn
            mov item, eax
        }
        return item;
    }

    // Пресет с проверками: пустой номер (-1) означает текущий.
    uint8_t* Resolve(int index, std::string* error)
    {
        uint8_t* collection = Collection();
        if (!collection)
        {
            if (error) *error = "post-processing is not loaded yet (no scene)";
            return nullptr;
        }
        if (index < 0)
            index = *reinterpret_cast<int*>(collection + OffCollIndex);
        uint8_t* item = ItemAt(collection, index);
        if (!item && error)
            *error = "no post-processing preset #" + std::to_string(index);
        return item;
    }

    std::string ReadDelphiString(uint8_t* field)
    {
        char* s = *reinterpret_cast<char**>(field);
        return s ? std::string(s) : std::string();
    }
}

const std::vector<PostFx::Field>& PostFx::Fields()
{
    static const std::vector<Field> fields = [] {
        std::vector<Field> v;
        for (const Layout& f : kLayout)
            v.push_back({ f.name, f.type, f.count });
        return v;
    }();
    return fields;
}

bool PostFx::Available()
{
    return Count() > 0;
}

int PostFx::Count()
{
    uint8_t* collection = Collection();
    if (!collection)
        return 0;
    uint8_t* list = *reinterpret_cast<uint8_t**>(collection + OffCollList);
    return list ? *reinterpret_cast<int*>(list + OffListCount) : 0;
}

int PostFx::Current()
{
    uint8_t* collection = Collection();
    return collection ? *reinterpret_cast<int*>(collection + OffCollIndex) : -1;
}

std::string PostFx::Name(int index)
{
    uint8_t* item = Resolve(index, nullptr);
    return item ? ReadDelphiString(item + OffItemName) : std::string();
}

bool PostFx::Get(int index, const std::string& name, Value* out, std::string* error)
{
    const Layout* f = Find(name);
    if (!f)
    {
        if (error) *error = "unknown post-processing field '" + name + "'";
        return false;
    }
    uint8_t* item = Resolve(index, error);
    if (!item)
        return false;

    uint8_t* p = FieldPtr(item, *f);
    out->type = f->type;
    switch (f->type)
    {
    case Type::Float:  out->number = *reinterpret_cast<float*>(p); break;
    case Type::Int:    out->number = *reinterpret_cast<int32_t*>(p); break;
    case Type::Bool:   out->boolean = *p != 0; break;
    case Type::String: out->text = ReadDelphiString(p); break;
    case Type::Vector:
        out->vector.assign(reinterpret_cast<float*>(p), reinterpret_cast<float*>(p) + f->count);
        break;
    }
    return true;
}

bool PostFx::Set(int index, const std::string& name, const Value& value, std::string* error)
{
    const Layout* f = Find(name);
    if (!f)
    {
        if (error) *error = "unknown post-processing field '" + name + "'";
        return false;
    }
    uint8_t* item = Resolve(index, error);
    if (!item)
        return false;

    uint8_t* p = FieldPtr(item, *f);
    switch (f->type)
    {
    case Type::Float: *reinterpret_cast<float*>(p) = static_cast<float>(value.number); break;
    case Type::Int:   *reinterpret_cast<int32_t*>(p) = static_cast<int32_t>(value.number); break;
    case Type::Bool:  *p = value.boolean ? 1 : 0; break;
    case Type::String:
    {
        // Имя текстуры-LUT ставим функцией движка: она же сбрасывает уже загруженную.
        GameApi::DelphiString text(value.text);
        const char* raw = text.get();
        void* fn = GameApi::Addr(VaSetGammaTex);
        __asm
        {
            mov eax, item
            mov edx, raw
            call fn
        }
        break;
    }
    case Type::Vector:
    {
        if (static_cast<int>(value.vector.size()) != f->count)
        {
            if (error) *error = name + " needs " + std::to_string(f->count) + " numbers";
            return false;
        }
        memcpy(p, value.vector.data(), sizeof(float) * f->count);
        break;
    }
    }
    return true;
}

bool PostFx::Apply(int index, std::string* error)
{
    uint8_t* collection = Collection();
    uint8_t* item = Resolve(index, error);
    if (!collection || !item)
        return false;
    uint8_t* hdr = *reinterpret_cast<uint8_t**>(collection + OffCollHdr);
    if (!hdr)
    {
        if (error) *error = "post-processing is off in this scene";
        return false;
    }

    void* fn = GameApi::Addr(VaApplyItem);
    __asm
    {
        mov eax, item
        mov edx, hdr
        mov cl, 1
        call fn
    }
    return true;
}
