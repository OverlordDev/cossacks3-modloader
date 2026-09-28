// Подставной мост страницы: то же, что модлоадер даёт странице (game.api,
// game.lua), только отвечает заготовленными данными. Нужен, чтобы вкладки
// инспектора можно было проверить, не запуская игру.
(function () {
  const TYPES = {
    TMapPlayer: [
      { name: 'name', type: 'string' }, { name: 'team', type: 'int' },
      { name: 'bhuman', type: 'bool' }, { name: 'startx', type: 'float' },
      { name: 'settings', type: 'TPlayerSettings' },
      { name: 'res', type: 'array', array: [0, 6] },
    ],
    TPlayerSettings: [{ name: 'difficulty', type: 'int' }, { name: 'nation', type: 'string' }],
  };
  const GLOBALS = [
    { name: 'gInterface', type: 'TInterface' },
    { name: 'gMap', type: 'TMap' },
    { name: 'gPlayer', type: 'array', array: [0, 11] },
    { name: 'gProfile', type: 'TProfile' },
  ];

  let WATER = [
    { index: 0, name: 'озеро', x1: -40, z1: -40, x2: 40, z2: 40, level: -1 },
  ];

  // Курсор стоит в заранее известной точке: так видно, что панель берёт из
  // world.cursor() именно x и z, а не x и высоту.
  const CURSOR = [12.5, 3.25, -40.75];

  const calls = [];
  window.__calls = calls;

  const handlers = {
    'game.isInGame': () => true,

    'state.globals': () => GLOBALS,

    'state.fields': (path) => {
      if (path === 'gPlayer') return { array: true, from: 0, to: 11, of: 'TMapPlayer' };
      if (/^gPlayer\[\d+\]$/.test(path)) return TYPES.TMapPlayer;
      if (/\.settings$/.test(path)) return TYPES.TPlayerSettings;
      if (/\.res$/.test(path)) return { array: true, from: 0, to: 6, of: 'int' };
      if (/\.(name|nation)$/.test(path)) return { simple: true, type: 'string' };
      if (/\.(team|difficulty)$/.test(path)) return { simple: true, type: 'int' };
      if (path === 'gMap') return [{ name: 'players', type: 'array', array: [0, 11] }];
      if (path === 'gInterface') return [{ name: 'gamemode', type: 'int' }];
      if (path === 'gProfile') return [{ name: 'sndmaster', type: 'float' }];
      throw new Error("state: unknown global '" + path + "'");
    },

    'state.read': (path) => {
      if (/^gPlayer\[\d+\]$/.test(path))
        return { name: 'Игрок ' + path.match(/\d+/)[0], team: 1, bhuman: true, startx: 1.5 };
      if (/\.settings$/.test(path)) return { difficulty: 2, nation: 'ukr' };
      if (/^obj\(/.test(path))
        return { sid: path.includes('201') ? 'mill18' : 'peasant', hp: 50, maxhp: 50,
                 x: -12.5, z: 40.25, player: 0, bbuilding: path.includes('201') };
      return {};
    },

    'state.set': () => true,

    'query.scan': (opts) => {
      const all = [
        { handle: 101, sid: 'peasant', player: 0, x: -12.5, z: 40.25, hp: 50 },
        { handle: 102, sid: 'peasant', player: 0, x: -10, z: 41, hp: 50 },
        { handle: 103, sid: 'peasant', player: 1, x: 80, z: -30, hp: 43 },
        { handle: 201, sid: 'mill18', player: 0, x: -20, z: 35, hp: 900 },
        { handle: 301, sid: 'musketeer18', player: 1, x: 90, z: -22, hp: 120 },
      ];
      return all.filter(r => (!opts || !opts.sid || r.sid === opts.sid)
                          && (!opts || opts.player === undefined || r.player === opts.player));
    },

    'camera.position': () => true,

    // Правка мира: сами кисти ничего не считают, важно лишь то, что панель
    // зовёт их с правильными аргументами — это видно в window.__calls.
    'terrain.raise': () => true,
    'terrain.lower': () => true,
    'terrain.smooth': () => true,
    'terrain.plateau': () => true,
    'terrain.random': () => true,
    'terrain.paint': () => true,
    'terrain.update': () => true,
    'terrain.water': (x, z, opts) => {
      WATER.push({ index: WATER.length, name: opts.name || 'water', level: opts.level,
                   x1: x - opts.radius, z1: z - opts.radius,
                   x2: x + opts.radius, z2: z + opts.radius });
      return WATER.length - 1;
    },
    'terrain.setCollision': () => true,
    'water.add': (opts) => {
      WATER.push({ index: WATER.length, name: opts.name, level: opts.level,
                   x1: opts.x1, z1: opts.z1, x2: opts.x2, z2: opts.z2 });
      return WATER.length - 1;
    },
    'water.list': () => WATER,
    'water.remove': (i) => { WATER = WATER.filter(f => f.index !== i); return true; },

    // Выделение: два объекта — крестьянин и мельница с очередью и улучшением.
    'units.selected': () => [101, 201],
    'units.info': (h) => ({ handle: h, sid: h === 201 ? 'mill18' : 'peasant',
                            hp: h === 201 ? 900 : 50, x: -20, z: 35, player: 0 }),
    'buildings.info': (h) => h !== 201 ? null : ({
      sid: 'mill18', player: 0,
      produce: [{ sid: 'peasant', price: { food: 50, wood: 0, stone: 0, gold: 0, iron: 0, coal: 0 } }],
      upgrades: [{ sid: 'mill18up1', price: { food: 0, wood: 200, stone: 100, gold: 0, iron: 0, coal: 0 } }],
      queue: [{ kind: 'unit', sid: 'peasant', amount: 3, progress: 0.4 }],
    }),
    'buildings.produce': () => true,
    'buildings.cancel': () => true,
    'buildings.upgrade': () => true,
    'buildings.cancelUpgrade': () => true,

    'profiler.start': () => true,
    'profiler.stop': () => true,
    'profiler.reset': () => true,
    'profiler.report': () => 'profiler: lua 412.0 KB\n  game.exec: 17 x 0.031 s (avg 0.0018)\n'
                           + '  state.read: 4 x 0.009 s (avg 0.0022)',
  };

  window.game = {
    async api(name, ...args) {
      calls.push([name, ...args]);
      const fn = handlers[name];
      if (!fn) throw new Error("api: unknown function '" + name + "'");
      return fn(...args);
    },
    // game.lua страница зовёт не только ради консоли: через него берут значения,
    // которых у game.api не получить (он отдаёт лишь первое из нескольких).
    async lua(code) {
      calls.push(['lua', code]);
      if (code === '{ world.cursor() }') return JSON.stringify(CURSOR);
      const cell = code.match(/^\{ terrain\.cell\(([-\d.]+), ([-\d.]+)\) \}$/);
      if (cell)   // карта 320: клетка = мир + 160
        return JSON.stringify([Math.floor(Number(cell[1]) + 160), Math.floor(Number(cell[2]) + 160)]);
      return 'ok: ' + code;
    },
  };
})();
