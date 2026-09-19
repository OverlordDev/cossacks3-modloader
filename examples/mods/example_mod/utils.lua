-- Модуль мода: подключается через require("utils"), т.к. указан в manifest.lua (files).
local utils = {}

function utils.formatResources(p)
    return string.format("gold=%d wood=%d food=%d stone=%d iron=%d coal=%d",
        p.gold, p.wood, p.food, p.stone, p.iron, p.coal)
end

return utils
