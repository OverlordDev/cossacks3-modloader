// Мелкие удобства поверх window.game, который модлоадер впрыскивает в страницу после загрузки.
//
// Сам мост появляется не мгновенно, поэтому кнопки лучше включать через bridge.whenReady.
window.bridge = {
  // Ждёт появления window.game. callback(true) — мост есть, callback(false) — не дождались.
  whenReady(callback, timeoutMs = 3000) {
    if (typeof window.game === 'object') return callback(true);
    let waited = 0;
    const timer = setInterval(() => {
      if (typeof window.game === 'object') {
        clearInterval(timer);
        callback(true);
      } else if ((waited += 50) >= timeoutMs) {
        clearInterval(timer);
        callback(false);
      }
    }, 50);
  },

  // Выполнить Lua в игре и получить ответ: game.lua возвращает JSON.
  //   const n = await bridge.ask("game.evalInt('gProfile.sndmaster')");
  async ask(luaCode) {
    const text = await game.lua(luaCode);
    try {
      return JSON.parse(text);
    } catch {
      return text;
    }
  },

  // Настройки игры — это опции проекта. Читает их модлоадер и кладёт сюда (см. client.lua),
  // а записываем мы отсюда, вызывая нативы игры через Lua.
  setOption(name, value) {
    if (typeof value === 'boolean') {
      return game.lua(`native.SetProjectOptionAsBoolean('${name}', ${value})`);
    }
    return game.lua(`native.SetProjectOptionAsString('${name}', '${String(value)}')`);
  },
};
