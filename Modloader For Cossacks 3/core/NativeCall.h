#pragma once

// Вызов любого натива скриптового API по его объявлению из NativesTable.
// Соглашение (проверено по дизассемблеру): __stdcall, параметры в обычном порядке;
//   Integer/Pointer — 4 байта, Boolean — байт в 4-байтовом слоте, Float — Single (4 байта),
//   String — Delphi AnsiString (char*); результат String — через скрытый указатель ПЕРВЫМ параметром,
//   Float — в ST(0), остальное — в eax.
//   var/out-параметры передаются указателем на наш буфер, а после вызова читаются обратно (outs).
namespace NativeCall
{
    enum class Type { None, Int, Bool, Float, String, Unsupported };

    struct Signature
    {
        std::string name;
        std::string decl;
        void* fn = nullptr;
        std::vector<Type> params;
        std::vector<bool> byRef;                 // var/out: значение возвращается, а не передаётся
        std::vector<std::string> paramTypeNames; // для сообщений об ошибках
        int inputCount = 0;                      // сколько параметров нужно передать (без var)
        Type result = Type::None;
        std::string error; // непусто — вызвать нельзя (и почему)
    };

    // nullptr — натива с таким именем нет (имя без учёта регистра).
    const Signature* Find(const std::string& name);

    struct Value
    {
        Type type = Type::None;
        int32_t i = 0;
        bool b = false;
        float f = 0;
        std::string s; // ANSI
    };

    // Только из главного потока игры. false — исключение внутри натива (*error заполнен).
    // args — только обычные параметры (var пропускаются); значения var-параметров кладутся в outs.
    bool Invoke(const Signature& sig, const std::vector<Value>& args, Value* result, std::string* error,
                std::vector<Value>* outs = nullptr);
}
