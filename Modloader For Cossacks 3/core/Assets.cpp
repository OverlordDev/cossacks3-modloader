#include "pch.h"
#include "Assets.h"
#include "Console.h"
#include "GameApi.h"
#include "Hooks.h"

#include <filesystem>
#include <fstream>
#include <map>

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

    void Scan()
    {
        std::string gameDir = GameDir();
        fs::path modloaderDir = fs::path(gameDir) / L"modloader";
        auto state = LoadModState(modloaderDir);

        std::error_code ec;
        for (const auto& entry : fs::directory_iterator(modloaderDir / L"mods", ec))
        {
            if (!entry.is_directory())
                continue;
            std::string folder = entry.path().filename().string();
            auto enabled = state.find(folder);
            if (enabled != state.end() && !enabled->second)
                continue;

            fs::path assets = entry.path() / L"assets";
            if (!fs::is_directory(assets, ec))
                continue;

            for (const auto& file : fs::recursive_directory_iterator(assets, ec))
            {
                if (!file.is_regular_file())
                    continue;
                std::string rel = fs::relative(file.path(), assets, ec).string();
                std::string key = Normalize(rel, {});
                if (key.empty() || g_map.count(key))
                {
                    if (!key.empty())
                        LOG_WARN("[assets] %s\\%s is already overridden by another mod — skipped", folder.c_str(), key.c_str());
                    continue;
                }
                std::string full = file.path().string();
                g_map.emplace(key, GameApi::DelphiString(full));
                g_list.push_back({ folder, key, full });
            }
        }
    }

    std::string g_gameDirKey;

    // Вызывается из перехватов: вернуть путь мода или исходный, если подмены нет.
    const char* __cdecl MapPath(const char* path)
    {
        if (!path || g_map.empty())
            return path;
        auto it = g_map.find(Normalize(path, g_gameDirKey));
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

bool Assets::Install()
{
    g_gameDirKey = Normalize(GameDir() + "\\", {});
    Scan();
    if (g_list.empty())
        return true; // подменять нечего — перехваты не ставим

    bool ok = Hooks::CreateRaw("File open", GameApi::Addr(VaOpenStream), reinterpret_cast<void*>(hkOpenStream), &oOpenStream);
    ok &= Hooks::CreateRaw("File open (archives)", GameApi::Addr(VaOpenStream2), reinterpret_cast<void*>(hkOpenStream2), &oOpenStream2);
    ok &= Hooks::CreateRaw("File exists", GameApi::Addr(VaFileExists), reinterpret_cast<void*>(hkFileExists), &oFileExists);
    if (ok)
        LOG_INFO("[assets] %d file(s) from mods will replace game files", static_cast<int>(g_list.size()));
    return ok;
}

const std::vector<Assets::Override>& Assets::List()
{
    return g_list;
}

void Assets::Print()
{
    if (g_list.empty())
    {
        Console::Print("No asset overrides. A mod can put files in modloader/mods/<mod>/assets/,");
        Console::Print("mirroring the game folder: assets/data/shaders/tone/tone.frag");
        return;
    }
    for (const Override& o : g_list)
        Console::Print("  %-20s %s", o.mod.c_str(), o.game.c_str());
}
