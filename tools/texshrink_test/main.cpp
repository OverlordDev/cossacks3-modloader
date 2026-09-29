// Стенд для TextureShrink: прогоняет все .dds игры из тех папок, которые режет модлоадер, и проверяет результат
// независимо от самого кода: размеры уровней пересчитываются заново, хвост данных сверяется с исходным файлом.
// Запуск: tools/texshrink_test/run.bat "<папка игры>" [макс. сторона, по умолчанию 1024]
#include "../../Modloader For Cossacks 3/core/TextureShrink.cpp"

#include <cstdio>
#include <filesystem>
#include <fstream>
#include <sstream>

namespace fs = std::filesystem;

static size_t Level(unsigned w, unsigned h, size_t bs)
{
    return static_cast<size_t>(std::max(1u, (w + 3) / 4)) * std::max(1u, (h + 3) / 4) * bs;
}

int main(int argc, char** argv)
{
    if (argc < 2)
    {
        std::printf("usage: texshrink_test <game dir> [max side]\n");
        return 2;
    }
    unsigned maxSide = argc > 2 ? static_cast<unsigned>(std::atoi(argv[2])) : 1024;
    const char* dirs[] = { "data/materials/buildings", "data/materials/env", "data/terrain/decals" };
    int files = 0, shrunk = 0, unchanged = 0, unsupported = 0, failures = 0;
    double before = 0, after = 0;
    for (const char* d : dirs)
    {
        std::error_code ec;
        for (const auto& e : fs::recursive_directory_iterator(fs::path(argv[1]) / d, ec))
        {
            if (!e.is_regular_file() || e.path().extension() != ".dds")
                continue;
            std::ifstream in(e.path(), std::ios::binary);
            std::stringstream ss;
            ss << in.rdbuf();
            std::string src = ss.str(), dst;
            ++files;
            int dropped = 0;
            TextureShrink::Result r = TextureShrink::Shrink(src, maxSide, &dst, &dropped);
            if (r == TextureShrink::Result::Unsupported)
            {
                ++unsupported;
                std::printf("unsupported: %s\n", e.path().string().c_str());
                continue;
            }
            before += src.size();
            if (r == TextureShrink::Result::Unchanged)
            {
                ++unchanged;
                after += src.size();
                continue;
            }
            ++shrunk;
            after += dst.size();

            // Независимая проверка результата.
            auto g = [](const std::string& s, size_t off) { uint32_t v; std::memcpy(&v, s.data() + off, 4); return v; };
            unsigned sh = g(src, 12), sw = g(src, 16), smips = g(src, 28);
            unsigned dh = g(dst, 12), dw = g(dst, 16), dmips = g(dst, 28);
            size_t bs = std::memcmp(src.data() + 84, "DXT1", 4) == 0 ? 8 : 16;
            bool bad = false;
            if (dh != std::max(1u, sh >> dropped) || dw != std::max(1u, sw >> dropped) || dmips != smips - dropped)
                bad = true;
            if (std::max(dh, dw) > maxSide && dmips > 1)
                bad = true; // могло остаться больше лимита только из-за единственного мипа
            size_t expect = 128, skip = 0;
            for (unsigned i = 0; i < dmips; ++i)
                expect += Level(std::max(1u, dw >> i), std::max(1u, dh >> i), bs);
            for (int i = 0; i < dropped; ++i)
                skip += Level(std::max(1u, sw >> i), std::max(1u, sh >> i), bs);
            if (dst.size() != expect || g(dst, 20) != Level(dw, dh, bs))
                bad = true;
            if (dst.compare(128, std::string::npos, src, 128 + skip, dst.size() - 128) != 0)
                bad = true; // оставшиеся уровни должны быть теми же байтами
            if (dst.compare(0, 12, src, 0, 12) != 0 || dst.compare(32, 96, src, 32, 96) != 0)
                bad = true; // остальной заголовок (формат, caps) не тронут
            if (bad)
            {
                ++failures;
                std::printf("FAIL %s\n", e.path().string().c_str());
            }
        }
    }
    std::printf("файлов %d: срезано %d, без изменений %d, не поддержано %d; сторона <= %u\n", files, shrunk, unchanged, unsupported, maxSide);
    std::printf("объём: %.1f МБ -> %.1f МБ (%.0f%%)\n", before / 1e6, after / 1e6, before ? 100.0 * after / before : 100.0);
    std::printf(failures ? "ПРОВАЛОВ: %d\n" : "ok\n", failures);
    return failures ? 1 : 0;
}
