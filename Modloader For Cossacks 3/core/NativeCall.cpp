#include "pch.h"
#include "NativeCall.h"
#include "Engine.h"
#include "GameApi.h"

#include <algorithm>
#include <mutex>
#include <unordered_map>

namespace
{
    std::string Lower(std::string s)
    {
        std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) { return static_cast<char>(tolower(c)); });
        return s;
    }

    std::string Trim(const std::string& s)
    {
        size_t b = s.find_first_not_of(" \t;");
        if (b == std::string::npos)
            return {};
        size_t e = s.find_last_not_of(" \t;");
        return s.substr(b, e - b + 1);
    }

    NativeCall::Type ParseType(const std::string& raw)
    {
        std::string t = Lower(Trim(raw));
        if (t == "integer" || t == "cardinal" || t == "pointer")
            return NativeCall::Type::Int;
        if (t == "boolean")
            return NativeCall::Type::Bool;
        if (t == "float" || t == "single")
            return NativeCall::Type::Float;
        if (t == "string")
            return NativeCall::Type::String;
        return NativeCall::Type::Unsupported;
    }

    // "function Name(const a, b: Integer; var c: Float): String"
    NativeCall::Signature Parse(const GameApi::Native& n)
    {
        NativeCall::Signature sig;
        sig.decl = n.decl;
        sig.name = std::string(GameApi::NameOf(n.decl));
        sig.fn = GameApi::Addr(n.va);

        std::string d = n.decl;
        bool isFunction = Lower(Trim(d)).rfind("function", 0) == 0;
        size_t open = d.find('('), close = d.rfind(')');
        std::string params = open != std::string::npos && close != std::string::npos && close > open
                                 ? d.substr(open + 1, close - open - 1) : "";
        std::string tail = close != std::string::npos && open != std::string::npos ? d.substr(close + 1)
                                                                                   : d.substr(d.find(sig.name) + sig.name.size());

        for (size_t pos = 0; pos < params.size();)
        {
            size_t end = params.find(';', pos);
            if (end == std::string::npos)
                end = params.size();
            std::string group = Trim(params.substr(pos, end - pos));
            pos = end + 1;
            if (group.empty())
                continue;

            size_t colon = group.find(':');
            if (colon == std::string::npos)
            {
                sig.error = "untyped parameter '" + group + "'";
                return sig;
            }
            std::string names = group.substr(0, colon), type = group.substr(colon + 1);
            std::string lnames = Lower(Trim(names));
            bool byRef = lnames.rfind("var ", 0) == 0 || lnames.rfind("out ", 0) == 0;
            NativeCall::Type t = ParseType(type);
            if (byRef && t == NativeCall::Type::String)
            {
                sig.error = "var String parameters are not supported yet";
                return sig;
            }
            if (t == NativeCall::Type::Unsupported)
            {
                sig.error = "unsupported parameter type '" + Trim(type) + "'";
                return sig;
            }
            size_t count = std::count(names.begin(), names.end(), ',') + 1;
            for (size_t i = 0; i < count; ++i)
            {
                sig.params.push_back(t);
                sig.byRef.push_back(byRef);
                sig.paramTypeNames.push_back(Trim(type));
                if (!byRef)
                    ++sig.inputCount;
            }
        }

        if (isFunction)
        {
            size_t colon = tail.find(':');
            sig.result = colon == std::string::npos ? NativeCall::Type::Unsupported : ParseType(tail.substr(colon + 1));
            if (sig.result == NativeCall::Type::Unsupported)
                sig.error = "unsupported result type '" + Trim(colon == std::string::npos ? tail : tail.substr(colon + 1)) + "'";
        }
        return sig;
    }

    // Сырые вызовы: без C++-объектов внутри — ради __try. Параметры кладутся справа налево (stdcall).
    bool RawCall(void* fn, const uint32_t* data, int count, bool floatResult, uint32_t* eaxOut, double* st0Out, DWORD* exc)
    {
        uint32_t eaxValue = 0;
        double fpValue = 0;
        __try
        {
            if (floatResult)
            {
                __asm
                {
                    mov ecx, count
                    mov esi, data
                push_f:
                    test ecx, ecx
                    jz call_f
                    dec ecx
                    push dword ptr [esi + ecx * 4]
                    jmp push_f
                call_f:
                    call fn
                    fstp fpValue
                }
            }
            else
            {
                __asm
                {
                    mov ecx, count
                    mov esi, data
                push_i:
                    test ecx, ecx
                    jz call_i
                    dec ecx
                    push dword ptr [esi + ecx * 4]
                    jmp push_i
                call_i:
                    call fn
                    mov eaxValue, eax
                }
            }
        }
        __except (*exc = GetExceptionCode(), EXCEPTION_EXECUTE_HANDLER)
        {
            return false;
        }
        *eaxOut = eaxValue;
        *st0Out = fpValue;
        return true;
    }
}

const NativeCall::Signature* NativeCall::Find(const std::string& name)
{
    static std::unordered_map<std::string, Signature> table;
    static std::once_flag once;
    std::call_once(once, [] {
        for (const auto& n : GameApi::Natives())
        {
            Signature sig = Parse(n);
            table.emplace(Lower(sig.name), std::move(sig));
        }
    });
    auto it = table.find(Lower(name));
    return it != table.end() ? &it->second : nullptr;
}

bool NativeCall::Invoke(const Signature& sig, const std::vector<Value>& args, Value* result, std::string* error,
                        std::vector<Value>* outs)
{
    std::vector<uint32_t> stack;
    // Буферы var-параметров: натив пишет прямо в них, поэтому они не должны переезжать при росте вектора.
    std::vector<std::unique_ptr<uint32_t>> refs;
    std::vector<std::unique_ptr<GameApi::DelphiString>> strings; // живут до конца вызова
    char* stringResult = nullptr;

    if (sig.result == Type::String)
        stack.push_back(reinterpret_cast<uint32_t>(&stringResult)); // скрытый var Result — первым

    size_t argIndex = 0;
    for (size_t i = 0; i < sig.params.size(); ++i)
    {
        if (sig.byRef[i])
        {
            refs.push_back(std::make_unique<uint32_t>(0));
            stack.push_back(reinterpret_cast<uint32_t>(refs.back().get()));
            continue;
        }
        const Value& v = args[argIndex++];
        switch (sig.params[i])
        {
        case Type::Int:
            stack.push_back(static_cast<uint32_t>(v.i));
            break;
        case Type::Bool:
            stack.push_back(v.b ? 1u : 0u);
            break;
        case Type::Float:
        {
            uint32_t bits;
            memcpy(&bits, &v.f, 4);
            stack.push_back(bits);
            break;
        }
        case Type::String:
            strings.push_back(std::make_unique<GameApi::DelphiString>(v.s));
            stack.push_back(reinterpret_cast<uint32_t>(strings.back()->get()));
            break;
        default:
            break;
        }
    }

    uint32_t eaxValue = 0;
    double st0 = 0;
    DWORD exc = 0;
    if (!RawCall(sig.fn, stack.data(), static_cast<int>(stack.size()), sig.result == Type::Float, &eaxValue, &st0, &exc))
    {
        char buf[64];
        snprintf(buf, sizeof(buf), "exception 0x%08lX inside native", exc);
        *error = buf;
        return false;
    }

    if (outs)
    {
        size_t refIndex = 0;
        for (size_t i = 0; i < sig.params.size(); ++i)
        {
            if (!sig.byRef[i])
                continue;
            uint32_t raw = *refs[refIndex++];
            Value v;
            v.type = sig.params[i];
            switch (v.type)
            {
            case Type::Int:   v.i = static_cast<int32_t>(raw); break;
            case Type::Bool:  v.b = (raw & 0xFF) != 0; break;
            case Type::Float: memcpy(&v.f, &raw, 4); break;
            default: break;
            }
            outs->push_back(v);
        }
    }

    result->type = sig.result;
    switch (sig.result)
    {
    case Type::Int:    result->i = static_cast<int32_t>(eaxValue); break;
    case Type::Bool:   result->b = (eaxValue & 0xFF) != 0; break;
    case Type::Float:  result->f = static_cast<float>(st0); break;
    case Type::String:
        result->s = stringResult ? stringResult : "";
        Engine::FreeString(&stringResult);
        break;
    default: break;
    }
    return true;
}
