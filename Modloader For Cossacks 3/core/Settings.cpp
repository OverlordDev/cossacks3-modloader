#include "pch.h"
#include "Settings.h"
#include "Console.h"

#include <algorithm>
#include <filesystem>
#include <fstream>
#include <map>
#include <string>

namespace
{
    std::map<std::string, std::string> Load()
    {
        wchar_t exe[MAX_PATH];
        GetModuleFileNameW(nullptr, exe, MAX_PATH);
        std::filesystem::path file = std::filesystem::path(exe).parent_path() / L"modloader" / L"settings.txt";

        std::map<std::string, std::string> values;
        std::ifstream in(file);
        if (!in)
            return values;

        std::string line;
        while (std::getline(in, line))
        {
            size_t eq = line.find('=');
            if (eq == std::string::npos || line.empty() || line[0] == '#' || line[0] == ';')
                continue;
            auto trim = [](std::string s) {
                size_t b = s.find_first_not_of(" \t\r");
                size_t e = s.find_last_not_of(" \t\r");
                if (b == std::string::npos)
                    return std::string();
                s = s.substr(b, e - b + 1);
                std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) { return static_cast<char>(tolower(c)); });
                return s;
            };
            values[trim(line.substr(0, eq))] = trim(line.substr(eq + 1));
        }
        LOG_INFO("[settings] %d option(s) from modloader\\settings.txt", static_cast<int>(values.size()));
        return values;
    }
}

bool Settings::Enabled(const char* key, bool byDefault)
{
    static const std::map<std::string, std::string> values = Load();
    auto it = values.find(key);
    if (it == values.end())
        return byDefault;
    return !(it->second == "0" || it->second == "false" || it->second == "no" || it->second == "off");
}
