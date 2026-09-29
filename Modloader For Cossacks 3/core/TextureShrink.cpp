#include "pch.h"
#include "TextureShrink.h"

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <vector>

namespace
{
    // Заголовок DDS: магия (4) + DDS_HEADER (124). Смещения — от начала файла.
    constexpr size_t kHeaderSize = 128;
    constexpr size_t kOffSize = 4, kOffFlags = 8, kOffHeight = 12, kOffWidth = 16, kOffLinear = 20, kOffMips = 28,
                     kOffPfFlags = 80, kOffFourCc = 84, kOffCaps2 = 112;
    constexpr uint32_t kFlagMipCount = 0x20000, kFlagLinearSize = 0x80000, kPfFourCc = 0x4;
    constexpr uint32_t kCaps2Cube = 0x200, kCaps2Volume = 0x200000;

    uint32_t Get32(const std::string& s, size_t off)
    {
        uint32_t v;
        std::memcpy(&v, s.data() + off, 4);
        return v;
    }
    void Put32(std::string* s, size_t off, uint32_t v) { std::memcpy(s->data() + off, &v, 4); }

    // Размер одного уровня в блоках 4x4 (в углах нецелых размеров считаем блок целиком, как в DDS).
    size_t LevelBytes(uint32_t w, uint32_t h, size_t blockBytes)
    {
        return static_cast<size_t>(std::max(1u, (w + 3) / 4)) * std::max(1u, (h + 3) / 4) * blockBytes;
    }
}

bool TextureShrink::TopSide(const std::string& head, unsigned* side)
{
    if (head.size() < kHeaderSize || std::memcmp(head.data(), "DDS ", 4) != 0)
        return false;
    *side = std::max(Get32(head, kOffHeight), Get32(head, kOffWidth));
    return true;
}

TextureShrink::Result TextureShrink::Shrink(const std::string& dds, unsigned maxSide, std::string* out, int* dropped)
{
    if (dropped)
        *dropped = 0;
    if (dds.size() < kHeaderSize || std::memcmp(dds.data(), "DDS ", 4) != 0 || Get32(dds, kOffSize) != 124)
        return Result::Unsupported;
    if ((Get32(dds, kOffPfFlags) & kPfFourCc) == 0 || (Get32(dds, kOffCaps2) & (kCaps2Cube | kCaps2Volume)))
        return Result::Unsupported;

    size_t block;
    if (std::memcmp(dds.data() + kOffFourCc, "DXT1", 4) == 0)
        block = 8;
    else if (std::memcmp(dds.data() + kOffFourCc, "DXT3", 4) == 0 || std::memcmp(dds.data() + kOffFourCc, "DXT5", 4) == 0)
        block = 16;
    else
        return Result::Unsupported;

    uint32_t h = Get32(dds, kOffHeight), w = Get32(dds, kOffWidth);
    uint32_t mips = (Get32(dds, kOffFlags) & kFlagMipCount) ? Get32(dds, kOffMips) : 1;
    if (w == 0 || h == 0 || w > 65536 || h > 65536 || mips == 0 || mips > 20)
        return Result::Unsupported;

    // Размеры уровней и сколько данных должно быть в файле.
    std::vector<size_t> sizes;
    size_t total = 0;
    for (uint32_t i = 0; i < mips; ++i)
    {
        size_t s = LevelBytes(std::max(1u, w >> i), std::max(1u, h >> i), block);
        sizes.push_back(s);
        total += s;
    }
    if (dds.size() < kHeaderSize + total)
        return Result::Unsupported; // оборванный файл: лучше отдать движку как есть, чем угадывать

    uint32_t drop = 0;
    while (std::max(w >> drop, h >> drop) > maxSide && drop + 1 < mips)
        ++drop;
    if (drop == 0)
        return Result::Unchanged;

    size_t skip = 0;
    for (uint32_t i = 0; i < drop; ++i)
        skip += sizes[i];

    std::string result = dds.substr(0, kHeaderSize);
    Put32(&result, kOffHeight, std::max(1u, h >> drop));
    Put32(&result, kOffWidth, std::max(1u, w >> drop));
    Put32(&result, kOffLinear, static_cast<uint32_t>(sizes[drop]));
    Put32(&result, kOffMips, mips - drop);
    Put32(&result, kOffFlags, Get32(result, kOffFlags) | kFlagMipCount | kFlagLinearSize);
    result.append(dds, kHeaderSize + skip, total - skip);

    *out = std::move(result);
    if (dropped)
        *dropped = static_cast<int>(drop);
    return Result::Shrunk;
}
