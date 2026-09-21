#pragma once

#include <functional>

// События игры для модов. Механизм: в код состояния игры (например DoProgress в menu.aix) вставляется строка
//   DScriptSetgDbgString0('ML:gui.DoProgress');
// Этот отладочный натив игрой не используется — мы его перехватываем и превращаем вызов в событие.
// Строка вида 'ML:событие|данные' передаёт обработчику данные (payload).
// Файлы игры не меняются: строка живёт только в памяти, после вставки состояние перекомпилируется.
namespace Events
{
    using Handler = std::function<void(const std::string& event, const std::string& payload)>;

    bool Install(); // хук натива-трамплина
    void Update();  // из цикла модлоадера: раз в секунду проверяет, что вставки на месте

    // Событие "gui.<State>" (в начале состояния) или "gui.<State>.end" (в конце; не сработает, если состояние
    // вышло раньше через exit). Вставка выполняется асинхронно в главном потоке игры.
    void HookGuiState(const std::string& state, bool atEnd = false);

    // Вставить в состояние GUI свою строку кода (она сама вызывает DScriptSetgDbgString0('ML:...')).
    // key — уникальное имя вставки (для повторов и логов).
    // Вернуть все вставки прямо сейчас (главный поток игры). Зовётся в начале DoCreate: игра пересобрала
    // интерфейс и сейчас построит экраны — ждать плановую проверку (раз в секунду) уже поздно.
    void MaintainNow();

    void HookGuiStateCode(const std::string& state, const std::string& key, const std::string& line, bool atEnd = false);

    // То же для библиотеки состояний объектов: library — путь от data\scripts ("units\unit.aix").
    // Код библиотеки общий для всех объектов этого вида, так что одна вставка ловит всех.
    // Обернуть в состоянии библиотеки каждый вызов call(...): line — строка события, где {0}, {1}...
    // заменяются аргументами вызова. key — уникальное имя вставки (у разных состояний — разные).
    //   WrapLibraryCalls("units\\unit.aix", "OnTagStates", "_misc_DoDamage", "damage@unit/OnTagStates",
    //       "DScriptSetgDbgString0('ML:unit.damage|'+IntToStr({0})+'|'+IntToStr({1})+'|'+IntToStr({2}))");
    void WrapLibraryCalls(const std::string& library, const std::string& state, const std::string& call,
                          const std::string& key, const std::string& line);

    void HookLibraryStateCode(const std::string& library, const std::string& state, const std::string& key,
                              const std::string& line, bool atEnd = false);

    // Сгенерировать событие из C++ (главный поток игры).
    void Emit(const std::string& event, const std::string& payload = {});

    // Из обработчика: попросить прервать состояние игры, в которое вставлено событие. Работает, если вставка
    // после вызова проверяет ответ: <вызов DScriptSetgDbgString0>; + kBlockCheck.
    void RequestBlock();
    inline constexpr char kBlockCheck[] = " if (DScriptGetgDbgString0='ML:block') then exit;";

    int Subscribe(const std::string& event, Handler handler); // event = "*" — все события
    void Unsubscribe(int id);

    void PrintStats(); // счётчики срабатываний

    // Обмен значениями со скриптом (главный поток игры):
    //   аргумент для скрипта — читается в нём через DScriptGetgDbgString0;
    //   результат из скрипта — DScriptSetgDbgString0('ML:ret:' + значение) попадает в захват.
    void SetScriptArg(const std::string& value);
    void BeginCapture();
    bool EndCapture(std::string* value); // false — скрипт ничего не вернул
}
