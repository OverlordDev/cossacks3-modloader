-- profile — профиль игрока: звук, управление, язык, настройки поведения.
--
--   profile.get("sndmaster")        --> 0.75
--   profile.set("sndmaster", 0.5)   -- только сервер/консоль/страницы
--   profile.all()                   --> весь профиль таблицей
--   profile.save()                  -- записать профиль на диск, как делает «Принять»
--
-- Поля — тип TProfile в GAME_STATE.md.
--
-- Экран настроек игры правит не gProfile, а временную копию gProfileTmp и переносит её по кнопке
-- «Принять». Если делаете свой экран настроек — работайте через profile.tmp, иначе «Принять»
-- затрёт ваши правки старыми значениями.

profile = {}

function profile.get(field) return state.get("gProfile." .. field) end
function profile.set(field, value) state.set("gProfile." .. field, value) end
function profile.all() return state.read("gProfile") end

function profile.save()
    if not game.exec then error("profile.save: server only", 2) end
    game.exec("_profile_SaveUserProfile;")
end

-- Временная копия экрана настроек: те же функции, но над gProfileTmp.
profile.tmp = {
    get = function(field) return state.get("gProfileTmp." .. field) end,
    set = function(field, value) state.set("gProfileTmp." .. field, value) end,
    all = function() return state.read("gProfileTmp") end,
}
