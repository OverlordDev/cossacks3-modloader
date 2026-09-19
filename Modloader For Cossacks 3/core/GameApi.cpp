#include "pch.h"
#include "GameApi.h"

namespace
{
    const GameApi::Native kNatives[] = {
#include "NativesTable.inc"
    };
}

std::span<const GameApi::Native> GameApi::Natives()
{
    return kNatives;
}

std::string_view GameApi::NameOf(std::string_view decl)
{
    size_t start = decl.find(' ');
    if (start == std::string_view::npos)
        return {};
    decl.remove_prefix(start + 1);
    while (!decl.empty() && decl.front() == ' ')
        decl.remove_prefix(1);
    size_t end = decl.find_first_of("(:; ");
    return decl.substr(0, end);
}
