#include "pch.h"
#include "Assets.h"
#include "Console.h"
#include "GameApi.h"
#include "Hooks.h"
#include "ScriptPatch.h"
#include "Content.h"
#include "ModelDecimate.h"

#include <algorithm>
#include <filesystem>
#include <fstream>
#include <map>
#include <mutex>
#include <set>
#include <sstream>

namespace fs = std::filesystem;

namespace
{
    // Файловый слой движка (TOSWApplicationFileIO). У всех трёх имя файла приходит в eax.
    constexpr uintptr_t VaOpenStream   = 0x4C32FC; // (eax = имя, edx = режим, ecx = флаг) -> поток
    constexpr uintptr_t VaOpenStream2  = 0x4C3460; // то же, вариант с архивами
    constexpr uintptr_t VaFileExists   = 0x4C3618; // (eax = имя) -> Boolean

    void* oOpenStream = nullptr;
    void* oOpenStream2 = nullptr;
    void* oFileExists = nullptr;

    // Готовые Delphi-строки с путями к файлам модов: отдаются движку как есть и живут до выгрузки.
    std::map<std::string, GameApi::DelphiString> g_map;
    std::vector<Assets::Override> g_list;

    // Патчи скриптов: путь в игре -> файлы .patch модов (по порядку модов). Файл собирается при первом
    // чтении движком: база (замена из assets, workshop-мод или файл игры) + встроенные правки + патчи,
    // результат пишется в modloader/cache и отдаётся движку вместо исходного.
    struct PatchSource { std::string mod, file, text; }; // text — патч, собранный модлоадером (content.lua)
    std::vector<Content::ModDir> g_enabledMods;      // включённые моды в порядке загрузки
    std::map<std::string, std::vector<PatchSource>> g_patches;
    std::set<std::string> g_pending;         // ещё не собранные (патчи или встроенные правки)
    std::map<std::string, std::string> g_workshop; // путь в игре -> файл из включённого мода Steam
    std::set<std::string> g_seen;            // dev-лог: какие скрипты движок читал
    std::set<std::string> g_contentKeys;     // что добавил content.lua — чтобы можно было пересобрать
    std::recursive_mutex g_mutex;
    std::string g_gameDir;

    // Встроенные правки модлоадера — для этих файлов сборка идёт всегда.
    const char* const kBuiltinFiles[] = { "data\\scripts\\lib\\unit.script", "data\\scripts\\lib\\miscext2.script",
                                          "data\\scripts\\dmscript.global", "data\\scripts\\dmscript.source" };

    std::string GameDir()
    {
        wchar_t exe[MAX_PATH];
        GetModuleFileNameW(nullptr, exe, MAX_PATH);
        return fs::path(exe).parent_path().string();
    }

    // Приводим путь к виду "data\shaders\tone\tone.frag": нижний регистр, обратные слэши,
    // без ведущего ".\" и без папки игры впереди.
    std::string Normalize(const std::string& path, const std::string& gameDir)
    {
        std::string s = path;
        for (char& c : s)
        {
            if (c == '/')
                c = '\\';
            c = static_cast<char>(tolower(static_cast<unsigned char>(c)));
        }
        if (s.rfind(gameDir, 0) == 0)
            s.erase(0, gameDir.size());
        while (s.rfind(".\\", 0) == 0)
            s.erase(0, 2);
        while (!s.empty() && s[0] == '\\')
            s.erase(0, 1);
        return s;
    }

    // Отключённые в меню моды свои файлы не подменяют. Ключ в modstate.txt — id мода; здесь ещё нет
    // Lua, чтобы прочитать манифест, поэтому сверяемся с именем папки (у наших модов они совпадают).
    std::map<std::string, bool> LoadModState(const fs::path& modloaderDir)
    {
        std::map<std::string, bool> state;
        std::ifstream in(modloaderDir / L"modstate.txt");
        std::string line;
        while (std::getline(in, line))
        {
            size_t eq = line.find('=');
            if (eq != std::string::npos && eq > 0 && line[0] != '#')
                state[line.substr(0, eq)] = line.compare(eq + 1, 1, "1") == 0;
        }
        return state;
    }

    // Lua ещё нет, поэтому enabled = false из manifest.lua читаем как текст (строка без комментария).
    bool ManifestDisabled(const fs::path& modDir)
    {
        std::ifstream in(modDir / L"manifest.lua");
        std::string line;
        while (std::getline(in, line))
        {
            line.erase(std::min(line.find("--"), line.size()));
            std::string t;
            for (char c : line)
                if (c != ' ' && c != '\t' && c != '\r')
                    t += c;
            if (t.rfind("enabled=false", 0) == 0)
                return true;
        }
        return false;
    }

    // id = "..." из manifest.lua: меню пишет в modstate.txt именно id, а папка может называться иначе.
    std::string ManifestId(const fs::path& modDir)
    {
        std::ifstream in(modDir / L"manifest.lua");
        std::string line;
        while (std::getline(in, line))
        {
            line.erase(std::min(line.find("--"), line.size()));
            std::string t;
            for (char c : line)
                if (!isspace(static_cast<unsigned char>(c)))
                    t += c;
            if (t.rfind("id=", 0) == 0 && t.size() > 4 && (t[3] == '"' || t[3] == '\''))
            {
                size_t end = t.find(t[3], 4);
                if (end != std::string::npos)
                    return t.substr(4, end - 4);
            }
        }
        return {};
    }

    int ManifestPriority(const fs::path& modDir)
    {
        std::ifstream in(modDir / L"manifest.lua");
        std::string line;
        while (std::getline(in, line))
        {
            line.erase(std::min(line.find("--"), line.size()));
            std::string t;
            for (char c : line)
                if (!isspace(static_cast<unsigned char>(c)))
                    t += c;
            if (t.rfind("priority=", 0) == 0)
                return atoi(t.c_str() + 9);
        }
        return 0;
    }

    void Scan()
    {
        std::string gameDir = GameDir();
        fs::path modloaderDir = fs::path(gameDir) / L"modloader";
        auto state = LoadModState(modloaderDir);

        std::error_code ec;
        // Порядок как у Lua-модов: priority из manifest.lua (меньше — раньше), потом имя папки.
        // Позже — главнее: его замена файла перекрывает, его патч накладывается последним.
        std::vector<std::pair<int, fs::directory_entry>> mods;
        for (const auto& entry : fs::directory_iterator(modloaderDir / L"mods", ec))
            if (entry.is_directory())
                mods.push_back({ ManifestPriority(entry.path()), entry });
        std::sort(mods.begin(), mods.end(), [](const auto& a, const auto& b) {
            return a.first != b.first ? a.first < b.first : a.second.path().filename() < b.second.path().filename();
        });
        for (const auto& [priority, entry] : mods)
        {
            std::string folder = entry.path().filename().string();
            std::string id = ManifestId(entry.path());
            auto enabled = state.find(id.empty() ? folder : id);
            if (enabled == state.end())
                enabled = state.find(folder);
            if (enabled != state.end() ? !enabled->second : ManifestDisabled(entry.path()))
                continue;

            g_enabledMods.push_back({ folder, entry.path() });

            fs::path patches = entry.path() / L"patches";
            if (fs::is_directory(patches, ec))
                for (const auto& file : fs::recursive_directory_iterator(patches, ec))
                {
                    if (!file.is_regular_file() || file.path().extension() != L".patch")
                        continue;
                    fs::path rel = fs::relative(file.path(), patches, ec);
                    rel.replace_extension(); // unit.script.patch -> unit.script
                    std::string key = Normalize(rel.string(), {});
                    g_patches[key].push_back({ folder, file.path().string() });
                    g_pending.insert(key);
                }

            fs::path assets = entry.path() / L"assets";
            if (!fs::is_directory(assets, ec))
                continue;

            for (const auto& file : fs::recursive_directory_iterator(assets, ec))
            {
                if (!file.is_regular_file())
                    continue;
                std::string rel = fs::relative(file.path(), assets, ec).string();
                std::string key = Normalize(rel, {});
                if (key.empty())
                    continue;
                std::string full = file.path().string();
                auto prev = std::find_if(g_list.begin(), g_list.end(), [&](const Assets::Override& o) { return o.game == key; });
                if (prev != g_list.end())
                {
                    LOG_WARN("[assets] %s: %s replaces the file from %s (higher priority or later name)", folder.c_str(),
                             key.c_str(), prev->mod.c_str());
                    g_list.erase(prev);
                }
                g_map.insert_or_assign(key, GameApi::DelphiString(full));
                g_list.push_back({ folder, key, full });
            }
        }
    }

    std::string g_gameDirKey;

    // Моды Steam Workshop (mods\mods.ini игры): их файлы тоже перекрывают игру, и патч надо накладывать
    // поверх них, а не поверх исходного файла — иначе мы бы молча выкинули чужие правки.
    void ScanWorkshop()
    {
        std::ifstream in(fs::path(g_gameDir) / L"mods" / L"mods.ini");
        std::string line, dir;
        std::vector<std::string> enabled;
        auto flush = [&](bool disabled) {
            if (!dir.empty() && !disabled)
                enabled.push_back(dir);
            dir.clear();
        };
        while (std::getline(in, line))
        {
            if (!line.empty() && line.back() == '\r')
                line.pop_back();
            size_t eq = line.find('=');
            if (eq == std::string::npos)
                continue;
            std::string k = line.substr(0, eq), v = line.substr(eq + 1);
            k.erase(0, k.find_first_not_of(" \t"));
            k.erase(k.find_last_not_of(" \t") + 1);
            v.erase(0, v.find_first_not_of(" \t"));
            v.erase(v.find_last_not_of(" \t") + 1);
            if (k == "dir")
                dir = v;
            else if (k == "dis")
                flush(_stricmp(v.c_str(), "True") == 0);
        }
        flush(false);
        for (const std::string& d : enabled) // поздние в списке главнее — как у движка
            for (const std::string& key : g_pending)
            {
                fs::path f = fs::path(g_gameDir) / d / key;
                std::error_code ec;
                if (fs::is_regular_file(f, ec))
                    g_workshop[key] = f.string();
            }
    }

    bool ReadAll(const std::string& path, std::string* out)
    {
        std::ifstream in(fs::path(path), std::ios::binary);
        if (!in)
            return false;
        std::ostringstream ss;
        ss << in.rdbuf();
        *out = ss.str();
        return true;
    }

    // Собрать файл с патчами. Путь к готовому файлу или пусто, если собирать нечего/не вышло.
    std::string Build(const std::string& key)
    {
        std::string base, from;
        if (auto it = g_map.find(key); it != g_map.end())
            base = it->second.get(), from = "assets";
        else if (auto w = g_workshop.find(key); w != g_workshop.end())
            base = w->second, from = "workshop";
        else
            base = (fs::path(g_gameDir) / key).string(), from = "game";

        std::string text;
        if (!ReadAll(base, &text))
        {
            LOG_WARN("[patch] %s: cannot read base file %s", key.c_str(), base.c_str());
            return {};
        }
        int blocks = 0;
        std::string builtin = ScriptPatch::Builtin(key);
        if (!builtin.empty())
            ScriptPatch::Apply(text, builtin, "modloader/" + key);
        for (const PatchSource& p : g_patches[key])
        {
            std::string patch = p.text;
            if (patch.empty() && !ReadAll(p.file, &patch))
                continue;
            int n = ScriptPatch::Apply(text, patch, p.mod + "/" + key);
            blocks += n;
            LOG_INFO("[patch] %s: %d block(s) from %s", key.c_str(), n, p.mod.c_str());
        }

        fs::path out = fs::path(g_gameDir) / L"modloader" / L"cache" / key;
        std::error_code ec;
        fs::create_directories(out.parent_path(), ec);
        std::ofstream o(out, std::ios::binary | std::ios::trunc);
        o.write(text.data(), static_cast<std::streamsize>(text.size()));
        if (!o)
        {
            LOG_ERROR("[patch] %s: cannot write %s", key.c_str(), out.string().c_str());
            return {};
        }
        LOG_DEV("[patch] %s built from %s (%s)%s", key.c_str(), from.c_str(), base.c_str(),
                builtin.empty() ? "" : " + modloader events");
        return out.string();
    }

    bool IsScript(const std::string& key)
    {
        for (const char* ext : { ".script", ".global", ".source", ".aix", ".inc" })
            if (key.size() > strlen(ext) && key.compare(key.size() - strlen(ext), strlen(ext), ext) == 0)
                return true;
        return false;
    }

    // Вызывается из перехватов: вернуть путь мода или исходный, если подмены нет.
    const char* __cdecl MapPath(const char* path)
    {
        Hooks::InFlight inFlight; // файловые хуки — naked, считают здесь
        if (!path)
            return path;
        std::string key = Normalize(path, g_gameDirKey);
        std::lock_guard lock(g_mutex);
        if (Console::Dev() && IsScript(key) && key.find(".inc") == std::string::npos && g_seen.insert(key).second)
            LOG_DEV("[files] engine reads %s", key.c_str());
        if (g_pending.count(key))
        {
            g_pending.erase(key);
            std::string built = Build(key);
            if (!built.empty())
                g_map.insert_or_assign(key, GameApi::DelphiString(built));
        }
        auto it = g_map.find(key);
        return it == g_map.end() ? path : it->second.get();
    }

    // Подменяем только имя файла (eax), остальные аргументы движка не трогаем.
    __declspec(naked) void hkOpenStream()
    {
        __asm
        {
            push ecx
            push edx
            push eax
            call MapPath
            add esp, 4
            pop edx
            pop ecx
            jmp oOpenStream
        }
    }

    __declspec(naked) void hkOpenStream2()
    {
        __asm
        {
            push ecx
            push edx
            push eax
            call MapPath
            add esp, 4
            pop edx
            pop ecx
            jmp oOpenStream2
        }
    }

    __declspec(naked) void hkFileExists()
    {
        __asm
        {
            push eax
            call MapPath
            add esp, 4
            jmp oFileExists
        }
    }
}

namespace
{
    // content.lua модов: новые нации и типы юнитов -> патчи и сгенерированные файлы.
    void GenerateContent()
    {
        auto readBase = [](const std::string& key) {
            std::string path;
            if (auto it = g_map.find(key); it != g_map.end())
                path = it->second.get();
            else
                path = (fs::path(g_gameDir) / key).string();
            std::string text;
            ReadAll(path, &text);
            return text;
        };
        auto listGameDir = [](const std::string& key) {
            std::vector<std::string> out;
            std::error_code ec;
            for (const auto& e : fs::directory_iterator(fs::path(g_gameDir) / key, ec))
                if (e.is_regular_file())
                    out.push_back(e.path().filename().string());
            return out;
        };
        Content::Result r = Content::Generate(g_enabledMods, readBase, listGameDir);
        for (const Content::Patch& p : r.patches)
        {
            g_patches[p.key].push_back({ p.mod, "", p.text });
            g_pending.insert(p.key);
            g_contentKeys.insert(p.key);
        }
        for (const Content::Link& l : r.links) // файлы мода по новому пути в игре (карты сражений)
        {
            g_map.insert_or_assign(l.key, GameApi::DelphiString(l.source));
            g_list.push_back({ l.mod + " (content)", l.key, l.source });
            g_contentKeys.insert(l.key);
        }
        fs::path dir = fs::path(g_gameDir) / L"modloader" / L"cache" / L"generated";
        for (const Content::File& f : r.files)
        {
            fs::path out = dir / f.key;
            std::error_code ec;
            fs::create_directories(out.parent_path(), ec);
            std::ofstream o(out, std::ios::binary | std::ios::trunc);
            o.write(f.text.data(), static_cast<std::streamsize>(f.text.size()));
            if (!o)
            {
                LOG_ERROR("[content] cannot write %s", out.string().c_str());
                continue;
            }
            g_map.insert_or_assign(f.key, GameApi::DelphiString(out.string()));
            g_list.push_back({ f.mod + " (content)", f.key, out.string() });
        }
    }
}

namespace
{
    // modloader/lod.txt: "units = 60" — оставить 60% треугольников у моделей юнитов. Нет файла или 100 —
    // выключено. Модели читаются один раз при старте игры, так что менять надо до запуска.
    // Упрощённые файлы кладём в modloader/cache/lod/<версия алгоритма>_<процент>/, пока исходник не
    // изменился — заново не считаем.
    constexpr int kLodVersion = 1;
    int g_lodPct = 100;
    // Что стояло в g_map под ключом модели до нашей подмены ("" — ничего): нужно, чтобы вернуть, как было,
    // и чтобы не потерять модель из мода (assets/), поверх которой мы положили упрощённую.
    std::map<std::string, std::string> g_lodPrev;

    int ReadLodPercent()
    {
        std::ifstream in(fs::path(g_gameDir) / L"modloader" / L"lod.txt");
        std::string line;
        while (std::getline(in, line))
        {
            size_t eq = line.find('=');
            if (eq == std::string::npos || line.find("units") == std::string::npos || line.find('#') < eq)
                continue;
            int pct = atoi(line.c_str() + eq + 1);
            return std::clamp(pct, 10, 100);
        }
        return 100;
    }

    void RemoveLod()
    {
        for (const auto& [key, prev] : g_lodPrev)
        {
            if (prev.empty())
                g_map.erase(key);
            else
                g_map.insert_or_assign(key, GameApi::DelphiString(prev));
        }
        g_lodPrev.clear();
        std::erase_if(g_list, [](const Assets::Override& o) { return o.mod == "lod"; });
    }

    void ApplyLod(int pct)
    {
        RemoveLod();
        g_lodPct = pct;
        if (pct >= 100)
            return;
        fs::path srcDir = fs::path(g_gameDir) / L"data" / L"actors" / L"units";
        fs::path outDir = fs::path(g_gameDir) / L"modloader" / L"cache" / L"lod" /
                          (L"v" + std::to_wstring(kLodVersion) + L"_" + std::to_wstring(pct));
        std::error_code ec;
        fs::create_directories(outDir, ec);
        int done = 0, cached = 0, failed = 0;
        long before = 0, after = 0;
        for (const auto& e : fs::directory_iterator(srcDir, ec))
        {
            if (!e.is_regular_file() || e.path().extension() != ".oss")
                continue;
            std::string key = Normalize((fs::path(L"data") / L"actors" / L"units" / e.path().filename()).string(), {});
            // Модель мода (assets/) важнее файла игры — упрощаем то, что игра реально загрузит бы.
            std::string source = e.path().string();
            if (auto it = g_map.find(key); it != g_map.end())
                source = it->second.get();
            fs::path out = outDir / e.path().filename();
            std::error_code te;
            if (fs::exists(out, te) && fs::last_write_time(out, te) >= fs::last_write_time(fs::path(source), te))
            {
                ++cached;
            }
            else
            {
                std::string in, res, err;
                ModelDecimate::Stats st;
                if (!ReadAll(source, &in) || !ModelDecimate::DecimateOss(in, pct / 100.0f, &res, &st, &err))
                {
                    LOG_WARN("[lod] %s: %s", key.c_str(), err.empty() ? "не прочитан" : err.c_str());
                    ++failed;
                    continue;
                }
                std::ofstream o(out, std::ios::binary | std::ios::trunc);
                o.write(res.data(), static_cast<std::streamsize>(res.size()));
                if (!o)
                {
                    LOG_ERROR("[lod] не записать %s", out.string().c_str());
                    ++failed;
                    continue;
                }
                before += st.trisBefore;
                after += st.trisAfter;
                ++done;
            }
            if (auto it = g_map.find(key); it != g_map.end())
                g_lodPrev[key] = it->second.get();
            else
                g_lodPrev[key] = "";
            g_map.insert_or_assign(key, GameApi::DelphiString(out.string()));
            g_list.push_back({ "lod", key, out.string() });
        }
        LOG_INFO("[lod] units = %d%%: упрощено %d, из кеша %d, ошибок %d%s", pct, done, cached, failed,
                 done ? (" (треугольников " + std::to_string(before) + " -> " + std::to_string(after) + ")").c_str() : "");
    }

    void GenerateLod() { ApplyLod(ReadLodPercent()); }
}

bool Assets::Install()
{
    g_gameDir = GameDir();
    g_gameDirKey = Normalize(g_gameDir + "\\", {});
    for (const char* key : kBuiltinFiles)
        g_pending.insert(key);
    Scan();
    GenerateContent();
    GenerateLod();
    ScanWorkshop();
    // Перехваты нужны всегда: встроенные правки скриптов (события модлоадера) собираются при чтении.

    bool ok = Hooks::CreateRaw("File open", GameApi::Addr(VaOpenStream), reinterpret_cast<void*>(hkOpenStream), &oOpenStream);
    ok &= Hooks::CreateRaw("File open (archives)", GameApi::Addr(VaOpenStream2), reinterpret_cast<void*>(hkOpenStream2), &oOpenStream2);
    ok &= Hooks::CreateRaw("File exists", GameApi::Addr(VaFileExists), reinterpret_cast<void*>(hkFileExists), &oFileExists);
    if (ok && !g_list.empty())
        LOG_INFO("[assets] %d file(s) from mods will replace game files", static_cast<int>(g_list.size()));
    if (ok && !g_patches.empty())
        LOG_INFO("[patch] %d game file(s) will be patched by mods", static_cast<int>(g_patches.size()));
    ok &= Content::InstallLocale();
    return ok;
}

int Assets::ReloadContent()
{
    std::lock_guard lock(g_mutex);

    // Правки content.lua отличаются от патчей из patches/ тем, что пришли
    // текстом, а не файлом мода. Снимаем только их — чужие патчи не трогаем.
    for (auto it = g_patches.begin(); it != g_patches.end();)
    {
        auto& sources = it->second;
        std::erase_if(sources, [](const PatchSource& p) { return p.file.empty() && !p.text.empty(); });
        it = sources.empty() ? g_patches.erase(it) : std::next(it);
    }
    // Файлы и ссылки, которые content положил раньше: без этого исчезнувший из
    // content.lua юнит остался бы в игре до перезапуска.
    for (const std::string& key : g_contentKeys)
    {
        g_map.erase(key);
        std::erase_if(g_list, [&](const Assets::Override& o) { return o.game == key; });
        g_pending.insert(key); // пересобрать при следующем чтении
    }
    size_t before = g_contentKeys.size();
    g_contentKeys.clear();

    GenerateContent();
    LOG_INFO("[content] пересобрано: было %d файл(ов), стало %d",
             static_cast<int>(before), static_cast<int>(g_contentKeys.size()));
    return static_cast<int>(g_contentKeys.size());
}

bool Assets::Built(const std::string& key)
{
    std::lock_guard lock(g_mutex);
    if (g_pending.count(key))
        return false;
    auto it = g_map.find(key);
    return it != g_map.end() && Normalize(it->second.get(), g_gameDirKey).rfind("modloader\\cache", 0) == 0;
}

int Assets::LodPercent()
{
    return g_lodPct;
}

void Assets::SetLod(int percent)
{
    percent = std::clamp(percent, 10, 100);
    {
        std::lock_guard lock(g_mutex);
        ApplyLod(percent);
    }
    // Чтобы следующий запуск начался с того же: lod.txt — единственное место, где это записано.
    std::ofstream out(fs::path(g_gameDir) / L"modloader" / L"lod.txt", std::ios::trunc);
    out << "# units = процент треугольников у моделей юнитов (10..100, 100 = выключено).\n"
        << "# В игре меняется командой .lod <процент>; файл пишется ею же.\n"
        << "units = " << percent << "\n";
}

const std::vector<Assets::Override>& Assets::List()
{
    return g_list;
}

void Assets::Print()
{
    {
        std::lock_guard lock(g_mutex);
        for (const auto& [key, sources] : g_patches)
            for (const PatchSource& p : sources)
                Console::Print("  patch %-14s %s%s", p.mod.c_str(), key.c_str(), g_pending.count(key) ? "  (not read by the game yet)" : "");
    }
    if (g_list.empty())
    {
        Console::Print("No asset overrides. A mod can put files in modloader/mods/<mod>/assets/,");
        Console::Print("mirroring the game folder: assets/data/shaders/tone/tone.frag");
        return;
    }
    for (const Override& o : g_list)
        Console::Print("  %-20s %s", o.mod.c_str(), o.game.c_str());
}
