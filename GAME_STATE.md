# Состояние игры

Сгенерировано `tools/gen_game_api.py` из `data/scripts/lib/classes.script`. Не править руками.

Любое поле читается одинаково из Lua и из страниц:

```lua
state.get('gProfile.sndmaster')       -- 0.75
state.read('gMap.players[0]')          -- вся запись таблицей
state.set('gProfile.sndmaster', 0.5)   -- только сервер/консоль
G.gMap.settings.gen.mapsize            -- то же, через точку
```

## Глобальные переменные

- `WallDx8` — array[0..8] of int
- `WallDy8` — array[0..8] of int
- `WallGd8` — array[0..9] of int
- `gAIConst` — TAIConst
- `gAchLastUpgrades` — TIntegerList
- `gArcherGrid` — array[0..19] of array[0..19] of TArcherCell
- `gArmyInfoCells` — array[0..?] of array[0..?] of TArmyInfoCell
- `gChatMessages` — TChatMessages
- `gConst` — TConst
- `gConstScenarioMarkers` — array[0..?] of string
- `gCtrlGroups` — array[0..11] of array[0..9] of TIntegerList
- `gCustomBuildPointsWall` — array[0..23] of TCustomBuildPointsWall
- `gCustomObjPoints` — array[0..23] of array[0..79] of TCustomObjPoints
- `gDeathUnits` — TIntegerList
- `gDestructListBuilding` — TIntegerList
- `gDestructListShip` — TIntegerList
- `gDoRoundDamageList` — TIntegerList
- `gEmptyList` — TIntegerList
- `gEnemyInfoList` — TEnemyInfoList
- `gFonts` — array[0..31] of TFonts
- `gGOPathList` — TIntegerList
- `gGuiSelectionHelper` — TIntegerList
- `gGuiUpdateHighlights` — TIntegerList
- `gIdleGrid` — array[0..799] of array[0..799] of int
- `gIntListWriteSquadAction` — TIntegerList
- `gIntegerList` — TIntegerList
- `gInternetShell` — TInternetShell
- `gInternetShellTmp` — TInternetShell
- `gIslands` — TIslands
- `gKeyColor` — array[0..23] of array[0..2] of float
- `gLanSyncData` — TLanSyncData
- `gLanSyncDataLast` — TLanSyncData
- `gLanSyncUnitsParamsUIDList` — TIntegerList
- `gLogMessages` — TLogMessages
- `gMap` — TMap
- `gMapHistoricalBattle` — TMap
- `gMapMask` — array[0..639] of array[0..639] of TGeneratorBitmapMask
- `gObjProp` — array[0..23] of array[0..79] of TObjProp
- `gOrderUnitsList` — TIntegerList
- `gOrderUnitsListTmp` — TIntegerList
- `gPatternMask` — array[0..639] of array[0..639] of bool
- `gPlayer` — array[0..11] of TPlayer
- `gPrimitives` — TIntegerList
- `gProfile` — TProfile
- `gProfileTmp` — TProfile
- `gProfileUserStruct` — TProfileUserStruct
- `gProfileUserStructTmp` — TProfileUserStruct
- `gProgress` — TProgress
- `gProjSimulatePoints` — TProjSimulatePoints
- `gPtrList` — TPtrList
- `gQuickPlay` — TQuickPlayers
- `gQuickPlayHideIcon` — TIntegerList
- `gReconnectManager` — TReconnectManager
- `gRegionsList` — TIntegerList
- `gRepairSessionList` — TIntegerList
- `gResGrid` — array[0..?] of array[0..?] of TResGridList
- `gSVNVersion` — int
- `gScanGrid` — array[0..?] of array[0..?] of TGridList
- `gScanGridUnits` — array[0..11] of array[0..?] of array[0..?] of TIntegerList
- `gScenario` — TScenario
- `gScenarioTmp` — TScenario
- `gSelectedObjects` — TIntegerList
- `gSelectedSquads` — TPtrList
- `gSettings` — TSettings
- `gSettingsTmp` — TSettings
- `gShellSortOnline` — TIntegerList
- `gShellSortOnlineMarked` — TIntegerList
- `gShellSortPlay` — TIntegerList
- `gShellSortPlayMarked` — TIntegerList
- `gSoundGrid` — array[0..?] of array[0..?] of TSoundGrid
- `gSoundManager` — TSoundManager
- `gSyncRes` — TIntegerList
- `gTmpHotkeyArray` — array[0..63] of array[0..3] of string
- `gTmpIntList` — TIntegerList
- `gTmpIntListFillSquad` — TIntegerList
- `gTmpIntListFindUnits` — TIntegerList
- `gTmpIntListGUIDrummerList` — TIntegerList
- `gTmpIntListGUIInsideList` — TIntegerList
- `gTmpIntListGUISquadList` — TIntegerList
- `gTmpIntListGetBuildPoints` — TIntegerList
- `gTmpIntListLANSquadTimeList` — TIntegerList
- `gTmpIntListLANSquadUIDList` — TIntegerList
- `gTmpIntListMembers` — TIntegerList
- `gTmpIntListObjectsInRadius` — TIntegerList
- `gTmpIntListOnSelection` — TIntegerList
- `gTmpIntListUpgrades` — TIntegerList
- `gUIConst` — TUIConst
- `gUnderCursorList` — TIntegerList
- `gUpdateAreas` — array[0..499] of TRect
- `gWallCluster` — TWallCluster
- `gWallClusterCreate` — TWallCluster
- `gWallSystem` — TWallSystem
- `gWaterPathList` — TIntegerList
- `gWeapons` — array[0..255] of TWeapon
- `gWriteNewRequestList` — TPtrList
- `gWriteSquadPtrList` — TPtrList

## Типы

### TAIBuildingProject

| поле | тип |
|---|---|
| `cid` | int |
| `sid` | string |
| `id` | int |
| `used` | bool |
| `placefound` | bool |
| `founded` | bool |
| `peasantscalled` | bool |
| `usage` | int |
| `nearx` | float |
| `nearz` | float |
| `x` | float |
| `y` | float |
| `options` | int |
| `attemptstostand` | int |
| `attemptstofindapprplace` | int |
| `maxpeasants` | int |
| `minpeasants` | int |
| `npeasantscalled` | int |
| `gohnd` | int |
| `curRad` | int |
| `curInd` | int |
| `maxTryDist` | int |

### TAIConst

| поле | тип |
|---|---|
| `armyMinCount` | array[0..15] of int |
| `defArmyMinCount` | array[0..15] of int |
| `armyMaxCount` | array[0..15] of int |
| `maxDivers` | array[0..1] of int |

### TAch

| поле | тип |
|---|---|
| `achid` | int |
| `achsid` | string |
| `goal` | int |
| `cur` | int |
| `status` | int |
| `stringtag` | string |
| `bbitcoded` | bool |

### TAchs

| поле | тип |
|---|---|
| `binit` | bool |
| `ach` | array[0..255] of TAch |

### TAdviser

| поле | тип |
|---|---|
| `bvisible` | bool |
| `benable` | bool |
| `bavailable` | bool |
| `bconstruct` | bool |
| `beconomy` | bool |
| `beconomyadvanced` | bool |
| `bcontrolpeasants` | bool |
| `bproducepeasants` | bool |
| `brepairbuildings` | bool |
| `bfillmines` | bool |
| `bmarketadvises` | bool |
| `bmanualresource` | bool |
| `resonfood` | float |
| `resonwood` | float |
| `resonstone` | float |
| `bupgrades` | bool |
| `bupgradesunavailable` | bool |
| `bquartermaster` | bool |
| `bsetupguards` | bool |
| `bproduceofficers` | bool |
| `bshowsquads` | bool |
| `settings` | int |
| `version` | int |

### TAiData

| поле | тип |
|---|---|
| `basenation` | int |
| `bestprojects` | TIdeasList |
| `centerfound` | bool |
| `centerx` | float |
| `centerz` | float |
| `agressorssent` | int |
| `defencestage` | bool |
| `makediversion` | bool |
| `landbattle` | bool |
| `waterbattle` | bool |
| `controllednations` | array[0..23] of bool |
| `upgradeid` | array[0..23] of array[0..63] of int |
| `unitupg` | array[0..23] of array[0..319] of TUnitUpgrade |
| `uniqupg` | array[0..23] of TUniqUpgList |
| `developmentera` | array[0..23] of int |
| `mines` | TIntegerList |
| `orelist` | TIntegerList |
| `peasantlist` | TIntegerList |
| `freepeasant` | TIntegerList |
| `ailist` | TIntegerList |
| `buildingslist` | TIntegerList |
| `storelist` | TIntegerList |
| `milllist` | TIntegerList |
| `unbuildhouses` | TIntegerList |
| `defenders` | TIntegerList |
| `guards` | TIntegerList |
| `agressors` | TIntegerList |
| `freewarriors` | TIntegerList |
| `towers` | TIntegerList |
| `armylist` | TArmyList |
| `unitsamount` | array[0..23] of array[0..79] of int |
| `avUnits` | array[0..23] of array[0..79] of bool |
| `officer17` | array[0..23] of int |
| `drummer17` | array[0..23] of int |
| `officer18` | array[0..23] of int |
| `drummer18` | array[0..23] of int |
| `aiunit` | array[0..23] of array[0..79] of int |
| `buildlink` | array[0..23] of array[0..79] of int |
| `buildprojects` | array[0..11] of TAIBuildingProject |
| `resbalance` | array[0..6] of array[0..2] of int |
| `onFood` | int |
| `onStone` | int |
| `onWood` | int |
| `defbuildings` | TAiProtectedBuildingList |
| `bFlags` | array[0..10] of bool |
| `inittime` | float |
| `bhumanai` | bool |
| `bprogressEconomy` | bool |
| `bprogressConstruction` | bool |
| `bprogressProduce` | bool |
| `bprogressUpgrades` | bool |
| `bprogressWar` | bool |
| `damagedBuildings` | TIntegerList |
| `guardsCount` | int |
| `guardsTotal` | int |

### TAiIdea

| поле | тип |
|---|---|
| `cid` | int |
| `id` | int |
| `ideatype` | int |
| `count` | int |
| `airole` | int |

### TAiProtectedBuilding

| поле | тип |
|---|---|
| `targetHnd` | int |
| `aipriority` | int |
| `defenders` | TIntegerList |

### TAiProtectedBuildingList

| поле | тип |
|---|---|
| `fList` | TPtrList |

### TArcherCell

| поле | тип |
|---|---|
| `weight` | float |
| `trgHnd` | int |

### TArmy

| поле | тип |
|---|---|
| `fSquadList` | TPtrList |
| `fIndex` | int |
| `fPlIndex` | int |
| `fOffsetCol` | float |
| `fOffsetRow` | float |
| `fSpec` | int |
| `fTopZone` | int |
| `fCurTopZone` | int |
| `fSpecialOrder` | bool |
| `fOrder` | TArmyOrder |
| `fX` | float |
| `fZ` | float |
| `fCurX` | float |
| `fCurZ` | float |
| `fSquadsCurX` | float |
| `fSquadsCurZ` | float |
| `fTag` | int |
| `fForce` | int |
| `fLastBattleTime` | float |
| `fLastArtTime` | float |
| `fActive` | bool |
| `fRegion` | int |
| `fOnEnemyLand` | bool |

### TArmyInfo

| поле | тип |
|---|---|
| `infantry` | int |
| `shooters` | int |
| `cavalry` | int |
| `cannons` | int |
| `mortars` | int |
| `mcannons` | int |
| `towers` | int |
| `ships` | int |
| `force` | int |
| `landCount` | int |
| `waterCount` | int |
| `region` | int |
| `regions` | TIntegerList |
| `minx` | int |
| `maxx` | int |
| `miny` | int |
| `maxy` | int |

### TArmyInfoCell

| поле | тип |
|---|---|
| `infantry` | int |
| `shooters` | int |
| `cavalry` | int |
| `cannons` | int |
| `mortars` | int |
| `mcannons` | int |
| `towers` | int |
| `ships` | int |
| `force` | int |
| `army` | int |
| `tag` | int |
| `checked` | bool |
| `region` | int |
| `regions` | TIntegerList |

### TArmyInfoList

| поле | тип |
|---|---|
| `fList` | TPtrList |

### TArmyList

| поле | тип |
|---|---|
| `fList` | TPtrList |

### TArmyOrder

| поле | тип |
|---|---|
| `iType` | int |
| `targetUID` | int |
| `tag` | int |
| `tag2` | int |
| `tag3` | int |
| `tagFloat` | float |

### TBox

| поле | тип |
|---|---|
| `minx` | Float = 0 |
| `miny` | Float = 0 |
| `minz` | Float = 0 |
| `maxx` | Float = 0 |
| `maxy` | Float = 0 |
| `maxz` | Float = 0 |

### TCampaignProgress

| поле | тип |
|---|---|
| `bexists` | bool |
| `campname` | string |
| `missname` | string |
| `benabled` | bool |
| `bvisible` | bool |
| `started` | int |
| `finished` | int |
| `lose` | int |
| `maxfinishdifficulty` | int |
| `storestring` | string |

### TChar

| поле | тип |
|---|---|
| `text` | string |
| `width` | int |
| `offx` | int |
| `addwidth` | int |
| `addoffx` | int |

### TChatMessage

| поле | тип |
|---|---|
| `sfrom` | string |
| `sto` | string |
| `text` | string |
| `mode` | int |
| `time` | float |

### TChatMessages

| поле | тип |
|---|---|
| `count` | int |
| `msg` | array[0..63] of TChatMessage |

### TColor

| поле | тип |
|---|---|
| `r` | Float = 1 |
| `g` | Float = 1 |
| `b` | Float = 1 |
| `a` | Float = 1 |

### TConst

| поле | тип |
|---|---|
| `logmessage` | array[0..?] of string |

### TCustomBuildPointsWall

| поле | тип |
|---|---|
| `builderCount` | int |
| `builderPoints` | array[0..15] of TPos2f |

### TCustomObjAABB

| поле | тип |
|---|---|
| `buse` | bool |
| `minx` | float |
| `maxx` | float |
| `miny` | float |
| `maxy` | float |
| `minz` | float |
| `maxz` | float |

### TCustomObjDecal

| поле | тип |
|---|---|
| `bexists` | bool |
| `scale` | float |
| `offx` | float |
| `offz` | float |
| `angle` | float |

### TCustomObjPoints

| поле | тип |
|---|---|
| `builderCount` | int |
| `builderPoints` | array[0..29] of TPos2f |
| `exitCount` | int |
| `exitPoints` | array[0..3] of TPos3f |
| `shotCount` | int |
| `shotPoints` | array[0..39] of TCustomObjShotPoint |
| `smokeCount` | int |
| `smokePoints` | array[0..79] of TCustomObjSmokePoint |
| `resourcePoint` | TPos3f |
| `aabb` | TCustomObjAABB |
| `decal` | TCustomObjDecal |

### TCustomObjShotPoint

| поле | тип |
|---|---|
| `x` | float |
| `y` | float |
| `z` | float |
| `bcustomdir` | bool |
| `bcustomweaponind` | bool |
| `minangle` | float |
| `maxangle` | float |
| `weaponind` | int |

### TCustomObjSmokePoint

| поле | тип |
|---|---|
| `x` | float |
| `y` | float |
| `z` | float |
| `nx` | float |
| `ny` | float |
| `nz` | float |

### TEnemyInfo

| поле | тип |
|---|---|
| `armyInfos` | TArmyInfoList |
| `towers` | TTowerList |
| `towerMap` | array[0..?] of array[0..?] of float |
| `team` | int |
| `enemyMask` | int |
| `changed` | bool |
| `enabled` | bool |
| `maxArmyForce` | int |

### TEnemyInfoList

| поле | тип |
|---|---|
| `fList` | TPtrList |

### TFonts

| поле | тип |
|---|---|
| `font` | string |
| `chars` | array[0..255] of TChar |

### TGeneratorBitmapMask

| поле | тип |
|---|---|
| `r` | float |
| `g` | float |
| `b` | float |
| `terrain` | int |
| `water` | int |
| `forest` | int |
| `bsmooth` | bool |
| `broad` | bool |

### TGridList

| поле | тип |
|---|---|
| `fCount` | int |
| `fCapacity` | int |
| `fGrowthDelta` | int |
| `fBufferItem` | Pointer |
| `fPackMode` | bool |
| `fExternalMemory` | bool |
| `fResetsMemory` | bool |
| `fBaseList` | Pointer |
| `fItemSize` | int |
| `fMatCount` | array[0..8] of int |
| `fPlCount` | array[0..11] of int |
| `fMask` | Integer = 0 |
| `fPlMask` | Integer = 0 |
| `fChecked` | Boolean = false |
| `owner` | int |
| `dist` | int |
| `fSELastCheckMask` | int |
| `fSELastCheckPlMask` | int |
| `fSELastCheckTime` | float |
| `fSELastCheckResult` | bool |

### TIdeasList

| поле | тип |
|---|---|
| `fList` | TPtrList |

### TInt32

| поле | тип |
|---|---|
| `data` | array[0..3] of byte |

### TIntegerList

| поле | тип |
|---|---|
| `fCount` | int |
| `fCapacity` | int |
| `fGrowthDelta` | int |
| `fBufferItem` | Pointer |
| `fPackMode` | bool |
| `fDebug` | bool |
| `fExternalMemory` | bool |
| `fResetsMemory` | bool |
| `fBaseList` | Pointer |
| `fItemSize` | int |

### TInternetShell

| поле | тип |
|---|---|
| `lanid` | int |
| `nick` | string |
| `mail` | string |
| `pass` | string |
| `key` | string |
| `selclientid` | int |
| `selsessionid` | int |
| `selrankingid` | int |
| `currentpage` | int |
| `currentsessionid` | int |
| `currentsession` | TInternetShellSession |
| `currentrankingpage` | int |
| `profile` | TInternetShellProfile |
| `profiletmp` | TInternetShellProfile |
| `clients` | TInternetShellClients |
| `sessions` | TInternetShellSessions |
| `rankings` | TInternetShellRankings |
| `rankingslastupdate` | float |
| `chatind` | int |
| `chat` | array[0..255] of string |
| `roomchatind` | int |
| `roomchat` | array[0..255] of string |
| `historyscrollind` | int |
| `historyind` | int |
| `history` | array[0..255] of string |
| `bshowroom` | bool |
| `bshowranking` | bool |
| `bshowprofile` | bool |
| `bjoin` | bool |
| `bprivate` | bool |
| `bratingroom` | bool |
| `bhistoricalbattle` | bool |
| `bauth` | bool |
| `bautosearch` | bool |
| `bcustomautosearch` | bool |
| `autosearchstarttime` | float |
| `autosearchtotaltime` | float |
| `autosearchhistorytotaltime` | float |
| `autosearchroomtime` | float |
| `autosearchrealstarttime` | float |
| `autosearchsettings` | int |
| `autosearchantispamlasttime` | float |
| `qprequeststart` | float |
| `qprequeststop` | float |
| `qprequeststartgame` | float |
| `qprequeststartgameplcount` | int |
| `qprequeststartgamename` | string |
| `qprequestterminate` | float |
| `qprequestcloseroom` | float |
| `qprequestsleep` | float |
| `qprequestsign` | float |
| `qprequestmakematch` | float |
| `qprequestmapname` | string |
| `qprankedgame` | bool |
| `mirrormatchscore` | int |
| `showrankingseasonoffset` | int |
| `autosearchteam` | int |
| `prevstate` | int |
| `roomdata` | string |
| `autosearchdocreate` | string |

### TInternetShellClient

| поле | тип |
|---|---|
| `lanid` | int |
| `nick` | string |
| `country` | string |
| `score` | int |
| `dlc` | int |
| `pur` | int |
| `ram` | int |
| `prevscore` | int |
| `prevgamesplayed` | int |
| `prevgameswin` | int |
| `state` | int |
| `gamesplayed` | int |
| `gameswin` | int |
| `lastgame` | string |
| `info` | string |
| `ping` | int |
| `bmute` | bool |
| `states` | TInternetShellClientStates |
| `sic` | int |
| `si1` | int |
| `si2` | int |
| `si3` | int |
| `snc` | string |
| `sn1` | string |
| `sn2` | string |
| `sn3` | string |

### TInternetShellClientStates

| поле | тип |
|---|---|
| `bplay` | bool |
| `bmaster` | bool |
| `bsession` | bool |
| `bonline` | bool |

### TInternetShellClients

| поле | тип |
|---|---|
| `fList` | TPtrList |

### TInternetShellProfile

| поле | тип |
|---|---|
| `lanid` | int |
| `nick` | string |
| `mail` | string |
| `pass` | string |
| `info` | string |
| `country` | string |

### TInternetShellRanking

| поле | тип |
|---|---|
| `ind` | int |
| `lanid` | int |
| `nick` | string |
| `score` | int |
| `rank` | int |
| `wins` | int |
| `games` | int |
| `states` | TInternetShellClientStates |

### TInternetShellRankings

| поле | тип |
|---|---|
| `fList` | TPtrList |

### TInternetShellSession

| поле | тип |
|---|---|
| `gamename` | string |
| `mapname` | string |
| `maxplayers` | int |
| `masterid` | int |
| `clientscount` | int |
| `blocked` | bool |
| `bclosed` | bool |

### TInternetShellSessions

| поле | тип |
|---|---|
| `fList` | TPtrList |

### TIslandInfo

| поле | тип |
|---|---|
| `index` | int |
| `shore` | bool |
| `checked` | bool |

### TIslands

| поле | тип |
|---|---|
| `count` | int |
| `grid` | array[0..?] of array[0..?] of TIslandInfo |

### TLanSyncData

| поле | тип |
|---|---|
| `playerstosync` | Word |
| `economyfieldstosync` | array[0..11] of Byte |
| `netplayer` | array[0..11] of TLanSyncPlayerData |

### TLanSyncPlayerData

| поле | тип |
|---|---|
| `plind` | Byte |
| `idlepeasants` | Word |
| `idlemines` | Word |
| `workersonres` | array[0..6] of Word |
| `squadsuids` | TIntegerList |
| `squadstime` | TIntegerList |

### TLogMessage

| поле | тип |
|---|---|
| `id` | int |
| `s1` | string |
| `s2` | string |
| `time` | float |
| `ballowdublicates` | bool |

### TLogMessages

| поле | тип |
|---|---|
| `count` | int |
| `msg` | array[0..7] of TLogMessage |

### TMap

| поле | тип |
|---|---|
| `name` | string |
| `gamestage` | int |
| `lastenvuid` | int |
| `dlcs` | int |
| `brating` | bool |
| `bbattle` | bool |
| `battlestage` | int |
| `battleind` | int |
| `battlemap` | string |
| `settings` | TMapSettings |
| `players` | array[0..11] of TMapPlayer |
| `playersinfo` | array[0..11] of TMapPlayerInfo |

### TMapPlayer

| поле | тип |
|---|---|
| `id` | int |
| `cid` | int |
| `csid` | string |
| `name` | string |
| `team` | int |
| `color` | int |
| `lanid` | int |
| `startx` | float |
| `starty` | float |
| `aidifficulty` | int |
| `bexists` | bool |
| `bai` | bool |
| `bhuman` | bool |
| `bclosed` | bool |
| `bready` | bool |
| `bloaded` | bool |
| `bleave` | bool |

### TMapPlayerInfo

| поле | тип |
|---|---|
| `sic` | int |
| `si1` | int |
| `si2` | int |
| `si3` | int |
| `snc` | string |
| `sn1` | string |
| `sn2` | string |
| `sn3` | string |

### TMapSettings

| поле | тип |
|---|---|
| `gen` | TMapSettingsGen |
| `additional` | TMapSettingsAdditional |

### TMapSettingsAdditional

| поле | тип |
|---|---|
| `activeoption` | int |
| `startingunits` | int |
| `balloon` | int |
| `cannons` | int |
| `peacetime` | int |
| `century18` | int |
| `capture` | int |
| `marketdip` | int |
| `teams` | int |
| `autosave` | int |
| `limit` | int |
| `gamespeed` | int |
| `adviserassistant` | int |

### TMapSettingsGen

| поле | тип |
|---|---|
| `randkey0` | int |
| `randkey1` | int |
| `mapsize` | int |
| `terraintype` | int |
| `relieftype` | int |
| `resourcestart` | int |
| `resourcemines` | int |
| `season` | int |

### TObjBase

| поле | тип |
|---|---|
| `sid` | string |
| `maxhp` | int |
| `shield` | int |
| `price` | array[0..6] of int |
| `buildtime` | float |
| `fishingspeed` | int |
| `fishingmax` | int |
| `speed` | float |
| `protection` | array[0..9] of int |
| `weapon` | array[0..3] of TObjWeapon |
| `bproduceenabled` | bool |

### TObjProp

| поле | тип |
|---|---|
| `id` | int |
| `sid` | string |
| `peasantabsorber` | int |
| `transport` | int |
| `material` | int |
| `radius` | float |
| `rotatespeed` | float |
| `costpercent` | float |
| `weapon` | array[0..3] of TObjWeaponStatic |
| `searchradius` | float |
| `minattackradius` | float |
| `cankill` | array[0..8] of bool |
| `mmask` | int |
| `kmask` | int |
| `vision` | int |
| `consume` | array[0..6] of int |
| `explmedia` | int |
| `explradius` | float |
| `media` | int |
| `score` | int |
| `motionstyle` | int |
| `usage` | int |
| `artdepo` | array[0..3] of int |
| `artind` | int |
| `farm` | int |
| `resourcebase` | array[0..6] of bool |
| `produce` | array[0..6] of int |
| `bbuilding` | bool |
| `bwall` | bool |
| `bgate` | bool |
| `bslowdeath` | bool |
| `bcapture` | bool |
| `bcancapture` | bool |
| `bprotector` | bool |
| `bshotdirection` | bool |
| `bshotforward` | bool |
| `bshotleftflank` | bool |
| `bshotrightflank` | bool |
| `bshotback` | bool |
| `bshowdelay` | bool |
| `bturnoff` | bool |
| `bstandground` | bool |
| `bnohungry` | bool |
| `bdrummer` | bool |
| `bofficer` | bool |
| `bmercenary` | bool |
| `bfastunit` | bool |
| `bpriest` | bool |
| `bartillery` | bool |
| `bartdepo` | bool |
| `bartprepare` | bool |
| `bmarket` | bool |
| `bcansetrally` | bool |
| `airole` | int |
| `aiforce` | int |
| `walkintervalfactor` | float |
| `exitmaxdelay` | float |

### TObjWeapon

| поле | тип |
|---|---|
| `damage` | int |
| `damageinit` | int |
| `damagestatic` | int |
| `damagepercent` | int |
| `radiusmax` | float |
| `pause` | float |
| `dispertion` | float |

### TObjWeaponStatic

| поле | тип |
|---|---|
| `enabled` | bool |
| `radiusmin` | float |
| `addradius` | float |
| `detectradiusmin` | float |
| `detectradiusmax` | float |
| `cost` | array[0..6] of int |
| `weaponsid` | string |
| `weaponid` | int |
| `kind` | int |
| `attmask` | int |
| `fxshot` | string |

### TPlayer

| поле | тип |
|---|---|
| `id` | int |
| `objbase` | array[0..23] of array[0..79] of TObjBase |
| `cid` | int |
| `csid` | string |
| `res` | array[0..6] of int |
| `setres` | array[0..6] of int |
| `lanres` | array[0..6] of int |
| `resefficiency` | array[0..23] of array[0..6] of int |
| `fieldlife` | int |
| `victorystate` | int |
| `victorystategametime` | float |
| `unitcount` | int |
| `farm` | int |
| `myplmask` | int |
| `enemyplmask` | int |
| `team` | int |
| `difficulty` | int |
| `bexists` | bool |
| `bgeology` | bool |
| `bballoon` | bool |
| `bfamine` | bool |
| `brebellion` | bool |
| `bai` | bool |
| `bneutral` | bool |
| `aidata` | TAiData |
| `squads` | TSquadList |
| `lastattacktime` | float |
| `lastprogresstime` | float |
| `lastcheckexists` | float |
| `lastcalcsquadsmovecounttime` | float |
| `lastprogressaitime` | float |
| `lastseedwheattime` | float |
| `progresstick` | int |
| `searchenemyprev` | int |
| `searchenemylast` | int |
| `searchenemycur` | int |
| `searchenemylasttime` | float |
| `artlimit` | array[0..3] of int |
| `artcount` | array[0..3] of int |
| `counter` | TPlayerCounters |
| `stat` | TPlayerStatistics |
| `upgstate` | array[0..23] of array[0..319] of TPlayerUpgradeState |
| `lists` | TPlayerLists |
| `playeradviser` | TPlayerAdviser |

### TPlayerAdviser

| поле | тип |
|---|---|
| `adviser` | TAdviser |
| `buildings` | TIntegerList |
| `upgradeseconomy` | TIntegerList |
| `upgradesmilitary` | TIntegerList |
| `produce` | TIntegerList |
| `squads` | TPtrList |
| `officers` | TIntegerList |
| `drummers` | TIntegerList |
| `peasants` | TIntegerList |

### TPlayerAdviserSquad

| поле | тип |
|---|---|
| `cid` | int |
| `id` | int |
| `count` | int |
| `bofficers` | bool |

### TPlayerArgs

| поле | тип |
|---|---|
| `fid` | int |
| `fposx` | float |
| `fposy` | float |
| `fposz` | float |
| `fvisposx` | float |
| `fvisposz` | float |
| `fdirx` | float |
| `fdirz` | float |
| `ftrgx` | float |
| `ftrgy` | float |
| `ftrgz` | float |
| `faddord` | bool |
| `fdofirst` | bool |
| `frebuild` | bool |
| `fcenter` | bool |
| `fmode` | int |
| `fgroup` | int |
| `fplayer` | int |
| `fcid` | int |
| `fracename` | string |
| `fbasename` | string |
| `fhandle` | int |
| `fcapture` | bool |
| `fordtyp` | int |
| `ftarget` | int |
| `fclrord` | bool |
| `fintlst` | Pointer |
| `famount` | int |
| `fbstate` | bool |
| `fform` | int |
| `fsquad` | int |
| `fofficer` | int |
| `fdrummer` | int |
| `fposition` | bool |
| `flocktrg` | bool |
| `fsid` | string |
| `find` | int |
| `fresult` | int |
| `fdead` | bool |
| `fweaponid` | int |
| `frnd` | float |
| `fbyte0` | Byte |
| `fbyte1` | Byte |
| `fbyte2` | Byte |
| `fpointer0` | Pointer |
| `fpointer1` | Pointer |

### TPlayerLists

| поле | тип |
|---|---|
| `buildings` | TIntegerList |
| `storehouses` | TIntegerList |
| `ports` | TIntegerList |
| `deluids` | TIntegerList |

### TPlayerStatistics

| поле | тип |
|---|---|
| `restotal` | array[0..6] of int |
| `resonupgrade` | array[0..6] of int |
| `resonmines` | array[0..6] of int |
| `resonunits` | array[0..6] of int |
| `resonbuildings` | array[0..6] of int |
| `resonlife` | array[0..6] of int |
| `resbuy` | array[0..6] of int |
| `ressell` | array[0..6] of int |
| `killed` | array[0..23] of array[0..79] of int |
| `produced` | array[0..23] of array[0..79] of int |
| `population` | TIntegerList |
| `scores` | TIntegerList |

### TPos2f

| поле | тип |
|---|---|
| `x` | Float = 0 |
| `y` | Float = 0 |

### TPos3f

| поле | тип |
|---|---|
| `x` | Float = 0 |
| `y` | Float = 0 |
| `z` | Float = 0 |

### TProfile

| поле | тип |
|---|---|
| `name` | string |
| `sndmute` | int |
| `sndmaster` | float |
| `sndmusic` | float |
| `sndambient` | float |
| `sndfx` | float |
| `sndvoice` | float |
| `sndinterface` | float |
| `keyscrollspeed` | float |
| `mousescrollspeed` | float |
| `middlemousescrollspeed` | float |
| `wheelspeed` | float |
| `igamespeed` | int |
| `lastcampaignsave` | string |
| `lastcustomsave` | string |
| `netemail` | string |
| `netpass` | string |
| `netcdkey` | string |
| `bautosave` | bool |
| `bbrushunderunit` | bool |
| `bclipmouse` | bool |
| `bsearchenemyinfront` | bool |
| `binfiniteonleftclick` | bool |
| `bselectallunitsonz` | bool |
| `bfreezoom` | bool |
| `bDbgPreloadPatterns` | bool |
| `bDbgLogPointerNil` | bool |
| `bDbgVisualizePlayOnceProjFX` | bool |
| `bShowPause` | bool |
| `bShowMiniMap` | bool |
| `bcenterfirstrow` | bool |
| `bFamine` | bool |
| `bRestrictCamera` | bool |
| `bDbgCamera` | bool |
| `bDbgNoBrushes` | bool |
| `bDbgHotkeys` | bool |
| `bDbgUnitDebugInfo` | bool |
| `bDemo` | bool |
| `bNewMapOnMainMenu` | bool |
| `bCheatPlaceUnits` | bool |
| `bCheatNoFogOfWar` | bool |
| `bCheatSwitchPlayer` | bool |
| `bCheatPeaceMode` | bool |
| `bCheatNoSpeedLimit` | bool |
| `bCheatCopyPaste` | bool |
| `bCheatMoveUnits` | bool |
| `bCheatShowAllMissions` | bool |
| `bShowFPS` | bool |
| `bNoAchs` | bool |
| `bDevMode` | bool |
| `lang` | string |
| `displaymode` | string |
| `dontshowannouncement` | int |
| `lastknowndlcs` | int |
| `purchaseunixtime` | int |

### TProfileUserStruct

| поле | тип |
|---|---|
| `custommap` | TMap |
| `campaign` | TUserCampaign |
| `achs` | TAchs |
| `adviserdefault` | TAdviser |

### TProgress

| поле | тип |
|---|---|
| `lastprogresstime` | float |
| `progresstick` | int |
| `soundlastprogresstime` | float |
| `soundprogresstick` | int |
| `soundcounterlastprogresstime` | float |
| `soundcounterprogresstick` | int |
| `lastprogresshistorytime` | float |
| `lastmiscplsecmaxtime` | float |
| `lastpoolplsecmaxtime` | float |
| `lastsearchenemycountmidtime` | float |
| `lastsearchenemycountsumtime` | float |
| `lastsearchenemycountertime` | float |
| `lastprogressstatisticstime` | float |
| `lastprogresstopzonestime` | float |
| `lastupdateenemyticktime` | float |
| `lastupdateenemytickteam` | int |
| `lastsoundprogressfreqtime` | array[0..5] of float |
| `lastsoundprogresscounterfreqtime` | array[0..5] of float |
| `lastupdateenemyinfotime` | float |

### TProj

| поле | тип |
|---|---|
| `baseid` | int |
| `weaponid` | int |
| `owner` | int |
| `trg` | int |
| `px` | float |
| `py` | float |
| `pz` | float |
| `dx` | float |
| `dy` | float |
| `dz` | float |
| `ownercid` | int |
| `ownerid` | int |
| `ownerweaponind` | int |
| `uniqrnd` | float |

### TProjSimulatePoint

| поле | тип |
|---|---|
| `weaponid` | int |
| `owner` | int |
| `px` | float |
| `pz` | float |
| `damagetime` | float |

### TProjSimulatePoints

| поле | тип |
|---|---|
| `curind` | int |
| `maxdamagetime` | float |
| `projsim` | array[0..2047] of TProjSimulatePoint |

### TPtrList

| поле | тип |
|---|---|
| `fCount` | int |
| `fCapacity` | int |
| `fGrowthDelta` | int |
| `fBufferItem` | Pointer |
| `fPackMode` | bool |
| `fDebug` | bool |
| `fExternalMemory` | bool |
| `fResetsMemory` | bool |
| `fBaseList` | Pointer |
| `fItemSize` | int |

### TQuickPlayer

| поле | тип |
|---|---|
| `playerid` | int |
| `sessionid` | int |
| `weight` | float |
| `score` | int |
| `rank` | float |
| `games` | int |
| `wins` | int |
| `waittime` | float |
| `ram` | int |
| `tolerance` | float |
| `winrate` | float |
| `checksum` | string |

### TQuickPlayers

| поле | тип |
|---|---|
| `player` | array[0..?] of TQuickPlayer |
| `count` | int |
| `session` | array[0..?] of TQuickSession |
| `sessioncount` | int |
| `sessionplayercount` | int |

### TQuickSession

| поле | тип |
|---|---|
| `players` | array[0..10] of TQuickPlayer |

### TReconnectManager

| поле | тип |
|---|---|
| `bsessionstarted` | bool |
| `btryreconnect` | bool |
| `bimpossibletoreconnect` | bool |
| `bsuccessreconnectserver` | bool |
| `bsuccessreconnectroom` | bool |
| `bconnectedserver` | bool |
| `bconnectedroom` | bool |
| `sessionstarttime` | float |
| `sessionendtime` | float |
| `attempt` | int |
| `lastattempttime` | float |
| `prevstate` | int |

### TRect

| поле | тип |
|---|---|
| `minx` | Float = 0 |
| `miny` | Float = 0 |
| `maxx` | Float = 0 |
| `maxy` | Float = 0 |

### TResGridList

| поле | тип |
|---|---|
| `fCount` | int |
| `fCapacity` | int |
| `fGrowthDelta` | int |
| `fBufferItem` | Pointer |
| `fPackMode` | bool |
| `fExternalMemory` | bool |
| `fResetsMemory` | bool |
| `fBaseList` | Pointer |
| `fItemSize` | int |
| `fResCount` | array[0..6] of int |
| `fWorkerCount` | array[0..11] of array[0..6] of int |

### TScenario

| поле | тип |
|---|---|
| `bactive` | bool |
| `bexists` | bool |
| `campname` | string |
| `missname` | string |
| `difficulty` | int |
| `settings` | TScenarioSettings |
| `ui` | TScenarioUI |
| `players` | array[0..11] of TScenarioPlayer |
| `flags` | array[0..?] of TScenarioFlag |
| `counters` | array[0..?] of TScenarioCounter |
| `timers` | array[0..?] of TScenarioTimer |
| `groups` | array[0..?] of TScenarioGroup |
| `zones` | array[0..?] of TScenarioZone |
| `triggers` | array[0..?] of TScenarioTrigger |
| `objectives` | array[0..?] of TScenarioObjective |
| `queries` | array[0..?] of TScenarioQuery |
| `images` | array[0..?] of TScenarioImage |
| `results` | array[0..?] of TScenarioResult |
| `resulttriggers` | array[0..?] of TScenarioTrigger |

### TScenarioCounter

| поле | тип |
|---|---|
| `name` | string |
| `value` | int |

### TScenarioFlag

| поле | тип |
|---|---|
| `name` | string |
| `bactive` | bool |

### TScenarioGroup

| поле | тип |
|---|---|
| `name` | string |
| `unitslist` | TIntegerList |

### TScenarioImage

| поле | тип |
|---|---|
| `name` | string |
| `material` | string |

### TScenarioObjective

| поле | тип |
|---|---|
| `name` | string |
| `langtable` | string |
| `langkey` | string |
| `gametime` | float |
| `bvisible` | bool |
| `bdone` | bool |

### TScenarioPlayer

| поле | тип |
|---|---|
| `name` | string |
| `cid` | int |
| `team` | int |
| `difficulty` | int |
| `resources` | array[0..6] of int |
| `bai` | bool |

### TScenarioQuery

| поле | тип |
|---|---|
| `name` | string |
| `langtable` | string |
| `langkey` | string |
| `imageid` | int |
| `results` | array[0..?] of int |

### TScenarioResult

| поле | тип |
|---|---|
| `name` | string |
| `langtable` | string |
| `langkey` | string |
| `nextqueryid` | int |
| `resulttriggerid` | int |
| `executecount` | int |

### TScenarioSettings

| поле | тип |
|---|---|
| `filename` | string |
| `preview` | string |
| `langfilename` | string |
| `langtable` | string |
| `name` | string |
| `description` | string |

### TScenarioTimer

| поле | тип |
|---|---|
| `name` | string |
| `bstarted` | bool |
| `bfinished` | bool |
| `time` | float |
| `starttime` | float |

### TScenarioTrigger

| поле | тип |
|---|---|
| `name` | string |
| `bactive` | bool |
| `bexists` | bool |
| `btriggertreeopen` | bool |
| `bconditionstreeopen` | bool |
| `bactionstreeopen` | bool |
| `conditions` | array[0..?] of TScenarioTriggerCondition |
| `actions` | array[0..?] of TScenarioTriggerAction |
| `activetime` | float |

### TScenarioTriggerAction

| поле | тип |
|---|---|
| `id` | int |
| `triggerid` | int |
| `flagid` | int |
| `counterid` | int |
| `timerid` | int |
| `groupid` | int |
| `groupidtrg` | int |
| `zoneid` | int |
| `objectiveid` | int |
| `queryid` | int |
| `bactive` | bool |
| `bstate` | bool |
| `usecounterid` | int |
| `busecounterasamount` | bool |
| `busecounterastime` | bool |
| `player` | int |
| `playertrg` | int |
| `resource` | int |
| `amount` | int |
| `time` | float |
| `radius` | float |
| `countryid` | int |
| `unitid` | int |
| `direction` | float |
| `upgradeid` | int |
| `formationid` | int |
| `executestate` | string |
| `stringregister` | string |
| `marker` | int |

### TScenarioTriggerCondition

| поле | тип |
|---|---|
| `id` | int |
| `triggerid` | int |
| `flagid` | int |
| `counterid` | int |
| `timerid` | int |
| `groupid` | int |
| `zoneid` | int |
| `resultid` | int |
| `bactive` | bool |
| `bstate` | bool |
| `usecounterid` | int |
| `busecounterasamount` | bool |
| `busecounterastime` | bool |
| `player` | int |
| `difficulty` | int |
| `resource` | int |
| `amount` | int |
| `sign` | int |
| `time` | float |
| `executestate` | string |
| `stringregister` | string |

### TScenarioUI

| поле | тип |
|---|---|
| `helpertype` | int |
| `bshowui` | bool |
| `beditresulttrigger` | bool |
| `pickedtriggerindex` | int |
| `pickedconditionindex` | int |
| `pickedactionindex` | int |
| `pickedplayerindex` | int |
| `pickedflagindex` | int |
| `pickedcounterindex` | int |
| `pickedtimerindex` | int |
| `pickedgroupindex` | int |
| `pickedzoneindex` | int |
| `pickedobjectiveindex` | int |
| `pickedqueryindex` | int |
| `pickedimageindex` | int |
| `pickedresultindex` | int |
| `pickedresulttriggerindex` | int |
| `pickedresulttriggeractionindex` | int |
| `pickedresulttriggerconditionindex` | int |
| `copytriggercache` | TScenarioTrigger |
| `copyactioncache` | TScenarioTriggerAction |
| `copyconditioncache` | TScenarioTriggerCondition |

### TScenarioZone

| поле | тип |
|---|---|
| `name` | string |
| `x` | float |
| `y` | float |
| `w` | float |
| `h` | float |
| `bactive` | bool |
| `player` | int |
| `group` | int |
| `blinkgroup` | bool |
| `buseaverage` | bool |
| `addradius` | float |
| `linkgroup` | int |
| `bonlyungroup` | bool |
| `unitslist` | TIntegerList |

### TSettings

| поле | тип |
|---|---|
| `video` | TSettingsVideo |

### TSettingsVideo

| поле | тип |
|---|---|
| `preset` | string |
| `resolution` | int |
| `antialiasing` | string |
| `fxaa` | bool |
| `ssao` | bool |
| `hdrtype` | string |
| `vsyncmode` | string |
| `shadowenabled` | bool |
| `shadowmap` | string |
| `texturequality` | string |
| `texturefilter` | string |
| `shadertype` | string |
| `waterreflection` | string |
| `lightpreset` | int |
| `advanced` | bool |

### TSoundGrid

| поле | тип |
|---|---|
| `sndrequests` | array[0..88] of int |
| `bsndrequestexist` | bool |

### TSoundManager

| поле | тип |
|---|---|
| `bprocess` | bool |
| `lastprogresstime` | float |
| `emitterhnd` | int |
| `frustumltx` | float |
| `frustumlty` | float |
| `frustumrtx` | float |
| `frustumrty` | float |
| `frustumrbx` | float |
| `frustumrby` | float |
| `frustumlbx` | float |
| `frustumlby` | float |
| `frustumcenx` | float |
| `frustumceny` | float |
| `frustumrad` | float |
| `counter` | TSoundManagerCounter |

### TSoundManagerCounter

| поле | тип |
|---|---|
| `walkinfcloth` | int |
| `walkinfmetal` | int |
| `walkartwheels` | int |
| `walkartmortar` | int |
| `walkcavfast` | int |
| `walkcavslow` | int |
| `walkpeastone` | int |
| `walkpea` | int |
| `walkdstinfcloth` | float |
| `walkdstinfmetal` | float |
| `walkdstartwheels` | float |
| `walkdstartmortar` | float |
| `walkdstcavfast` | float |
| `walkdstcavslow` | float |
| `walkdstpeastone` | float |
| `walkdstpea` | float |

### TSquad

| поле | тип |
|---|---|
| `fList` | TIntegerList |
| `fFormation` | int |
| `fBaseCount` | int |
| `fStandGround` | bool |
| `fSearchVictim` | bool |
| `fSelected` | bool |
| `fIndex` | int |
| `fOfficerID` | int |
| `fPlIndex` | int |
| `fGroupName` | string |
| `fHoldMode` | bool |
| `fAddDamage` | int |
| `fAddShield` | int |
| `fAddDamageHold` | int |
| `fAddShieldHold` | int |
| `fDirX` | float |
| `fDirZ` | float |
| `fWidth` | int |
| `fHeight` | int |
| `fMoveCount` | int |
| `fAttackCount` | int |
| `fDelayCount` | int |
| `fUID` | int |
| `fTag` | float |
| `fAgressive` | bool |
| `fAttackMode` | bool |
| `fHoldModeProgress` | float |
| `fNeedRebuild` | bool |
| `fCurX` | float |
| `fCurZ` | float |
| `fArmy` | int |
| `fType` | int |
| `fWarType` | int |
| `arGrid` | array[0..24] of array[0..54] of int |

### TSquadList

| поле | тип |
|---|---|
| `fList` | TPtrList |
| `fNextUID` | int |

### TTopZone

| поле | тип |
|---|---|
| `danger` | array[0..12] of float |
| `attract` | array[0..12] of float |
| `changeDanger` | array[0..12] of float |
| `changeAttract` | array[0..12] of float |
| `centerDist` | array[0..12] of int |
| `changed` | bool |

### TTower

| поле | тип |
|---|---|
| `hnd` | int |
| `pause` | float |
| `radius` | float |
| `update` | bool |
| `remove` | bool |

### TTowerList

| поле | тип |
|---|---|
| `fList` | TPtrList |

### TUIConst

| поле | тип |
|---|---|
| `halign` | array[0..?] of string |
| `valign` | array[0..?] of string |
| `font` | array[0..?] of string |
| `fontstyle` | array[0..?] of string |

### TUniqUpgList

| поле | тип |
|---|---|
| `fList` | TPtrList |

### TUniqUpgrade

| поле | тип |
|---|---|
| `cid` | int |
| `unitid` | int |
| `airole` | int |
| `levelid` | array[0..7] of int |
| `levelsid` | array[0..7] of string |

### TUnitUpgrade

| поле | тип |
|---|---|
| `unitid` | int |
| `defenceupgrade` | int |
| `attackupgrade` | int |
| `defenceupgradeid` | array[0..7] of int |
| `attackupgradeid` | array[0..7] of int |

### TUserCampaign

| поле | тип |
|---|---|
| `difficulty` | int |
| `campprogress` | array[0..255] of TCampaignProgress |

### TVec3f

| поле | тип |
|---|---|
| `x` | Float = 0 |
| `y` | Float = 0 |
| `z` | Float = 0 |

### TWallCell

| поле | тип |
|---|---|
| `fSprite` | int |
| `x` | int |
| `y` | int |
| `wallType` | int |
| `cid` | int |
| `visible` | bool |
| `goHnd` | int |
| `plInd` | int |

### TWallCluster

| поле | тип |
|---|---|
| `wallType` | int |
| `cornPt` | TIntegerList |
| `Cells` | TPtrList |
| `lastX` | int |
| `lastY` | int |
| `finalX` | int |
| `finalY` | int |
| `plIndex` | int |
| `cid` | int |
| `firstWall` | bool |
| `buildWall` | bool |

### TWallSystem

| поле | тип |
|---|---|
| `fList` | TPtrList |

### TWeapon

| поле | тип |
|---|---|
| `sid` | string |
| `id` | int |
| `fx` | string |
| `projbasename` | string |
| `damage` | int |
| `radius` | float |
| `gravity` | float |
| `angle` | float |
| `speed` | float |
| `propagation` | int |
| `time` | float |
| `trailfx` | string |
| `sound` | string |
| `sndind` | int |
| `buseownerdamage` | bool |
| `buseownerfxshot` | bool |
| `buseownercustomobjpoints` | bool |
| `brotate` | bool |
| `bcollisiondetection` | bool |
| `bcheckfriendonline` | bool |
| `volumeclippedfreq` | float |
| `expdecname` | string |
| `childs` | TWeaponChild |
| `customexplosions` | array[0..6] of TWeaponCustomExplosion |
| `syncweaponslist` | TIntegerList |

### TWeaponChild

| поле | тип |
|---|---|
| `mincount` | int |
| `maxcount` | int |
| `buseparentdestpos` | bool |
| `list` | TIntegerList |

### TWeaponCustomExplosion

| поле | тип |
|---|---|
| `mincount` | int |
| `maxcount` | int |
| `list` | TIntegerList |

### TWriteNewRequest

| поле | тип |
|---|---|
| `plind` | int |
| `racename` | string |
| `basename` | string |
| `cid` | int |
| `uid` | int |
| `posx` | float |
| `posz` | float |
| `itype` | int |
| `bpush` | bool |

