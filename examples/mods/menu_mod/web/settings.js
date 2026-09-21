// Настройки: чтение и запись реальных значений игры.
//
// Игра хранит их в двух местах:
//   опции проекта (графика)      — native.GetProjectOptionAs* / SetProjectOptionAs*
//   профиль игрока               — скриптовая структура, читается через game.eval*
//
// Важно: профиль правим в gProfileTmp, а не в gProfile. Игра держит временную копию, и кнопки
// внизу экрана работают именно с ней: «Принять» делает gProfile := gProfileTmp и сохраняет на диск,
// «Отмена» — gProfileTmp := gProfile. Если писать напрямую в gProfile, «Принять» затрёт правки
// старыми значениями, а «Отмена» их оставит — то есть ровно наоборот.
//
// Звук лежит в обоих местах: gProfile.snd* сохраняется, а svg*/Sound.Master — то, что слышно
// прямо сейчас. Поэтому пишем в оба, как родной экран.

const OPTIONS = {
  // Графика: строковые опции проекта.
  string: ['VSyncMode', 'AntiAliasing', 'ShadowMap', 'TextureFilteringQuality',
           'DDSDetailLevel', 'ShaderType', 'WaterReflection', 'HDRType'],
  // Графика: переключатели.
  bool: ['FXAAEnable', 'SSAOEnable', 'ShadowMapEnabled'],
};

// Звук: поле профиля -> опция проекта, через которую громкость слышна.
const SOUND = {
  sndmaster: 'Sound.Master',
  sndmusic: 'svgMusic',
  sndfx: 'svgSFX',
  sndambient: 'svgAmbient',
  sndinterface: 'svgInterface',
};

// Управление: числовые поля профиля.
const SPEEDS = ['mousescrollspeed', 'keyscrollspeed', 'middlemousescrollspeed', 'wheelspeed'];

// Управление: переключатели профиля.
const FLAGS = ['bclipmouse', 'bfreezoom', 'bautosave', 'bcenterfirstrow',
               'binfiniteonleftclick', 'bsearchenemyinfront', 'bselectallunitsonz'];

// Собирает одним запросом всё, что показывает экран.
function readQuery() {
  const parts = [];
  for (const name of OPTIONS.string) parts.push(`${name} = native.GetProjectOptionAsString('${name}')`);
  for (const name of OPTIONS.bool) parts.push(`${name} = native.GetProjectOptionAsBoolean('${name}')`);
  for (const field of Object.keys(SOUND)) parts.push(`${field} = game.evalFloat('gProfileTmp.${field}')`);
  for (const field of SPEEDS) parts.push(`${field} = game.evalFloat('gProfileTmp.${field}')`);
  for (const field of FLAGS) parts.push(`${field} = game.evalBool('gProfileTmp.${field}')`);
  parts.push(`sndmute = game.evalInt('gProfileTmp.sndmute')`);
  parts.push(`lang = game.eval('gProfileTmp.lang')`);
  return '{' + parts.join(', ') + '}';
}

// Запись. Опции проекта — напрямую; профиль — скриптом, вместе с опцией громкости.
function writeQuery(name, value) {
  if (OPTIONS.bool.includes(name)) {
    return `native.SetProjectOptionAsBoolean('${name}', ${value})`;
  }
  if (OPTIONS.string.includes(name)) {
    return `native.SetProjectOptionAsString('${name}', '${value}')`;
  }
  if (SOUND[name]) {
    const v = Number(value).toFixed(3);
    return `game.exec("gProfileTmp.${name} := ${v}; SetProjectOptionAsFloat('${SOUND[name]}', ${v});")`;
  }
  if (SPEEDS.includes(name)) {
    return `game.exec("gProfileTmp.${name} := ${Number(value).toFixed(3)};")`;
  }
  if (FLAGS.includes(name)) {
    return `game.exec("gProfileTmp.${name} := ${value ? 'True' : 'False'};")`;
  }
  if (name === 'sndmute') {
    return `game.exec("gProfileTmp.sndmute := ${value ? 1 : 0};")`;
  }
  return null;
}

window.settings = {
  // Значения на момент открытия: по ним откатываем графику при отмене.
  initial: null,

  async load() {
    const values = await bridge.ask(readQuery());
    this.initial = values;
    for (const [name, value] of Object.entries(values || {})) {
      const el = document.querySelector(`[data-option="${name}"]`);
      if (!el) continue;
      if (el.type === 'checkbox') el.checked = name === 'sndmute' ? value > 0 : !!value;
      else if (el.type === 'range') el.value = String(Math.round(Number(value) * 100));
      else el.value = String(value);
      el.dispatchEvent(new Event('display'));
    }
    return values;
  },

  async write(el) {
    let value;
    if (el.type === 'checkbox') value = el.checked;
    else if (el.type === 'range') value = Number(el.value) / 100;
    else value = el.value;

    const code = writeQuery(el.dataset.option, value);
    if (code) await game.lua(code);
  },

  // Профиль игра откатит сама (gProfileTmp := gProfile), а опции проекта мы меняем напрямую,
  // поэтому графику при отмене возвращаем руками.
  async revertGraphics() {
    if (!this.initial) return;
    for (const name of [...OPTIONS.string, ...OPTIONS.bool]) {
      if (!(name in this.initial)) continue;
      const kind = OPTIONS.bool.includes(name) ? 'Boolean' : 'String';
      const value = OPTIONS.bool.includes(name) ? this.initial[name] : `'${this.initial[name]}'`;
      await game.lua(`native.SetProjectOptionAs${kind}('${name}', ${value})`);
    }
  },
};
