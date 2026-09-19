#pragma once

#include <string>
#include <vector>

// Параметры пост-обработки живьём: те самые поля, что игра читает из data/posteffects/posteffects.lib
// (bloom/HDR, контраст, насыщенность, виньетка, DOF, SSAO, гамма по текстуре-LUT). Нативами они не
// управляются — натив умеет только выбрать пресет целиком по номеру. Мы пишем поля объекта пресета
// (TXPHDRItem) и просим движок перелить их в шейдеры, поэтому менять можно прямо в партии.
//
// Путь к пресетам: движок скриптов -> проект (+4Ch) -> TXProject.GetRenderTree -> +148h -> +68h
// (TXPHDRCollection). Имена и смещения полей сняты с загрузчика .lib (sub_5D570C).
// Всё — только из главного потока игры.
namespace PostFx
{
    enum class Type { Float, Int, Bool, String, Vector };

    struct Field
    {
        const char* name;
        Type type;
        int count; // для Vector — сколько чисел
    };

    // Значение поля: заполнен ровно один вариант по типу поля.
    struct Value
    {
        Type type = Type::Float;
        double number = 0;
        bool boolean = false;
        std::string text;
        std::vector<float> vector;
    };

    const std::vector<Field>& Fields();

    bool Available();           // сцена загружена и пресеты есть
    int Count();                // сколько пресетов
    int Current();              // номер текущего (-1 — ни одного)
    std::string Name(int index);

    bool Get(int index, const std::string& field, Value* out, std::string* error);
    bool Set(int index, const std::string& field, const Value& value, std::string* error);

    // Перелить пресет в шейдеры. Без этого записанные поля не видны на экране.
    bool Apply(int index, std::string* error);
}
