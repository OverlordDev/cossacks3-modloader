-- Новые нации и типы юнитов. Модлоадер сам строит из этого патчи скриптов, списки объектов,
-- .prop и иконки. Нужен перезапуск игры. Проверка: .content в консоли и modloader.log ([content]).

-- Нация: копия шаблона (from) — те же юниты, здания, улучшения и ИИ; свой sid (3 буквы) и название.
nation {
    sid = "zap",
    from = "ukr",
    name = { ru = "Запорожская Сечь", uk = "Запорізька Січ", en = "Zaporozhian Sich" },
}

-- Юнит: копия родителя (from) — модель, анимации, иконка, характеристики, место найма.
unit {
    sid = "serdiukvet",
    from = "serdiuk",
    nations = { "ukr", "zap" },
    cell = { 1, 1 },                     -- клетка панели найма (иначе — клетка родителя)
    base = { maxhp = 150 },              -- поля TObjBase (GAME_STATE.md): maxhp, speed, price[3], weapon[1].damage ...
    prop = {},                           -- поля TObjProp: vision, ...
    name = { ru = "Сердюк-ветеран", uk = "Сердюк-ветеран", en = "Veteran Serdiuk" },
    -- свои модель/материал/анимации (имена из actors.lib / .mat / acl.lib):
    -- actor = "mymodel", material = "mymodel", animations = "serdiuk", icon = "icons.unit.serdiuk",
}
