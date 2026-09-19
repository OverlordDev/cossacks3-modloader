#pragma once

#include <functional>

// Сообщения модов по официальному сетевому соединению игры.
// Отправка: LanSendParser(kPacketType, parser) — тот же механизм, которым игра шлёт свои пакеты.
// Приём: строка, вставленная в GUI-состояние OnLanEvent, ловит пакеты нашего типа (и выходит из состояния,
// чтобы игра не писала "unknown ID"), плюс события подключения/отключения игроков.
//
// Направления: 's' — клиент → хост, 'c' — хост → клиенты. В одиночной игре и на хосте сообщения
// доставляются локально (хост — одновременно сервер и клиент), поэтому моды работают одинаково везде.
namespace Net
{
    constexpr int kPacketType = 7700; // игра использует 1..17, 100..103, 200..206, 300

    using Receiver = std::function<void(char direction, const std::string& mod, const std::string& event,
                                        const std::string& data, int from)>;

    void Install(Receiver receiver);

    // Главный поток игры. false + *error — нельзя отправить.
    bool SendToServer(const std::string& mod, const std::string& event, const std::string& data, std::string* error);
    bool Broadcast(const std::string& mod, const std::string& event, const std::string& data, std::string* error);
}
