-- profile — профиль игрока: звук, управление, язык, настройки поведения.
--
--   profile.get("sndmaster")        --> 0.75
--   profile.set("sndmaster", 0.5)   -- только сервер/консоль/страницы
--   profile.all()                   --> весь профиль таблицей
--   profile.save()                  -- записать профиль на диск, как делает «Принять»
--   profile.tmp.get("sndmaster")    -- черновик экрана настроек (gProfileTmp)
--
-- Поля — тип TProfile в GAME_STATE.md.
-- Чтение (get/all) — shared (везде); запись (set/save) — server/shared/страница
-- (на client нет game.exec — проси сервер через net.send, читай HUD через game.api).
--
-- Экран настроек игры правит не gProfile, а временную копию gProfileTmp и переносит её по кнопке
-- «Принять». Если делаете свой экран настроек — работайте через profile.tmp, иначе «Принять»
-- затрёт ваши правки старыми значениями.

profile = {}

-- profile.get(field): одно поле профиля. Парам: field — имя поля TProfile. Возврат: значение.
-- Сторона: shared (везде). Ошибки: state.get — unknown global/no field при неверном имени.
function profile.get(field) return state.get("gProfile." .. field) end
-- profile.set(field, value): записать поле профиля. Сторона: server/shared/страница
-- (через state.set: на client — ошибка "only server scripts", проси через net.send).
-- Ошибки: неверное имя поля; не простое значение.
function profile.set(field, value) state.set("gProfile." .. field, value) end
-- profile.all(): весь профиль таблицей. Возврат: таблица TProfile. Сторона: shared (везде).
function profile.all() return state.read("gProfile") end

-- profile.save(): записать профиль на диск (как кнопка «Принять»: _profile_SaveUserProfile).
-- Сторона: server/shared/страница. Ошибки: "profile.save: server only" на client (нет game.exec).
function profile.save()
    if not game.exec then error("profile.save: server only", 2) end
    game.exec("_profile_SaveUserProfile;")
end

-- Временная копия экрана настроек: те же функции, но над gProfileTmp.
-- Чтение — везде, запись — server/shared/страница (как у profile). Ошибки — те же, что у state.get/set.
profile.tmp = {
    get = function(field) return state.get("gProfileTmp." .. field) end,
    set = function(field, value) state.set("gProfileTmp." .. field, value) end,
    all = function() return state.read("gProfileTmp") end,
}
