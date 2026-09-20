# Картинки интерфейса Cossacks 3

Сгенерировано `tools/list_ui_textures.py` из `data/hud/hud.tex` и `data/hud/hud.mat`.

Чтобы заменить картинку, положите свой BMP **того же размера и той же разрядности** в
`modloader/mods/<мод>/assets/data/hud/textures/ui/`. Прямоугольники, которые движок вырезает
из текстуры, зашиты в `hud.mat` — рисунок должен попадать в них.

Собрать BMP нужного формата из своей картинки: `tools/make_menu_art.py`.

С чего обычно начинают:

| хочу поменять | текстура | размер |
|---|---|---|
| фон главного меню | `mainmenu_art.bmp` | 2048x1024, 24 бита |
| логотип | `logo_small.bmp` | 512x256, 32 бита |
| экраны загрузки, 8 штук | `progressbar1.bmp` … `progressbar8.bmp` | 2048x1024, 24 бита |
| кнопки, рамки, свитки | `tex05.bmp` | 2048x2048, 32 бита |
| окна и диалоги | `dialogs01.bmp` | 2048x2048, 32 бита |
| иконки команд | `icons.bmp` | 1024x512, 32 бита |
| иконки юнитов | `iconsunits.bmp` | 1024x512, 24 бита |

Атласы (`tex*`, `dialogs*`, `icons*`) держат сотни картинок в одном файле — менять их надо
целиком, оставляя каждую вещь на своём месте. Списки ниже говорят, что где лежит.

## day01.glow — 1 материал(ов)

`data/env/flares/textures/day01.glow.tga` — файла нет на диске

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `misc.glow.1` | 0, 0, 0, 0 |

## primitives — 17 материал(ов)

`data/hud/textures/primitives.bmp` — 64x64, 32 бит, 0.0 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `icons.keycolor.1` | 3, 12, 2, 2 |
| `icons.keycolor.10` | 15, 26, 2, 2 |
| `icons.keycolor.11` | 21, 26, 2, 2 |
| `icons.keycolor.12` | 33, 26, 2, 2 |
| `icons.keycolor.13` | 45, 12, 2, 2 |
| `icons.keycolor.14` | 33, 12, 2, 2 |
| `icons.keycolor.15` | 51, 12, 2, 2 |
| `icons.keycolor.16` | 27, 26, 2, 2 |
| `icons.keycolor.2` | 9, 12, 2, 2 |
| `icons.keycolor.3` | 15, 12, 2, 2 |
| `icons.keycolor.4` | 21, 12, 2, 2 |
| `icons.keycolor.5` | 27, 12, 2, 2 |
| `icons.keycolor.6` | 57, 12, 2, 2 |
| `icons.keycolor.7` | 39, 12, 2, 2 |
| `icons.keycolor.8` | 3, 26, 2, 2 |
| `icons.keycolor.9` | 9, 26, 2, 2 |
| `icons.keycolor.sel` | 51, 12, 2, 2 |

## blank — 7 материал(ов)

`data/hud/textures/ui/blank.bmp` — 64x64, 32 бит, 0.0 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `misc.blank` | 0, 0, 0, 0 |
| `misc.blank.checked` | 0, 0, 0, 0 |
| `misc.blank.disabled` | 0, 0, 0, 0 |
| `misc.blank.hover` | 0, 0, 0, 0 |
| `misc.blank.normal` | 0, 0, 0, 0 |
| `misc.blank.pressed` | 0, 0, 0, 0 |
| `misc.snapshot` | 0, 0, 0, 0 |

## dialogs01 — 84 материал(ов)

`data/hud/textures/ui/dialogs01.bmp` — 2048x2048, 32 бит, 16.0 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `dialog.1.1.1` | 0, 4, 222, 134 |
| `dialog.1.1.2` | 226, 4, 252, 145 |
| `dialog.1.1.3` | 482, 4, 352, 178 |
| `dialog.1.2` | 837, 4, 211, 132 |
| `dialog.1.3.1` | 1053, 4, 140, 233 |
| `dialog.1.3.2` | 1197, 4, 160, 257 |
| `dialog.1.3.3` | 1360, 4, 147, 232 |
| `dialog.1.3.4` | 1510, 4, 147, 185 |
| `dialog.1.3.5` | 1661, 4, 124, 181 |
| `dialog.1.3.6` | 1788, 4, 107, 170 |
| `dialog.1.4` | 68, 1844, 287, 127 |
| `dialog.2.1` | 4, 1284, 514, 347 |
| `dialog.2.2` | 1017, 1262, 127, 178 |
| `dialog.2.3` | 1147, 1262, 129, 165 |
| `dialog.2.4` | 1017, 1442, 147, 180 |
| `dialog.2.5` | 1168, 1431, 115, 177 |
| `dialog.2.6` | 1288, 1429, 92, 180 |
| `dialog.3.1` | 4, 142, 139, 169 |
| `dialog.3.10` | 1341, 265, 280, 238 |
| `dialog.3.11` | 1624, 192, 274, 238 |
| `dialog.3.12` | 1902, 134, 134, 164 |
| `dialog.3.13` | 1794, 540, 130, 184 |
| `dialog.3.14` | 522, 1264, 122, 215 |
| `dialog.3.15` | 647, 1281, 138, 203 |
| `dialog.3.16` | 843, 1281, 171, 227 |
| `dialog.3.17` | 815, 1512, 132, 202 |
| `dialog.3.18` | 980, 1626, 99, 202 |
| `dialog.3.19` | 1082, 1625, 125, 177 |
| `dialog.3.2` | 147, 153, 154, 169 |
| `dialog.3.3` | 304, 153, 150, 205 |
| `dialog.3.4` | 457, 185, 112, 188 |
| `dialog.3.5` | 572, 185, 176, 206 |
| `dialog.3.6` | 752, 186, 103, 162 |
| `dialog.3.7` | 859, 140, 107, 176 |
| `dialog.3.8` | 970, 265, 368, 261 |
| `dialog.3.9` | 867, 320, 99, 153 |
| `dialog.4.1` | 4, 314, 126, 191 |
| `dialog.4.10` | 1386, 506, 404, 266 |
| `dialog.4.11` | 1902, 358, 106, 178 |
| `dialog.4.12` | 4, 1636, 357, 198 |
| `dialog.4.13.1` | 522, 1487, 154, 238 |
| `dialog.4.13.2` | 679, 1487, 122, 256 |
| `dialog.4.14` | 4, 596, 213, 284 |
| `dialog.4.15` | 365, 1747, 599, 299 |
| `dialog.4.16` | 221, 596, 115, 215 |
| `dialog.4.2` | 133, 361, 256, 232 |
| `dialog.4.3` | 392, 376, 130, 213 |
| `dialog.4.4` | 527, 394, 170, 220 |
| `dialog.4.5` | 701, 394, 116, 228 |
| `dialog.4.6` | 821, 477, 130, 209 |
| `dialog.4.7` | 925, 529, 145, 230 |
| `dialog.4.8` | 1104, 529, 158, 238 |
| `dialog.4.9` | 1265, 529, 118, 199 |
| `dialog.5.1` | 339, 596, 160, 199 |
| `dialog.5.10` | 907, 771, 226, 242 |
| `dialog.5.11` | 1137, 775, 347, 272 |
| `dialog.5.12` | 1488, 775, 99, 180 |
| `dialog.5.13` | 1591, 775, 125, 202 |
| `dialog.5.14` | 1720, 775, 158, 171 |
| `dialog.5.15` | 1882, 742, 148, 187 |
| `dialog.5.16` | 1211, 1640, 237, 155 |
| `dialog.5.17` | 1452, 1442, 413, 170 |
| `dialog.5.18` | 1452, 1616, 395, 187 |
| `dialog.5.2` | 503, 617, 144, 183 |
| `dialog.5.3` | 4, 884, 200, 213 |
| `dialog.5.4` | 221, 815, 132, 217 |
| `dialog.5.5` | 356, 798, 128, 222 |
| `dialog.5.6` | 488, 804, 128, 198 |
| `dialog.5.7` | 651, 626, 147, 226 |
| `dialog.5.8` | 801, 690, 102, 188 |
| `dialog.5.9` | 620, 881, 225, 173 |
| `dialog.6.1` | 4, 1100, 118, 219 |
| `dialog.6.2` | 125, 1100, 103, 186 |
| `dialog.6.3` | 231, 1036, 127, 200 |
| `dialog.6.4` | 361, 1024, 133, 222 |
| `dialog.6.5` | 498, 1057, 128, 199 |
| `dialog.6.6` | 629, 1057, 127, 204 |
| `dialog.6.7` | 760, 1057, 141, 221 |
| `dialog.6.8` | 904, 1050, 412, 209 |
| `dialog.6.9` | 1319, 1050, 178, 288 |
| `dialog.7.1` | 1500, 980, 137, 209 |
| `dialog.7.2` | 1641, 980, 143, 219 |
| `dialog.7.3` | 1788, 950, 124, 231 |
| `dialog.7.4` | 1501, 1203, 377, 236 |

## dialogs02 — 6 материал(ов)

`data/hud/textures/ui/dialogs02.bmp` — 1024x256, 32 бит, 1.0 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `dialog.8.1` | 6, 0, 148, 256 |
| `dialog.8.2` | 500, 0, 144, 256 |
| `dialog.8.3` | 355, 0, 146, 256 |
| `dialog.8.4` | 650, 0, 167, 256 |
| `dialog.8.5` | 173, 0, 165, 256 |
| `dialog.8.6` | 820, 0, 183, 256 |

## dialogs03 — 9 материал(ов)

`data/hud/textures/ui/dialogs03.bmp` — 1024x512, 32 бит, 2.0 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `dialog.9.1` | 0, 0, 136, 239 |
| `dialog.9.1a` | 136, 0, 136, 239 |
| `dialog.9.2` | 276, 0, 168, 190 |
| `dialog.9.3` | 297, 222, 109, 290 |
| `dialog.9.4` | 406, 222, 122, 282 |
| `dialog.9.5` | 444, 0, 120, 184 |
| `dialog.9.6` | 0, 241, 273, 271 |
| `dialog.9.7` | 583, 4, 318, 184 |
| `dialog.9.8` | 582, 188, 442, 324 |

## icons — 189 материал(ов)

`data/hud/textures/ui/icons.bmp` — 1024x512, 32 бит, 2.0 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `customgame.flag.1` | 453, 490, 24, 22 |
| `customgame.flag.2` | 478, 493, 24, 18 |
| `hud.res.1` | 557, 416, 60, 60 |
| `hud.res.2` | 617, 416, 60, 60 |
| `hud.res.3` | 317, 416, 60, 60 |
| `hud.res.4` | 377, 416, 60, 60 |
| `hud.res.5` | 437, 416, 60, 60 |
| `hud.res.6` | 497, 416, 60, 60 |
| `icons.bld.aca` | 230, 46, 46, 46 |
| `icons.bld.algtem` | 276, 0, 46, 46 |
| `icons.bld.art` | 184, 46, 46, 46 |
| `icons.bld.ba2` | 46, 92, 46, 46 |
| `icons.bld.bar` | 46, 46, 46, 46 |
| `icons.bld.bla` | 92, 46, 46, 46 |
| `icons.bld.blg` | 322, 0, 46, 46 |
| `icons.bld.blg2` | 322, 0, 46, 46 |
| `icons.bld.cen` | 92, 92, 46, 46 |
| `icons.bld.coa` | 138, 0, 46, 46 |
| `icons.bld.com` | 368, 92, 46, 46 |
| `icons.bld.dip` | 0, 92, 46, 46 |
| `icons.bld.eurtow` | 230, 92, 46, 46 |
| `icons.bld.gol` | 138, 0, 46, 46 |
| `icons.bld.hou` | 0, 0, 46, 46 |
| `icons.bld.iro` | 138, 0, 46, 46 |
| `icons.bld.mar` | 0, 46, 46, 46 |
| `icons.bld.mil` | 46, 0, 46, 46 |
| `icons.bld.por` | 230, 0, 46, 46 |
| `icons.bld.russga` | 886, 184, 46, 46 |
| `icons.bld.russwa` | 322, 46, 46, 46 |
| `icons.bld.rustow` | 322, 92, 46, 46 |
| `icons.bld.scoba2` | 368, 0, 46, 46 |
| `icons.bld.sga` | 886, 184, 46, 46 |
| `icons.bld.sta` | 138, 46, 46, 46 |
| `icons.bld.sto` | 92, 0, 46, 46 |
| `icons.bld.swa` | 184, 92, 46, 46 |
| `icons.bld.tem` | 184, 0, 46, 46 |
| `icons.bld.tursga` | 886, 184, 46, 46 |
| `icons.bld.turswa` | 276, 46, 46, 46 |
| `icons.bld.turtem` | 276, 0, 46, 46 |
| `icons.bld.turtow` | 276, 92, 46, 46 |
| `icons.bld.wga` | 886, 184, 46, 46 |
| `icons.bld.wwa` | 138, 92, 46, 46 |
| `icons.control.artillerypreparation` | 794, 138, 46, 46 |
| `icons.control.columnformation` | 932, 92, 46, 46 |
| `icons.control.decreaseformationsize` | 840, 138, 46, 46 |
| `icons.control.disableattack` | 886, 92, 46, 46 |
| `icons.control.dismissformation` | 840, 0, 46, 46 |
| `icons.control.enableattack` | 840, 92, 46, 46 |
| `icons.control.ferryunloadall` | 978, 184, 46, 46 |
| `icons.control.fillformation` | 886, 0, 46, 46 |
| `icons.control.frame.active.1` | 46, 138, 46, 46 |
| `icons.control.frame.active.2` | 92, 138, 46, 46 |
| `icons.control.frame.active.3` | 138, 138, 46, 46 |
| `icons.control.freeposition` | 840, 46, 46, 46 |
| `icons.control.gateclose` | 886, 184, 46, 46 |
| `icons.control.gateopen` | 840, 184, 46, 46 |
| `icons.control.gowithattack` | 794, 92, 46, 46 |
| `icons.control.groupformations` | 932, 0, 46, 46 |
| `icons.control.guard` | 794, 46, 46, 46 |
| `icons.control.hideobjectives` | 932, 230, 46, 46 |
| `icons.control.holdposition` | 886, 46, 46, 46 |
| `icons.control.idlemines` | 978, 46, 46, 46 |
| `icons.control.idlepeasants` | 978, 0, 46, 46 |
| `icons.control.increaseformationsize` | 886, 138, 46, 46 |
| `icons.control.lineformation` | 932, 46, 46, 46 |
| `icons.control.patrol` | 794, 0, 46, 46 |
| `icons.control.rallypoint` | 978, 92, 46, 46 |
| `icons.control.showobjectives` | 978, 230, 46, 46 |
| `icons.control.squareformation` | 932, 138, 46, 46 |
| `icons.defence.0` | 0, 487, 23, 24 |
| `icons.defence.1` | 26, 461, 24, 24 |
| `icons.defence.2` | 0, 461, 24, 24 |
| `icons.defence.3` | 78, 461, 24, 24 |
| `icons.defence.4` | 130, 461, 24, 24 |
| `icons.defence.5` | 52, 461, 24, 24 |
| `icons.defence.6` | 156, 461, 24, 24 |
| `icons.defence.7` | 104, 461, 24, 24 |
| `icons.defence.8` | 104, 461, 24, 24 |
| `icons.defence.9` | 211, 487, 24, 24 |
| `icons.empty` | 368, 46, 46, 46 |
| `icons.kills` | 237, 487, 25, 24 |
| `icons.nofarm` | 264, 460, 53, 52 |
| `icons.num.big.1` | 318, 481, 5, 11 |
| `icons.num.big.2` | 328, 481, 9, 11 |
| `icons.num.big.3` | 341, 481, 14, 11 |
| `icons.num.big.4` | 359, 481, 14, 11 |
| `icons.num.big.5` | 377, 481, 10, 11 |
| `icons.num.big.6` | 391, 481, 13, 11 |
| `icons.num.big.7` | 408, 481, 17, 11 |
| `icons.num.small.1` | 318, 496, 5, 9 |
| `icons.num.small.2` | 327, 496, 9, 9 |
| `icons.num.small.3` | 340, 496, 13, 9 |
| `icons.num.small.4` | 357, 496, 13, 9 |
| `icons.num.small.5` | 373, 496, 10, 9 |
| `icons.num.small.6` | 386, 496, 13, 9 |
| `icons.num.small.7` | 403, 496, 16, 9 |
| `icons.progress.background` | 187, 173, 40, 4 |
| `icons.progress.frame` | 186, 178, 42, 6 |
| `icons.progress.meter` | 187, 168, 40, 4 |
| `icons.res.1` | 0, 414, 46, 46 |
| `icons.res.2` | 46, 414, 46, 46 |
| `icons.res.3` | 92, 414, 46, 46 |
| `icons.res.4` | 138, 414, 46, 46 |
| `icons.res.5` | 184, 414, 46, 46 |
| `icons.res.6` | 230, 414, 46, 46 |
| `icons.unit.field` | 978, 138, 46, 46 |
| `icons.upg.%com%coa.%num%` | 414, 184, 46, 46 |
| `icons.upg.%com%gol.%num%` | 414, 184, 46, 46 |
| `icons.upg.%com%iro.%num%` | 414, 184, 46, 46 |
| `icons.upg.%com%mil.1` | 322, 184, 46, 46 |
| `icons.upg.%com%mil.2` | 368, 184, 46, 46 |
| `icons.upg.%com%swa.1` | 932, 184, 46, 46 |
| `icons.upg.%com%tow.%num%` | 0, 138, 46, 46 |
| `icons.upg.%com%wwa.1` | 932, 184, 46, 46 |
| `icons.upg.%member%.1.1` | 0, 184, 46, 46 |
| `icons.upg.%member%.1.2` | 46, 184, 46, 46 |
| `icons.upg.%member%.1.3` | 92, 184, 46, 46 |
| `icons.upg.%member%.1.4` | 138, 184, 46, 46 |
| `icons.upg.%member%.1.5` | 184, 184, 46, 46 |
| `icons.upg.%member%.1.6` | 230, 184, 46, 46 |
| `icons.upg.%member%.2.1` | 0, 230, 46, 46 |
| `icons.upg.%member%.2.2` | 46, 230, 46, 46 |
| `icons.upg.%member%.2.3` | 92, 230, 46, 46 |
| `icons.upg.%member%.2.4` | 138, 230, 46, 46 |
| `icons.upg.%member%.2.5` | 184, 230, 46, 46 |
| `icons.upg.%member%.2.6` | 230, 230, 46, 46 |
| `icons.upg.%nat%aca.1` | 0, 276, 46, 46 |
| `icons.upg.%nat%aca.10` | 138, 276, 46, 46 |
| `icons.upg.%nat%aca.11` | 138, 322, 46, 46 |
| `icons.upg.%nat%aca.12` | 138, 368, 46, 46 |
| `icons.upg.%nat%aca.13` | 184, 276, 46, 46 |
| `icons.upg.%nat%aca.14` | 184, 322, 46, 46 |
| `icons.upg.%nat%aca.15` | 184, 368, 46, 46 |
| `icons.upg.%nat%aca.16` | 230, 276, 46, 46 |
| `icons.upg.%nat%aca.17` | 230, 322, 46, 46 |
| `icons.upg.%nat%aca.18` | 230, 368, 46, 46 |
| `icons.upg.%nat%aca.19` | 276, 276, 46, 46 |
| `icons.upg.%nat%aca.2` | 0, 322, 46, 46 |
| `icons.upg.%nat%aca.20` | 276, 322, 46, 46 |
| `icons.upg.%nat%aca.21` | 276, 368, 46, 46 |
| `icons.upg.%nat%aca.22` | 322, 276, 46, 46 |
| `icons.upg.%nat%aca.23` | 322, 322, 46, 46 |
| `icons.upg.%nat%aca.24` | 322, 368, 46, 46 |
| `icons.upg.%nat%aca.25` | 368, 276, 46, 46 |
| `icons.upg.%nat%aca.26` | 368, 322, 46, 46 |
| `icons.upg.%nat%aca.27` | 368, 368, 46, 46 |
| `icons.upg.%nat%aca.28` | 414, 276, 46, 46 |
| `icons.upg.%nat%aca.29` | 414, 322, 46, 46 |
| `icons.upg.%nat%aca.3` | 0, 368, 46, 46 |
| `icons.upg.%nat%aca.30` | 414, 368, 46, 46 |
| `icons.upg.%nat%aca.31` | 460, 276, 46, 46 |
| `icons.upg.%nat%aca.32` | 460, 322, 46, 46 |
| `icons.upg.%nat%aca.33` | 460, 368, 46, 46 |
| `icons.upg.%nat%aca.34` | 506, 276, 46, 46 |
| `icons.upg.%nat%aca.35` | 506, 322, 46, 46 |
| `icons.upg.%nat%aca.36` | 506, 368, 46, 46 |
| `icons.upg.%nat%aca.4` | 46, 276, 46, 46 |
| `icons.upg.%nat%aca.5` | 46, 322, 46, 46 |
| `icons.upg.%nat%aca.6` | 46, 368, 46, 46 |
| `icons.upg.%nat%aca.7` | 92, 276, 46, 46 |
| `icons.upg.%nat%aca.8` | 92, 322, 46, 46 |
| `icons.upg.%nat%aca.9` | 92, 368, 46, 46 |
| `icons.upg.%nat%art.cannon.1.%num%` | 460, 184, 46, 46 |
| `icons.upg.%nat%art.cannon.2.%num%` | 506, 184, 46, 46 |
| `icons.upg.%nat%art.howitzer.1.%num%` | 460, 184, 46, 46 |
| `icons.upg.%nat%art.howitzer.2.%num%` | 506, 184, 46, 46 |
| `icons.upg.%nat%bla.1` | 552, 230, 46, 46 |
| `icons.upg.%nat%bla.1.old` | 276, 230, 46, 46 |
| `icons.upg.%nat%bla.2` | 322, 230, 46, 46 |
| `icons.upg.%nat%bla.3` | 368, 230, 46, 46 |
| `icons.upg.%nat%bla.4` | 414, 230, 46, 46 |
| `icons.upg.%nat%bla.5` | 460, 230, 46, 46 |
| `icons.upg.%nat%bla.6` | 552, 184, 46, 46 |
| `icons.upg.%nat%bla.6.old` | 506, 230, 46, 46 |
| `icons.upg.%nat%cen.1` | 276, 184, 46, 46 |
| `icons.upg.%nat%por.1` | 276, 368, 46, 46 |
| `icons.upg.eurpor.1` | 276, 368, 46, 46 |
| `icons.upgdon` | 552, 276, 33, 33 |
| `icons.weapon.0` | 51, 488, 24, 24 |
| `icons.weapon.1` | 51, 488, 24, 22 |
| `icons.weapon.2` | 25, 487, 24, 24 |
| `icons.weapon.3` | 77, 487, 24, 24 |
| `icons.weapon.4` | 155, 487, 25, 24 |
| `icons.weapon.5` | 103, 488, 23, 22 |
| `icons.weapon.6` | 182, 487, 28, 24 |
| `icons.weapon.7` | 129, 487, 24, 24 |
| `icons.weapon.8` | 129, 487, 24, 24 |
| `icons.weapon.9` | 211, 487, 24, 24 |
| `sign.infinity` | 430, 498, 20, 10 |

## iconsold — 34 материал(ов)

`data/hud/textures/ui/iconsold.bmp` — 512x512, 32 бит, 1.0 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `icons.market.accept` | 166, 172, 40, 40 |
| `icons.market.clear` | 166, 213, 40, 40 |
| `icons.market.num.-10` | 1, 172, 40, 40 |
| `icons.market.num.-100` | 1, 213, 40, 40 |
| `icons.market.num.-1000` | 83, 172, 40, 40 |
| `icons.market.num.-10000` | 83, 213, 40, 40 |
| `icons.market.num.10` | 42, 172, 40, 40 |
| `icons.market.num.100` | 42, 213, 40, 40 |
| `icons.market.num.1000` | 125, 172, 40, 40 |
| `icons.market.num.10000` | 125, 213, 40, 40 |
| `icons.upg.eurtow.%num%` | 1, 272, 39, 39 |
| `icons.upg.ferry.1` | 121, 272, 39, 39 |
| `icons.upg.rustow.%num%` | 41, 272, 39, 39 |
| `icons.upg.turtow.%num%` | 81, 272, 39, 39 |
| `tmp.icons.defence.0` | 1, 152, 19, 19 |
| `tmp.icons.defence.1` | 21, 152, 19, 19 |
| `tmp.icons.defence.2` | 41, 152, 19, 19 |
| `tmp.icons.defence.3` | 61, 152, 19, 19 |
| `tmp.icons.defence.4` | 81, 152, 19, 19 |
| `tmp.icons.defence.5` | 101, 152, 19, 19 |
| `tmp.icons.defence.6` | 121, 152, 19, 19 |
| `tmp.icons.defence.7` | 141, 152, 19, 19 |
| `tmp.icons.defence.8` | 161, 152, 19, 19 |
| `tmp.icons.defence.9` | 181, 152, 19, 19 |
| `tmp.icons.weapon.0` | 1, 132, 19, 19 |
| `tmp.icons.weapon.1` | 21, 132, 19, 19 |
| `tmp.icons.weapon.2` | 41, 132, 19, 19 |
| `tmp.icons.weapon.3` | 61, 132, 19, 19 |
| `tmp.icons.weapon.4` | 81, 132, 19, 19 |
| `tmp.icons.weapon.5` | 101, 132, 19, 19 |
| `tmp.icons.weapon.6` | 121, 132, 19, 19 |
| `tmp.icons.weapon.7` | 141, 132, 19, 19 |
| `tmp.icons.weapon.8` | 161, 132, 19, 19 |
| `tmp.icons.weapon.9` | 181, 132, 19, 19 |

## iconsunits — 125 материал(ов)

`data/hud/textures/ui/iconsunits.bmp` — 1024x512, 24 бит, 1.5 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `icons.unit.archer` | 322, 92, 46, 46 |
| `icons.unit.archerdip` | 92, 414, 46, 46 |
| `icons.unit.archersco` | 460, 92, 46, 46 |
| `icons.unit.archerscodip` | 368, 414, 46, 46 |
| `icons.unit.archertur` | 368, 92, 46, 46 |
| `icons.unit.archerturdip` | 322, 414, 46, 46 |
| `icons.unit.bagpiper` | 322, 184, 46, 46 |
| `icons.unit.battleship` | 322, 460, 46, 46 |
| `icons.unit.cannon` | 138, 230, 46, 46 |
| `icons.unit.chaika` | 368, 460, 46, 46 |
| `icons.unit.chasseur` | 92, 138, 46, 46 |
| `icons.unit.cossackdon` | 138, 322, 46, 46 |
| `icons.unit.cossackregister` | 230, 322, 46, 46 |
| `icons.unit.cossacksich` | 92, 276, 46, 46 |
| `icons.unit.cossacksichdip` | 184, 414, 46, 46 |
| `icons.unit.croat` | 0, 276, 46, 46 |
| `icons.unit.cuirassier` | 414, 322, 46, 46 |
| `icons.unit.dragoon` | 0, 368, 46, 46 |
| `icons.unit.dragoon18` | 138, 368, 46, 46 |
| `icons.unit.dragoon18dip` | 230, 414, 46, 46 |
| `icons.unit.dragoon18fra` | 184, 368, 46, 46 |
| `icons.unit.dragoon18net` | 368, 368, 46, 46 |
| `icons.unit.dragoon18pie` | 414, 368, 46, 46 |
| `icons.unit.dragoonpol` | 322, 368, 46, 46 |
| `icons.unit.drummer` | 184, 184, 46, 46 |
| `icons.unit.drummer18` | 368, 184, 46, 46 |
| `icons.unit.drummerrus` | 230, 184, 46, 46 |
| `icons.unit.drummertur` | 276, 184, 46, 46 |
| `icons.unit.empty` | 460, 0, 46, 46 |
| `icons.unit.ferry` | 46, 460, 46, 46 |
| `icons.unit.fishboat` | 0, 460, 46, 46 |
| `icons.unit.framegun` | 414, 460, 46, 46 |
| `icons.unit.frigate` | 230, 460, 46, 46 |
| `icons.unit.galley` | 92, 460, 46, 46 |
| `icons.unit.gauduk` | 506, 92, 46, 46 |
| `icons.unit.grenadier` | 184, 138, 46, 46 |
| `icons.unit.grenadierbav` | 414, 46, 46, 46 |
| `icons.unit.grenadierden` | 322, 138, 46, 46 |
| `icons.unit.grenadierdip` | 138, 414, 46, 46 |
| `icons.unit.grenadierhun` | 598, 138, 46, 46 |
| `icons.unit.grenadierpru` | 460, 138, 46, 46 |
| `icons.unit.grenadiersax` | 414, 138, 46, 46 |
| `icons.unit.guardcavalrysax` | 460, 322, 46, 46 |
| `icons.unit.hackapell` | 230, 276, 46, 46 |
| `icons.unit.hetman` | 276, 322, 46, 46 |
| `icons.unit.highlander` | 138, 138, 46, 46 |
| `icons.unit.howitzer` | 184, 230, 46, 46 |
| `icons.unit.hussar` | 138, 276, 46, 46 |
| `icons.unit.hussarhun` | 368, 276, 46, 46 |
| `icons.unit.hussarpru` | 184, 276, 46, 46 |
| `icons.unit.hussarswi` | 414, 276, 46, 46 |
| `icons.unit.jagerpor` | 506, 138, 46, 46 |
| `icons.unit.jagerswi` | 644, 138, 46, 46 |
| `icons.unit.jannisary` | 276, 92, 46, 46 |
| `icons.unit.kingmusketeer` | 46, 368, 46, 46 |
| `icons.unit.lancersco` | 322, 276, 46, 46 |
| `icons.unit.lightcavalry` | 276, 368, 46, 46 |
| `icons.unit.lightcavalry.nocolor` | 230, 368, 46, 46 |
| `icons.unit.lightcavalrydip` | 276, 414, 46, 46 |
| `icons.unit.lightinfantry` | 230, 46, 46, 46 |
| `icons.unit.lightinfantrydip` | 0, 414, 46, 46 |
| `icons.unit.mameluke` | 368, 322, 46, 46 |
| `icons.unit.misdonkey` | 322, 230, 46, 46 |
| `icons.unit.misflagman` | 368, 230, 46, 46 |
| `icons.unit.misgeneral` | 414, 230, 46, 46 |
| `icons.unit.mistrader` | 460, 230, 46, 46 |
| `icons.unit.mortar` | 230, 230, 46, 46 |
| `icons.unit.mullah` | 92, 230, 46, 46 |
| `icons.unit.multicannon` | 276, 230, 46, 46 |
| `icons.unit.musketeer` | 0, 92, 46, 46 |
| `icons.unit.musketeer18` | 0, 138, 46, 46 |
| `icons.unit.musketeer18bav` | 368, 46, 46, 46 |
| `icons.unit.musketeer18den` | 276, 138, 46, 46 |
| `icons.unit.musketeer18pru` | 230, 138, 46, 46 |
| `icons.unit.musketeer18sax` | 368, 138, 46, 46 |
| `icons.unit.musketeeraus` | 138, 92, 46, 46 |
| `icons.unit.musketeernet` | 414, 92, 46, 46 |
| `icons.unit.musketeerpol` | 46, 92, 46, 46 |
| `icons.unit.musketeersco` | 460, 46, 46, 46 |
| `icons.unit.musketeerspa` | 184, 92, 46, 46 |
| `icons.unit.officer` | 0, 184, 46, 46 |
| `icons.unit.officer18` | 138, 184, 46, 46 |
| `icons.unit.officerrus` | 46, 184, 46, 46 |
| `icons.unit.officersco` | 414, 184, 46, 46 |
| `icons.unit.officertur` | 92, 184, 46, 46 |
| `icons.unit.padre` | 506, 230, 46, 46 |
| `icons.unit.pandur` | 46, 138, 46, 46 |
| `icons.unit.pandurhun` | 552, 138, 46, 46 |
| `icons.unit.peaaus` | 0, 0, 46, 46 |
| `icons.unit.peaeng` | 46, 0, 46, 46 |
| `icons.unit.peapol` | 230, 0, 46, 46 |
| `icons.unit.pearus` | 138, 0, 46, 46 |
| `icons.unit.peasco` | 322, 0, 46, 46 |
| `icons.unit.peaspa` | 92, 0, 46, 46 |
| `icons.unit.peatur` | 276, 0, 46, 46 |
| `icons.unit.peaukr` | 184, 0, 46, 46 |
| `icons.unit.pikeman` | 0, 46, 46, 46 |
| `icons.unit.pikeman18` | 276, 46, 46, 46 |
| `icons.unit.pikeman18swe` | 322, 46, 46, 46 |
| `icons.unit.pikemanpol` | 46, 46, 46, 46 |
| `icons.unit.pikemanpor` | 552, 46, 46, 46 |
| `icons.unit.pikemanrus` | 92, 46, 46, 46 |
| `icons.unit.pikemansco` | 414, 414, 46, 46 |
| `icons.unit.pikemanspa` | 506, 46, 46, 46 |
| `icons.unit.pikemanswi` | 598, 46, 46, 46 |
| `icons.unit.pikemantur` | 138, 46, 46, 46 |
| `icons.unit.pope` | 46, 230, 46, 46 |
| `icons.unit.priest` | 0, 230, 46, 46 |
| `icons.unit.raidersco` | 276, 276, 46, 46 |
| `icons.unit.reiter` | 0, 322, 46, 46 |
| `icons.unit.reiterpol` | 184, 322, 46, 46 |
| `icons.unit.reiterswe` | 46, 322, 46, 46 |
| `icons.unit.roundshier` | 184, 46, 46, 46 |
| `icons.unit.roundshierdip` | 46, 414, 46, 46 |
| `icons.unit.serdiuk` | 230, 92, 46, 46 |
| `icons.unit.sipahi` | 506, 322, 46, 46 |
| `icons.unit.spakh` | 322, 322, 46, 46 |
| `icons.unit.strelet` | 92, 92, 46, 46 |
| `icons.unit.swordsmansco` | 460, 414, 46, 46 |
| `icons.unit.tatar` | 92, 368, 46, 46 |
| `icons.unit.vityaz` | 92, 322, 46, 46 |
| `icons.unit.wingedhussar` | 46, 276, 46, 46 |
| `icons.unit.xebec` | 276, 460, 46, 46 |
| `icons.unit.yacht` | 138, 460, 46, 46 |
| `icons.unit.yachttur` | 184, 460, 46, 46 |

## load01 — 3 материал(ов)

`data/hud/textures/ui/load01.bmp` — 256x256, 24 бит, 0.2 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `loading.1` | 0, 0, 256, 70 |
| `loading.2` | 0, 70, 256, 70 |
| `loading.3` | 0, 141, 256, 70 |

## logo_small — 1 материал(ов)

`data/hud/textures/ui/logo_small.bmp` — 512x256, 32 бит, 0.5 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `logo_small` | 0, 0, 468, 193 |

## mainmenu_art — 1 материал(ов)

`data/hud/textures/ui/mainmenu_art.bmp` — 2048x1024, 24 бит, 6.0 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `mainmenu_art` | 0, 0, 1674, 1024 |

## progressbar1 — 1 материал(ов)

`data/hud/textures/ui/progressbar1.bmp` — 2048x1024, 24 бит, 6.0 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `progressbar1` | 0, 0, 1920, 1024 |

## progressbar2 — 1 материал(ов)

`data/hud/textures/ui/progressbar2.bmp` — 2048x1024, 24 бит, 6.0 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `progressbar2` | 0, 0, 1920, 1024 |

## progressbar3 — 1 материал(ов)

`data/hud/textures/ui/progressbar3.bmp` — 2048x1024, 24 бит, 6.0 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `progressbar3` | 0, 0, 1920, 1024 |

## progressbar4 — 1 материал(ов)

`data/hud/textures/ui/progressbar4.bmp` — 2048x1024, 24 бит, 6.0 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `progressbar4` | 0, 0, 1920, 1024 |

## progressbar5 — 1 материал(ов)

`data/hud/textures/ui/progressbar5.bmp` — 2048x1024, 24 бит, 6.0 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `progressbar5` | 0, 0, 1920, 1024 |

## progressbar6 — 1 материал(ов)

`data/hud/textures/ui/progressbar6.bmp` — 2048x1024, 24 бит, 6.0 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `progressbar6` | 0, 0, 1920, 1024 |

## progressbar7 — 1 материал(ов)

`data/hud/textures/ui/progressbar7.bmp` — 2048x1024, 24 бит, 6.0 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `progressbar7` | 0, 0, 1920, 1024 |

## progressbar8 — 1 материал(ов)

`data/hud/textures/ui/progressbar8.bmp` — 2048x1024, 24 бит, 6.0 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `progressbar8` | 0, 0, 1920, 1024 |

## tex01 — 5 материал(ов)

`data/hud/textures/ui/tex01.bmp` — 256x256, 24 бит, 0.2 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `pbar.dragon` | 1, 1306, 772, 182 |
| `pbar.progress` | 253, 257, 92, 92 |
| `pbar.progress.background` | 1, 1489, 772, 171 |
| `pbar.progress.flip` | 346, 257, 92, 92 |
| `pbar.progress.flip.highlight` | 439, 257, 92, 92 |

## tex02 — 75 материал(ов)

`data/hud/textures/ui/tex02.bmp` — 1024x1024, 32 бит, 4.0 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `btn.rectangle.close.checked` | 661, 113, 34, 27 |
| `btn.rectangle.close.disabled` | 661, 85, 34, 27 |
| `btn.rectangle.close.hover` | 661, 29, 34, 27 |
| `btn.rectangle.close.normal` | 661, 1, 34, 27 |
| `btn.rectangle.close.pressed` | 661, 57, 34, 27 |
| `btn.rectangle.menu.checked` | 521, 113, 34, 27 |
| `btn.rectangle.menu.disabled` | 521, 85, 34, 27 |
| `btn.rectangle.menu.hover` | 521, 29, 34, 27 |
| `btn.rectangle.menu.normal` | 521, 1, 34, 27 |
| `btn.rectangle.menu.pressed` | 521, 57, 34, 27 |
| `btn.rectangle.minimize.checked` | 556, 113, 34, 27 |
| `btn.rectangle.minimize.disabled` | 556, 85, 34, 27 |
| `btn.rectangle.minimize.hover` | 556, 29, 34, 27 |
| `btn.rectangle.minimize.normal` | 556, 1, 34, 27 |
| `btn.rectangle.minimize.pressed` | 556, 57, 34, 27 |
| `btn.rectangle.rolldown.checked` | 626, 113, 34, 27 |
| `btn.rectangle.rolldown.disabled` | 626, 85, 34, 27 |
| `btn.rectangle.rolldown.hover` | 626, 29, 34, 27 |
| `btn.rectangle.rolldown.normal` | 626, 1, 34, 27 |
| `btn.rectangle.rolldown.pressed` | 626, 57, 34, 27 |
| `btn.rectangle.rollup.checked` | 591, 113, 34, 27 |
| `btn.rectangle.rollup.disabled` | 591, 85, 34, 27 |
| `btn.rectangle.rollup.hover` | 591, 29, 34, 27 |
| `btn.rectangle.rollup.normal` | 591, 1, 34, 27 |
| `btn.rectangle.rollup.pressed` | 591, 57, 34, 27 |
| `btn.rectangle.settings.checked` | 486, 113, 34, 27 |
| `btn.rectangle.settings.disabled` | 486, 85, 34, 27 |
| `btn.rectangle.settings.hover` | 486, 29, 34, 27 |
| `btn.rectangle.settings.normal` | 486, 1, 34, 27 |
| `btn.rectangle.settings.pressed` | 486, 57, 34, 27 |
| `combobox.list.background` | 420, 145, 248, 19 |
| `combobox.list.corner_lb` | 416, 164, 4, 4 |
| `combobox.list.corner_lt` | 416, 141, 4, 4 |
| `combobox.list.corner_rb` | 668, 164, 4, 4 |
| `combobox.list.corner_rt` | 668, 141, 4, 4 |
| `combobox.list.hover` | 416, 169, 256, 29 |
| `combobox.list.selected` | 416, 199, 256, 29 |
| `misc.color.black` | 940, 1, 40, 40 |
| `misc.color.blue` | 897, 87, 40, 40 |
| `misc.color.bluelight` | 897, 130, 40, 40 |
| `misc.color.green` | 897, 1, 40, 40 |
| `misc.color.greendark` | 940, 130, 40, 40 |
| `misc.color.grey` | 940, 87, 40, 40 |
| `misc.color.grey25` | 897, 172, 40, 40 |
| `misc.color.grey37` | 940, 172, 40, 40 |
| `misc.color.grey50` | 983, 172, 40, 40 |
| `misc.color.orange` | 940, 44, 40, 40 |
| `misc.color.orangelight` | 897, 44, 40, 40 |
| `misc.color.red` | 983, 1, 40, 40 |
| `misc.color.reddark` | 983, 130, 40, 40 |
| `misc.color.white` | 983, 87, 40, 40 |
| `misc.color.yellow` | 983, 44, 40, 40 |
| `old.combobox.btn` | 488, 229, 8, 6 |
| `old.combobox.btn.divider` | 673, 145, 1, 19 |
| `old.combobox.left` | 416, 141, 3, 27 |
| `old.combobox.list.bottom` | 420, 164, 248, 4 |
| `old.combobox.list.left` | 416, 145, 4, 19 |
| `old.combobox.list.right` | 668, 145, 4, 19 |
| `old.combobox.list.top` | 420, 141, 248, 4 |
| `old.combobox.middle` | 419, 141, 250, 27 |
| `old.combobox.right` | 669, 141, 3, 27 |
| `old.scroller` | 435, 229, 14, 18 |
| `old.scroller.down` | 450, 229, 18, 19 |
| `old.scroller.tile` | 1005, 223, 18, 800 |
| `old.scroller.up` | 416, 229, 18, 19 |
| `tex02.tooltip.background` | 0, 1024, 128, 1024 |
| `tex02.tooltip.bottom` | 168, 10, 128, 8 |
| `tex02.tooltip.corner_lb` | 150, 11, 8, 8 |
| `tex02.tooltip.corner_lt` | 150, 1, 8, 8 |
| `tex02.tooltip.corner_rb` | 159, 11, 8, 8 |
| `tex02.tooltip.corner_rt` | 159, 1, 8, 8 |
| `tex02.tooltip.left` | 141, 1024, 8, 1024 |
| `tex02.tooltip.right` | 132, 1024, 8, 1024 |
| `tex02.tooltip.top` | 168, 1, 128, 8 |
| `tex02.tooltip.vertline` | 132096, 1024, 2, 1024 |

## tex03 — 21 материал(ов)

`data/hud/textures/ui/tex03.bmp` — 2048x512, 32 бит, 4.0 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `btn.56x56.frame` | 0, 763, 56, 56 |
| `btn.56x56.highlight` | 51, 712, 50, 50 |
| `btn.56x56.placer` | 57, 763, 56, 56 |
| `btn.menu.disabled` | 1563, 306, 204, 41 |
| `btn.menu.hover` | 1563, 222, 204, 41 |
| `btn.menu.normal` | 1563, 180, 204, 41 |
| `btn.menu.pressed` | 1563, 264, 204, 41 |
| `controlpanel.buttons.background` | 212, 820, 730, 204 |
| `controlpanel.buttons.background.rightborder` | 943, 820, 34, 204 |
| `controlpanel.info.background` | 0, 820, 213, 204 |
| `minimap.background` | 1768, 179, 280, 279 |
| `resourcepanel.background` | 386, 183, 1159, 58 |
| `unitpanel.bottomframe` | 0, 163, 1872, 15 |
| `unitpanel.leftbackground` | 0, 27, 209, 142 |
| `unitpanel.rightbackground` | 209, 27, 1663, 142 |
| `unitpanel.rightframe` | 1873, 18, 35, 160 |
| `unitpanel.rightframe.shadow` | 1908, 0, 9, 178 |
| `unitpanel.rightframe.topshadow` | 1898, 0, 10, 18 |
| `unitpanel.topframe` | 0, 18, 1872, 15 |
| `unitpanel.topframe.shadow` | 0, 0, 1872, 18 |
| `unitpanel.unitname.background` | 0, 178, 380, 39 |

## tex04 — 56 материал(ов)

`data/hud/textures/ui/tex04.bmp` — 1024x1024, 32 бит, 4.0 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `btn.down.normal` | 32, 769, 31, 31 |
| `btn.down2.normal` | 64, 769, 31, 31 |
| `btn.up.normal` | 0, 769, 31, 31 |
| `btn.up2.normal` | 96, 769, 31, 31 |
| `frame.background` | 512, 0, 512, 512 |
| `frame.bottom` | 46, 7, 256, 6 |
| `frame.corner_lb` | 144, 75, 6, 6 |
| `frame.corner_lb.cross` | 46, 63, 48, 48 |
| `frame.corner_lb.decor` | 144, 41, 39, 26 |
| `frame.corner_lt` | 144, 68, 6, 6 |
| `frame.corner_lt.cross` | 46, 14, 48, 48 |
| `frame.corner_lt.decor` | 144, 14, 39, 26 |
| `frame.corner_rb` | 151, 75, 6, 6 |
| `frame.corner_rb.cross` | 95, 63, 48, 48 |
| `frame.corner_rb.decor` | 184, 41, 39, 26 |
| `frame.corner_rt` | 151, 68, 6, 6 |
| `frame.corner_rt.cross` | 95, 14, 48, 48 |
| `frame.corner_rt.decor` | 184, 14, 39, 26 |
| `frame.left` | 32, 0, 6, 256 |
| `frame.right` | 39, 0, 6, 256 |
| `frame.top` | 46, 0, 256, 6 |
| `line.21.checked` | 0, 591, 1024, 21 |
| `line.21.disabled` | 0, 635, 1024, 21 |
| `line.21.hover` | 0, 591, 1024, 21 |
| `line.21.normal` | 0, 569, 1024, 21 |
| `line.21.pressed` | 0, 613, 1024, 21 |
| `line.27.checked` | 0, 685, 1024, 27 |
| `line.27.disabled` | 0, 741, 1024, 27 |
| `line.27.hover` | 0, 685, 1024, 27 |
| `line.27.normal` | 0, 657, 1024, 27 |
| `line.27.pressed` | 0, 713, 1024, 27 |
| `line.31.checked` | 0, 929, 1024, 31 |
| `line.31.disabled` | 0, 993, 1024, 31 |
| `line.31.hover` | 0, 929, 1024, 31 |
| `line.31.left.checked` | 223, 801, 5, 31 |
| `line.31.left.disabled` | 223, 865, 5, 31 |
| `line.31.left.hover` | 223, 801, 5, 31 |
| `line.31.left.normal` | 223, 769, 5, 31 |
| `line.31.left.pressed` | 223, 833, 5, 31 |
| `line.31.normal` | 0, 897, 1024, 31 |
| `line.31.pressed` | 0, 961, 1024, 31 |
| `line.31.right.checked` | 229, 801, 5, 31 |
| `line.31.right.disabled` | 229, 865, 5, 31 |
| `line.31.right.hover` | 229, 801, 5, 31 |
| `line.31.right.normal` | 229, 769, 5, 31 |
| `line.31.right.pressed` | 229, 833, 5, 31 |
| `old.combobox.btn` | 0, 148, 31, 31 |
| `old.combobox.btn.up` | 0, 180, 31, 31 |
| `old.combobox.left` | 303, 112, 2, 31 |
| `old.combobox.middle` | 46, 112, 256, 31 |
| `old.combobox.right` | 306, 112, 2, 31 |
| `old.scroller` | 0, 32, 31, 41 |
| `old.scroller.down` | 0, 116, 31, 31 |
| `old.scroller.newbad` | 329, 843, 31, 53 |
| `old.scroller.tile` | 0, 74, 31, 41 |
| `old.scroller.up` | 0, 0, 31, 31 |

## tex05 — 171 материал(ов)

`data/hud/textures/ui/tex05.bmp` — 2048x2048, 32 бит, 16.0 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `alliance.limiter` | 2042, 1, 5, 390 |
| `btn.acceptalliance.disabled` | 1839, 673, 24, 23 |
| `btn.acceptalliance.hover` | 1839, 673, 24, 23 |
| `btn.acceptalliance.normal` | 1839, 673, 24, 23 |
| `btn.acceptalliance.pressed` | 1839, 673, 24, 23 |
| `btn.breakalliance.disabled` | 1864, 664, 32, 31 |
| `btn.breakalliance.hover` | 1864, 664, 32, 31 |
| `btn.breakalliance.normal` | 1864, 664, 32, 31 |
| `btn.breakalliance.pressed` | 1864, 664, 32, 31 |
| `btn.cancelalliance.disabled` | 1814, 673, 24, 23 |
| `btn.cancelalliance.hover` | 1814, 673, 24, 23 |
| `btn.cancelalliance.normal` | 1814, 673, 24, 23 |
| `btn.cancelalliance.pressed` | 1814, 673, 24, 23 |
| `btn.close.disabled` | 1494, 114, 54, 28 |
| `btn.close.hover` | 1494, 56, 54, 28 |
| `btn.close.normal` | 1494, 27, 54, 28 |
| `btn.close.pressed` | 1494, 85, 54, 28 |
| `btn.expand.disabled` | 1940, 389, 54, 28 |
| `btn.expand.hover` | 1940, 331, 54, 28 |
| `btn.expand.normal` | 1940, 302, 54, 28 |
| `btn.expand.pressed` | 1940, 360, 54, 28 |
| `btn.faq.disabled` | 1986, 846, 30, 30 |
| `btn.faq.hover` | 1986, 816, 30, 30 |
| `btn.faq.normal` | 1986, 786, 30, 30 |
| `btn.faq.pressed` | 1986, 846, 30, 30 |
| `btn.fb.disabled` | 2017, 755, 31, 30 |
| `btn.fb.hover` | 2017, 693, 31, 30 |
| `btn.fb.normal` | 2017, 662, 31, 30 |
| `btn.fb.pressed` | 2017, 724, 31, 30 |
| `btn.hideassist.disabled` | 2018, 611, 24, 47 |
| `btn.hideassist.hover` | 1964, 611, 24, 47 |
| `btn.hideassist.normal` | 1937, 611, 24, 47 |
| `btn.hideassist.pressed` | 1991, 611, 24, 47 |
| `btn.large.checked` | 1496, 353, 235, 51 |
| `btn.large.disabled` | 1496, 455, 235, 51 |
| `btn.large.hover` | 1496, 353, 235, 51 |
| `btn.large.normal` | 1496, 302, 235, 51 |
| `btn.large.pressed` | 1496, 404, 235, 51 |
| `btn.medium.checked` | 1732, 347, 205, 45 |
| `btn.medium.disabled` | 1732, 437, 205, 45 |
| `btn.medium.hover` | 1732, 347, 205, 45 |
| `btn.medium.normal` | 1732, 302, 205, 45 |
| `btn.medium.pressed` | 1732, 392, 205, 45 |
| `btn.mini.checked` | 1779, 542, 151, 29 |
| `btn.mini.disabled` | 1779, 571, 151, 29 |
| `btn.mini.hover` | 1779, 513, 151, 29 |
| `btn.mini.normal` | 1779, 484, 151, 29 |
| `btn.mini.pressed` | 1779, 542, 151, 29 |
| `btn.nodecor.disabled` | 1780, 571, 149, 28 |
| `btn.nodecor.hover` | 1780, 513, 149, 28 |
| `btn.nodecor.normal` | 1780, 484, 149, 28 |
| `btn.nodecor.pressed` | 1780, 542, 149, 28 |
| `btn.proposealliance.disabled` | 1899, 664, 32, 31 |
| `btn.proposealliance.hover` | 1899, 664, 32, 31 |
| `btn.proposealliance.normal` | 1899, 664, 32, 31 |
| `btn.proposealliance.pressed` | 1899, 664, 32, 31 |
| `btn.showassist.disabled` | 1937, 562, 24, 47 |
| `btn.showassist.hover` | 1991, 562, 24, 47 |
| `btn.showassist.normal` | 2018, 562, 24, 47 |
| `btn.showassist.pressed` | 1964, 562, 24, 47 |
| `btn.small.checked` | 1596, 76, 177, 39 |
| `btn.small.disabled` | 1596, 154, 177, 39 |
| `btn.small.hover` | 1596, 76, 177, 39 |
| `btn.small.normal` | 1596, 37, 177, 39 |
| `btn.small.pressed` | 1596, 115, 177, 39 |
| `btn.steam.disabled` | 1955, 755, 31, 30 |
| `btn.steam.hover` | 1955, 693, 31, 30 |
| `btn.steam.normal` | 1955, 662, 31, 30 |
| `btn.steam.pressed` | 1955, 724, 31, 30 |
| `btn.unexpand.disabled` | 1940, 505, 54, 28 |
| `btn.unexpand.hover` | 1940, 447, 54, 28 |
| `btn.unexpand.normal` | 1940, 418, 54, 28 |
| `btn.unexpand.pressed` | 1940, 476, 54, 28 |
| `btn.vk.disabled` | 1986, 755, 31, 30 |
| `btn.vk.hover` | 1986, 693, 31, 30 |
| `btn.vk.normal` | 1986, 662, 31, 30 |
| `btn.vk.pressed` | 1986, 724, 31, 30 |
| `btn.waitingtosubmitaliance.disabled` | 1789, 673, 24, 23 |
| `btn.waitingtosubmitaliance.hover` | 1789, 673, 24, 23 |
| `btn.waitingtosubmitaliance.normal` | 1789, 673, 24, 23 |
| `btn.waitingtosubmitaliance.pressed` | 1789, 673, 24, 23 |
| `checkbox.checked` | 1994, 37, 22, 21 |
| `checkbox.disabled` | 1573, 79, 22, 21 |
| `checkbox.hover` | 1573, 37, 22, 21 |
| `checkbox.normal` | 1971, 37, 22, 21 |
| `checkbox.pressed` | 1573, 58, 22, 21 |
| `combobox.background.1` | 1794, 63, 222, 21 |
| `combobox.background.2` | 1794, 85, 222, 21 |
| `combobox.background.3` | 1794, 107, 222, 21 |
| `combobox.background.4` | 1794, 129, 222, 21 |
| `combobox.background.5` | 1794, 151, 222, 21 |
| `combobox.background.6` | 1794, 173, 222, 21 |
| `combobox.btn.disabled` | 1556, 10, 16, 16 |
| `combobox.btn.hover` | 1587, 10, 16, 16 |
| `combobox.btn.normal` | 1540, 10, 16, 16 |
| `combobox.btn.pressed` | 1572, 10, 16, 16 |
| `encyclopedia.faq` | 1960, 787, 25, 25 |
| `gsc.logo` | 966, 561, 262, 159 |
| `header.paper.large` | 1554, 207, 444, 93 |
| `inputbox.l` | 1605, 10, 104, 26 |
| `inputbox.m` | 1709, 10, 266, 26 |
| `inputbox.r` | 2000, 10, 18, 26 |
| `mainframe.background` | 0, 771, 1878, 1277 |
| `metalframe.bottom` | 1499, 5, 540, 3 |
| `metalframe.left` | 2044, 1, 4, 396 |
| `metalframe.right` | 2040, 1, 4, 396 |
| `metalframe.top` | 1499, 1, 540, 3 |
| `net.client.award.0` | 1523, 273, 24, 25 |
| `net.client.award.1` | 1525, 245, 20, 25 |
| `net.client.award.2` | 1522, 218, 25, 25 |
| `net.client.award.3` | 1524, 191, 20, 25 |
| `net.client.award.4` | 1523, 167, 22, 25 |
| `net.client.award.5` | 1522, 143, 25, 25 |
| `net.client.award.6` | 1552, 30, 14, 25 |
| `net.client.award.7` | 1552, 61, 15, 25 |
| `net.client.award.8` | 1553, 92, 13, 25 |
| `net.client.award.rank1` | 1751, 563, 24, 25 |
| `net.client.award.rank11.30` | 1639, 563, 24, 25 |
| `net.client.award.rank2` | 1723, 563, 24, 25 |
| `net.client.award.rank3` | 1695, 563, 24, 25 |
| `net.client.award.rank31.60` | 1611, 563, 24, 25 |
| `net.client.award.rank4.10` | 1667, 563, 24, 25 |
| `net.client.award.rank61.100` | 1583, 563, 24, 25 |
| `net.client.award.seasonclash.medal.1` | 1504, 563, 16, 25 |
| `net.client.award.seasonclash.medal.2` | 1486, 563, 16, 25 |
| `net.client.award.seasonclash.medal.3` | 1468, 563, 16, 25 |
| `net.client.award.seasonclash1` | 1562, 563, 18, 25 |
| `net.client.award.seasonclash2` | 1542, 563, 18, 25 |
| `net.client.award.seasonclash3` | 1522, 563, 18, 25 |
| `net.client.award.streamer.1` | 1441, 563, 24, 25 |
| `net.client.award.streamer.2` | 1415, 563, 24, 25 |
| `net.client.dlcs.exp1` | 1703, 533, 36, 21 |
| `net.client.mods.green` | 1549, 122, 25, 25 |
| `net.client.mods.red` | 1549, 148, 25, 25 |
| `net.client.rank.1` | 1494, 507, 25, 25 |
| `net.client.rank.10` | 1719, 507, 25, 25 |
| `net.client.rank.2` | 1519, 507, 25, 25 |
| `net.client.rank.3` | 1544, 507, 25, 25 |
| `net.client.rank.4` | 1569, 507, 25, 25 |
| `net.client.rank.5` | 1594, 507, 25, 25 |
| `net.client.rank.6` | 1619, 507, 25, 25 |
| `net.client.rank.7` | 1644, 507, 25, 25 |
| `net.client.rank.8` | 1669, 507, 25, 25 |
| `net.client.rank.9` | 1694, 507, 25, 25 |
| `net.client.state.master` | 1494, 169, 25, 25 |
| `net.client.state.mute` | 1494, 247, 25, 25 |
| `net.client.state.online` | 1494, 143, 25, 25 |
| `net.client.state.play` | 1494, 221, 25, 25 |
| `net.client.state.quickplaysearch` | 1494, 273, 25, 25 |
| `net.client.state.session` | 1494, 195, 25, 25 |
| `scroller.btn` | 2019, 11, 18, 29 |
| `scroller.btn.down` | 2017, 532, 22, 21 |
| `scroller.btn.up` | 2017, 41, 22, 21 |
| `scroller.tile` | 2018, 63, 21, 468 |
| `skin.background` | 747, 0, 746, 554 |
| `skin.bottom` | 64, 490, 618, 64 |
| `skin.corner_lb` | 0, 490, 64, 64 |
| `skin.corner_lt` | 0, 0, 64, 64 |
| `skin.corner_rb` | 682, 490, 64, 64 |
| `skin.corner_rt` | 682, 0, 64, 64 |
| `skin.header.l` | 0, 557, 942, 32 |
| `skin.header.r` | 942, 557, 19, 32 |
| `skin.left` | 0, 64, 64, 426 |
| `skin.right` | 682, 64, 64, 426 |
| `skin.top` | 64, 0, 618, 64 |
| `skinhead.large` | 0, 603, 941, 53 |
| `slider.btn.disabled` | 1999, 207, 16, 23 |
| `slider.btn.hover` | 1999, 207, 16, 23 |
| `slider.btn.normal` | 1999, 207, 16, 23 |
| `slider.btn.pressed` | 1999, 207, 16, 23 |
| `slider.line` | 1786, 199, 229, 7 |

## tex06 — 27 материал(ов)

`data/hud/textures/ui/tex06.bmp` — 2048x2048, 32 бит, 16.0 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `bambooframe.bottom` | 226, 2034, 646, 14 |
| `bambooframe.corner_lb` | 0, 1936, 112, 112 |
| `bambooframe.corner_lt` | 0, 1823, 112, 112 |
| `bambooframe.corner_rb` | 113, 1936, 112, 112 |
| `bambooframe.corner_rt` | 113, 1823, 112, 112 |
| `bambooframe.left` | 0, 1515, 15, 307 |
| `bambooframe.right` | 16, 1515, 15, 307 |
| `bambooframe.top` | 226, 2018, 646, 15 |
| `mainframe.bottom` | 0, 0, 1422, 230 |
| `mainframe.corner_lb` | 0, 824, 334, 360 |
| `mainframe.corner_lt` | 0, 463, 334, 360 |
| `mainframe.corner_rb` | 335, 824, 334, 360 |
| `mainframe.corner_rt` | 335, 463, 334, 360 |
| `mainframe.header` | 0, 1185, 546, 46 |
| `mainframe.left` | 670, 463, 230, 768 |
| `mainframe.right` | 901, 463, 231, 768 |
| `mainframe.top` | 0, 231, 1421, 231 |
| `paper.background` | 1009, 1264, 845, 593 |
| `paper.background.blick` | 1676, 0, 372, 367 |
| `paper.bottom` | 1009, 1954, 845, 94 |
| `paper.corner_lb` | 1856, 1365, 96, 92 |
| `paper.corner_lt` | 1856, 1269, 96, 95 |
| `paper.corner_rb` | 1953, 1365, 95, 92 |
| `paper.corner_rt` | 1953, 1269, 95, 95 |
| `paper.left` | 1855, 1458, 96, 590 |
| `paper.right` | 1952, 1458, 96, 586 |
| `paper.top` | 1009, 1857, 845, 96 |

## todo — 1 материал(ов)

`data/hud/textures/ui/todo.bmp` — 64x64, 32 бит, 0.0 МБ

| материал | кусок текстуры (x, y, ширина, высота) |
|---|---|
| `misc.todo` | 0, 0, 0, 0 |

