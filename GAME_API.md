# Cossacks 3 — справочник функций модлоадера

> Источник: `Modloader For Cossacks 3/core/NativesTable.inc` (генератор `tools/ida_export_natives.py`).
> Билд игры: 2.2.3, 32-bit Delphi, ImageBase `0x400000`. Адреса ниже — VA при этой базе.
> Реальный адрес = `GetModuleHandleW(nullptr) + (VA - 0x400000)` (`GameApi::Addr`).
> Все нативы — `__stdcall`, `String` = Delphi AnsiString.

Всего нативов: **4856**. Движок/системные: **2254**, юниты/объекты/игроки: **1700**, GUI: **586**, камера/окружение/рендер: **259**, прочее (редактор): **57**.

Поиск из игры: консоль модлоадера `.find <слова>` + `.find -d` (по параметрам). Вызов: строка консоли = код DWScript, `? expr`, `?i/?f/?b`, `/текст` = чат через `_misc_ProcessMessage`.

## Содержание

- [1. Движок](#1-движок) — логи, StateMachine, строки, математика, файлы
- [2. Юниты / объекты / игроки](#2-юниты--объекты--игроки) — GameObject, Group, Player, Squad, Weapon, Country, Scenario, AI
- [3. GUI](#3-gui) — дерево элементов, геометрия, вид, ввод, списки, миникарта, селекция, команды
- [4. Камера / окружение / рендер](#4-камера--окружение--рендер) — камера, туман, свет, небо, облака, вода
- [5. Прочее](#5-прочее) — редактор
- [6. TOSW из functions.txt](#6-tosw-из-functionstxt) — классы рендера/GUI для поиска в .i64
- [7. Перехват GUI](#7-перехват-gui) — чистое создание vs перехват

## 1. Движок

Якоря в `core/GameApi.h`: `Log 0x60DBD8`, `TimeLog 0x60DC98`, `GetBuildVersion 0x60EADC`, `StateMachineGetGUISMHandle 0x6C4B00`, `StateAdd 0x6C3A50`, `StateAddCodeLine 0x6C3A80`, `StateExecuteState 0x6C3C08`, движок `0x705944`, `SMStateIndexByName 0x863C3C`, `SMStateByIndex 0x863AA0`, `SMExecuteState 0x8638E0` (внутри гейт `sub_732414`), логгеры `0x8CE9BC-0x8CECB0`. Ниже — остальные системные нативы.

### Files — файлы/битмапы/сериализация — 148

| VA | Объявление |
|---|---|
| `0x0060E9F4` | `function ExtractFileName(const afile: String): String` |
| `0x0060EA50` | `function ExtractFileExt(const afile: String): String` |
| `0x0060EA64` | `function ExtractFilePath(const afile: String): String` |
| `0x0060EA78` | `function IsFileExists(const afile: String): Boolean` |
| `0x0060EA88` | `function FileAge(const filename: String): Integer` |
| `0x0060F7F8` | `procedure SavePresetStatsToBMP(const amapfilename, abmpfilename: String)` |
| `0x0060FDE4` | `function OpenFileRead(const filename: String): Integer` |
| `0x0060FE0C` | `function OpenFileWrite(const filename: String): Integer` |
| `0x0060FE24` | `procedure CloseFile(const fs: Integer)` |
| `0x0060FE60` | `function SizeFile(const fs: Integer): Integer` |
| `0x0060FFB8` | `procedure WriteByte(const fs: Integer; const val: Byte)` |
| `0x0060FFFC` | `procedure WriteBuffer(const fs: Integer; const val: Pointer; const size: Integer)` |
| `0x00610188` | `procedure ReadByte(const fs: Integer; var val: Byte)` |
| `0x006101CC` | `procedure ReadBuffer(const fs: Integer; var val: Pointer; const size: Integer)` |
| `0x00610318` | `procedure SeekByte(const fs: Integer)` |
| `0x0061035C` | `procedure SeekBuffer(const fs, size: Integer)` |
| `0x006103A4` | `function CreateBitmap: Integer` |
| `0x006103B4` | `function CreateBitmapTGA: Integer` |
| `0x006103C4` | `procedure FreeBitmap(const bitmap: Integer)` |
| `0x00610400` | `procedure LoadBitmap(const bitmap: Integer; const filename: String)` |
| `0x00610440` | `procedure SaveBitmap(const bitmap: Integer; const filename: String)` |
| `0x00610480` | `procedure SetBitmapSize(const bitmap, width, height: Integer)` |
| `0x006104CC` | `procedure GetBitmapSize(const bitmap: Integer; var width, height: Integer)` |
| `0x0061063C` | `procedure SetBitmapPixel(const bitmap, x, y: Integer; const r, g, b, a: Float)` |
| `0x00610750` | `procedure GetBitmapPixel(const bitmap, x, y: Integer; var r, g, b, a: Float)` |
| `0x0061121C` | `function GetApplicationFileName: string` |
| `0x00611758` | `function LoadLibrary(const libname: string): integer` |
| `0x0067B5A0` | `function GetLastCreateSnapShotFileName: String` |
| `0x0067B5B8` | `function LoadMapSnapShotToMaterial(const smapfile: String; const smaterial: String): Boolean` |
| `0x0067B66C` | `function LoadImageToMaterial(const simagefile: String; const smaterial: String): Boolean` |
| `0x00684024` | `function IsLanReady(): Boolean` |
| `0x00684054` | `procedure LanDoReady()` |
| `0x00684068` | `procedure LanDoReadyDone()` |
| `0x0068407C` | `procedure LanDoReadyForce()` |
| `0x0068425C` | `procedure LanSrvSetMapFile(const amap: String)` |
| `0x00684478` | `procedure LanPublicServerCloseSession` |
| `0x0068448C` | `procedure LanPublicServerWrongCloseSession` |
| `0x00685E14` | `function RecordCustomWriteBeginBitFields: Boolean` |
| `0x00685E44` | `function RecordCustomWriteBit(const value: Boolean): Boolean` |
| `0x00685E7C` | `function RecordCustomWriteEndBitFields: Boolean` |
| `0x00685FC8` | `function RecordCustomWriteWord(const value: Word): Boolean` |
| `0x00686004` | `function RecordCustomWriteByte(const value: Byte): Boolean` |
| `0x006860EC` | `function RecordCustomWriteBuffer(var buff: Pointer; const buffsize: Integer): Boolean` |
| `0x00686128` | `function RecordCustomBeginReadBitFields: Boolean` |
| `0x00686158` | `function RecordCustomReadBit: Boolean` |
| `0x00686188` | `function RecordCustomEndReadBitFields: Boolean` |
| `0x006862D0` | `function RecordCustomReadWord: Word` |
| `0x00686300` | `function RecordCustomReadByte: Byte` |
| `0x006863E4` | `function RecordCustomReadBuffer(var buff: Pointer; const buffsize: Integer): Boolean` |
| `0x00686420` | `function RecordCustomGetReadPackageSize: Integer` |
| `0x00686450` | `function RecordCustomGetWritePackageSize: Integer` |
| `0x006867E4` | `procedure LanPublicServerDeleteFriends(friend: integer)` |
| `0x0068689C` | `procedure LanPublicServerDeleteChats(id: integer)` |
| `0x00686984` | `procedure LanPublicServerDeleteClans(id: integer)` |
| `0x006869E8` | `procedure LanPublicServerDeleteMembers(clanid, userid: integer)` |
| `0x00686A3C` | `procedure LanPublicServerDeleteAdmins(userid: integer)` |
| `0x00686B14` | `procedure LanPublicServerDeleteStats()` |
| `0x0068A56C` | `function MapGetInitMachineFileName : String` |
| `0x0068AE98` | `procedure DeleteTrackNodeByIndex(const index : Integer)` |
| `0x0068B040` | `procedure MapInitMachineLoadFromFile(const val : String)` |
| `0x006AB810` | `procedure LoadMapNeeded(const filename: String)` |
| `0x006AC310` | `procedure CloseQuery()` |
| `0x006AC3A4` | `function GetCurrentMapFileName(): String` |
| `0x006AE63C` | `function GetLocaleTableFileName: String` |
| `0x006AE658` | `procedure SetLocaleTableFileName(const val: String)` |
| `0x006AE674` | `function GetLocaleTableListFileName: String` |
| `0x006AE690` | `procedure SetLocaleTableListFileName(const val: String)` |
| `0x006AE7D8` | `procedure DeleteLocaleTableList(const ind: Integer)` |
| `0x006AE83C` | `function IndexOfLocaleTableListByFile(const filename: String): Integer` |
| `0x006AE85C` | `procedure SaveLocaleTableList(const ind: Integer; const filename: String)` |
| `0x006B27E4` | `procedure LoadPatterns(const binload, objload: Boolean)` |
| `0x006B4734` | `function GetAppSaveDirectoryPath: String` |
| `0x006B4E80` | `procedure LibActorLoadByHandle(libactorhandle: Integer; filename: String)` |
| `0x006B4FDC` | `procedure LibActorSaveByHandle(libactorhandle: Integer; filename: String)` |
| `0x006B7C48` | `procedure TopologySaveToFile(const filename: String)` |
| `0x006B7C7C` | `procedure TopologyLoadFromFile(const filename: String)` |
| `0x006B8710` | `function GetResourceExtOSMFileEnable: Boolean` |
| `0x006B8718` | `procedure SetResourceExtOSMFileEnable(const val: Boolean)` |
| `0x006B882C` | `procedure OpenURL(const url: string)` |
| `0x006B89F8` | `function ModLibraryGetIniFile: string` |
| `0x006B8A38` | `function ModLibraryGetDatFile: string` |
| `0x006B8A58` | `function ModLibraryGetCountOfFiles: integer` |
| `0x006B8A68` | `function ModLibraryGetFileExists(const f: string): boolean` |
| `0x006B8BF8` | `function ModLibGetFileExist(libind: integer; const f: string): boolean` |
| `0x006B8C40` | `function DlcLibraryGetIniFile: string` |
| `0x006B8C80` | `function DlcLibraryGetDatFile: string` |
| `0x006B8CA0` | `function DlcLibraryGetCountOfFiles: integer` |
| `0x006B8CB0` | `function DlcLibraryGetFileExists(const f: string): boolean` |
| `0x006B8E40` | `function DlcLibGetFileExist(libind: integer; const f: string): boolean` |
| `0x006BB36C` | `procedure AmbientThreadListImportFile(const afromfile: String)` |
| `0x006C3364` | `procedure DeleteVariableByIndex(index: Integer)` |
| `0x006C374C` | `procedure ArrayDeleteItemsByRange(index1: Integer; index2: Integer)` |
| `0x006C3798` | `procedure ArrayDeleteItemByIndex(index: Integer)` |
| `0x006C45C0` | `procedure MoveMem(const source: Pointer; var dest: Pointer; count: Integer)` |
| `0x006C4A20` | `function EvaluateFile(const filename: String): Boolean` |
| `0x006C4A48` | `function EvaluateFileThread(const filename: String): Boolean` |
| `0x006C4A9C` | `function RefreshFileList(const path: String): Integer` |
| `0x006C4AB0` | `function GetFileListNameByIndex(const index: Integer): String` |
| `0x006C565C` | `procedure SaveClassToFile(const filename, classname: String)` |
| `0x006C56C0` | `procedure MachineLibrarySaveSerialsToFile(const filename: String)` |
| `0x006C56DC` | `procedure MachineLibraryToSerialTypes(const clean: Boolean)` |
| `0x006C56F0` | `procedure SerializedToSerialTypes(const clean: Boolean)` |
| `0x006C5704` | `procedure CleanSerialTypes` |
| `0x006C5710` | `procedure ArgumentsToSerialTypes(const smhnd: Integer)` |
| `0x006C5790` | `function SizeOfSerialTypes: Integer` |
| `0x006C5F84` | `procedure TriggerManagerSaveToBinFile(const filename : String)` |
| `0x006C5FAC` | `procedure TriggerManagerLoadFromBinFile(const filename : String)` |
| `0x006C5FD4` | `procedure TriggerManagerSaveToTextFile(const filename : String)` |
| `0x006C5FFC` | `procedure TriggerManagerLoadFromTextFile(const filename : String)` |
| `0x006C7798` | `function UserRenameProfile(const aname: String): Boolean` |
| `0x006C77E4` | `function UserDeleteProfile(const aname: String): Boolean` |
| `0x006C7830` | `function UserSaveProfile: Boolean` |
| `0x006C787C` | `function UserSaveProfileExt(const engine, data: boolean): Boolean` |
| `0x006C78CC` | `procedure UserProfileLoadMap(const aname: String)` |
| `0x006C7940` | `procedure UserProfileSaveMap(const aname: String)` |
| `0x006C7A24` | `procedure UserProfileSaveMapExt(const filename: String; const hidegui: Boolean)` |
| `0x006C7B08` | `procedure UserProfileDeleteMap(const aname: String)` |
| `0x006C7B88` | `function UserProfileSaveMapIndex(const aname: String): Integer` |
| `0x006C7BA8` | `procedure UserProfileLoadReplay(const aname: String)` |
| `0x006C7C1C` | `procedure UserProfileSaveReplay(const aname: String; const sorignmap: String)` |
| `0x006C7D00` | `procedure UserProfileDeleteReplay(const aname: String)` |
| `0x006C7DA0` | `procedure UserProfileLoadCustom(const aname: String)` |
| `0x006C7E14` | `procedure UserProfileSaveCustom(const aname: String)` |
| `0x006C7EF8` | `procedure UserProfileSaveCustomExt(const filename: String; hidegui: Boolean)` |
| `0x006C7FDC` | `procedure UserProfileDeleteCustom(const aname: String)` |
| `0x006C80BC` | `function UserGetProfileFileNameByIndex(aindex: Integer): String` |
| `0x006C817C` | `function UserGetProfileSavesCount: Integer` |
| `0x006C8190` | `function UserGetProfileSaveByIndex(aindex: Integer): String` |
| `0x006C81B0` | `function UserGetProfileSaveFilePathByIndex(aindex: Integer): String` |
| `0x006C821C` | `function UserGetProfileSaveDateByIndex(aindex: Integer): String` |
| `0x006C82F0` | `function UserGetProfileReplayFilePathByIndex(aindex: Integer): String` |
| `0x006C8430` | `function UserGetProfileCustomFilePathByIndex(aindex: Integer): String` |
| `0x006C853C` | `procedure UserProfileRefreshSavesList` |
| `0x006E031C` | `function GetPFXFireFXManagerNoZWrite(const managername: String): Boolean` |
| `0x006E035C` | `procedure SetPFXFireFXManagerNoZWrite(const managername: String; const val: Boolean)` |
| `0x006EC710` | `procedure DebugTextWrite(const id, font, text: string; x, y, z, scale, r, g, b, a: Float; align, layout: Integer)` |
| `0x006EC89C` | `procedure DebugTextDelete(const index: Integer)` |
| `0x006EC8D8` | `procedure DebugTextWriteByIndex(const index: Integer; id, font, text: string; x, y, z, scale, r, g, b, a: Float; align, layout: Integer)` |
| `0x006ECA04` | `procedure DebugTextReadByIndex(const index: Integer; var id, font, text: string; var x, y, z, scale, r, g, b, a: Float; var align, layout: Integer)` |
| `0x006F896C` | `function SteamAPPLoad(libname: string): boolean` |
| `0x006F89C4` | `function IsSteamAPPLoaded: boolean` |
| `0x006F8BB0` | `function SteamwrapIsLoaded: boolean` |
| `0x006FAF48` | `function SteamLoadWorkshopItems: integer` |
| `0x00705A24` | `procedure ConsoleWrite(val: String)` |
| `0x00705A80` | `procedure ConsoleWriteln(val: String)` |
| `0x00705AF8` | `function ConsoleRead: String` |
| `0x00705B1C` | `function ConsoleReadln: String` |
| `0x00705BC4` | `procedure ConsoleWriteToFile(filename: String)` |

### Log — логи — 77

| VA | Объявление |
|---|---|
| `0x0060DA04` | `procedure SafeTrace(const msg: String)` |
| `0x0060DA0C` | `procedure SafeLog(const msg: String)` |
| `0x0060DA58` | `procedure SafeLogEx(const msg: String)` |
| `0x0060DAA4` | `procedure SafeErrorLog(const msg: String)` |
| `0x0060DAF0` | `procedure SafeTimeLog(const msg: String)` |
| `0x0060DB3C` | `procedure SafeLogOpen(const msg: String)` |
| `0x0060DBC0` | `procedure SafeLogClose()` |
| `0x0060DBD0` | `procedure Trace(const msg: String)` |
| `0x0060DBD8` | `procedure Log(const msg: String)` |
| `0x0060DC18` | `procedure LogEx(const msg: String)` |
| `0x0060DC58` | `procedure ErrorLog(const msg: String)` |
| `0x0060DC98` | `procedure TimeLog(const msg: String)` |
| `0x0060DCD8` | `procedure LogOpen(const msg: String)` |
| `0x0060DD50` | `procedure LogClose()` |
| `0x0060DD58` | `procedure TimeLogReset()` |
| `0x0060DD60` | `procedure LogClear()` |
| `0x0060DD68` | `procedure LogCreateWnd()` |
| `0x0060DD70` | `procedure LogReleaseWnd()` |
| `0x0060DD78` | `function IsLogWndCreated: Boolean` |
| `0x0060DD84` | `procedure LogDisabled(dis: Boolean)` |
| `0x0060DD94` | `function IsLogDisabled: Boolean` |
| `0x0060DD9C` | `procedure LogGlobalDisabled(dis: Boolean)` |
| `0x0060DDAC` | `function IsLogGlobalDisabled: Boolean` |
| `0x0060DDB4` | `procedure LogVisible(vis: Boolean)` |
| `0x0060DDE0` | `function IsLogVisible: Boolean` |
| `0x0060FD60` | `procedure SetLogFileEnabled(val: Boolean)` |
| `0x0060FD74` | `function GetLogFileEnabled: Boolean` |
| `0x006543D8` | `procedure GObjDoProcFrndsStLog2(const gohandle: Integer; ffov, fcoltag_equal: Integer; fisendpind_equal: Boolean; fcountcolobjs_greater, frelquart_notequal, fgrstackindtodecv, fcoltagtoset: Integer; fexecstendpind_true, fexecstendpind_false: String)` |
| `0x0065764C` | `function GetTrackPointAddTraceDist: Float` |
| `0x0065765C` | `procedure SetTrackPointAddTraceDist(dist: Float)` |
| `0x006844EC` | `procedure LanPublicServerLogin` |
| `0x00698908` | `function GetSLogicFrmMaxWidth: Float` |
| `0x00698924` | `procedure SetAllFormationLogicsMaxWidth(cmaxwidth: Float)` |
| `0x006989C4` | `function GetSLogicTestLineDistance(vstartx, vstartz, vdirx, vdirz: Float): Float` |
| `0x0069943C` | `function SLogicFrmPointGetPath(const startx, starty, endx, endy: Float): Boolean` |
| `0x00699538` | `function SLogicGetTrackPointsCount: Integer` |
| `0x00699560` | `procedure SLogicGetTrackPointByIndex(const ind: Integer; var posx, posy: Float)` |
| `0x006995E8` | `function SLogicFrmRotateGetReactionRadius: Float` |
| `0x00699618` | `procedure SLogicFrmRotateSetReactionRadius(aradius: Float)` |
| `0x00699640` | `function SLogicFrmRotateGetStretchRadius: Float` |
| `0x00699670` | `procedure SLogicFrmRotateSetStretchRadius(aradius: Float)` |
| `0x00699698` | `function SLogicFrmRotateGetUseStretchRadius: Boolean` |
| `0x006996BC` | `procedure SLogicFrmRotateSetUseStretchRadius(avalue: Boolean)` |
| `0x006996E4` | `function SLogicFrmRotateGetStretchResult: Integer` |
| `0x00699708` | `procedure SLogicFrmRotateGetPosition(var posx: Float; var posy: Float; var posz: Float)` |
| `0x00699770` | `function SLogicFrmRotateGetAlignPosition: Boolean` |
| `0x00699794` | `procedure SLogicFrmRotateSetAlignPosition(avalue: Boolean)` |
| `0x006997BC` | `function SLogicFrmRotateGetAlignDefDirection: Boolean` |
| `0x006997E0` | `procedure SLogicFrmRotateSetAlignDefDirection(avalue: Boolean)` |
| `0x00699808` | `function SLogicFrmRotateGetBlockRadius: Float` |
| `0x00699838` | `procedure SLogicFrmRotateSetBlockRadius(aradius: Float)` |
| `0x00699860` | `function SLogicFrmRotateGetSamplingDirRadius: Float` |
| `0x00699890` | `procedure SLogicFrmRotateSetSamplingDirRadius(aradius: Float)` |
| `0x006998B8` | `function SLogicFrmRotateGetDeltaAngle: Float` |
| `0x006998E8` | `procedure SLogicFrmRotateSetDeltaAngle(angle: Float)` |
| `0x00699910` | `procedure SLogicFrmRotateGetDirection(var dirx: Float; var diry: Float; var dirz: Float)` |
| `0x00699978` | `function SLogicFrmRotateGetFindFreePosition: Boolean` |
| `0x0069999C` | `procedure SLogicFrmRotateSetFindFreePosition(avalue: Boolean)` |
| `0x006999C4` | `function SLogicFrmRotateGetShift: Float` |
| `0x006999F4` | `procedure SLogicFrmRotateSetShift(avalue: Float)` |
| `0x00699A1C` | `function SLogicFrmRotateGetRowShift: Float` |
| `0x00699A4C` | `procedure SLogicFrmRotateSetRowShift(avalue: Float)` |
| `0x00699A74` | `function SLogicFrmRotateGetMaxWidth: Float` |
| `0x00699AA4` | `procedure SLogicFrmRotateSetMaxWidth(avalue: Float)` |
| `0x00699B8C` | `function SLogicFrmRotateGetUseReflect: Boolean` |
| `0x00699BB4` | `procedure SLogicFrmRotateSetUseReflect(avalue: Boolean)` |
| `0x00699BE0` | `function SLogicFrmRotateGetStaticDir: Boolean` |
| `0x00699C08` | `procedure SLogicFrmRotateSetStaticDir(avalue: Boolean)` |
| `0x00699C34` | `function SLogicFrmRotateGetUsePointFormation: Boolean` |
| `0x00699C58` | `procedure SLogicFrmRotateSetUsePointFormation(avalue: Boolean)` |
| `0x00699C80` | `function SLogicFrmRotateGetUseLinesFormation: Boolean` |
| `0x00699CA4` | `procedure SLogicFrmRotateSetUseLinesFormation(avalue: Boolean)` |
| `0x006B7F88` | `function TraceLineQuadTree(stx, stz, endx, endz: Float; prior, quadtree: Integer): Boolean` |
| `0x006B8010` | `function TraceLineQuadTreeExt(stx, stz, endx, endz: Float; prior, quadtree: Integer; var resnearx, resnearz, resfarx, resfarz: Float): Boolean` |
| `0x006DF820` | `function GetPFXTracerFXManagerExisted(const managername: String): Boolean` |
| `0x006F8C54` | `procedure SteamwrapWarningMessageHookToLog(val: boolean)` |
| `0x006F9324` | `function SteamwrapIsLoggedOn: boolean` |

### Math — числа/вектора — 295

| VA | Объявление |
|---|---|
| `0x0060E1CC` | `function Round(const val: Float): Integer` |
| `0x0060E1DC` | `function Trunc(const val: Float): Integer` |
| `0x0060E1EC` | `function Floor(const val: Float): Integer` |
| `0x0060E1FC` | `function Ceil(const val: Float): Integer` |
| `0x0060E20C` | `function MathCeil(const val: Float): Integer` |
| `0x0060E224` | `function Abs(const val: Float): Float` |
| `0x0060E23C` | `function Max(const a, b: Integer): Integer` |
| `0x0060E250` | `function Min(const a, b: Integer): Integer` |
| `0x0060E264` | `function MaxFloat(const a, b: Float): Float` |
| `0x0060E28C` | `function MinFloat(const a, b: Float): Float` |
| `0x0060E2D4` | `function Lerp(const a, b, t: Float): Float` |
| `0x0060E2F4` | `function Sqrt(const val: Float): Float` |
| `0x0060E30C` | `function Sqr(const val: Float): Float` |
| `0x0060E324` | `function Sin(const val: Float): Float` |
| `0x0060E33C` | `function Cos(const val: Float): Float` |
| `0x0060E354` | `function Tan(const val: Float): Float` |
| `0x0060E36C` | `function ArcSin(const val: Float): Float` |
| `0x0060E384` | `function ArcCos(const val: Float): Float` |
| `0x0060E39C` | `function ArcTan(const val: Float): Float` |
| `0x0060E3B4` | `function Clamp(const val, min, max: Float): Float` |
| `0x0060E3D4` | `function ClampInt(const val, min, max: Integer): Integer` |
| `0x0060E410` | `function IsInRangeInt(const val, min, max: Integer): Boolean` |
| `0x0060E42C` | `function Pow(const base, exponent: Float): Float` |
| `0x0060E448` | `function Ln(const val: Float): Float` |
| `0x0060E464` | `function Exp(const val: Float): Float` |
| `0x0060E47C` | `function Random: Float` |
| `0x0060E48C` | `function VectorAngle(x1, y1, z1: Float; x2, y2, z2: Float): Float` |
| `0x0060E4E4` | `function VectorDot(x1, y1, z1: Float; x2, y2, z2: Float): Float` |
| `0x0060E524` | `procedure VectorCross(x1, y1, z1: Float; x2, y2, z2: Float; var rx, ry, rz: Float)` |
| `0x0060E578` | `function VectorDistance(x1, y1, z1: Float; x2, y2, z2: Float): Float` |
| `0x0060E5B8` | `function VectorLength(x1, y1, z1: Float): Float` |
| `0x0060E5D8` | `procedure VectorRotateX(var x1, y1, z1: Float; angle: Float)` |
| `0x0060E63C` | `procedure VectorRotateY(var x1, y1, z1: Float; angle: Float)` |
| `0x0060E6A0` | `procedure VectorRotateZ(var x1, y1, z1: Float; angle: Float)` |
| `0x0060E704` | `procedure VectorRotateAxis(var x, y, z: Float; axisx, axisy, axisz: Float; angle: Float)` |
| `0x0060E77C` | `procedure VectorNormalize(var x, y, z: Float)` |
| `0x0060E7F4` | `procedure VectorReflect(var vx, vy, vz: Float; nx, ny, nz: Float)` |
| `0x0060E850` | `function PointInSector(cx, cy: Float; sx1, sy1: Float; sx2, sy2: Float; px, py: Float): Boolean` |
| `0x0060E8B4` | `procedure PointLineClosestPoint(const px, py, pz, lpx, ply, lpz, ldx, ldy, ldz: Float; var x, y, z: Float)` |
| `0x0060E924` | `function GetAngleToPosition(const x, y, z, tx, ty, tz, nulldirx, nulldiry, nulldirz: Float): Float` |
| `0x0060F254` | `procedure SetgDbgInt0(arg: Integer)` |
| `0x0060F268` | `function GetgDbgInt0: Integer` |
| `0x0060F270` | `procedure SetgDbgFloat0(arg: Float)` |
| `0x0060F284` | `function GetgDbgFloat0: Float` |
| `0x0060F294` | `procedure SetgDbgBool0(arg: Boolean)` |
| `0x0060F2A8` | `function GetgDbgBool0: Boolean` |
| `0x0060F310` | `procedure SetgDbgInt1(arg: Integer)` |
| `0x0060F324` | `function GetgDbgInt1: Integer` |
| `0x0060F32C` | `procedure SetgDbgFloat1(arg: Float)` |
| `0x0060F340` | `function GetgDbgFloat1: Float` |
| `0x0060F350` | `procedure SetgDbgBool1(arg: Boolean)` |
| `0x0060F364` | `function GetgDbgBool1: Boolean` |
| `0x0060F3CC` | `procedure SetgDbgInt2(arg: Integer)` |
| `0x0060F3E0` | `function GetgDbgInt2: Integer` |
| `0x0060F3E8` | `procedure SetgDbgFloat2(arg: Float)` |
| `0x0060F3FC` | `function GetgDbgFloat2: Float` |
| `0x0060F40C` | `procedure SetgDbgBool2(arg: Boolean)` |
| `0x0060F420` | `function GetgDbgBool2: Boolean` |
| `0x0060F488` | `procedure SetgDbgInt3(arg: Integer)` |
| `0x0060F49C` | `function GetgDbgInt3: Integer` |
| `0x0060F4A4` | `procedure SetgDbgFloat3(arg: Float)` |
| `0x0060F4B8` | `function GetgDbgFloat3: Float` |
| `0x0060F4C8` | `procedure SetgDbgBool3(arg: Boolean)` |
| `0x0060F4DC` | `function GetgDbgBool3: Boolean` |
| `0x0060F544` | `procedure SetgDbgInt4(arg: Integer)` |
| `0x0060F558` | `function GetgDbgInt4: Integer` |
| `0x0060F560` | `procedure SetgDbgFloat4(arg: Float)` |
| `0x0060F574` | `function GetgDbgFloat4: Float` |
| `0x0060F584` | `procedure SetgDbgBool4(arg: Boolean)` |
| `0x0060F598` | `function GetgDbgBool4: Boolean` |
| `0x0060F64C` | `function RandomExt(): Float` |
| `0x0060F69C` | `function GetRandomKey: Integer` |
| `0x0060F6A4` | `procedure SetRandomKey(key: Integer)` |
| `0x0060F6BC` | `procedure GetRandomExtKey64(var key0: Integer; var key1: Integer)` |
| `0x0060F6DC` | `procedure SetRandomExtKey64(const key0, key1: Integer)` |
| `0x0060F9E0` | `function IsPointInHex(const px, py, x0, y0, x1, y1, x2, y2, x3, y3, x4, y4, x5, y5: Float): Boolean` |
| `0x0060FB84` | `function RegExprCreate(const expression: String): Integer` |
| `0x0060FBA8` | `procedure RegExprFree(const reghnd: Integer)` |
| `0x0060FBD0` | `procedure RegExprExpression(const reghnd: Integer; const expression: String)` |
| `0x0060FBFC` | `function RegExprExec(const reghnd: Integer; const input: String): Boolean` |
| `0x0060FC2C` | `function RegExprExecPos(const reghnd: Integer; const input: String; offset: Integer): Boolean` |
| `0x0060FC6C` | `function RegExprExecNext(const reghnd: Integer): Boolean` |
| `0x0060FC98` | `function RegExprMatchCount(const reghnd: Integer): Integer` |
| `0x0060FCC4` | `function RegExprMatchPos(const reghnd, idx: Integer): Integer` |
| `0x0060FCF4` | `function RegExprMatchLen(const reghnd, idx: Integer): Integer` |
| `0x0060FD24` | `function RegExprMatch(const reghnd, idx: Integer): String` |
| `0x0060FEAC` | `procedure WriteInteger(const fs: Integer; const val: Integer)` |
| `0x0060FEF0` | `procedure WriteFloat(const fs: Integer; const val: Float)` |
| `0x0060FF34` | `procedure WriteBoolean(const fs: Integer; const val: Boolean)` |
| `0x00610040` | `procedure ReadInteger(const fs: Integer; var val: Integer)` |
| `0x00610084` | `procedure ReadFloat(const fs: Integer; var val: Float)` |
| `0x006100C8` | `procedure ReadBoolean(const fs: Integer; var val: Boolean)` |
| `0x00610210` | `procedure SeekInteger(const fs: Integer)` |
| `0x00610254` | `procedure SeekFloat(const fs: Integer)` |
| `0x00610298` | `procedure SeekBoolean(const fs: Integer)` |
| `0x0061171C` | `function GetMonitorDPIFromPoint(screenx, screeny: integer): integer` |
| `0x00651534` | `procedure AssignTrackPointFromParent(const gohandle: Integer)` |
| `0x006550B8` | `function OctreeRayCastIntersect(gohandle: Integer; rs_x, rs_y, rs_z: Float; dir_x, dir_y, dir_z: Float; var p_x, p_y, p_z: Float; var n_x, n_y, n_z: Float): Boolean` |
| `0x00655150` | `function OctreeRayCastIntersectChildren(gohandle: Integer; rs_x, rs_y, rs_z: Float; dir_x, dir_y, dir_z: Float; var p_x, p_y, p_z: Float; var n_x, n_y, n_z: Float): Boolean` |
| `0x006554E4` | `function GetWallMaxCollidedCount(gohandle: Integer): Integer` |
| `0x0066223C` | `function GetAngleViaDirectionByHandle(grhandle: Integer): Float` |
| `0x0066226C` | `function GetInvertAngleViaDirectionByHandle(grhandle: Integer): Float` |
| `0x006637BC` | `procedure SetMinMaxGridCols(grhandle: Integer; mincol: Integer; maxcol: Integer)` |
| `0x006637E4` | `procedure GetMinMaxGridCols(grhandle: Integer; var mincol: Integer; var maxcol: Integer)` |
| `0x0067B6F4` | `function SetMinimapTextureToMaterial(const material: String): Boolean` |
| `0x006854CC` | `function LanIpToInt(const aip: String): Integer` |
| `0x0068599C` | `procedure RecordSynchStackIntByIndex(index: Integer)` |
| `0x006859B8` | `procedure RecordSynchStackIntByIndexTestChanges(index: Integer)` |
| `0x006859D4` | `procedure RecordSynchStackFloatByIndex(index: Integer)` |
| `0x006859F0` | `procedure RecordSynchStackFloatByIndexTestChanges(index: Integer)` |
| `0x00685A44` | `procedure RecordSynchStackIntByName(const name: String)` |
| `0x00685A78` | `procedure RecordSynchStackIntByNameTestChanges(const name: String)` |
| `0x00685AAC` | `procedure RecordSynchStackFloatByName(const name: String)` |
| `0x00685AE0` | `procedure RecordSynchStackFloatByNameTestChanges(const name: String)` |
| `0x00685B7C` | `procedure RecordSynchIntRegister(const index: Integer)` |
| `0x00685B98` | `procedure RecordSynchFloatRegister(const index: Integer)` |
| `0x00685F1C` | `function RecordCustomWriteInteger(const value: Integer): Boolean` |
| `0x00685F54` | `function RecordCustomWriteInt24(const value: Integer): Boolean` |
| `0x00685F8C` | `function RecordCustomWriteSmallInt(const value: SmallInt): Boolean` |
| `0x0068603C` | `function RecordCustomWriteBoolean(const value: Boolean): Boolean` |
| `0x00686074` | `function RecordCustomWriteFloat(const value: Float): Boolean` |
| `0x006860AC` | `function RecordCustomWritePackedFloat(const value, minfloat, maxfloat: Float): Boolean` |
| `0x00686240` | `function RecordCustomReadInteger: Integer` |
| `0x00686270` | `function RecordCustomReadInt24: Integer` |
| `0x006862A0` | `function RecordCustomReadSmallInt: Smallint` |
| `0x00686330` | `function RecordCustomReadBoolean: Boolean` |
| `0x00686360` | `function RecordCustomReadFloat: Float` |
| `0x0068639C` | `function RecordCustomReadPackedFloat(const minfloat, maxfloat: Float): Float` |
| `0x00686570` | `procedure LanSetOptimizedMinMaxFloat(min, max: float)` |
| `0x006865A0` | `procedure LanGetOptimizedMinMaxFloat(var min, max: float)` |
| `0x006865D4` | `procedure LanSetOptimizedMinMaxFloatDef(min, max: float)` |
| `0x006865F0` | `procedure LanGetOptimizedMinMaxFloatDef(var min, max: float)` |
| `0x006899D4` | `procedure SetMapIntValue(const key: String; value: Integer)` |
| `0x006899F4` | `function GetMapIntValue(const key: String): Integer` |
| `0x00689A14` | `procedure SetMapFloatValue(const key: String; value: Float)` |
| `0x00689A34` | `function GetMapFloatValue(const key: String): Float` |
| `0x00689A5C` | `function GetMapBoolValue(const key: String): Boolean` |
| `0x00689A7C` | `procedure SetMapBoolValue(const key: String; value: Boolean)` |
| `0x00689ADC` | `function GetMapIntValueInd(index: Integer): Integer` |
| `0x00689AFC` | `procedure SetMapIntValueInd(index: Integer; value: Integer)` |
| `0x00689B1C` | `function GetMapFloatValueInd(index: Integer): Float` |
| `0x00689B44` | `procedure SetMapFloatValueInd(index: Integer; value: Float)` |
| `0x00689B64` | `function GetMapBoolValueInd(index: Integer): Boolean` |
| `0x00689B84` | `procedure SetMapBoolValueInd(index: Integer; value: Boolean)` |
| `0x0068B124` | `procedure PathDataThreadMinPriority(const val : Integer)` |
| `0x0068B144` | `procedure PathDataThreadMaxPriority(const val : Integer)` |
| `0x0068B310` | `procedure MapAngleCollisionTagClear` |
| `0x0068B32C` | `function MapAngleCollisionTagCount : Integer` |
| `0x0068B348` | `function MapAngleCollisionTagAdd(startangle, endangle : Float; tag : Integer) : Integer` |
| `0x0068B384` | `procedure MapAngleCollisionTagDelete(index : Integer)` |
| `0x0068B3AC` | `procedure GetMapAngleCollisionTagByIndex(index : Integer; var startangle : Float; var endangle : Float; var tag : Integer)` |
| `0x0068B3F0` | `function GetMapAngleCollisionTagExists(tag : Integer) : Boolean` |
| `0x0068B418` | `function GetMapAngleCollisionTagByAngle(angle : Float) : Integer` |
| `0x0068B444` | `procedure MapAngleCollisionTagLoadFromFile(const filename : String)` |
| `0x0068B46C` | `procedure MapAngleCollisionTagSaveToFile(const filename : String)` |
| `0x0068B6CC` | `function MapGetAngleByAxisX(const x, z, dx : Float) : Float` |
| `0x0068B6FC` | `function MapGetAngleByAxisZ(const x, z, dz : Float) : Float` |
| `0x0069A6A4` | `procedure SetProgressMaxDisabled(const v: Boolean)` |
| `0x0069A6C0` | `function GetProgressMaxDisabled: Boolean` |
| `0x006A916C` | `function GetMinute(): Integer` |
| `0x006A9190` | `procedure SetMinute(minute: Integer)` |
| `0x006A9FC8` | `function GetArrowAngle(startpositionx: Float; startpositiony: Float; startpositionz: Float; targetcoordsx: Float; targetcoordsy: Float; targetcoordsz: Float; speed: Float): Float` |
| `0x006AC264` | `procedure GetMapGeneratorRandomKey(var randkey0: Integer; var randkey1: Integer)` |
| `0x006AC28C` | `procedure SetMapGeneratorRandomKey(const randkey0, randkey1: Integer)` |
| `0x006AC2B4` | `procedure GetGlobalMapGeneratorRandomKey(var randkey0: Integer; var randkey1: Integer)` |
| `0x006AC2E0` | `procedure SetGlobalMapGeneratorRandomKey(const randkey0, randkey1: Integer)` |
| `0x006AEA38` | `procedure ExprotSnapShotFromCurrentMap(const sfile: String)` |
| `0x006B04CC` | `function GetMapMinHeight(const x, y: Integer; const rad: Float): Float` |
| `0x006B0738` | `function GetMapMaxHeight(const x, y: Integer; const rad: Float): Float` |
| `0x006B09A4` | `procedure GetMapMinMaxHeight(const x, y: Integer; const rad: Float; var minh, maxh: Float)` |
| `0x006B0C6C` | `function GetMapAverageAngle(const x, y: Integer; const rad: Float): Float` |
| `0x006B1254` | `function GetMapMinHeightInRect(const minx, miny, maxx, maxy: Float): Float` |
| `0x006B1434` | `function GetMapMaxHeightInRect(const minx, miny, maxx, maxy: Float): Float` |
| `0x006B1614` | `procedure GetMapMinMaxHeightInRect(const minx, miny, maxx, maxy: Float; var minh, maxh: Float)` |
| `0x006B22F0` | `function GetPointDecalDistance(const dhandle: Integer; const x, y: Float): Float` |
| `0x006B2574` | `function IsSegmentWallsIntersect(const x0, y0, x1, y1: Float; var xres, yres: Float): Boolean` |
| `0x006B25E0` | `procedure GetWallNearestPoint(const posx, posy: Float; var resx, resy: Float)` |
| `0x006B26B8` | `procedure GetWallNearestPointAndIndex(const posx, posy: Float; var resx, resy: Float; var index: Integer)` |
| `0x006B27A0` | `function IsPointInsideCastle(const posx, posy: Float): Boolean` |
| `0x006B2878` | `procedure StandPatternWithAngle(const plhandle: Integer; const patternname: String; const standx, standz, rotangle, minangle, maxangle: Float)` |
| `0x006B2B60` | `function StandPatternWithAngleAdv(const plhandle: Integer; const patternname: String; const standx, standz, rotangle, minangle, maxangle: Float; makegr, movetopar: Boolean; grname, parbase: String; parind: Integer): Integer` |
| `0x006B3120` | `procedure RandomHeightTerrain(const x, y: Integer; const round: Boolean; const mb: Integer; const delta: Float)` |
| `0x006B43D0` | `function GetDecalTexRollAngleByHandle(dechnd: Integer): Float` |
| `0x006B4400` | `procedure SetDecalTexRollAngleByHandle(dechnd: Integer; texrollangle: Float)` |
| `0x006B5054` | `procedure LibActorPrepareDistanceMaxByHandle(libactorhandle: Integer)` |
| `0x006B5094` | `procedure LibActorShaderLODListCalcMinMaxByHandle(libactorhandle: Integer; var min, max, minim, maxim: Float)` |
| `0x006B50B8` | `function GetLibActorDistanceMaxByHandle(libactorhandle: Integer): Float` |
| `0x006B50E8` | `procedure SetLibActorDistanceMaxByHandle(libactorhandle: Integer; distmax: Float)` |
| `0x006B623C` | `function GetLibActorLODActorCollectionDistanceMinByHandleByIndex(libactorhandle, lodactorcollectionindex, lodindex: Integer): Float` |
| `0x006B62B0` | `function GetLibActorLODActorCollectionDistanceMaxByHandleByIndex(libactorhandle, lodactorcollectionindex, lodindex: Integer): Float` |
| `0x006B6324` | `procedure SetLibActorLODActorCollectionDistanceMinMaxByHandleByIndex(libactorhandle, lodactorcollectionindex, lodindex: Integer; min, max: Float)` |
| `0x006B63D8` | `function DecalManagerGetDecalMaxDist: Float` |
| `0x006B63F4` | `procedure DecalManagerSetDecalMaxDist(maxdist: Float)` |
| `0x006B6818` | `function TopologyGetMaxZoneSize: Integer` |
| `0x006B6844` | `procedure TopologySetMaxZoneSize(val: Integer)` |
| `0x006B6DC8` | `function TopologyGetZoneTrackPointsCountByIndex(ind: Integer): Integer` |
| `0x006B6E50` | `procedure TopologyGetZoneTrackPointCoordsByIndex(tzind, tpind: Integer; var x, y: Float)` |
| `0x006B81E0` | `function GetFOWLerpFactor: Float` |
| `0x006B8204` | `procedure SetFOWLerpFactor(val: Float)` |
| `0x006B855C` | `procedure SetFOWFillMaxNum(val: Integer)` |
| `0x006B8584` | `function GetFOWFillMaxNum: Integer` |
| `0x006BBB08` | `procedure SetSndSoundMaxRadius(maxradius: Float; sound: Integer)` |
| `0x006BBB70` | `function GetSndSoundMaxRadius(sound: Integer): Float` |
| `0x006BBB94` | `procedure SetSndSoundMinDist(value: Float; sound: Integer)` |
| `0x006BBBB0` | `function GetSndSoundMinDist(sound: Integer): Float` |
| `0x006BBBD4` | `procedure SetSndSoundMaxDist(value: Float; sound: Integer)` |
| `0x006BBBF0` | `function GetSndSoundMaxDist(sound: Integer): Float` |
| `0x006BBC14` | `procedure SetSndSoundInsideConeAngle(value: Float; sound: Integer)` |
| `0x006BBC30` | `function GetSndSoundInsideConeAngle(sound: Integer): Float` |
| `0x006BBC54` | `procedure SetSndSoundOutsideConeAngle(value: Float; sound: Integer)` |
| `0x006BBC70` | `function GetSndSoundOutsideConeAngle(sound: Integer): Float` |
| `0x006BBD08` | `procedure SetSndSoundRandomOffset(value: Integer; sound: Integer)` |
| `0x006BBD24` | `function GetSndSoundRandomOffset(sound: Integer): Integer` |
| `0x006BBEE0` | `function GetAbsSoundManagerListenerAsObject : Boolean` |
| `0x006BBF0C` | `procedure SetAbsSoundManagerListenerAsObject(const val : Boolean)` |
| `0x006C31C4` | `function GetFloatValueByName(const name: String): Float` |
| `0x006C31E4` | `procedure SetFloatValueByName(const name: String; value: Float)` |
| `0x006C3200` | `function GetIntValueByName(const name: String): Integer` |
| `0x006C3218` | `procedure SetIntValueByName(const name: String; value: Integer)` |
| `0x006C3254` | `function GetBoolValueByName(const name: String): Boolean` |
| `0x006C326C` | `procedure SetBoolValueByName(const name: String; value: Boolean)` |
| `0x006C32C0` | `function GetFloatValueByIndex(index: Integer): Float` |
| `0x006C32E0` | `procedure SetFloatValueByIndex(index: Integer; value: Float)` |
| `0x006C32FC` | `function GetIntValueByIndex(index: Integer): Integer` |
| `0x006C3314` | `procedure SetIntValueByIndex(index: Integer; value: Integer)` |
| `0x006C3330` | `function GetBoolValueByIndex(index: Integer): Boolean` |
| `0x006C3348` | `procedure SetBoolValueByIndex(index: Integer; value: Boolean)` |
| `0x006C33FC` | `procedure ArrayAffineVectorPush(x, y, z: Float)` |
| `0x006C342C` | `procedure ArrayAffineVectorPop(var x: Float; var y: Float; var z: Float)` |
| `0x006C3460` | `procedure ArrayAffineVectorSetValueByIndex(index: Integer; x, y, z: Float)` |
| `0x006C34A8` | `procedure ArrayAffineVectorGetValueByIndex(index: Integer; var x: Float; var y: Float; var z: Float)` |
| `0x006C34F4` | `procedure ArrayAffineVectorSwap(index0, index1: Integer)` |
| `0x006C3538` | `procedure ArrayAffineVectorSetCount(count: Integer)` |
| `0x006C3550` | `function ArrayAffineVectorGetCount(): Integer` |
| `0x006C355C` | `procedure ArrayAffineVectorClear()` |
| `0x006C356C` | `procedure ArrayAffineVectorDeleteByRange(index0, index1: Integer)` |
| `0x006C35B4` | `procedure ArrayAffineVectorDeleteByIndex(index: Integer)` |
| `0x006C43F0` | `function GetAddrInteger(var v: Integer): Integer` |
| `0x006C43FC` | `function GetAddrFloat(var v: Float): Integer` |
| `0x006C4414` | `function GetAddrBoolean(var v: Boolean): Integer` |
| `0x006C4420` | `function GetAddrPointer(var v: Pointer): Integer` |
| `0x006C4494` | `function GetPtrInteger(var v: Integer): Pointer` |
| `0x006C44A0` | `function GetPtrFloat(var v: Float): Pointer` |
| `0x006C44B8` | `function GetPtrBoolean(var v: Boolean): Pointer` |
| `0x006C44C4` | `function GetPtrPointer(var v: Pointer): Pointer` |
| `0x006C44F4` | `function AddrToPointer(const addr: Integer): Pointer` |
| `0x006C4500` | `function PointerToAddr(const p: Pointer): Integer` |
| `0x006C7488` | `procedure SetUserIntValue(const key: String; value: Integer)` |
| `0x006C74AC` | `function GetUserIntValue(const key: String): Integer` |
| `0x006C74CC` | `procedure SetUserFloatValue(const key: String; value: Float)` |
| `0x006C74F0` | `function GetUserFloatValue(const key: String): Float` |
| `0x006C751C` | `function GetUserBoolValue(const key: String): Boolean` |
| `0x006C753C` | `procedure SetUserBoolValue(const key: String; value: Boolean)` |
| `0x006C75A8` | `function GetUserIntValueInd(index: Integer): Integer` |
| `0x006C75C8` | `procedure SetUserIntValueInd(index: Integer; value: Integer)` |
| `0x006C75EC` | `function GetUserFloatValueInd(index: Integer): Float` |
| `0x006C7618` | `procedure SetUserFloatValueInd(index: Integer; value: Float)` |
| `0x006C763C` | `function GetUserBoolValueInd(index: Integer): Boolean` |
| `0x006C765C` | `procedure SetUserBoolValueInd(index: Integer; value: Boolean)` |
| `0x006DE69C` | `procedure SetBehaviourBoolProperty(behaviour: Integer; const name: String; value: Boolean)` |
| `0x006DE6BC` | `procedure SetBehaviourIntProperty(behaviour: Integer; const name: String; value: Integer)` |
| `0x006DE6DC` | `procedure SetBehaviourFloatProperty(behaviour: Integer; const name: String; value: Float)` |
| `0x006DE750` | `procedure SetBehaviourVectorProperty(behaviour: Integer; const name: String; x, y, z, w: Float)` |
| `0x006DE778` | `procedure SetBehaviourAffineVectorProperty(behaviour: Integer; const name: String; x, y, z: Float)` |
| `0x006DE79C` | `function GetBehaviourBoolProperty(behaviour: Integer; const name: String): Boolean` |
| `0x006DE7BC` | `function GetBehaviourIntProperty(behaviour: Integer; const name: String): Integer` |
| `0x006DE7DC` | `function GetBehaviourFloatProperty(behaviour: Integer; const name: String): Float` |
| `0x006DE83C` | `procedure GetBehaviourVectorProperty(behaviour: Integer; const name: String; var x, y, z, w: Float)` |
| `0x006DE884` | `procedure GetBehaviourAffineVectorProperty(behaviour: Integer; const name: String; var x, y, z: Float)` |
| `0x006DF900` | `function GetPFXThorFXManagerMaxPoints(const managername: String): Integer` |
| `0x006DF940` | `procedure SetPFXThorFXManagerMaxPoints(const managername: String; const val: Integer)` |
| `0x006DFB88` | `function GetPFXFireFXManagerMaxParticles(const managername: String): Integer` |
| `0x006DFBC8` | `procedure SetPFXFireFXManagerMaxParticles(const managername: String; const val: Integer)` |
| `0x006E021C` | `function GetPFXFireFXManagerParticleInterval(const managername: String): Float` |
| `0x006E0264` | `procedure SetPFXFireFXManagerParticleInterval(const managername: String; const val: Float)` |
| `0x006E02A0` | `function GetPFXFireFXManagerUseInterval(const managername: String): Boolean` |
| `0x006E02E0` | `procedure SetPFXFireFXManagerUseInterval(const managername: String; const val: Boolean)` |
| `0x006E03C0` | `procedure EffectSourcePFXIsotropicExplosion(const effect: Integer; time: Float; mininitialspeed, maxinitialspeed: Float; nbparticles: Integer)` |
| `0x006E03EC` | `procedure EffectSourcePFXRingExplosion(const effect: Integer; time: Float; mininitialspeed, maxinitialspeed: Float; nbparticles: Integer)` |
| `0x006E0418` | `procedure EffectSourcePFXRingExplosionXY(const effect: Integer; time: Float; mininitialspeed, maxinitialspeed: Float; ringxvectorx, ringxvectory, ringxvectorz, ringyvectorx, ringyvectory, ringyvectorz: Float; nbparticles: Integer)` |
| `0x006E04A0` | `procedure EffectFireFXIsotropicExplosion(const effect: Integer; mininitialspeed, maxinitialspeed, lifeboostfactor: Float; nbparticles: Integer)` |
| `0x006E04E4` | `procedure EffectFireFXRingExplosion(const effect: Integer; mininitialspeed, maxinitialspeed, lifeboostfactor: Float; ringxvectorx, ringxvectory, ringxvectorz, ringyvectorx, ringyvectory, ringyvectorz: Float; nbparticles: Integer)` |
| `0x006F8C04` | `procedure SteamwrapWriteMiniDump(structuredexceptioncode: integer; var exceptioninfo: pointer; buildid: integer)` |
| `0x006F8C30` | `procedure SteamwrapSetMiniDumpComment(const msg: string)` |
| `0x006F8E48` | `function SteamwrapGetSecondsSinceAppActive: integer` |
| `0x006F8E60` | `function SteamwrapGetSecondsSinceComputerActive: integer` |
| `0x006F9064` | `function SteamwrapGetCurrentBatteryPower: integer` |
| `0x006F9870` | `function SteamwrapGetStatInt32(name: string; var data: integer): boolean` |
| `0x006F98D8` | `function SteamwrapGetStatFloat(name: string; var data: float): boolean` |
| `0x006F9940` | `function SteamwrapSetStatInt32(name: string; data: integer): boolean` |
| `0x006F99A8` | `function SteamwrapSetStatFloat(name: string; data: float): boolean` |
| `0x006F9E24` | `function SteamwrapGetUserStatInt32(const steamiduser: pointer; name: string; var data: integer): boolean` |
| `0x006F9E9C` | `function SteamwrapGetUserStatFloat(const steamiduser: pointer; name: string; var data: float): boolean` |
| `0x006FA51C` | `function SteamwrapGetGlobalStatInt64(statname: string; var data: pointer): boolean` |
| `0x006FA614` | `function SteamwrapGetGlobalStatHistoryInt64(statname: string; var data: pointer; cdata: integer): integer` |

### Misc — разное — 383

| VA | Объявление |
|---|---|
| `0x005FB194` | `procedure AddEditorFormInput(const skey: String; const slabel: String; const sdefault: String)` |
| `0x005FB1FC` | `procedure SetEditorFormButtonNames(const sok, scancel: String)` |
| `0x005FB268` | `function GetEditorFormValue(const skey: String): String` |
| `0x005FB280` | `function SetEditorCurrentControl(const skey: String): Boolean` |
| `0x005FB29C` | `function AddEditorControl(const skey: String; const slabel: String; const sclass: String): Boolean` |
| `0x005FB2BC` | `function SetEditorControlValue(const svalue: String): Boolean` |
| `0x005FB2D4` | `function AddEditorControlValue(const svalue: String): Boolean` |
| `0x00603958` | `procedure SetCurrentColorTableIndex(index : Integer)` |
| `0x00603978` | `function GetCurrentColorTableIndex : Integer` |
| `0x0060DE40` | `function IsElementByHandle(index: Integer): Boolean` |
| `0x0060DE5C` | `function GetObjectClassNameByHandle(ahandle: Integer): String` |
| `0x0060E2B4` | `procedure Inc(var a: Integer; b: Integer)` |
| `0x0060E2C4` | `procedure Dec(var a: Integer; b: Integer)` |
| `0x0060E3EC` | `function IsInRange(const val, min, max: Float): Boolean` |
| `0x0060EB34` | `function GetCirclesCountAroundCircle(const insideradius, outsideradius: Float): Integer` |
| `0x0060F24C` | `function DefaultSystemCodePage: Integer` |
| `0x0060F998` | `function GetTriangleCircleCenter(const x1, y1, x2, y2, x3, y3: Float; var xc, yc: Float): Boolean` |
| `0x0060F9BC` | `function GetTriangleCircleCenterTouchSides(const x1, y1, x2, y2, x3, y3: Float; var xc, yc: Float): Boolean` |
| `0x0060FA4C` | `function GetTriangleArea(const x0, y0, x1, y1, x2, y2: Float): Float` |
| `0x0060FD7C` | `function GetDetectClassName(const hnd: Integer): String` |
| `0x0060FDC8` | `function GetDetectClassInstance(const hnd: Integer): Boolean` |
| `0x006109B4` | `procedure GetWin32VideoControllerInfo(const parser: integer)` |
| `0x00611250` | `function IsAppInDEPExceptionList: boolean` |
| `0x00611258` | `function GetSystemDEPPolicy: integer` |
| `0x00611268` | `function GetDEPExcepted: boolean` |
| `0x00611270` | `function GetVirtualProtectFails: integer` |
| `0x006116E4` | `function CanSupportOldDpiAwareness(autoenable: boolean): boolean` |
| `0x0061173C` | `function GetLastOSError: integer` |
| `0x00611744` | `function GetOSErrorMessage(code: integer): string` |
| `0x006117E0` | `function GetProcAddress(handle: integer; const funcname: string; var addr: pointer): boolean` |
| `0x00611844` | `function AddProcAddress(handle: integer; const funcname, funcargsdesc: string): boolean` |
| `0x006118C4` | `function CreateFunction(const funcargsdesc: string; const addr: pointer): boolean` |
| `0x00611920` | `function IsFunctionExists(const funcargsdesc: string): boolean` |
| `0x006119E0` | `function RemoveFunction(const funcargsdesc: string): boolean` |
| `0x00655450` | `function GetWallCollidedCount(gohandle: Integer): Integer` |
| `0x006577D4` | `function GetLibMaterialShaderTexExCount(const mathnd: Integer): Integer` |
| `0x00660EE8` | `function GetGRHandleByIndex(const playername: String; groupindex: Integer): Integer` |
| `0x00675438` | `function IsKeyDown(vk: Integer): Boolean` |
| `0x00675450` | `function KeyPressed(minvkcode: Integer): Integer` |
| `0x00675468` | `function IsKeyDownByName(const sname: String): Boolean` |
| `0x00675484` | `function GetKeyCodeByName(const sname: String): Integer` |
| `0x0067549C` | `function GetKeyNameByCode(code: Integer): String` |
| `0x006764EC` | `procedure SetGUPProgressBarFullScreen(value: Boolean)` |
| `0x00676510` | `function GetGUPProgressBarFullScreen(): Boolean` |
| `0x006787E4` | `procedure GetCurrentMouseWorldCoord(var arayx, arayy, arayz: Float)` |
| `0x0067AFCC` | `procedure CreateSnapShot(ashowgui: Boolean)` |
| `0x0067B298` | `procedure CreateSnapShotExt(const showgui: Boolean; const filename: String; const w, h: Integer)` |
| `0x00686690` | `function HTTPGetData(const url: string; const conntimeout, recvtimeout, sendtimeout, maxfilesize: integer): string` |
| `0x006866DC` | `procedure HTTPGetPars(parser: Integer; const url: string; const conntimeout, recvtimeout, sendtimeout, maxfilesize: integer)` |
| `0x0068B060` | `procedure PathDataThreadTerminate` |
| `0x0068B074` | `procedure PathDataThreadResume` |
| `0x0068B088` | `procedure PathDataThreadSuspend` |
| `0x0068B09C` | `function PathDataThreadSuspended : Boolean` |
| `0x0068B0B0` | `procedure PathDataThreadSafeClean` |
| `0x0068B0C4` | `procedure PathDataThreadDeltaPriority(const val : Integer)` |
| `0x0068B0E4` | `procedure PathDataThreadDynamicPriority(const val : Boolean)` |
| `0x0068B104` | `procedure PathDataThreadStaticPriority(const val : Integer)` |
| `0x0068B1A4` | `function PathDataThreadCount : Integer` |
| `0x006A9204` | `procedure ClearEditManagerPickedObjects()` |
| `0x006AA600` | `function GetCountOfRaces(): Integer` |
| `0x006AA624` | `function GetRaceNameByIndex(index: Integer): String` |
| `0x006AA660` | `function GetCountOfObjectsByRaceName(const racename: String): Integer` |
| `0x006AA68C` | `function GetBaseNameOfObjectByIndex(const racename: String; index: Integer): String` |
| `0x006AA6CC` | `function GetRadiusBoxOfObjectByIndex(const racename: String; index: Integer): Float` |
| `0x006AA814` | `function GetIndexOfObjectByBaseName(const racename: String; const basename: String): Integer` |
| `0x006AA914` | `function GetCountUseableMaterialsOfObjectByIndex(const racename: String; index: Integer; indexmesh: Integer): Integer` |
| `0x006AA994` | `function GetUseableMaterialNameOfObjectByIndex(const racename: String; index: Integer; indexmesh: Integer; indexmaterial: Integer): String` |
| `0x006AABD4` | `procedure ScreenToWorldRayCast(ascreenx, ascreeny: Integer; var arayx, arayy, arayz: Float)` |
| `0x006AADB0` | `procedure ClearGameManagerPickedObjects()` |
| `0x006AB7C8` | `procedure SetPickedObjectsTargetPosition(x: Float; y: Float; z: Float)` |
| `0x006AC320` | `procedure SwitchApplication(const app: String; const params: String)` |
| `0x006AC360` | `procedure RestartApplication` |
| `0x006AC378` | `procedure RestartApplicationParam(const param: string)` |
| `0x006AC65C` | `procedure GetPickPosition(var x: Float; var y: Float; var z: Float)` |
| `0x006AC874` | `function GetSeasonType(): Integer` |
| `0x006AC89C` | `procedure SetSeasonType(index: integer)` |
| `0x006ACC60` | `procedure DestroyEditManagerPickedObjects()` |
| `0x006ACC78` | `procedure DestroyGameManagerPickedObjects()` |
| `0x006ACC90` | `procedure SetProgressingPauseMode(value: Boolean)` |
| `0x006ACCA8` | `function GetProgressingPauseMode:Boolean` |
| `0x006AE460` | `procedure GameManagerCancelBrush` |
| `0x006AE4C4` | `function GameManagerIsBrushMode:Boolean` |
| `0x006AE4F8` | `procedure GameManagerStartBrush` |
| `0x006AE538` | `procedure GameManagerStartSelection(const smode: String)` |
| `0x006AE55C` | `procedure GameManagerCancelSelection` |
| `0x006AE570` | `function GameManagerIsSelectionMode:Boolean` |
| `0x006AE584` | `procedure GameManagerBeginSelection` |
| `0x006AE598` | `procedure GameManagerEndSelection` |
| `0x006AE5AC` | `function GetGameManagerPickingMode: String` |
| `0x006AE5CC` | `function GetGameManagerRestrictSelection(): boolean` |
| `0x006AE5E0` | `procedure SetGameManagerRestrictSelection(value: boolean)` |
| `0x006AE5FC` | `function GetGameManagerSelectionUseStep(): boolean` |
| `0x006AE618` | `procedure SetGameManagerSelectionUseStep(value: boolean)` |
| `0x006AEDC4` | `procedure SetFullScreenMode(const amode: integer);` |
| `0x006AEDE4` | `function GetCurrentResolutionMode: Integer` |
| `0x006AEDFC` | `procedure SetDisplayMode(const mode: String)` |
| `0x006AEE3C` | `function GetDisplayMode: String` |
| `0x006AF918` | `procedure SetCurrentHDRIndex(hdrindex: Integer)` |
| `0x006AF940` | `function GetCurrentHDRIndex: Integer` |
| `0x006AF95C` | `procedure SetCurrentPHDRIndex(phdrindex: Integer)` |
| `0x006AF984` | `function GetCurrentPHDRIndex: Integer` |
| `0x006AFAFC` | `function GetDOFEnable(): Boolean` |
| `0x006AFB20` | `procedure SetDOFEnable(const val: Boolean)` |
| `0x006AFB48` | `function GetSSAOEnable(): Boolean` |
| `0x006AFB6C` | `procedure SetSSAOEnable(const val: Boolean)` |
| `0x006AFB94` | `function GetFXAAEnable(): Boolean` |
| `0x006AFBB8` | `procedure SetFXAAEnable(const val: Boolean)` |
| `0x006AFC54` | `procedure SetAntiAliasing(const val: String)` |
| `0x006AFCD8` | `function GetAntiAliasing: String` |
| `0x006AFD20` | `procedure SetVSyncMode(const val: String)` |
| `0x006AFD58` | `function GetVSyncMode: String` |
| `0x006AFDA4` | `function RayCastHeight(x, y: Float): Float` |
| `0x006B189C` | `function GetClimaticZoneIndexByParams(const tile: Integer): Integer` |
| `0x006B1BEC` | `function IsChildInCircle(const centerx, centery, radius: Float; const playername, basename: String): Boolean` |
| `0x006B1C8C` | `function GetPresetByParams(const zoneindex: Integer; const minheight, maxheight, angle: Float): Integer` |
| `0x006B1D0C` | `function GetTileIndex(const i, j: Integer): Integer` |
| `0x006B1D50` | `procedure SetTileIndex(const i, j, tile: Integer)` |
| `0x006B1D84` | `function GetTileName(const i, j: Integer): String` |
| `0x006B23EC` | `procedure BreakWallByGOHandle(const gohandle: Integer)` |
| `0x006B2464` | `procedure PrepareSpaceChildren` |
| `0x006B2484` | `function GetWallCount: Integer` |
| `0x006B24A8` | `function GetWallExtentsByIndex(wallindex: Integer; var leftx, leftz, rightx, rightz: Float): Boolean` |
| `0x006B2814` | `procedure UnloadPatterns(const binunload, objunload: Boolean)` |
| `0x006B28D8` | `procedure StandPattern(const plhandle: Integer; const patternname: String; const standx, standz, rotangle: Float)` |
| `0x006B2930` | `function StandPatternAdv(const plhandle: Integer; const patternname: String; const standx, standz, rotangle: Float; makegr, movetopar: Boolean; grname, parbase: String; parind: Integer): Integer` |
| `0x006B2D98` | `function GetPatternMaskWidth(const patternname: String): Integer` |
| `0x006B2DD4` | `function GetPatternMaskHeight(const patternname: String): Integer` |
| `0x006B2E10` | `function GetPatternMaskValue(const patternname: String; i, j: Integer): Boolean` |
| `0x006B2E54` | `function GetPatternOffsetX(const patternname: String): Float` |
| `0x006B2E9C` | `function GetPatternOffsetZ(const patternname: String): Float` |
| `0x006B2EE4` | `function GetPatternMaskStand(const patternname: String): Boolean` |
| `0x006B2F24` | `function GetPatternInvMaskStand(const patternname: String): Boolean` |
| `0x006B31C4` | `function GetHeightData(const x, y: Integer): Float` |
| `0x006B3300` | `procedure SetHeightData(const x, y: Integer; const cheightvalue: Float)` |
| `0x006B384C` | `procedure SetVisibilityCulling(const val: Boolean)` |
| `0x006B3884` | `function GetVisibilityCulling: Boolean` |
| `0x006B389C` | `procedure SetObjectBasedVisibilityCulling(const val: Boolean)` |
| `0x006B38D4` | `function GetObjectBasedVisibilityCulling: Boolean` |
| `0x006B3B70` | `procedure CadencerReset` |
| `0x006B3BC8` | `procedure CadencerProgress` |
| `0x006B3CBC` | `function GetCadencerMode: Integer` |
| `0x006B3CE0` | `procedure SetCadencerMode(v: Integer)` |
| `0x006B3D08` | `procedure CadencerRestart` |
| `0x006B3D24` | `function ASAPCadencerCount: Integer` |
| `0x006B3D2C` | `procedure UnlockUpdating` |
| `0x006B3DAC` | `procedure GetPerformanceView(var atotal, arender, aprogress, alansend, alanrecv: Boolean)` |
| `0x006B3E20` | `procedure SetPerformanceView(atotal, arender, aprogress, alansend, alanrecv: Boolean)` |
| `0x006B4660` | `procedure AddObjectToDestroyList(handle: Integer)` |
| `0x006B467C` | `function IsEditor: Boolean` |
| `0x006B4680` | `function IsEngine: Boolean` |
| `0x006B4684` | `function IsEditorAIX: Boolean` |
| `0x006B4688` | `function ApplicationInvalidate(const framespersecond: Float): Boolean` |
| `0x006B46F0` | `function FrameCount: Integer` |
| `0x006B4744` | `function GetFogEnable: Boolean` |
| `0x006B475C` | `procedure SetFogEnable(const val: Boolean)` |
| `0x006B4C08` | `function GetLibActorHandleByLibActorName(libactorname: String): Integer` |
| `0x006B4C6C` | `procedure LibActorReloadByHandle(libactorhandle: Integer)` |
| `0x006B4D84` | `procedure LibActorRequestPoolsByHandle(libactorhandle: Integer)` |
| `0x006B5074` | `procedure LibActorDestroyImposterHandlesByHandle(libactorhandle: Integer)` |
| `0x006B5290` | `procedure GetLibActorShaderLODListDataByHandle(libactorhandle: Integer; var enabled: Boolean; var childpooled: Integer; var childpoolmax: Float)` |
| `0x006B52CC` | `procedure SetLibActorShaderLODListDataByHandle(libactorhandle: Integer; enabled: Boolean; childpooled: Integer; childpoolmax: Float)` |
| `0x006B53E4` | `procedure LibActorShaderLODListClearByHandle(libactorhandle: Integer)` |
| `0x006B5408` | `function LibActorShaderLODListAddByHandle(libactorhandle: Integer): Integer` |
| `0x006B5440` | `function GetLibActorShaderLODListCountByHandle(libactorhandle: Integer): Integer` |
| `0x006B5468` | `procedure GetLibActorShaderLODDataByHandleByIndex(libactorhnd, shaderlodlistind: Integer; var shaderid, shaderidnobones, shaderidim: Integer; var matdisableinimmode, norenderinimmode: Boolean; var mindist, maxdist, mindistim, maxdistim: Float)` |
| `0x006B54F4` | `procedure SetLibActorShaderLODDataByHandleByIndex(libactorhnd, shaderlodlistind: Integer; var shaderid, shaderidnobones, shaderidim: Integer; var matdisableinimmode, norenderinimmode: Boolean; var mindist, maxdist, mindistim, maxdistim: Float)` |
| `0x006B569C` | `procedure LibActorDynamicUniformsClearByHandle(libactorhandle: Integer)` |
| `0x006B56C8` | `function LibActorDynamicUniformsAddByHandle(libactorhandle: Integer): Integer` |
| `0x006B570C` | `function GetLibActorDynamicUniformsCountByHandle(libactorhandle: Integer): Integer` |
| `0x006B573C` | `procedure GetLibActorDynamicUniformsDataByHandleByIndex(libactorhandle, dynuniind: Integer; var ui: Integer; var uv0x, uv0y, uv0z, uv0w, uv1x, uv1y, uv1z, uv1w, uv2x, uv2y, uv2z, uv2w, uv3x, uv3y, uv3z, uv3w: Float)` |
| `0x006B5820` | `procedure SetLibActorDynamicUniformsDataByHandleByIndex(libactorhandle, dynuniind: Integer; ui: Integer; uv0x, uv0y, uv0z, uv0w, uv1x, uv1y, uv1z, uv1w, uv2x, uv2y, uv2z, uv2w, uv3x, uv3y, uv3z, uv3w: Float)` |
| `0x006B58E4` | `function GetLibActorLODActorCollectionCountByHandle(libactorhandle: Integer): Integer` |
| `0x006B5908` | `function GetLibActorLODActorCollectionImpostoredByHandleByIndex(libactorhandle, lodactorcollectionindex: Integer): Boolean` |
| `0x006B5948` | `procedure SetLibActorLODActorCollectionImpostoredByHandleByIndex(libactorhandle, lodactorcollectionindex: Integer; impostored: Boolean)` |
| `0x006B5A70` | `procedure GetLibActorImpDataByHndByInd(hnd,ind: Integer; var fr,smpsz,light,ref,comp,magf,minf: Integer; var imblend,imalpha,impers,imrot: Boolean; var smpratbias,smpalpscale, bckr,bckg,bckb,bcka, boffx,boffy,boffz, alptresh, mindist: Float)` |
| `0x006B5BAC` | `procedure SetLibActorImpDataByHndByInd(hnd,ind: Integer; fr,smpsz,light,ref,comp,magf,minf: Integer; imblend,imalpha,impers,imrot: Boolean; smpratbias,smpalpscale, bckr,bckg,bckb,bcka, boffx,boffy,boffz, alptresh, mindist: Float)` |
| `0x006B5EFC` | `function GetLibActorImpCoronasAddByHandleByIndex(libactorhandle, lodactorcollectionindex: Integer): Integer` |
| `0x006B5F64` | `function GetLibActorImpCoronasCountByHandleByIndex(libactorhandle, lodactorcollectionindex: Integer): Integer` |
| `0x006B5FBC` | `procedure GetLibActorImpCoronasDataByHandleByIndex(libactorhandle, lodactorcollectionindex, coronasindex: Integer; var elevation: Float; var samples: Integer)` |
| `0x006B6048` | `procedure SetLibActorImpCoronasDataByHandleByIndex(libactorhandle, lodactorcollectionindex, coronasindex: Integer; elevation: Float; samples: Integer)` |
| `0x006B6198` | `procedure GetLibActorLODActorCollectionImposterSamplesPerAxisByHandleByIndex(libactorhandle, lodactorcollectionindex: Integer; var x: Integer; var y: Integer)` |
| `0x006B61F8` | `function GetLibActorLODActorCollectionCountLODByHandleByIndex(libactorhandle, lodactorcollectionindex: Integer): Integer` |
| `0x006B6410` | `function GetUseZLib: Boolean` |
| `0x006B6420` | `procedure SetUseZLib(val: Boolean)` |
| `0x006B7CB0` | `procedure WorldAddQuadTree(prior : Integer; testoption : String)` |
| `0x006B7D3C` | `function GetCountEditManagerPickedObjects(): Integer` |
| `0x006B7D54` | `function GetHandleEditManagerPickedObjects(const index: Integer): Integer` |
| `0x006B7DDC` | `function GetCountGameManagerPickedObjects(): Integer` |
| `0x006B7DF4` | `function GetHandleGameManagerPickedObjects(const index: Integer): Integer` |
| `0x006B7E7C` | `procedure SetGameManagerSelectionSettings(const pickgroups, pickgamemanagerplayer, pickplayableObject, pickfrustum: Boolean)` |
| `0x006B7EDC` | `procedure GetGameManagerSelectionSettings(var pickgroups, pickgamemanagerplayer, pickplayableObject, pickfrustum: Boolean)` |
| `0x006B8168` | `function GetFOWEnable: Boolean` |
| `0x006B817C` | `procedure SetFOWEnable(val: Boolean)` |
| `0x006B8198` | `function GetFOWElevation: Float` |
| `0x006B81BC` | `procedure SetFOWElevation(val: Float)` |
| `0x006B82E8` | `procedure AddFOWObjects(hnd: Integer)` |
| `0x006B8344` | `procedure DelFOWObjects(hnd: Integer)` |
| `0x006B8370` | `procedure ClearFOWObjects` |
| `0x006B8394` | `function GetFOWDovFunc: String` |
| `0x006B83BC` | `procedure SetFOWDovFunc(val: String)` |
| `0x006B8418` | `function GetFOWDefDov: Integer` |
| `0x006B8438` | `procedure SetFOWDefDov(val: Integer)` |
| `0x006B8460` | `procedure GetFOWColor(var r, g, b, a: Float)` |
| `0x006B84E0` | `procedure SetFOWColor(r, g, b, a: Float)` |
| `0x006B8524` | `function GetFOWLOSData(x, z: Float): Integer` |
| `0x006B85E4` | `procedure FOWBuildFull` |
| `0x006B8600` | `procedure GetFOWSmooth(var pcfsmooth: boolean; var pcffactor: float; var aasmooth: boolean; var aafactor: float)` |
| `0x006B8680` | `procedure SetFOWSmooth(pcfsmooth: boolean; pcffactor: float; aasmooth: boolean; aafactor: float)` |
| `0x006B8728` | `function GetAppParamExist: Boolean` |
| `0x006B8730` | `function GetAppParamCom(cmd: String; first: Integer): Integer` |
| `0x006B8788` | `function GetAppParamVal(ind: Integer; offset: Integer): String` |
| `0x006B87AC` | `function GetAppParamDef(cmd, def: String): String` |
| `0x006B8804` | `procedure SetClipCursor(const val: boolean)` |
| `0x006B881C` | `function GetClipCursor: boolean` |
| `0x006B88B0` | `procedure SetUseProgressControlThread(const val: boolean)` |
| `0x006B88C8` | `function GetUseProgressControlThread: boolean` |
| `0x006B88D8` | `procedure SetUseMultithreadedMode(const val: boolean)` |
| `0x006B88F0` | `function GetUseMultithreadedMode: boolean` |
| `0x006B8900` | `function GetPerfTotal(index: integer): Float` |
| `0x006B892C` | `function GetPerfRender(index: integer): Float` |
| `0x006B8958` | `function GetPerfProgress(index: integer): Float` |
| `0x006BC9F8` | `function PreloadAmbientThread(thread: Integer): Boolean` |
| `0x006BCA94` | `function RequestAmbientThread(thread: Integer): Boolean` |
| `0x006BCAF4` | `function UnloadAmbientThread(thread: Integer): Boolean` |
| `0x006C315C` | `procedure SwitchTo(const state: String)` |
| `0x006C318C` | `function GetValueByName(const name: String): String` |
| `0x006C31A8` | `procedure SetValueByName(const name: String; const value: String)` |
| `0x006C3288` | `function GetValueByIndex(index: Integer): String` |
| `0x006C32A4` | `procedure SetValueByIndex(index: Integer; const value: String)` |
| `0x006C3380` | `function GetIndexByName(const name: String): Integer` |
| `0x006C339C` | `function GetNameByIndex(index: Integer): String` |
| `0x006C33B8` | `procedure SetNameByIndex(index: Integer; const name: String)` |
| `0x006C33D4` | `procedure SetVarsCount(count: Integer)` |
| `0x006C33EC` | `function GetVarsCount(): Integer` |
| `0x006C35E0` | `procedure ArrayPushValue(value: Integer)` |
| `0x006C35F8` | `function ArrayPopValue(): Integer` |
| `0x006C3608` | `procedure ArraySetValueByIndex(index: Integer; value: Integer)` |
| `0x006C3638` | `function ArrayGetValueByIndex(index: Integer): Integer` |
| `0x006C3668` | `function ArrayGetIndexByValue(value: Integer): Integer` |
| `0x006C3680` | `procedure ArraySwapValues(index1: Integer; index2: Integer)` |
| `0x006C36C4` | `procedure ArraySetDirectCount(count: Integer)` |
| `0x006C36DC` | `procedure ArraySetCount(count: Integer)` |
| `0x006C3730` | `function ArrayGetCount(): Integer` |
| `0x006C373C` | `procedure ArrayClear()` |
| `0x006C37C4` | `procedure ArrayFlip()` |
| `0x006C3850` | `procedure ArraySort(grow: Boolean)` |
| `0x006C39B8` | `procedure ClearVariables()` |
| `0x006C39CC` | `function GetValueExistedByIndex(index: Integer): Boolean` |
| `0x006C39E4` | `function GetValueExistedByName(const name: String): Boolean` |
| `0x006C43AC` | `function GetAddrFunction(const func: String): Integer` |
| `0x006C43D8` | `function GetAddrGlobal(const keyclass, keyvar: String): Integer` |
| `0x006C442C` | `function GetAddrByte(var v: Byte): Integer` |
| `0x006C4444` | `function GetAddrWord(var v: Word): Integer` |
| `0x006C4450` | `function GetPtrFunction(const func: String): Pointer` |
| `0x006C447C` | `function GetPtrGlobal(const keyclass, keyvar: String): Pointer` |
| `0x006C44D0` | `function GetPtrByte(var v: Byte): Pointer` |
| `0x006C44E8` | `function GetPtrWord(var v: Word): Pointer` |
| `0x006C450C` | `procedure GetMem(var p: Pointer; size: Integer)` |
| `0x006C4548` | `procedure ReallocMem(var p: Pointer; size: Integer)` |
| `0x006C4584` | `procedure FreeMem(const p: Pointer)` |
| `0x006C460C` | `procedure FillMem(var p: Pointer; size, val: Integer)` |
| `0x006C4650` | `function Assigned(const p: Pointer): Boolean` |
| `0x006C4A0C` | `procedure EvaluateCode(const code: String)` |
| `0x006C4A34` | `function EvaluateCodeThread(const code: String): Boolean` |
| `0x006C4A5C` | `procedure LockThreadAcquire` |
| `0x006C4A7C` | `procedure LockThreadRelease` |
| `0x006C547C` | `function CreateTypeBase(const typ: Pointer): Pointer` |
| `0x006C549C` | `procedure DestroyTypeBase(const typ: Pointer; var addr: Pointer)` |
| `0x006C54B8` | `procedure ConstructorTypeBase(const typ, addr: Pointer)` |
| `0x006C54D0` | `procedure DestructorTypeBase(const typ, addr: Pointer)` |
| `0x006C54E8` | `function GetTypeNameByTypeBase(const typ: Pointer): String` |
| `0x006C5510` | `function GetTypeBaseByTypeName(const typnam: String; const findinserialtypes: Boolean): Pointer` |
| `0x006C561C` | `function DScriptIsSameTypeBase(const typ1, typ2: Pointer; const compared: Boolean): Boolean` |
| `0x006C5638` | `procedure DScriptAssignDataTypeBase(const typsrc, typdst, addrsrc, addrdst: Pointer; const compared: Boolean)` |
| `0x006C7440` | `procedure SetUserValue(const key: String; const value: String)` |
| `0x006C7464` | `function GetUserValue(const key: String): String` |
| `0x006C7560` | `procedure SetUserValueInd(index: Integer; const value: String)` |
| `0x006C7584` | `function GetUserValueInd(index: Integer): String` |
| `0x006C7700` | `function UserCreateProfile(const aname: String): Boolean` |
| `0x006C774C` | `function UserSelectProfile(const aname: String): Boolean` |
| `0x006C7D80` | `function UserProfileReplayIndex(const aname: String): Integer` |
| `0x006C805C` | `function UserProfileCustomIndex(const aname: String): Integer` |
| `0x006C807C` | `function UserGetProfileName: String` |
| `0x006C809C` | `function UserGetProfileNameByIndex(aindex: Integer): String` |
| `0x006C8168` | `function UserGetProfilesCount: Integer` |
| `0x006C82BC` | `function UserGetProfileReplaysCount: Integer` |
| `0x006C82D0` | `function UserGetProfileReplayByIndex(aindex: Integer): String` |
| `0x006C83FC` | `function UserGetProfileCustomsCount: Integer` |
| `0x006C8410` | `function UserGetProfileCustomByIndex(aindex: Integer): String` |
| `0x006C8550` | `procedure UserProfileRefreshReplaysList` |
| `0x006C8564` | `procedure UserProfileRefreshCustomsList` |
| `0x006C8578` | `procedure UserProfileRefreshProfilesList` |
| `0x006C858C` | `procedure SetUserProfileCustomsRoot(const customsroot: String)` |
| `0x006C85A0` | `function GetUserProfileCustomsRoot: String` |
| `0x006DEAA0` | `function GetPFXManagerExisted(const managername: String): Boolean` |
| `0x006DEAC8` | `function GetOrCreatePFXManager(const managername: String): Integer` |
| `0x006DEB1C` | `function GetPFXManagerType(const managername: String): String` |
| `0x006DEB6C` | `procedure SetPFXManagerType(const managername, pfxtype: String)` |
| `0x006DEBB4` | `procedure DestroyPFXManager(const managername: String)` |
| `0x006DEC60` | `function GetPFXPerlinPFXManagerExisted(const managername: String): Boolean` |
| `0x006DEC9C` | `function GetPFXPerlinPFXManagerParticleCount(const managername: String): Integer` |
| `0x006DECDC` | `function GetPFXPerlinPFXManagerZSort(const managername: String): Boolean` |
| `0x006DED1C` | `procedure SetPFXPerlinPFXManagerZSort(const managername: String; const val: Boolean)` |
| `0x006DED58` | `function GetPFXPerlinPFXManagerZTest(const managername: String): Boolean` |
| `0x006DED98` | `procedure SetPFXPerlinPFXManagerZTest(const managername: String; const val: Boolean)` |
| `0x006DEDD4` | `procedure GetPFXPerlinPFXManagerAcceleration(const managername: String; var x: Float; var y: Float; var z: Float)` |
| `0x006DEE28` | `procedure SetPFXPerlinPFXManagerAcceleration(const managername: String; const x, y, z: Float)` |
| `0x006DEE94` | `function GetPFXPerlinPFXManagerFriction(const managername: String): Float` |
| `0x006DEEDC` | `procedure SetPFXPerlinPFXManagerFriction(const managername: String; const val: Float)` |
| `0x006DEF18` | `function GetPFXPerlinPFXManagerBlendingMode(const managername: String): String` |
| `0x006DEF70` | `procedure SetPFXPerlinPFXManagerBlendingMode(const managername: String; const val: String)` |
| `0x006DEFC4` | `function GetPFXPerlinPFXManagerMixLSDiff0Factor(const managername: String): Float` |
| `0x006DF010` | `procedure SetPFXPerlinPFXManagerMixLSDiff0Factor(const managername: String; const val: Float)` |
| `0x006DF050` | `function GetPFXPerlinPFXManagerMixLSDiff0(const managername: String): Boolean` |
| `0x006DF090` | `procedure SetPFXPerlinPFXManagerMixLSDiff0(const managername: String; const val: Boolean)` |
| `0x006DF0D0` | `function GetPFXPerlinPFXManagerParticleSize(const managername: String): Float` |
| `0x006DF120` | `procedure SetPFXPerlinPFXManagerParticleSize(const managername: String; const val: Float)` |
| `0x006DF160` | `function GetPFXPerlinPFXManagerShareLibMaterialName(const managername: String): String` |
| `0x006DF1B4` | `procedure SetPFXPerlinPFXManagerShareLibMaterialName(const managername: String; const val: String)` |
| `0x006DF1F4` | `function GetPFXPerlinPFXManagerRotation(const managername: String): Float` |
| `0x006DF240` | `procedure SetPFXPerlinPFXManagerRotation(const managername: String; const val: Float)` |
| `0x006DF280` | `function GetPFXPerlinPFXManagerAspectRatio(const managername: String): Float` |
| `0x006DF2CC` | `procedure SetPFXPerlinPFXManagerAspectRatio(const managername: String; const val: Float)` |
| `0x006DF30C` | `function GetPFXPerlinPFXManagerColorMode(const managername: String): String` |
| `0x006DF368` | `procedure SetPFXPerlinPFXManagerColorMode(const managername: String; const val: String)` |
| `0x006DF444` | `function GetPFXPerlinPFXManagerSmoothness(const managername: String): Float` |
| `0x006DF490` | `procedure SetPFXPerlinPFXManagerSmoothness(const managername: String; const val: Float)` |
| `0x006DF4D0` | `function GetPFXPerlinPFXManagerBrightness(const managername: String): Float` |
| `0x006DF51C` | `procedure SetPFXPerlinPFXManagerBrightness(const managername: String; const val: Float)` |
| `0x006DF55C` | `function GetPFXPerlinPFXManagerGamma(const managername: String): Float` |
| `0x006DF5A8` | `procedure SetPFXPerlinPFXManagerGamma(const managername: String; const val: Float)` |
| `0x006DF5E8` | `function GetPFXPerlinPFXManagerNoiseSeed(const managername: String): Integer` |
| `0x006DF628` | `procedure SetPFXPerlinPFXManagerNoiseSeed(const managername: String; const val: Integer)` |
| `0x006DF668` | `function GetPFXPerlinPFXManagerNoiseScale(const managername: String): Integer` |
| `0x006DF6A8` | `procedure SetPFXPerlinPFXManagerNoiseScale(const managername: String; const val: Integer)` |
| `0x006DF6E8` | `function GetPFXPerlinPFXManagerNoiseAmplitude(const managername: String): Integer` |
| `0x006DF728` | `procedure SetPFXPerlinPFXManagerNoiseAmplitude(const managername: String; const val: Integer)` |
| `0x006DF840` | `function GetPFXFountainFXManagerExisted(const managername: String): Boolean` |
| `0x006DF860` | `function GetPFXTrailFXManagerExisted(const managername: String): Boolean` |
| `0x006DF880` | `function GetPFXAtmosphereFXManagerExisted(const managername: String): Boolean` |
| `0x006DF8A0` | `function GetPFXSpriteFXManagerExisted(const managername: String): Boolean` |
| `0x006DF8C0` | `function GetPFXAnimatedSpriteFXManagerExisted(const managername: String): Boolean` |
| `0x006DF8E0` | `function GetPFXThorFXManagerExisted(const managername: String): Boolean` |
| `0x006DF980` | `function GetPFXFireFXManagerExisted(const managername: String): Boolean` |
| `0x006DF9A0` | `function GetPFXFireFXManagerParticleCount(const managername: String): Integer` |
| `0x006DF9E0` | `procedure GetPFXFireFXManagerFireDir(const managername: String; var x: Float; var y: Float; var z: Float; var w: Float)` |
| `0x006DFA58` | `procedure SetPFXFireFXManagerFireDir(const managername: String; x, y, z, w: Float)` |
| `0x006DFAB4` | `procedure GetPFXFireFXManagerInitialDir(const managername: String; var x: Float; var y: Float; var z: Float; var w: Float)` |
| `0x006DFB2C` | `procedure SetPFXFireFXManagerInitialDir(const managername: String; x, y, z, w: Float)` |
| `0x006DFC08` | `function GetPFXFireFXManagerParticleSize(const managername: String): Float` |
| `0x006DFC50` | `procedure SetPFXFireFXManagerParticleSize(const managername: String; const val: Float)` |
| `0x006DFC8C` | `procedure GetPFXFireFXManagerInnerColor(const managername: String; var r: Float; var g: Float; var b: Float; var a: Float)` |
| `0x006DFD04` | `procedure SetPFXFireFXManagerInnerColor(const managername: String; r, g, b, a: Float)` |
| `0x006DFD50` | `procedure GetPFXFireFXManagerOuterColor(const managername: String; var r: Float; var g: Float; var b: Float; var a: Float)` |
| `0x006DFDC8` | `procedure SetPFXFireFXManagerOuterColor(const managername: String; r, g, b, a: Float)` |
| `0x006DFE14` | `function GetPFXFireFXManagerFireDensity(const managername: String): Float` |
| `0x006DFE5C` | `procedure SetPFXFireFXManagerFireDensity(const managername: String; const val: Float)` |
| `0x006DFE98` | `function GetPFXFireFXManagerFireEvaporation(const managername: String): Float` |
| `0x006DFEE0` | `procedure SetPFXFireFXManagerFireEvaporation(const managername: String; const val: Float)` |
| `0x006DFF1C` | `function GetPFXFireFXManagerFireCrown(const managername: String): Float` |
| `0x006DFF64` | `procedure SetPFXFireFXManagerFireCrown(const managername: String; const val: Float)` |
| `0x006DFFA0` | `function GetPFXFireFXManagerParticleLife(const managername: String): Integer` |
| `0x006DFFE0` | `procedure SetPFXFireFXManagerParticleLife(const managername: String; const val: Integer)` |
| `0x006E001C` | `function GetPFXFireFXManagerFireBurst(const managername: String): Float` |
| `0x006E0064` | `procedure SetPFXFireFXManagerFireBurst(const managername: String; const val: Float)` |
| `0x006E00A0` | `function GetPFXFireFXManagerFireRadius(const managername: String): Float` |
| `0x006E00E8` | `procedure SetPFXFireFXManagerFireRadius(const managername: String; const val: Float)` |
| `0x006E0124` | `function GetPFXFireFXManagerDisabled(const managername: String): Boolean` |
| `0x006E0164` | `procedure SetPFXFireFXManagerDisabled(const managername: String; const val: Boolean)` |
| `0x006E01A0` | `function GetPFXFireFXManagerPaused(const managername: String): Boolean` |
| `0x006E01E0` | `procedure SetPFXFireFXManagerPaused(const managername: String; const val: Boolean)` |
| `0x006E055C` | `procedure GetHighlightRenderSettings(var size, dirx, diry, dirz: Float; var texs: Integer; var scaling, visible: Boolean)` |
| `0x006E0634` | `procedure SetHighlightRenderSettings(const size, dirx, diry, dirz: Float; texs: Integer; scaling, visible: Boolean)` |
| `0x006EBD30` | `procedure DebugDrawClean(const name: string)` |
| `0x006EBDA0` | `procedure DebugDrawLine(const name: string; x1, y1, z1, x2, y2, z2: Float; r, g, b: Float)` |
| `0x006EBE80` | `procedure DebugDrawBox(const name: string; x, y, z, size, r, g, b: Float)` |
| `0x006EC364` | `procedure DebugDrawSphere(const name: string; x, y, z, radius: Float; slices, stacks: Integer; r, g, b: Float)` |
| `0x006EC668` | `procedure DebugDrawAxis(const name: string; x, y, z, nx, ny, nz: Float; r, g, b: Float)` |
| `0x006EC824` | `procedure DebugTextClean(const id: string)` |
| `0x006EC884` | `function DebugTextCount: Integer` |
| `0x006ECB20` | `function DebugTextIndexByID(const id: String): Integer` |
| `0x006ECB74` | `procedure DebugOGLInfo(var iglvendor: Integer; var iglversion: Integer; var iglrenderer: Integer)` |
| `0x00705B68` | `procedure ConsoleClear` |

### ScriptCore — StateMachine/проекты/запросы — 354

| VA | Объявление |
|---|---|
| `0x006840B4` | `function GetLanGameState(): Integer` |
| `0x006840C8` | `procedure SetLanGameState(val: Integer)` |
| `0x00684D00` | `procedure LanPublicServerGetClientStatesByIndex(aclientindex: Integer; var online, session, master, played: boolean)` |
| `0x00684DA8` | `procedure LanPublicServerGetClientStatesByClientID(aclientid: Integer; var online, session, master, played: boolean)` |
| `0x0068595C` | `procedure RecordSynchState(const name: String)` |
| `0x00685D34` | `function RecordCustomBeginStateMachine(const smhnd: Integer; const state: String): Boolean` |
| `0x00689BA4` | `procedure MapExecuteState(const state: String)` |
| `0x00689BFC` | `procedure MapClearStateMachine` |
| `0x00689C10` | `procedure MapClearStates` |
| `0x0068A2F8` | `procedure MapStateAdd(const state: String)` |
| `0x0068A330` | `procedure MapStateAddCodeLine(const state, codeline : String)` |
| `0x0068A394` | `procedure MapSetInitState(const state: String)` |
| `0x0068A3B4` | `function MapGetInitState : String` |
| `0x0068A3D4` | `procedure MapSetSaveState(const state : String)` |
| `0x0068A3F4` | `function MapGetSaveState : String` |
| `0x0068A414` | `procedure MapSetLoadState(const state : String)` |
| `0x0068A434` | `function MapGetLoadState : String` |
| `0x0068A454` | `procedure MapSetLoadFullState(const state : String)` |
| `0x0068A474` | `function MapGetLoadFullState : String` |
| `0x0068A494` | `procedure MapSetStateMachineStore(const val : Boolean)` |
| `0x0068A4AC` | `function MapGetStateMachineStore : Boolean` |
| `0x0068A4E4` | `procedure MapSetStateMachineReset(const val : Boolean)` |
| `0x0068A4FC` | `function MapGetStateMachineReset : Boolean` |
| `0x006AA3EC` | `function GetProjectMode(): String` |
| `0x006AA420` | `function GetProjectModeInt(): Integer` |
| `0x006AA43C` | `procedure SetProjectMode(const mode: String)` |
| `0x006AA528` | `procedure SetProjectModeInt(const mode: Integer)` |
| `0x006AC924` | `procedure ProjectLoadLodActor(const lodactorname: String)` |
| `0x006AC950` | `procedure ProjectLoadLodActorsAndMaterials(const race, base: String)` |
| `0x006ACA88` | `procedure ProjectLoadDecalMaterial(const libmat: String)` |
| `0x006ACAB4` | `procedure ProjectLoadPFXMaterial(const libmat: String)` |
| `0x006ACCB8` | `function SetProjectOptionAsInteger(const aoption: String; const avalue: Integer): Boolean` |
| `0x006ACD0C` | `function SetProjectOptionAsBoolean(const aoption: String; const avalue: Boolean): Boolean` |
| `0x006ACD64` | `function SetProjectOptionAsFloat(const aoption: String; const avalue: Float): Boolean` |
| `0x006ACDC0` | `function GetProjectOptionAsInteger(const aoption: String):Integer` |
| `0x006ACE14` | `function GetProjectOptionAsBoolean(const aoption: String):Boolean` |
| `0x006ACE68` | `function GetProjectOptionAsFloat(const aoption: String):Float` |
| `0x006ACECC` | `function SetProjectOptionAsString(const aoption: String; const avalue: String): Boolean` |
| `0x006ADA80` | `function GetProjectOptionAsString(const aoption: String):String` |
| `0x006AE450` | `procedure ProjectSaveOptions` |
| `0x006B8E6C` | `procedure ReloadProjectNeeded()` |
| `0x006C3100` | `function CurrentStateOwner(): Integer` |
| `0x006C3124` | `function CurrentState(): String` |
| `0x006C3174` | `procedure ExecuteState(const state: String)` |
| `0x006C39FC` | `procedure StateMachineClearVariables(const handle: Integer)` |
| `0x006C3A18` | `procedure StateMachineClear(const handle: Integer)` |
| `0x006C3A34` | `procedure StateMachineClearStates(const handle: Integer)` |
| `0x006C3A50` | `procedure StateMachineStateAdd(const handle: Integer; const state: String)` |
| `0x006C3A80` | `procedure StateMachineStateAddCodeLine(const handle: Integer; const state, codeline: String)` |
| `0x006C3AD0` | `procedure StateMachineLoadFromFile(const handle: Integer; const filename: String)` |
| `0x006C3AF4` | `function GetStateMachineFileName(const handle: Integer): String` |
| `0x006C3B1C` | `function StateMachineLibraryGet(const filename: String): Integer` |
| `0x006C3B38` | `function StateMachineLibraryGetOrAdd(const filename: String): Integer` |
| `0x006C3B54` | `function StateMachineLibraryGetOrAddExt(const filename: String; const compile: Boolean; const compilestate: String): Integer` |
| `0x006C3BA8` | `function StateMachineCurrentState(const handle: Integer): String` |
| `0x006C3BE8` | `procedure StateMachineSwitchTo(const handle: Integer; const state: String)` |
| `0x006C3C08` | `procedure StateMachineExecuteState(const handle: Integer; const state: String; const taghandle: Integer)` |
| `0x006C3C3C` | `function StateMachineGetValueByName(const handle: Integer; const name: String): String` |
| `0x006C3C74` | `procedure StateMachineSetValueByName(const handle: Integer; const name: String; const value: String)` |
| `0x006C3C98` | `function StateMachineGetFloatValueByName(const handle: Integer; const name: String): Float` |
| `0x006C3CC8` | `procedure StateMachineSetFloatValueByName(const handle: Integer; const name: String; value: Float)` |
| `0x006C3CEC` | `function StateMachineGetIntValueByName(const handle: Integer; const name: String): Integer` |
| `0x006C3D10` | `procedure StateMachineSetIntValueByName(const handle: Integer; const name: String; value: Integer)` |
| `0x006C3D34` | `function StateMachineGetBoolValueByName(const handle: Integer; const name: String): Boolean` |
| `0x006C3D58` | `procedure StateMachineSetBoolValueByName(const handle: Integer; const name: String; value: Boolean)` |
| `0x006C3D7C` | `function StateMachineGetValueByIndex(const handle: Integer; const index: Integer): String` |
| `0x006C3DB4` | `procedure StateMachineSetValueByIndex(const handle: Integer; const index: Integer; const value: String)` |
| `0x006C3DD8` | `function StateMachineGetFloatValueByIndex(const handle: Integer; const index: Integer): Float` |
| `0x006C3E08` | `procedure StateMachineSetFloatValueByIndex(const handle: Integer; const index: Integer; value: Float)` |
| `0x006C3E2C` | `function StateMachineGetIntValueByIndex(const handle: Integer; const index: Integer): Integer` |
| `0x006C3E50` | `procedure StateMachineSetIntValueByIndex(const handle: Integer; const index: Integer; value: Integer)` |
| `0x006C3E74` | `function StateMachineGetBoolValueByIndex(const handle: Integer; const index: Integer): Boolean` |
| `0x006C3E98` | `procedure StateMachineSetBoolValueByIndex(const handle: Integer; const index: Integer; value: Boolean)` |
| `0x006C3EBC` | `procedure StateMachineDeleteVariableByIndex(const handle: Integer; const index: Integer)` |
| `0x006C3EE0` | `function StateMachineGetIndexByName(const handle: Integer; const name: String): Integer` |
| `0x006C3F0C` | `function StateMachineGetNameByIndex(const handle: Integer; const index: Integer): String` |
| `0x006C3F38` | `procedure StateMachineSetNameByIndex(const handle: Integer; const index: Integer; const name: String)` |
| `0x006C3F5C` | `procedure StateMachineSetVarsCount(const handle: Integer; const count: Integer)` |
| `0x006C3F7C` | `function StateMachineGetVarsCount(const handle: Integer): Integer` |
| `0x006C3FA0` | `function StateMachineGetFileScript(const handle: Integer): String` |
| `0x006C3FD4` | `function GetCurrentStateMachineHandle(): Integer` |
| `0x006C3FE0` | `function StateMachineLibraryInstrMD5Checksum(): string` |
| `0x006C3FF8` | `function StateMachineLibraryCodeMD5Checksum(): string` |
| `0x006C4010` | `function StateMachineLibraryInstrSize(): Integer` |
| `0x006C4020` | `function StateMachineLibraryCodeSize(): Integer` |
| `0x006C4030` | `function StateMachineGlobalInstrSize(): Integer` |
| `0x006C4040` | `function StateMachineGlobalCodeSize(): Integer` |
| `0x006C4050` | `procedure StateMachineLibraryCompile()` |
| `0x006C40E4` | `procedure StateMachineLibraryFlush()` |
| `0x006C4178` | `procedure StateMachineLoadGlobal()` |
| `0x006C422C` | `procedure StateMachineReloadGlobal()` |
| `0x006C42E0` | `procedure StateMachineGlobalVariablesSaveToParser(const handle: Integer; const justkey: String; const excludeprivate, addchild: Boolean)` |
| `0x006C4318` | `procedure StateMachineGlobalVariablesLoadFromParser(const handle: Integer; const justkey: String; const excludeprivate, findkey: Boolean)` |
| `0x006C434C` | `procedure StateMachineGlobalVariablesLoadFromStack(const statemachinehandle: Integer; const keyclass, keyvar: String)` |
| `0x006C437C` | `procedure StateMachineGlobalVariablesSaveToStack(const statemachinehandle: Integer; const keyclass, keyvar: String)` |
| `0x006C48CC` | `procedure StateMachineReloadScript(const filescript: String)` |
| `0x006C48E8` | `procedure StateMachineReloadLibrary` |
| `0x006C4AF0` | `function StateMachineGetMapSMHandle: Integer` |
| `0x006C4B14` | `function StateMachineGetGrpSMHandle(const racename: String): Integer` |
| `0x006C4B3C` | `function StateMachineGetPlrSMHandle(const racename: String): Integer` |
| `0x006C4B64` | `function StateMachineGetObjSMHandle(const racename, basename: String): Integer` |
| `0x006C4BB4` | `function StateMachineGetGrpSMHandleByRaceInd(const raceind: Integer): Integer` |
| `0x006C4BDC` | `function StateMachineGetPlrSMHandleByRaceInd(const raceind: Integer): Integer` |
| `0x006C4C04` | `function StateMachineGetObjSMHandleByRaceInd(const raceind: Integer; const basename: String): Integer` |
| `0x006C4C64` | `function StateMachineGetOwnerHndByHandle(const smhnd: Integer): Integer` |
| `0x006C4C84` | `function StateMachineGetStateNameByInd(const smhnd, stateind: Integer): String` |
| `0x006C4CBC` | `function StateMachineGetStateIndByName(const smhnd: Integer; const statename: String): Integer` |
| `0x006C4CE4` | `function StateMachineGetStateHndByInd(const smhnd, stateind: Integer): Integer` |
| `0x006C4D10` | `function StateMachineGetStateHndByName(const smhnd: Integer; const statename: String): Integer` |
| `0x006C4D3C` | `procedure StateMachineExecuteByInd(const smhnd, stateind: Integer)` |
| `0x006C4D5C` | `procedure StateExecuteByHnd(const smhnd, statehnd: Integer)` |
| `0x006C4D94` | `procedure StateExecuteTagByHnd(const smhnd, statehnd, taghandle: Integer)` |
| `0x006C4DD0` | `procedure StateDirectExecuteByHnd(const smhnd, statehnd: Integer)` |
| `0x006C4E08` | `procedure StateDirectExecuteTagByHnd(const smhnd, statehnd, taghandle: Integer)` |
| `0x006C4E44` | `function StateMachineGetArgsCount(const smhnd: Integer): Integer` |
| `0x006C4E70` | `function StateMachineGetArgIndByKey(const smhnd: Integer; const key: String; const size: Integer): Integer` |
| `0x006C4EA4` | `function StateMachineGetArgKeyByInd(const smhnd, argind: Integer): String` |
| `0x006C4EF8` | `procedure StateMachineGetArgInfoByInd(const smhnd, argind: Integer; var key: String; var size: Integer; var typ: String; var enbl: Boolean)` |
| `0x006C4F8C` | `function StateMachineGetArgDataByInd(const smhnd, argind: Integer): Pointer` |
| `0x006C4FBC` | `procedure StateMachineSetArgDataByInd(const smhnd, argind: Integer; data: Pointer)` |
| `0x006C500C` | `function StateGetArgsCount(const statehnd: Integer): Integer` |
| `0x006C5030` | `function StateGetArgIndByKey(const statehnd: Integer; const key: String; const size: Integer): Integer` |
| `0x006C5058` | `function StateGetArgKeyByInd(const statehnd, argind: Integer): String` |
| `0x006C50E8` | `procedure StateGetArgInfoByInd(const statehnd, argind: Integer; var key: String; var size: Integer; var typ: String; var enbl: Boolean)` |
| `0x006C51C4` | `function StateGetArgDataByInd(const smhnd, statehnd, argind: Integer): Pointer` |
| `0x006C5230` | `procedure StateSetArgDataByInd(const smhnd, statehnd, argind: Integer; data: Pointer)` |
| `0x006C52B4` | `function GetStateOwnerStateMachineHandle(const statehnd: Integer): Integer` |
| `0x006C5344` | `function GetCurrentStateHandle: Integer` |
| `0x006C5350` | `function GetCurrentStateName: String` |
| `0x006C5380` | `function GetCurrentStateIndex: Integer` |
| `0x006C538C` | `function GetCurrentStateFileName: String` |
| `0x006C53E4` | `function GetCurrentStateMachineFileName: String` |
| `0x006C5400` | `function GetCurrentStateIsUsedFile: Boolean` |
| `0x006C5424` | `function GetCurrentStateUsedFileName: String` |
| `0x006C545C` | `function GetTagObjectByStateMachine(const smhnd: Integer): Integer` |
| `0x006C5F4C` | `function GetTriggerManagerStateMachineHandle(const triggername : String) : Integer` |
| `0x006C7680` | `procedure UserExecuteState(const state: String)` |
| `0x006C85B8` | `function GetUserProfileStateMachineHandle: Integer` |
| `0x006E5DBC` | `procedure QueryMachineSaveRuntimeToParserFile(const filename : String; states, variables, queries, custom, quest : Boolean)` |
| `0x006E5DE8` | `procedure QueryMachineLoadRuntimeFromParserFile(const filename : String; states, variables, queries, custom, quest : Boolean)` |
| `0x006E5E14` | `procedure QueryMachineDestroy` |
| `0x006E5E20` | `procedure QueryMachineSaveToParserFile(const filename : String)` |
| `0x006E5E3C` | `procedure QueryMachineLoadFromParserFile(const filename : String)` |
| `0x006E5E58` | `procedure QueryMachineCustomSaveToParserFile(const filename : String)` |
| `0x006E5E74` | `procedure QueryMachineCustomLoadFromParserFile(const filename : String)` |
| `0x006E5E90` | `function QueryMachineCustomQueryLast : Integer` |
| `0x006E5EA0` | `function QueryMachineCustomQueryGet(const id : String) : Integer` |
| `0x006E5EBC` | `procedure QueryMachineCustomQueryDelete(const id : String)` |
| `0x006E5ED8` | `procedure QueryMachineCustomQueryDeleteLast` |
| `0x006E5EE8` | `function QueryMachineCustomQueryCreate(const id : String) : Integer` |
| `0x006E5F04` | `procedure QueryMachineCustomQueriesClear` |
| `0x006E5F14` | `function QueryMachineCustomQueriesCount : Integer` |
| `0x006E5F24` | `function QueryMachineGetStateMachineHandle : Integer` |
| `0x006E5F34` | `procedure QueryMachineExecuteState(const state : String; const exechandle : Integer; const execevent : String)` |
| `0x006E5FC0` | `function QueryMachineIsResultHandle(const handle : Integer) : Boolean` |
| `0x006E5FDC` | `function QueryMachineIsQueryHandle(const handle : Integer) : Boolean` |
| `0x006E5FF8` | `function QueryMachineIsExecutedEvent : Boolean` |
| `0x006E600C` | `function QueryMachineGetExecutedHandle : Integer` |
| `0x006E6020` | `function QueryMachineGetExecutedEvent : String` |
| `0x006E604C` | `function QueryMachineGetOnInitial : String` |
| `0x006E6068` | `procedure QueryMachineSetOnInitial(const val : String)` |
| `0x006E6084` | `function QueryMachineGetOnAfterLoad : String` |
| `0x006E60A0` | `procedure QueryMachineSetOnAfterLoad(const val : String)` |
| `0x006E60BC` | `function QueryMachineGetOnBeforeSave : String` |
| `0x006E60D8` | `procedure QueryMachineSetOnBeforeSave(const val : String)` |
| `0x006E60F4` | `function QueryMachineGetCustomOnInitial : String` |
| `0x006E6110` | `procedure QueryMachineSetCustomOnInitial(const val : String)` |
| `0x006E612C` | `function QueryMachineGetCustomOnAfterLoad : String` |
| `0x006E6148` | `procedure QueryMachineSetCustomOnAfterLoad(const val : String)` |
| `0x006E6164` | `function QueryMachineGetCustomOnBeforeSave : String` |
| `0x006E6180` | `procedure QueryMachineSetCustomOnBeforeSave(const val : String)` |
| `0x006E619C` | `function QueryMachineGetQueriesHandle : Integer` |
| `0x006E61AC` | `function QueryMachineGetCustomQueriesHandle : Integer` |
| `0x006E61BC` | `function QueryMachineQueriesAdd(const querieshandle : Integer) : Integer` |
| `0x006E61E4` | `procedure QueryMachineQueriesDelete(const querieshandle, index : Integer)` |
| `0x006E6204` | `function QueryMachineQueriesInsert(const querieshandle, index : Integer) : Integer` |
| `0x006E6230` | `function QueryMachineQueriesRemove(const querieshandle, queryhandle : Integer) : Integer` |
| `0x006E626C` | `function QueryMachineQueriesCount(const querieshandle : Integer) : Integer` |
| `0x006E6290` | `procedure QueryMachineQueriesClear(const querieshandle : Integer)` |
| `0x006E62B0` | `function QueryMachineQueriesIndexOfByHandle(const querieshandle, queryhandle : Integer) : Integer` |
| `0x006E62EC` | `function QueryMachineQueriesIndexOfByID(const querieshandle : Integer; const cid : String) : Integer` |
| `0x006E6314` | `function QueryMachineQueriesGetByIndex(const querieshandle, index : Integer) : Integer` |
| `0x006E6340` | `function QueryMachineQueriesGetByID(const querieshandle : Integer; const cid : String) : Integer` |
| `0x006E636C` | `function QueryMachineQueriesGetOrAddByID(const querieshandle : Integer; const cid : String) : Integer` |
| `0x006E6398` | `function QueryMachineQueryGetQueries(const queryhandle : Integer) : Integer` |
| `0x006E63B8` | `procedure QueryMachineQueryAssign(const queryhandle, sourcequeryhandle : Integer)` |
| `0x006E63F0` | `procedure QueryMachineQueryExecuteState(const queryhandle : Integer; const state : String; const execevent : String)` |
| `0x006E642C` | `procedure QueryMachineQueryDoCreateExecute(const queryhandle : Integer)` |
| `0x006E644C` | `procedure QueryMachineQueryDoParserExecute(const queryhandle : Integer)` |
| `0x006E646C` | `procedure QueryMachineQueryDoCloseExecute(const queryhandle : Integer)` |
| `0x006E648C` | `procedure QueryMachineQueryDoProgressExecute(const queryhandle : Integer)` |
| `0x006E64AC` | `function QueryMachineQueryGetResults(const queryhandle : Integer) : Integer` |
| `0x006E64CC` | `function QueryMachineQueryGetID(const queryhandle : Integer) : String` |
| `0x006E6500` | `procedure QueryMachineQuerySetID(const queryhandle : Integer; const cid : String)` |
| `0x006E6528` | `function QueryMachineQueryGetTable(const queryhandle : Integer) : String` |
| `0x006E655C` | `procedure QueryMachineQuerySetTable(const queryhandle : Integer; const table : String)` |
| `0x006E6584` | `function QueryMachineQueryGetKey(const queryhandle : Integer) : String` |
| `0x006E65B8` | `function QueryMachineQueryGetKeyValue(const queryhandle : Integer) : String` |
| `0x006E65EC` | `procedure QueryMachineQuerySetKey(const queryhandle : Integer; const key : String)` |
| `0x006E6614` | `function QueryMachineQueryGetClear(const queryhandle : Integer) : Boolean)` |
| `0x006E6634` | `procedure QueryMachineQuerySetClear(const queryhandle : Integer; const clear : Boolean)` |
| `0x006E6654` | `function QueryMachineQueryGetHistory(const queryhandle : Integer) : Boolean)` |
| `0x006E6674` | `procedure QueryMachineQuerySetHistory(const queryhandle : Integer; const history : Boolean)` |
| `0x006E6694` | `function QueryMachineQueryGetIcon(const queryhandle : Integer) : String` |
| `0x006E66C8` | `procedure QueryMachineQuerySetIcon(const queryhandle : Integer; const icon : String)` |
| `0x006E66F0` | `function QueryMachineQueryGetStyle(const queryhandle : Integer) : String` |
| `0x006E6724` | `procedure QueryMachineQuerySetStyle(const queryhandle : Integer; const style : String)` |
| `0x006E674C` | `function QueryMachineQueryGetCaption(const queryhandle : Integer) : String` |
| `0x006E6780` | `function QueryMachineQueryGetCaptionValue(const queryhandle : Integer) : String` |
| `0x006E67B4` | `procedure QueryMachineQuerySetCaption(const queryhandle : Integer; const caption : String)` |
| `0x006E67DC` | `function QueryMachineQueryGetBackgroundImage(const queryhandle : Integer) : String` |
| `0x006E6810` | `procedure QueryMachineQuerySetBackgroundImage(const queryhandle : Integer; const backgroundimage : String)` |
| `0x006E6838` | `function QueryMachineQueryGetPriority(const queryhandle : Integer) : Integer` |
| `0x006E6858` | `procedure QueryMachineQuerySetPriority(const queryhandle : Integer; const priority : Integer)` |
| `0x006E6878` | `function QueryMachineQueryGetOnCreate(const queryhandle : Integer) : String` |
| `0x006E68AC` | `procedure QueryMachineQuerySetOnCreate(const queryhandle : Integer; const oncreate : String)` |
| `0x006E68D4` | `function QueryMachineQueryGetOnParser(const queryhandle : Integer) : String` |
| `0x006E6908` | `procedure QueryMachineQuerySetOnParser(const queryhandle : Integer; const onparser : String)` |
| `0x006E6930` | `function QueryMachineQueryGetOnClose(const queryhandle : Integer) : String` |
| `0x006E6964` | `procedure QueryMachineQuerySetOnClose(const queryhandle : Integer; const onclose : String)` |
| `0x006E698C` | `function QueryMachineQueryGetOnProgress(const queryhandle : Integer) : String` |
| `0x006E69C0` | `procedure QueryMachineQuerySetOnProgress(const queryhandle : Integer; const onprogress : String)` |
| `0x006E69E8` | `function QueryMachineQueryGetEnable(const queryhandle : Integer) : Boolean` |
| `0x006E6A08` | `procedure QueryMachineQuerySetEnable(const queryhandle : Integer; const enable : Boolean)` |
| `0x006E6A28` | `function QueryMachineQueryGetVisible(const queryhandle : Integer) : Boolean` |
| `0x006E6A48` | `procedure QueryMachineQuerySetVisible(const queryhandle : Integer; const visible : Boolean)` |
| `0x006E6A68` | `function QueryMachineQueryGetUnique(const queryhandle : Integer) : Boolean` |
| `0x006E6A88` | `procedure QueryMachineQuerySetUnique(const queryhandle : Integer; const unique : Boolean)` |
| `0x006E6AA8` | `function QueryMachineQueryGetUniqueEnable(const queryhandle : Integer) : Boolean` |
| `0x006E6AC8` | `procedure QueryMachineQuerySetUniqueEnable(const queryhandle : Integer; const uniqueenable : Boolean)` |
| `0x006E6AE8` | `function QueryMachineQueryGetCustomParserHandle(const queryhandle : Integer) : Integer` |
| `0x006E6B08` | `function QueryMachineResultsGetQuery(const resultshandle : Integer) : Integer` |
| `0x006E6B28` | `procedure QueryMachineResultsAssign(const resultshandle, sourceresultshandle : Integer)` |
| `0x006E6B60` | `function QueryMachineResultsAdd(const resultshandle : Integer) : Integer` |
| `0x006E6B88` | `procedure QueryMachineResultsDelete(const resultshandle, index : Integer)` |
| `0x006E6BA8` | `function QueryMachineResultsInsert(const resultshandle, index : Integer) : Integer` |
| `0x006E6BD4` | `function QueryMachineResultsRemove(const resultshandle, resulthandle : Integer) : Integer` |
| `0x006E6C10` | `function QueryMachineResultsCount(const resultshandle : Integer) : Integer` |
| `0x006E6C34` | `procedure QueryMachineResultsClear(const resultshandle : Integer)` |
| `0x006E6C54` | `function QueryMachineResultsIndexOfByHandle(const resultshandle, resulthandle : Integer) : Integer` |
| `0x006E6C90` | `function QueryMachineResultsIndexOfByID(const resultshandle : Integer; const cid : String) : Integer` |
| `0x006E6CB8` | `function QueryMachineResultsGetByIndex(const resultshandle, index : Integer) : Integer` |
| `0x006E6CE4` | `function QueryMachineResultsGetByID(const resultshandle : Integer; const cid : String) : Integer` |
| `0x006E6D10` | `function QueryMachineResultsGetOrAddByID(const resultshandle : Integer; const cid : String) : Integer` |
| `0x006E6D3C` | `function QueryMachineResultGetResults(const resulthandle : Integer) : Integer` |
| `0x006E6D5C` | `function QueryMachineResultGetQuery(const resulthandle : Integer) : Integer` |
| `0x006E6D84` | `procedure QueryMachineResultAssign(const resulthandle, sourceresulthandle : Integer)` |
| `0x006E6DBC` | `procedure QueryMachineResultExecuteState(const resulthandle : Integer; const state : String; const execevent : String)` |
| `0x006E6DF8` | `procedure QueryMachineResultDoParserExecute(const resulthandle : Integer)` |
| `0x006E6E18` | `procedure QueryMachineResultDoCreateExecute(const resulthandle : Integer)` |
| `0x006E6E38` | `procedure QueryMachineResultDoSelectExecute(const resulthandle : Integer)` |
| `0x006E6E58` | `procedure QueryMachineResultDoTargetCollideExecute(const resulthandle : Integer)` |
| `0x006E6E78` | `procedure QueryMachineResultDoTargetUncollideExecute(const resulthandle : Integer)` |
| `0x006E6E98` | `function QueryMachineResultGetID(const resulthandle : Integer) : String` |
| `0x006E6ECC` | `procedure QueryMachineResultSetID(const resulthandle : Integer; const cid : String)` |
| `0x006E6EF4` | `function QueryMachineResultGetTable(const resulthandle : Integer) : String` |
| `0x006E6F28` | `procedure QueryMachineResultSetTable(const resulthandle : Integer; const table : String)` |
| `0x006E6F50` | `function QueryMachineResultGetKey(const resulthandle : Integer) : String` |
| `0x006E6F84` | `function QueryMachineResultGetKeyValue(const resulthandle : Integer) : String` |
| `0x006E6FB8` | `procedure QueryMachineResultSetKey(const resulthandle : Integer; const key : String)` |
| `0x006E6FE0` | `function QueryMachineResultGetEnable(const resulthandle : Integer) : Boolean` |
| `0x006E7000` | `procedure QueryMachineResultSetEnable(const resulthandle : Integer; const enable : Boolean)` |
| `0x006E7020` | `function QueryMachineResultGetVisible(const resulthandle : Integer) : Boolean` |
| `0x006E7040` | `procedure QueryMachineResultSetVisible(const resulthandle : Integer; const visible : Boolean)` |
| `0x006E7060` | `function QueryMachineResultGetNextQuery(const resulthandle : Integer) : String` |
| `0x006E7094` | `procedure QueryMachineResultSetNextQuery(const resulthandle : Integer; const nextQuery : String)` |
| `0x006E70BC` | `function QueryMachineResultGetIcon(const resulthandle : Integer) : String` |
| `0x006E70F0` | `procedure QueryMachineResultSetIcon(const resulthandle : Integer; const icon : String)` |
| `0x006E7118` | `function QueryMachineResultGetStyle(const resulthandle : Integer) : String` |
| `0x006E714C` | `procedure QueryMachineResultSetStyle(const resulthandle : Integer; const style : String)` |
| `0x006E7174` | `function QueryMachineResultGetOnParser(const resulthandle : Integer) : String` |
| `0x006E71A8` | `procedure QueryMachineResultSetOnParser(const resulthandle : Integer; const onparser : String)` |
| `0x006E71D0` | `function QueryMachineResultGetOnCreate(const resulthandle : Integer) : String` |
| `0x006E7204` | `procedure QueryMachineResultSetOnCreate(const resulthandle : Integer; const oncreate : String)` |
| `0x006E722C` | `function QueryMachineResultGetOnSelect(const resulthandle : Integer) : String` |
| `0x006E7260` | `procedure QueryMachineResultSetOnSelect(const resulthandle : Integer; const onselect : String)` |
| `0x006E7288` | `function QueryMachineResultGetTagInteger(const resulthandle : Integer) : Integer` |
| `0x006E72A8` | `procedure QueryMachineResultSetTagInteger(const resulthandle : Integer; const taginteger : Integer)` |
| `0x006E72C8` | `function QueryMachineResultGetTagString(const resulthandle : Integer) : String` |
| `0x006E72FC` | `procedure QueryMachineResultSetTagString(const resulthandle : Integer; const tagstring : String)` |
| `0x006E7324` | `function QueryMachineResultGetTagFloat(const resulthandle : Integer) : Float` |
| `0x006E7350` | `procedure QueryMachineResultSetTagFloat(const resulthandle : Integer; const tagfloat : Float)` |
| `0x006E7370` | `function QueryMachineResultGetTargetObject(const resulthandle : Integer) : String` |
| `0x006E73A4` | `procedure QueryMachineResultSetTargetObject(const resulthandle : Integer; const targetobject : String)` |
| `0x006E73CC` | `function QueryMachineResultGetTargetUniqID(const resulthandle : Integer) : Integer` |
| `0x006E73EC` | `procedure QueryMachineResultSetTargetUniqID(const resulthandle : Integer; const targetuniqid : Integer)` |
| `0x006E7468` | `function QueryMachineResultGetTargetCustomName(const resulthandle : Integer) : String` |
| `0x006E749C` | `procedure QueryMachineResultSetTargetCustomName(const resulthandle : Integer; const targetcustomname : String)` |
| `0x006E74C4` | `function QueryMachineResultGetTargetQueryID(const resulthandle : Integer) : String` |
| `0x006E74F8` | `procedure QueryMachineResultSetTargetQueryID(const resulthandle : Integer; const targetqueryid : String)` |
| `0x006E7520` | `function QueryMachineResultGetTargetMarkerID(const resulthandle : Integer) : Integer` |
| `0x006E7540` | `procedure QueryMachineResultSetTargetMarkerID(const resulthandle : Integer; const targetmarkerid : Integer)` |
| `0x006E7560` | `function QueryMachineResultGetTargetDoCollide(const resulthandle : Integer) : Boolean` |
| `0x006E7580` | `procedure QueryMachineResultSetTargetDoCollide(const resulthandle : Integer; const targetdocollide : Boolean)` |
| `0x006E75A0` | `function QueryMachineResultGetTargetDoUncollide(const resulthandle : Integer) : Boolean` |
| `0x006E75C0` | `procedure QueryMachineResultSetTargetDoUncollide(const resulthandle : Integer; const targetdouncollide : Boolean)` |
| `0x006E75E0` | `function QueryMachineResultGetTargetOnCollide(const resulthandle : Integer) : String` |
| `0x006E7614` | `procedure QueryMachineResultSetTargetOnCollide(const resulthandle : Integer; const targetoncollide : String)` |
| `0x006E763C` | `function QueryMachineResultGetTargetOnUncollide(const resulthandle : Integer) : String` |
| `0x006E7670` | `procedure QueryMachineResultSetTargetOnUncollide(const resulthandle : Integer; const targetonuncollide : String)` |
| `0x006E7698` | `function QueryMachineResultGetDisableQueryID(const resulthandle : Integer) : String` |
| `0x006E76CC` | `procedure QueryMachineResultSetDisableQueryID(const resulthandle : Integer; const val : String)` |
| `0x006E76F4` | `function QueryMachineResultGetDisableResultID(const resulthandle : Integer) : String` |
| `0x006E7728` | `procedure QueryMachineResultSetDisableResultID(const resulthandle : Integer; const val : String)` |
| `0x006E7750` | `function QueryMachineResultGetNextResultID(const resulthandle : Integer) : String` |
| `0x006E7784` | `procedure QueryMachineResultSetNextResultID(const resulthandle : Integer; const val : String)` |
| `0x006E77AC` | `function QueryMachineResultGetCustomParserHandle(const resulthandle : Integer) : Integer` |
| `0x006E77CC` | `procedure QueryMachineQuestSaveToParserFile(const filename : String)` |
| `0x006E77E8` | `procedure QueryMachineQuestLoadFromParserFile(const filename : String)` |
| `0x006E7804` | `function QueryMachineQuestQueryLast : Integer` |
| `0x006E7814` | `function QueryMachineQuestQueryGet(const id : String) : Integer` |
| `0x006E7830` | `procedure QueryMachineQuestQueryDelete(const id : String)` |
| `0x006E784C` | `procedure QueryMachineQuestQueryDeleteLast` |
| `0x006E785C` | `function QueryMachineQuestQueryCreate(const id : String) : Integer` |
| `0x006E7878` | `function QueryMachineQuestQueryAddNew(const id : String) : Integer` |
| `0x006E7894` | `procedure QueryMachineQuestQueriesClear` |
| `0x006E78A4` | `function QueryMachineQuestQueriesCount : Integer` |
| `0x006E78B4` | `function QueryMachineGetQuestOnInitial : String` |
| `0x006E78D0` | `procedure QueryMachineSetQuestOnInitial(const val : String)` |
| `0x006E78EC` | `function QueryMachineGetQuestOnAfterLoad : String` |
| `0x006E7908` | `procedure QueryMachineSetQuestOnAfterLoad(const val : String)` |
| `0x006E7924` | `function QueryMachineGetQuestOnBeforeSave : String` |
| `0x006E7940` | `procedure QueryMachineSetQuestOnBeforeSave(const val : String)` |
| `0x006E795C` | `function QueryMachineGetQuestQueriesHandle : Integer` |
| `0x006E796C` | `function QueryMachineGetQuestOnProgress : String` |
| `0x006E7988` | `procedure QueryMachineSetQuestOnProgress(const val : String)` |
| `0x006E79A4` | `function QueryMachineGetQuestProgressInterval : Integer` |
| `0x006E79B4` | `procedure QueryMachineSetQuestProgressInterval(const val : Integer)` |
| `0x006E79CC` | `function QueryMachineGetQuestOnAfterBattle : String` |
| `0x006E79EC` | `procedure QueryMachineSetQuestOnAfterBattle(const val : String)` |
| `0x006E7A0C` | `function QueryMachineGetQuestOnBeforeBattle : String` |
| `0x006E7A2C` | `procedure QueryMachineSetQuestOnBeforeBattle(const val : String)` |
| `0x006E7A4C` | `function QueryMachineGetQuestOnChangeArmy : String` |
| `0x006E7A6C` | `procedure QueryMachineSetQuestOnChangeArmy(const val : String)` |
| `0x006E7A8C` | `function QueryMachineGetQuestOnChangeInventory : String` |
| `0x006E7AAC` | `procedure QueryMachineSetQuestOnChangeInventory(const val : String)` |
| `0x006E7ACC` | `function QueryMachineGetQuestOnCollideObject : String` |
| `0x006E7AEC` | `procedure QueryMachineSetQuestOnCollideObject(const val : String)` |
| `0x006E7B0C` | `function QueryMachineGetQuestOnUncollideObject : String` |
| `0x006E7B2C` | `procedure QueryMachineSetQuestOnUncollideObject(const val : String)` |
| `0x006E7B4C` | `procedure QueryMachineExecuteQuestOnAfterBattle` |
| `0x006E7B88` | `procedure QueryMachineExecuteQuestOnBeforeBattle` |
| `0x006E7BC4` | `procedure QueryMachineExecuteQuestOnChangeArmy` |
| `0x006E7C00` | `procedure QueryMachineExecuteQuestOnChangeInventory` |
| `0x006E7C3C` | `procedure QueryMachineExecuteQuestOnCollideObject` |
| `0x006E7C78` | `procedure QueryMachineExecuteQuestOnUncollideObject` |
| `0x006E9DD0` | `function ParserSelectCurrentStateMachine: Integer` |
| `0x006E9EC4` | `function ParserCreateCurrentStateMachine: Integer` |
| `0x006E9FD4` | `procedure ParserFreeCurrentStateMachine` |
| `0x006EA05C` | `function ParserSelectStateMachineByHandle(const handle: Integer): Integer` |
| `0x006EA080` | `function ParserCreateStateMachineByHandle(const handle: Integer): Integer` |
| `0x006EA0A8` | `procedure ParserFreeStateMachineByHandle(const handle: Integer)` |
| `0x006FA770` | `function SteamwrapFriendsGetPersonaState: integer` |
| `0x006FA834` | `function SteamwrapFriendsGetFriendPersonaState(const friendid: pointer): integer` |

### Strings — строки/парсер — 258

| VA | Объявление |
|---|---|
| `0x0060DEA0` | `function SameText(const s1: String; const s2: String): Boolean` |
| `0x0060DEB4` | `function StrPos(const substr: String; const source: String): Integer` |
| `0x0060DF1C` | `function StrPosEx(const substr: String; const source: String; posfrom: Integer): Integer` |
| `0x0060DF88` | `function StrExists(const source: String; const substr: String): Boolean` |
| `0x0060DFF4` | `function SubStr(const source: String; aindex, acount: Integer): String` |
| `0x0060E010` | `function StrReplace(const instr, whatstr, tostr: String): String` |
| `0x0060E034` | `function StrLength(const str: String): Integer` |
| `0x0060E044` | `function StrToUpperCase(const str: String): String` |
| `0x0060E058` | `function StrToLowerCase(const str: String): String` |
| `0x0060E06C` | `function StrTrim(const str: String): String` |
| `0x0060E080` | `function Chr(const val: Byte): Char` |
| `0x0060E08C` | `function Ord(const val: String): Byte` |
| `0x0060E0AC` | `function UIntToStr(const n: pointer): string` |
| `0x0060E0E0` | `function Int64ToStr(const n: pointer): string` |
| `0x0060E110` | `function UInt64ToStr(const n: pointer): string` |
| `0x0060E140` | `function IntToStr(val: Integer): String` |
| `0x0060E154` | `function BoolToStr(val: Boolean): String` |
| `0x0060E168` | `function FloatToStr(val: Float): String` |
| `0x0060E184` | `function StrToInt(const val: String): Integer` |
| `0x0060E198` | `function StrToBool(const val: String): Boolean` |
| `0x0060E1AC` | `function StrToFloat(const val: String): Float` |
| `0x0060EAB8` | `function DateTimeFormat(const format: String; const datetime: Integer): String` |
| `0x0060EB48` | `procedure WideStringLoadWideLocaleTableItem(argres: Integer; const skey: String)` |
| `0x0060EBC0` | `procedure WideStringLoadStringLocaleTableItem(argres: Integer; const skey: String)` |
| `0x0060EC38` | `procedure WideStringLoadWideLocaleTableListItemByIndex(argres, ind: Integer; const skey: String)` |
| `0x0060ECB4` | `procedure WideStringLoadStringLocaleTableListItemByIndex(argres, ind: Integer; const skey: String)` |
| `0x0060ED30` | `procedure WideStringLoadWideLocaleTableListItemByID(argres: Integer; const sid, skey: String)` |
| `0x0060EDAC` | `procedure WideStringLoadStringLocaleTableListItemByID(argres: Integer; const sid, skey: String)` |
| `0x0060EE28` | `procedure WideStringLoadToString(var str: String; argres: Integer)` |
| `0x0060EE54` | `procedure WideStringLoadToStringCoded(var str: String; argres: Integer)` |
| `0x0060EEF0` | `procedure WideStringAssignString(argres: Integer; const str: String)` |
| `0x0060EF44` | `procedure WideStringAssignStringCoded(argres: Integer; const str: String)` |
| `0x0060F060` | `procedure WideStringAssign(argres: Integer; arg1: Integer)` |
| `0x0060F0A4` | `procedure WideStringAdd(argres: Integer; arg1: Integer; arg2: Integer)` |
| `0x0060F104` | `procedure WideStringEmpty(argres: Integer)` |
| `0x0060F134` | `procedure WideStringReplace(argres: Integer; argsource: Integer; argwhat: Integer; argwith: Integer)` |
| `0x0060F1F8` | `function WideStringLength(arg: Integer): Integer` |
| `0x0060F21C` | `function WideStringToString(arg, codepage: Integer): String` |
| `0x0060F2B0` | `procedure DScriptSetgDbgString0(arg: String)` |
| `0x0060F2F8` | `function DScriptGetgDbgString0: String` |
| `0x0060F36C` | `procedure SetgDbgString1(arg: String)` |
| `0x0060F3B4` | `function GetgDbgString1: String` |
| `0x0060F428` | `procedure SetgDbgString2(arg: String)` |
| `0x0060F470` | `function GetgDbgString2: String` |
| `0x0060F4E4` | `procedure SetgDbgString3(arg: String)` |
| `0x0060F52C` | `function GetgDbgString3: String` |
| `0x0060F5A0` | `procedure SetgDbgString4(arg: String)` |
| `0x0060F5E8` | `function GetgDbgString4: String` |
| `0x0060F600` | `function IsDelimiterCharExists(const value: String; const delimiter: Char): Boolean` |
| `0x0060F614` | `function GetDelimiterStringCount(const value: String; const delimiter, quotechar: Char): Integer` |
| `0x0060F62C` | `function GetDelimiterStringByIndex(const value: String; const delimiter, quotechar: Char; index: Integer): String` |
| `0x0060F6FC` | `procedure OpenFileStreamForRead(const afilename: String)` |
| `0x0060F744` | `procedure OpenFileStreamForWrite(const afilename: String)` |
| `0x0060F780` | `procedure CloseFileStream` |
| `0x0060F7A4` | `procedure FileStreamWriteInteger(const avalue: Integer)` |
| `0x0060F7D0` | `function FileStreamReadInteger: Integer` |
| `0x0060FAA0` | `procedure CopyFileStream(const srcfilename, dstfilename: String)` |
| `0x0060FB40` | `procedure DeleteFileStream(const filename: String)` |
| `0x0060FB50` | `procedure MoveFileStream(const srcfilename, dstfilename: String)` |
| `0x0060FB70` | `procedure RenameFileStream(const oldfilename, newfilename: String)` |
| `0x0060FF78` | `procedure WriteString(const fs: Integer; const val: String)` |
| `0x0061010C` | `procedure ReadString(const fs: Integer; var val: String)` |
| `0x006102DC` | `procedure SeekString(const fs: Integer)` |
| `0x0061051C` | `procedure SetBitmapFormat(const bitmap, numbit: Integer)` |
| `0x006105F0` | `function GetBitmapFormat(const bitmap: Integer): Integer` |
| `0x00611234` | `function WindowsRegistryReadString(root: integer; const key, name: string): string` |
| `0x00611554` | `procedure ProcessesToParserStruct(const parser: integer)` |
| `0x00657804` | `function GetLibMaterialTextureFormat(const mathnd: Integer): Integer` |
| `0x0067D220` | `function GetFormatFontFamilyCount(const fontname: String): Integer` |
| `0x0067D258` | `function GetFormatFontFamilyNameByIndex(const fontname: String; const idx: Integer): String` |
| `0x0067D2A0` | `function GetFormatFontFamilyStyleByIndex(const fontname: String; const idx: Integer): String` |
| `0x0067D2E8` | `function GetFormatFontFamilyIndexByStyle(const fontname: String; const style: String): Integer` |
| `0x0067D320` | `function GetFormatFontFamilyNameByStyle(const fontname: String; const style: String): String` |
| `0x0067D368` | `function GetFormatSyntaxTagStyle: String` |
| `0x0067D378` | `procedure SetFormatSyntaxTagStyle(const val: String)` |
| `0x0067D388` | `function GetFormatSyntaxTagColor: String` |
| `0x0067D398` | `procedure SetFormatSyntaxTagColor(const val: String)` |
| `0x0067D3A8` | `function GetFormatSyntaxTagRefOpen: String` |
| `0x0067D3B8` | `procedure SetFormatSyntaxTagRefOpen(const val: String)` |
| `0x0067D3C8` | `function GetFormatSyntaxTagRefClose: String` |
| `0x0067D3D8` | `procedure SetFormatSyntaxTagRefClose(const val: String)` |
| `0x0067D3E8` | `function GetFormatSyntaxArgAttention: String` |
| `0x0067D3F8` | `procedure SetFormatSyntaxArgAttention(const val: String)` |
| `0x0067D408` | `function GetFormatSyntaxArgInfo: String` |
| `0x0067D418` | `procedure SetFormatSyntaxArgInfo(const val: String)` |
| `0x0067D428` | `function GetFormatSyntaxArgExtraInfo: String` |
| `0x0067D438` | `procedure SetFormatSyntaxArgExtraInfo(const val: String)` |
| `0x0067D448` | `function GetFormatSyntaxArgWarning: String` |
| `0x0067D458` | `procedure SetFormatSyntaxArgWarning(const val: String)` |
| `0x0067D468` | `function GetFormatSyntaxArgDefault: String` |
| `0x0067D478` | `procedure SetFormatSyntaxArgDefault(const val: String)` |
| `0x0067D488` | `function GetFormatSyntaxArgIgnore: String` |
| `0x0067D498` | `procedure SetFormatSyntaxArgIgnore(const val: String)` |
| `0x0067D4A8` | `function GetFormatSyntaxArgRestore: String` |
| `0x0067D4B8` | `procedure SetFormatSyntaxArgRestore(const val: String)` |
| `0x0067D4C8` | `function FormatPosToTextPos(const val: String; const pos: Integer): Integer` |
| `0x0067D5EC` | `function FormatRefCount(const val: String): Integer` |
| `0x0067D5FC` | `function FormatRefData(const val: String; const refind: Integer; var refpos: Integer; var refarg, refval: String): Boolean` |
| `0x0067D740` | `function FormatTagData(const val: String; const tagind: Integer; var tag: String; var tagpos, taglen: Integer; var tagarg: String): Boolean` |
| `0x0067D88C` | `function FormatTagCount(const val: String; tag: String): Integer` |
| `0x0067D8D8` | `function FormatTagCountData(const val: String; var color, style, refer: Integer; var justtext: String): Integer` |
| `0x0067D8F8` | `function FormatStyleTagCount(const val: String): Integer` |
| `0x0067D908` | `function FormatColorTagCount(const val: String): Integer` |
| `0x0067D918` | `function FormatGetJustTextWithoutTags(const val: String; tag: String): String` |
| `0x0067D960` | `function FormatIsHexString(hex: String): Boolean` |
| `0x0067D9A8` | `function FormatColorToHex3(c0, c1, c2: Float): String` |
| `0x0067D9D4` | `function FormatColorToHex4(c0, c1, c2, c3: Float): String` |
| `0x0067DA00` | `procedure FormatHexToColor3(hex: String; var c0, c1, c2: Float)` |
| `0x0067DA7C` | `procedure FormatHexToColor4(hex: String; var c0, c1, c2, c3: Float)` |
| `0x006841E4` | `procedure LanGetServersListToParser(aparserhandle: Integer)` |
| `0x00684514` | `procedure LanPublicServerClientsToParser(iparser: Integer)` |
| `0x006845E8` | `procedure LanPublicServerSessionsToParser(iparser: Integer)` |
| `0x006846FC` | `procedure LanPublicServerSendSessionParser(idprivate, idparser, parserhandle: Integer)` |
| `0x006849F8` | `function LanPublicServerGetClientInfoToParserByIndex(aclientindex: Integer; aphandle: Integer): Boolean` |
| `0x00684A9C` | `function LanPublicServerGetClientInfoToParserByClientID(aclientid: Integer; aphandle: Integer): Boolean` |
| `0x006850DC` | `function LanPublicServerGetSessionInfoToParserByIndex(asessionindex: Integer; aphandle: Integer): Boolean` |
| `0x00685180` | `function LanPublicServerGetSessionInfoToParserByClientID(aclientid: Integer; aphandle: Integer): Boolean` |
| `0x00685428` | `function LanGetServerInfoToParser(aip: Integer; aparserhandle: Integer): Boolean` |
| `0x006854B8` | `function LanIpToString(aip: Integer): String` |
| `0x00685760` | `procedure LanSendParser(const aid: Integer; const aparserhandle: Integer)` |
| `0x00685794` | `function LanSelectParser: Integer` |
| `0x006857B8` | `function LanGetParserID: Integer` |
| `0x00685A0C` | `procedure RecordSynchStackStringByIndex(index: Integer)` |
| `0x00685A28` | `procedure RecordSynchStackStringByIndexTestChanges(index: Integer)` |
| `0x00685B14` | `procedure RecordSynchStackStringByName(const name: String)` |
| `0x00685B48` | `procedure RecordSynchStackStringByNameTestChanges(const name: String)` |
| `0x00685BB4` | `procedure RecordSynchStringRegister(const index: Integer)` |
| `0x00685EAC` | `function RecordCustomWriteString(const value: String): Boolean` |
| `0x00685EE4` | `function RecordCustomWriteShortString(const value: String): Boolean` |
| `0x006861B8` | `function RecordCustomReadString: String` |
| `0x006861FC` | `function RecordCustomReadShortString: String` |
| `0x0068A50C` | `procedure MapSetInfoStructStore(const val : Boolean)` |
| `0x0068A528` | `function MapGetInfoStructStore : Boolean` |
| `0x0068A53C` | `procedure MapSetInfoStructReset(const val : Boolean)` |
| `0x0068A558` | `function MapGetInfoStructReset : Boolean` |
| `0x006AAFAC` | `procedure GetStretchCoord(var x: Float; var y: Float; var z: Float)` |
| `0x006AAFF8` | `function GetStretchBrushFadeIn(): Boolean` |
| `0x006AB010` | `procedure SetStretchBrushFadeIn(value: Boolean)` |
| `0x006AB030` | `function GetStretchBrushFadeTime(): Float` |
| `0x006AB050` | `procedure SetStretchBrushFadeTime(value: Float)` |
| `0x006AB070` | `function GetStretchBrushFadeInTime(): Float` |
| `0x006AB090` | `procedure SetStretchBrushFadeInTime(value: Float)` |
| `0x006AB0B0` | `function GetStretchBrushUseGrid(): Boolean` |
| `0x006AB0C8` | `procedure SetStretchBrushUseGrid(value: Boolean)` |
| `0x006AB0E8` | `procedure GetStretchBrushDirection(var dirx: Float; var diry: Float; var dirz: Float)` |
| `0x006AB12C` | `function GetStretchBrushAngleByDir(dirx, diry: Float): Float` |
| `0x006AB184` | `procedure GetStretchBrushDirByAngle(angle: Float; var dirx: Float; var diry: Float)` |
| `0x006AB1E0` | `function GetStretchBrushCollisionPriority: Integer` |
| `0x006AB210` | `procedure SetStretchBrushCollisionPriority(val: Integer)` |
| `0x006AB248` | `function GetStretchBrushTestPriorityOption: String` |
| `0x006AB2A0` | `procedure SetStretchBrushTestPriorityOption(val: String)` |
| `0x006AB4CC` | `function GetStretchBrushLocked(): boolean` |
| `0x006AB4E0` | `procedure SetStretchBrushLocked(value: boolean)` |
| `0x006AB4FC` | `procedure SetStretchBrushLockedStart(startx, starty, startz: Float)` |
| `0x006AB540` | `procedure SetStretchBrushLockedEnd(endx, endy, endz: Float)` |
| `0x006AB584` | `procedure SetStretchBrushLockedOffset(value: Float)` |
| `0x006AB5A0` | `procedure SetStretchBrushLockedOffsetDir(dirx, diry, dirz: Float)` |
| `0x006AB69C` | `procedure GetUserStretchIntCoordByIndex(index: integer; var x,y,z: Float)` |
| `0x006AE494` | `function GameManagerIsStretchBrushMode:Boolean` |
| `0x006AE51C` | `procedure SetGameManagerStretchTargetMode(btargetmode: Boolean)` |
| `0x006AEAC0` | `function GetAvailableResolutionsToActiveParser(awide: Boolean; aminwidth, aminheight: Integer): Boolean` |
| `0x006B6438` | `function GetFormatMap: Integer` |
| `0x006B6448` | `procedure SetFormatMap(val: Integer)` |
| `0x006B89DC` | `procedure ModLibraryGetParser(const parser: integer; full: boolean)` |
| `0x006B8C24` | `procedure DlcLibraryGetParser(const parser: integer; full: boolean)` |
| `0x006C4408` | `function GetAddrString(var v: String): Integer` |
| `0x006C4438` | `function GetAddrChar(var v: Char): Integer` |
| `0x006C44AC` | `function GetPtrString(var v: String): Pointer` |
| `0x006C44DC` | `function GetPtrChar(var v: Char): Pointer` |
| `0x006C5554` | `function GetStreamSizeTypeBase(const typ, addr: Pointer; const nam: String; const sm: Integer; useproc: boolean): Integer` |
| `0x006C5578` | `procedure SaveStreamTypeBase(const fs: Integer; const typ, addr: Pointer; const nam: String; const sm: Integer; useproc: boolean)` |
| `0x006C55A0` | `procedure LoadStreamTypeBase(const fs: Integer; const typ, addr: Pointer; const nam: String; const sm: Integer; useproc: boolean)` |
| `0x006C55C8` | `procedure MergeStreamTypeBase(const fs: Integer; const typdst, addr: Pointer; const nam: String; const sm: Integer; useproc: boolean; const typsrc: Pointer; const compared: boolean)` |
| `0x006C55F8` | `procedure SeekStreamTypeBase(const fs: Integer; const typ: Pointer; const nam: String; const sm: Integer; useproc: boolean)` |
| `0x006C5738` | `procedure SaveSerialToParser(const parserhnd: Integer; clean: Boolean)` |
| `0x006C5764` | `procedure LoadSerialFromParser(const parserhnd: Integer; clean: Boolean)` |
| `0x006C6024` | `procedure TriggerManagerFromParserStruct(const parser : Integer)` |
| `0x006C604C` | `procedure TriggerManagerToParserStruct(const parser : Integer)` |
| `0x006DE5A4` | `function GetBehaviourPropertiesToParser(behaviour: Integer): Boolean` |
| `0x006DE5EC` | `function SetBehaviourPropertiesFromParser(behaviour: Integer): Boolean` |
| `0x006DE628` | `function GetBehaviourPropertiesToParserByHandle(behaviour, parser: Integer): Boolean` |
| `0x006DE628` | `function BehaviourPropertiesSaveToParserByHandle(behaviour, parser: Integer): Boolean` |
| `0x006DE668` | `function SetBehaviourPropertiesFromParserByHandle(behaviour, parser: Integer): Boolean` |
| `0x006DE668` | `function BehaviourPropertiesLoadFromParserByHandle(behaviour, parser: Integer): Boolean` |
| `0x006DE6FC` | `procedure SetBehaviourStringProperty(behaviour: Integer; const name: String; value: String)` |
| `0x006DE808` | `function GetBehaviourStringProperty(behaviour: Integer; const name: String): String` |
| `0x006DEBE0` | `procedure SavePFXManagerToParser(const managername: String; const parser: Integer)` |
| `0x006DEC20` | `procedure LoadPFXManagerFromParser(const managername: String; const parser: Integer)` |
| `0x006E9C60` | `function ParserCreate(const aparser: String):Integer` |
| `0x006E9CAC` | `procedure ParserClearByHandle(const aparser: Integer)` |
| `0x006E9CD0` | `procedure ParserFree(const aparser: String)` |
| `0x006E9D0C` | `procedure ParserFreeByHandle(const aparser: Integer)` |
| `0x006E9D4C` | `procedure ParserFreeAll` |
| `0x006E9D64` | `function ParserSelectMap: Integer` |
| `0x006E9D88` | `function ParserSelectUser: Integer` |
| `0x006E9DAC` | `function ParserSelectRecordManager: Integer` |
| `0x006EA0BC` | `function ParserSelectByKey(const aparser: String):Integer` |
| `0x006EA0E8` | `function ParserSelectByHandle(const aparser: Integer):Integer` |
| `0x006EA120` | `function ParserSelectByHandleByKey(const aparser: Integer; const akey: String):Integer` |
| `0x006EA174` | `function ParserSelectByHandleByIndex(const aparser: Integer; index: Integer):Integer` |
| `0x006EA1FC` | `function ParserCopyFromByKey(const aparser: String):Boolean` |
| `0x006EA24C` | `function ParserCopyToByKey(const aparser: String):Boolean` |
| `0x006EA298` | `function ParserCopyFromByHandle(const aparser: Integer):Boolean` |
| `0x006EA2E8` | `function ParserCopyToByHandle(const aparser: Integer):Boolean` |
| `0x006EA334` | `function ParserSaveToFile(const afilename: String): Boolean` |
| `0x006EA3BC` | `function ParserLoadFromFile(const afilename: String): Boolean` |
| `0x006EA460` | `function ParserSaveToFileByHandle(const parser: Integer; const filename: String): Boolean` |
| `0x006EA4EC` | `function ParserLoadFromFileByHandle(const parser: Integer; const filename: String): Boolean` |
| `0x006EA590` | `function ParserGetFilesInRoot(const aroot: String): Boolean` |
| `0x006EA660` | `procedure ParserSetValueByKey(const akey: String; const avalue: String)` |
| `0x006EA688` | `procedure ParserSetWideValueByKey(const akey: String; avaluearg: Integer)` |
| `0x006EA6C8` | `procedure ParserSetIntValueByKey(const akey: String; const avalue: Integer)` |
| `0x006EA6F0` | `procedure ParserSetFloatValueByKey(const akey: String; const avalue: Float)` |
| `0x006EA718` | `procedure ParserSetBoolValueByKey(const akey: String; const avalue: Boolean)` |
| `0x006EA740` | `procedure ParserSetValueByIndex(index: Integer; const avalue: String)` |
| `0x006EA788` | `procedure ParserSetWideValueByIndex(index: Integer; avaluearg: Integer)` |
| `0x006EA7E8` | `procedure ParserSetIntValueByIndex(index: Integer; const avalue: Integer)` |
| `0x006EA82C` | `procedure ParserSetFloatValueByIndex(index: Integer; const avalue: Float)` |
| `0x006EA870` | `procedure ParserSetBoolValueByIndex(index: Integer; const avalue: Boolean)` |
| `0x006EA8B4` | `procedure ParserSetValueByKeyByHandle(aparser: Integer; const akey: String; const avalue: String)` |
| `0x006EA8E0` | `procedure ParserSetWideValueByKeyByHandle(aparser: Integer; const akey: String; avaluearg: Integer)` |
| `0x006EA924` | `procedure ParserSetIntValueByKeyByHandle(aparser: Integer; const akey: String; const avalue: Integer)` |
| `0x006EA950` | `procedure ParserSetFloatValueByKeyByHandle(aparser: Integer; const akey: String; const avalue: Float)` |
| `0x006EA97C` | `procedure ParserSetBoolValueByKeyByHandle(aparser: Integer; const akey: String; const avalue: Boolean)` |
| `0x006EA9A8` | `function ParserGetValueByKey(const akey: String): String` |
| `0x006EA9E4` | `procedure ParserGetWideValueByKey(const akey: String; avaluearg: Integer)` |
| `0x006EAA78` | `function ParserGetIntValueByKey(const akey: String): Integer` |
| `0x006EAAA0` | `function ParserGetFloatValueByKey(const akey: String): Float` |
| `0x006EAAD4` | `function ParserGetBoolValueByKey(const akey: String): Boolean` |
| `0x006EAAFC` | `function ParserGetValueByKeyByHandle(aparser: Integer; const akey: String): String` |
| `0x006EAB3C` | `procedure ParserGetWideValueByKeyByHandle(aparser: Integer; const akey: String; avaluearg: Integer)` |
| `0x006EABD4` | `function ParserGetIntValueByKeyByHandle(aparser: Integer; const akey: String): Integer` |
| `0x006EAC00` | `function ParserGetFloatValueByKeyByHandle(aparser: Integer; const akey: String): Float` |
| `0x006EAC38` | `function ParserGetBoolValueByKeyByHandle(aparser: Integer; const akey: String): Boolean` |
| `0x006EAC64` | `function ParserGetValueByIndex(index: Integer): String` |
| `0x006EACC0` | `procedure ParserGetWideValueByIndex(index: Integer; avaluearg: Integer)` |
| `0x006EAD70` | `function ParserGetIntValueByIndex(index: Integer): Integer` |
| `0x006EADB4` | `function ParserGetFloatValueByIndex(index: Integer): Float` |
| `0x006EAE04` | `function ParserGetBoolValueByIndex(index: Integer): Boolean` |
| `0x006EAE48` | `function ParserGetValueByIndexByHandle(parser, index: Integer): String` |
| `0x006EAEA4` | `procedure ParserGetWideValueByIndexByHandle(parser, index: Integer; ValueArg: Integer)` |
| `0x006EAF50` | `function ParserGetIntValueByIndexByHandle(parser, index: Integer): Integer` |
| `0x006EAF94` | `function ParserGetFloatValueByIndexByHandle(parser, index: Integer): Float` |
| `0x006EAFE4` | `function ParserGetBoolValueByIndexByHandle(parser, index: Integer): Boolean` |
| `0x006EB028` | `function ParserGetCountByHandle(handle: Integer): Integer` |
| `0x006EB050` | `function ParserGetCountByKey(const akey: String): Integer` |
| `0x006EB084` | `function ParserGetCountByIndex(index: Integer): Integer` |
| `0x006EB0D0` | `function ParserGetKeyName(aparser: Integer): String` |
| `0x006EB104` | `function ParserGetKeyIndex(aparser: Integer; aIndex: Integer): String` |
| `0x006EB168` | `function ParserGetFullKeyName(aparser: Integer): String` |
| `0x006EB19C` | `function ParserGetActiveParserHandle: Integer` |
| `0x006EB1A8` | `function ParserGetMaxIntNameOfKey(aparser: Integer): Integer` |
| `0x006EB204` | `function ParserFindChildIndexByEqualChildKey(const akey: String; const avalue: String):Integer` |
| `0x006EB29C` | `function ParserFindChildIndexByNotEqualChildKey(const akey: String; const avalue: String):Integer` |
| `0x006EB388` | `function ParserAddChildByIndex(aparser: Integer; const achild: String): Integer` |
| `0x006EB3CC` | `function ParserGetIndexOf(aparser: Integer): Integer` |
| `0x006EB400` | `function ParserGetParent(aparser: Integer): Integer` |
| `0x006EB424` | `function ParserIsValueExistsByKeyByHandle(aparser: Integer; const akey: String): Boolean` |

### System — время/версии/локаль — 53

| VA | Объявление |
|---|---|
| `0x0060D9F4` | `procedure Sleep(const milisecvalue: Integer)` |
| `0x0060EA98` | `function DateTimeNow(const format: String): String` |
| `0x0060EADC` | `function GetBuildVersion: String` |
| `0x0060EAFC` | `function GetMapVersion: String` |
| `0x0060EB1C` | `function GetCoreVersion: Integer` |
| `0x0060EB24` | `function GetMapCoreVersion: Integer` |
| `0x006851F8` | `function LanPublicServerProfLastGameTime: String` |
| `0x0068B164` | `procedure PathDataThreadSleepLength(const val : Integer)` |
| `0x0068B184` | `procedure PathDataThreadSleepStep(const val : Integer)` |
| `0x006A903C` | `function GetYear(): Integer` |
| `0x006A9060` | `procedure SetYear(year: Integer)` |
| `0x006A9088` | `function GetMonth(): Integer` |
| `0x006A90AC` | `procedure SetMonth(month: Integer)` |
| `0x006A90D4` | `function GetDay(): Integer` |
| `0x006A90F8` | `procedure SetDay(day: Integer)` |
| `0x006A9120` | `function GetHour(): Integer` |
| `0x006A9144` | `procedure SetHour(hour: Integer)` |
| `0x006A91B8` | `function GetSecond(): Integer` |
| `0x006A91DC` | `procedure SetSecond(second: Integer)` |
| `0x006AAA48` | `function GetVisibleAtDesignTimeOfObjectByIndex(const racename: String; index: Integer): Boolean` |
| `0x006AC604` | `procedure SetTimeSpeedFactor(factor: Float)` |
| `0x006AC638` | `function GetTimeSpeedFactor(): Float` |
| `0x006AC754` | `function GetCurrentTime(): Float` |
| `0x006AC778` | `function GetTotalTime(): Float` |
| `0x006AC7F4` | `function GetGameTime(): Float` |
| `0x006AC830` | `procedure SetGameTime(val: Float)` |
| `0x006AC864` | `function GetRealTime(): Float` |
| `0x006AE6AC` | `function GetLocaleTableItem(const skey: String): String` |
| `0x006AE6D0` | `function GetLocaleTableListItemByIndex(const ind: Integer; const skey: String): String` |
| `0x006AE70C` | `function GetLocaleTableListItemByID(const sid, skey: String): String` |
| `0x006AE748` | `function GetLocaleTableListUseTags: Boolean` |
| `0x006AE760` | `procedure SetLocaleTableListUseTags(const val: Boolean)` |
| `0x006AE780` | `function CountLocaleTableList: Integer` |
| `0x006AE798` | `function AddLocaleTableList(const id, filename: String): Integer` |
| `0x006AE81C` | `function IndexOfLocaleTableList(const id: String): Integer` |
| `0x006AF9A0` | `procedure SetDateTimeManagerEnabled(enabled: Boolean)` |
| `0x006AF9B4` | `function GetDateTimeManagerEnabled: Boolean` |
| `0x006B3B18` | `procedure CadencerProgressDeltaTime` |
| `0x006B3C20` | `function GetCadencerSleepLength: Integer` |
| `0x006B3C40` | `procedure SetCadencerSleepLength(v: Integer)` |
| `0x006B3C64` | `function GetCadencerTimeMultiplier: Float` |
| `0x006B3C90` | `procedure SetCadencerTimeMultiplier(v: Float)` |
| `0x006B3D48` | `function FramesPerSecond: Float` |
| `0x006B3D74` | `function FramesPerSecondText(decimals: Integer): String` |
| `0x006B4704` | `function LastFrameTime: Float` |
| `0x006B85A4` | `function GetFOWDateTime: Boolean` |
| `0x006B85C0` | `procedure SetFOWDateTime(val: Boolean)` |
| `0x006C835C` | `function UserGetProfileReplayDateByIndex(aindex: Integer): String` |
| `0x006C849C` | `function UserGetProfileCustomDateByIndex(aindex: Integer): String` |
| `0x006F8FB8` | `function SteamwrapGetServerRealTime: integer` |
| `0x006F9BB0` | `function SteamwrapGetAchievementAndUnlockTime(name: string; var achieved: boolean; var unlocktime: integer): boolean` |
| `0x006F9F8C` | `function SteamwrapGetUserAchievementAndUnlockTime(const steamiduser: pointer; name: string; var achieved: boolean; var unlocktime: integer): boolean` |
| `0x006FAAE4` | `function SteamwrapGetEarliestPurchaseUnixTime(appid: integer): integer` |

### World — звук/карта/ресурсы/сеть/сервис — 686

| VA | Объявление |
|---|---|
| `0x006108D0` | `procedure GetHardwareCPUInfo(var cpuvendor: string; var mmx, sse, sse2, sse3, sse4, htt, amdmmx, _3dnow, _3dnow2: boolean; var numlogproc, numcores, maxmhz, curmhz: integer)` |
| `0x00610938` | `procedure GetHardwareRAMInfo(var totalphys, availphys, totalvirt, availvirt: integer)` |
| `0x00611260` | `function GetProcessDEPEnabled: boolean` |
| `0x00611278` | `function GetProcessID(const processname: string; var processid: integer): boolean` |
| `0x006113A8` | `function IsProcessesExist(const processes, delimiter: string; usage: integer): boolean` |
| `0x006116C0` | `function GetProcessMemoryInfo: integer` |
| `0x006116D4` | `function CanSupportPerMonitorDpi(autoenable: boolean): boolean` |
| `0x006116F4` | `function IsWindows81OrLater: boolean` |
| `0x006116FC` | `function GetPrimaryMonitorDPI: integer` |
| `0x00611704` | `function GetWindowMonitorDPI: integer` |
| `0x0061179C` | `function FreeLibrary(handle: integer): boolean` |
| `0x00684010` | `function IsLanGame(): Boolean` |
| `0x00684090` | `procedure LanDoStart` |
| `0x006840A4` | `function GetLanMode(): Integer` |
| `0x006840E4` | `procedure LanKillClient(aip: Integer)` |
| `0x00684100` | `function GetRecordManagerGameMode: Integer` |
| `0x00684114` | `procedure LanSetMyNick(const anick: String)` |
| `0x00684130` | `procedure LanSetMyEmail(const aemail: String)` |
| `0x00684150` | `procedure LanSetMyCDKey(const akey: String)` |
| `0x00684190` | `procedure LanSetMyPassword(const apassword: String)` |
| `0x006841B0` | `procedure LanSetMyProfInfo(const ainfo: String)` |
| `0x006841D0` | `procedure LanRefreshServersList` |
| `0x00684278` | `procedure LanSrvSetMoney(const amoney: Integer)` |
| `0x00684294` | `procedure LanSrvSetFogOfWarMode(const amode: Boolean)` |
| `0x006842B0` | `procedure LanSrvSetBattleFieldMode(const amode: Byte)` |
| `0x006842CC` | `procedure LanSrvSetClientScore(aclientid: Integer; ascore: Integer)` |
| `0x006842EC` | `procedure LanClSetMyTeam(const ateam: Integer)` |
| `0x00684308` | `procedure LanClSetMyScore(const ascore: Integer)` |
| `0x00684324` | `procedure LanCreateGame(const agamepsw: String; const agamename: String; const amap: String; const amaxplayers: Integer)` |
| `0x00684398` | `procedure LanRecreateGame(const agamepsw: String; const agamename: String; const amap: String; const amaxplayers, asessionid: Integer)` |
| `0x00684410` | `procedure LanJoinGame(const agamepsw: String; const ahost: String; bspec: Boolean)` |
| `0x00684434` | `procedure LanPublicServerEnter(const ahost: String; aport: Integer)` |
| `0x00684464` | `procedure LanPublicServerLeave` |
| `0x006844A0` | `procedure LanPublicServerUserExist(const semail: String)` |
| `0x006844BC` | `procedure LanPublicServerForgotPassword(const semail: String)` |
| `0x006844D8` | `function IsLanPublicServerMode: Boolean` |
| `0x00684500` | `procedure LanPublicServerRegister` |
| `0x006846BC` | `procedure LanPublicServerSendMessage(idprivate: Integer; const smsg: String)` |
| `0x006846DC` | `procedure LanPublicServerSendSessionMessage(idprivate: Integer; const smsg: String)` |
| `0x00684730` | `procedure LanPublicServerUpdateClientInfo(idclient: Integer)` |
| `0x0068474C` | `procedure LanPublicServerUpdateMySessionInfo` |
| `0x00684760` | `procedure LanPublicServerUpdateTopUsers(acount: Integer)` |
| `0x0068477C` | `procedure LanPublicServerUpdateInfo` |
| `0x00684790` | `function LanPublicServerGetRegIDFrom: Integer` |
| `0x006847A4` | `function LanPublicServerGetRegIDTo: Integer` |
| `0x006847B8` | `function LanPublicServerGetRegMessage: String` |
| `0x006847D8` | `function LanPublicServerGetClientTeamByIndex(aclientindex: Integer): Integer` |
| `0x00684870` | `function LanPublicServerGetClientTeamByClientID(aclientid: Integer): Integer` |
| `0x006848E8` | `function LanPublicServerGetClientSpecByIndex(aclientindex: Integer): Boolean` |
| `0x00684980` | `function LanPublicServerGetClientSpecByClientID(aclientid: Integer): Boolean` |
| `0x00684AB8` | `function LanPublicServerGetClientNickByIndex(aclientindex: Integer): String` |
| `0x00684B38` | `function LanPublicServerGetClientNickByClientID(aclientid: Integer): String` |
| `0x00684BF0` | `function LanPublicServerGetClientIDByIndex(aclientindex: Integer): Integer` |
| `0x00684C6C` | `function LanPublicServerGetClientScoreByIndex(aclientindex: Integer): Integer` |
| `0x00684CE8` | `function LanPublicServerGetClientScoreByClientID(aclientid: Integer): Integer` |
| `0x00684DD0` | `function LanPublicServerGetClientGamesPlayedByIndex(aclientindex: Integer): Integer` |
| `0x00684E4C` | `function LanPublicServerGetClientGamesPlayedByClientID(aclientid: Integer): Integer` |
| `0x00684E64` | `function LanPublicServerGetClientGamesWinByIndex(aclientindex: Integer): Integer` |
| `0x00684EE0` | `function LanPublicServerGetClientGamesWinByClientID(aclientid: Integer): Integer` |
| `0x00684EF8` | `function LanPublicServerGetClientLastGamePlayedByIndex(aclientindex: Integer): String` |
| `0x00684F7C` | `function LanPublicServerGetClientLastGamePlayedByClientID(aclientid: Integer): String` |
| `0x00684F98` | `function LanPublicServerGetClientInfoByIndex(aclientindex: Integer): String` |
| `0x00685018` | `function LanPublicServerGetClientInfoByClientID(aclientid: Integer): String` |
| `0x00685034` | `function LanPublicServerGetClientPingtimeByIndex(aclientindex: Integer): Integer` |
| `0x006850C4` | `function LanPublicServerGetClientPingtimeByClientID(aclientid: Integer): Integer` |
| `0x0068519C` | `function LanPublicServerProfScore: Integer` |
| `0x006851D0` | `function LanPublicServerProfGamesPlayed: Integer` |
| `0x006851E4` | `function LanPublicServerProfGamesWin: Integer` |
| `0x00685220` | `function LanPublicServerProfInfo: String` |
| `0x00685240` | `function LanPublicServerGetClientsCount: Integer` |
| `0x0068526C` | `function LanPublicServerGetSessionsCount: Integer` |
| `0x00685298` | `function LanPublicServerGetClientIndexByClientID(aclientid: Integer): Integer` |
| `0x006852D0` | `function LanPublicServerGetClientIndexByClientNick(const anick: String): Integer` |
| `0x00685308` | `function LanPublicServerGetSessionIndexByClientID(aclientid: Integer): Integer` |
| `0x00685340` | `procedure LanLockServer` |
| `0x00685354` | `procedure LanTerminateGame` |
| `0x00685368` | `procedure LanShutdown` |
| `0x0068537C` | `function LanMyInfoHost: String` |
| `0x0068538C` | `function LanMyInfoIP: Integer` |
| `0x006853A0` | `function LanMyInfoID: Integer` |
| `0x006853B4` | `function LanMyInfoSpec: Boolean` |
| `0x006853E4` | `function LanMyInfoName: String` |
| `0x006854DC` | `function LanGetClientsCount: Integer` |
| `0x00685504` | `function LanGetClientIDByIndex(aindex: Integer): Integer` |
| `0x00685554` | `function LanGetClientHostByIndex(aindex: Integer): String` |
| `0x006855B4` | `function LanGetClientNameByIndex(aindex: Integer): String` |
| `0x00685614` | `function LanGetClientSpecByIndex(aindex: Integer): Boolean` |
| `0x00685664` | `function LanGetClientIndexByID(aid: Integer): Integer` |
| `0x006857C8` | `function GetRecordEnabled: Boolean` |
| `0x006857DC` | `procedure SetRecordEnabled(const val: Boolean)` |
| `0x006857F8` | `function GetRecordInitializeEnabled: Boolean` |
| `0x0068580C` | `procedure SetRecordInitializeEnabled(const val: Boolean)` |
| `0x00685858` | `procedure RecordSynchBegin()` |
| `0x00685874` | `procedure RecordSynchBeginByHandle(handle: Integer)` |
| `0x00685924` | `procedure RecordSynchBeginMAP()` |
| `0x00685948` | `procedure RecordSynchEnd()` |
| `0x00685BD0` | `function LanGetSendDataThreadCount: Integer` |
| `0x00685BE8` | `procedure LanSetSendDataThreadDeltaPriority(const deltapriority: Integer)` |
| `0x00685C08` | `function LanGetSendDataThreadEnabled: Boolean` |
| `0x00685C1C` | `procedure LanSetSendDataThreadEnabled(const threadsenabled: Boolean)` |
| `0x00685C38` | `function RecordCustomBegin(const state: String): Boolean` |
| `0x00685C6C` | `function RecordCustomBeginTagObject(const taghnd: Integer; const state: String): Boolean` |
| `0x00685DC0` | `function RecordCustomBeginMap(const state: String): Boolean` |
| `0x00685E00` | `procedure RecordCustomEnd` |
| `0x00686480` | `procedure LanSetNoDelayOption(opt: boolean)` |
| `0x0068649C` | `function LanGetNoDelayOption: boolean` |
| `0x006864B0` | `procedure LanSetCustErrHandler(val: boolean)` |
| `0x006864CC` | `function LanGetCustErrHandler: boolean` |
| `0x006864E0` | `function LanGetCustErrEvent: integer` |
| `0x006864F4` | `procedure LanSetCustErrCode(val: integer)` |
| `0x00686510` | `function LanGetCustErrCode: integer` |
| `0x00686524` | `procedure LanSetOptimizedPackage(val: integer)` |
| `0x00686540` | `function LanGetOptimizedPackage: integer` |
| `0x00686554` | `procedure LanSetOptimizedPackageDef(val: integer)` |
| `0x00686568` | `function LanGetOptimizedPackageDef: integer` |
| `0x00686610` | `function RecordPackagesCount: Integer` |
| `0x00686628` | `function RecordPackagesCursor: Integer` |
| `0x0068663C` | `function RecordPackagesSize(cursor: Integer): Integer` |
| `0x0068667C` | `function RecordPackagesTotalSize: Integer` |
| `0x006867A4` | `procedure LanPublicServerSelectFriends(limit, offset: integer)` |
| `0x006867C4` | `procedure LanPublicServerUpdateFriends(friend, status: integer)` |
| `0x00686800` | `procedure LanPublicServerSelectChats(friend, limit, offset, stat: integer)` |
| `0x00686828` | `procedure LanPublicServerInsertChats(recid, stat: integer; mess: string)` |
| `0x0068687C` | `procedure LanPublicServerUpdateChats(id, stat: integer)` |
| `0x006868B8` | `procedure LanPublicServerSelectClans(id, limit, offset, order: integer)` |
| `0x006868E0` | `procedure LanPublicServerInsertClans(clname: string; status: integer)` |
| `0x00686930` | `procedure LanPublicServerUpdateClans(id, status: integer; clname: string)` |
| `0x006869A0` | `procedure LanPublicServerSelectMembers(userid, clanid, limit, offset: integer)` |
| `0x006869C8` | `procedure LanPublicServerInsertMembers(clanid, userid: integer)` |
| `0x00686A08` | `procedure LanPublicServerSelectAdmins()` |
| `0x00686A1C` | `procedure LanPublicServerUpdateAdmins(userid, status: integer)` |
| `0x00686A58` | `procedure LanPublicServerBanningAdmins(userid, ban: integer)` |
| `0x00686A78` | `procedure LanPublicServerSelectStats()` |
| `0x00686A8C` | `procedure LanPublicServerUpdateStats()` |
| `0x00686B28` | `procedure LanPublicServerGetSessions()` |
| `0x00686B3C` | `procedure LanPublicServerReconnection(masterid: integer)` |
| `0x00686B58` | `procedure LanPublicServerReconnectionBySID(sid: integer)` |
| `0x00686B74` | `function LanPublicServerIsReconnection(): boolean` |
| `0x00686B88` | `procedure LanPublicServerPingLock()` |
| `0x00686B9C` | `procedure LanPublicServerPingUnlock()` |
| `0x00686BB0` | `function LanPublicServerGetClientSocketHost: string` |
| `0x00686BCC` | `procedure LanPublicServerSetClientSocketHost(const val: string)` |
| `0x00686BE8` | `function LanPublicServerGetClientSocketPort: integer` |
| `0x00686BFC` | `procedure LanPublicServerSetClientSocketPort(val: integer)` |
| `0x00686C18` | `function LanMyInfoSessionID: integer` |
| `0x00689994` | `procedure SetMapValue(const key: String; const value: String)` |
| `0x006899B4` | `function GetMapValue(const key: String): String` |
| `0x00689A9C` | `procedure SetMapValueInd(index: Integer; const value: String)` |
| `0x00689ABC` | `function GetMapValueInd(index: Integer): String` |
| `0x00689C24` | `function GetMapCollisionTag(x, y : Float; buselayers: Boolean): Integer` |
| `0x00689D58` | `function GetMapCollisionTagInRadius(x, y : Float; rad : Integer; buselayers: Boolean): Integer` |
| `0x00689F04` | `procedure MapDrawCollision(x, y : Float; tag : Integer; radius : Float; round : Boolean)` |
| `0x0068A0D8` | `procedure MapDrawCustomMaskCollision(x, y, angle : Float; tag : Integer)` |
| `0x0068A288` | `procedure MapSetCustomMaskSize(w, h : Integer)` |
| `0x0068A2AC` | `procedure MapSetCustomMaskItem(x, y : Integer; val: Boolean)` |
| `0x0068A4BC` | `procedure MapSetStackStore(const val : Boolean)` |
| `0x0068A4D4` | `function MapGetStackStore : Boolean` |
| `0x0068A58C` | `procedure MapGenerateUniqueId` |
| `0x0068A5A0` | `function GetMapUniqueId : String` |
| `0x0068A5C0` | `procedure ClearTrackNodeList(const group: String)` |
| `0x0068A5E8` | `function AddTrackNode(const group: String; const x, y, z : Float; const alayer : Integer) : Integer` |
| `0x0068A61C` | `function AddTrackNodeCheckPos(const group: String; const x, y, z : Float; const alayer : Integer; const checkpos : Boolean) : Integer` |
| `0x0068A654` | `function GetTrackNodeCount : Integer` |
| `0x0068A670` | `function GetTrackNodeHandleByIndex(const index : Integer) : Integer` |
| `0x0068A6B0` | `function GetTrackNodeHandleByPosition(const x, y, z : Float) : Integer` |
| `0x0068A6F0` | `procedure GetTrackNodePositionByIndex(const index : Integer; var x, y, z : Float)` |
| `0x0068A76C` | `function GetTrackNodeHandleByGOHandle(const gohandle : Integer) : Integer` |
| `0x0068A7BC` | `procedure ConnectTrackNodesByHandle(const tnhandle1, tnhandle2 : Integer)` |
| `0x0068A810` | `procedure OneSideConnectTrackNodesByHandle(const tnhandle1, tnhandle2 : Integer)` |
| `0x0068A864` | `procedure ReflectTrackNodeConnections` |
| `0x0068A880` | `procedure BreakConnectionsByTrackNodes(dist: Float)` |
| `0x0068A8A8` | `function GetTrackNodeNeighboursCountByHandle(const tnhandle : Integer) : Integer` |
| `0x0068A8CC` | `function GetTrackNodeNeighbourHandleByHandleByIndex(const tnhandle, index : Integer) : Integer` |
| `0x0068A8F8` | `procedure GetTrackNodePositionByHandle(const tnhandle : Integer; var x, y, z : Float)` |
| `0x0068A93C` | `function GetLayerTrackNodesCount(const layer : Integer) : Integer` |
| `0x0068A964` | `function GetTrackNodeHandleByLayerByIndex(const layer, index : Integer) : Integer` |
| `0x0068A98C` | `function GetTrackNodePathByHandle(const tnhandle1, tnhandle2 : Integer) : Boolean` |
| `0x0068A9E4` | `function GetTrackNodeLayerByHandle(const tnhandle: Integer) : Integer` |
| `0x0068AA04` | `procedure SetTrackNodePositionByHandle(const tnhandle : Integer; x, y, z : Float)` |
| `0x0068AA40` | `function TrackNodePathExistByHandle(const tnhandle1, tnhandle2 : Integer) : Boolean` |
| `0x0068AA98` | `function GetTrackNodesConnectedByHandle(const tnhandle1, tnhandle2 : Integer) : Boolean` |
| `0x0068AB2C` | `procedure SetTrackNodeBoundedByHandle(const tnhandle : Integer; const cbounded : Boolean)` |
| `0x0068AB60` | `procedure SetTrackNodeBoundingPositionByHandle(const tnhandle : Integer; const posx, posy, posz : Float)` |
| `0x0068ABBC` | `procedure SetTrackNodeBoundingDirectionByHandle(const tnhandle : Integer; const dirx, diry, dirz : Float)` |
| `0x0068AC18` | `procedure SetTrackNodeFOVByHandle(const tnhandle : Integer; const fov : Float)` |
| `0x0068AC4C` | `function GetTrackNodeNameByHandle(const tnhandle : Integer) : String` |
| `0x0068AC98` | `procedure SetTrackNodeNameByHandle(const tnhandle : Integer; const aname : String)` |
| `0x0068ACD8` | `function GetTrackNodeTPCount : Integer` |
| `0x0068ACF8` | `procedure GetTrackNodeTPByIndex(const tpIndex : Integer; var x, y : Float)` |
| `0x0068AD64` | `function GetNearestTrackNodeHandle(const x, y : Float; layer : Integer) : Integer` |
| `0x0068AD90` | `function GetTrackNodeEnabledByHandle(const tnhandle : Integer) : Boolean` |
| `0x0068ADC8` | `procedure SetTrackNodeEnabledByHandle(const tnhandle : Integer; const aenabled : Boolean)` |
| `0x0068ADFC` | `function GetTrackNodeDistFactorByHandle(const tnhandle : Integer) : Float` |
| `0x0068AE40` | `procedure SetTrackNodeDistFactorByHandle(const tnhandle : Integer; const adistfactor : Float)` |
| `0x0068AE74` | `function GetTrackNodePathLength : Float` |
| `0x0068AEC0` | `function GetTrackNodeIndexByHandle(const tnhandle : Integer) : Integer` |
| `0x0068AEF8` | `function GetTrackNodeIndexByName(const name : String) : Integer` |
| `0x0068AF2C` | `function GetTrackNodeNameByIndex(const index : Integer) : String` |
| `0x0068AF74` | `procedure SetTrackNodeNameByIndex(const index : Integer; const name : String)` |
| `0x0068AFAC` | `function GetOrCreateTrackNodeList(index : Integer) : Integer` |
| `0x0068AFEC` | `procedure SetActiveTrackNodeList(index : Integer)` |
| `0x0068B018` | `function GetActiveTrackNodeListIndex : Integer` |
| `0x0068B030` | `function GetMapInitMachineHandle : Integer` |
| `0x0068B1B8` | `function MapUniqIdCounter : Integer` |
| `0x0068B1CC` | `function MapUniqNullIndex : Integer` |
| `0x0068B1E0` | `function MapUniqueGOListCount : Integer` |
| `0x0068B1F8` | `function MapUniqueGOListByIndex(index : Integer) : Integer` |
| `0x0068B240` | `function GetMapNextUniqId: Integer` |
| `0x0068B2E0` | `function GetMapUseUniqNullIndex: Boolean` |
| `0x0068B2F4` | `procedure SetMapUseUniqNullIndex(const val: Boolean)` |
| `0x0068B494` | `function MapReplaceTiles(const oldtileind, newtileind : Integer; const swap : Boolean) : Integer` |
| `0x0068B5FC` | `function MapGetTileBlockByTileIndex(const index : Integer) : String` |
| `0x0068B65C` | `function MapGetTileIndexByTileBlock(const tile : String): Integer` |
| `0x0068B72C` | `procedure NewMap(const awidth, aheight, atilebrush: Integer)` |
| `0x006A9228` | `function GetMapWidth(): Integer` |
| `0x006A9248` | `function GetMapHeight(): Integer` |
| `0x006AA3AC` | `function GetViewerWidth(): Integer` |
| `0x006AA3CC` | `function GetViewerHeight(): Integer` |
| `0x006AA5CC` | `procedure MapWorldUpdateTerrainData(tag: Integer; deltaheight: Float)` |
| `0x006AA7BC` | `function GetCountMeshesOfObjectByIndex(const racename: String; index: Integer): Integer` |
| `0x006AA844` | `function GetMeshNameOfObjectByIndex(const racename: String; index: Integer; indexmesh: Integer): String` |
| `0x006AA8B4` | `function GetMeshUseableOfObjectByIndex(const racename: String; index: Integer; indexmesh: Integer): Boolean` |
| `0x006AB83C` | `procedure GenerateMapNeeded(const filename, zonename, presetname: String; const w, h, c, k0, k1, seasind, watind: Integer; const mapinffile, trigfile, sndvolfile, ambsndfile, inimachfile, inimachstate, guifile, guistate, lightname: String)` |
| `0x006ABA18` | `procedure GenerateMapNeededExt(const filename, zonename, presetname: String; const w,h,c,k0,k1,setind,seasind,watind: Integer; const mapinffile, trigfile, sndvolfile, ambsndfile, inimachfile, inimachstate, guifile, guistate, lightname, casttype: String)` |
| `0x006ABBE8` | `procedure GenerateMapNeededExtBorder(filename,zonename,presetname:String;w,h,c,k0,k1,setind,seasind,watind:Integer;mapinffile,trigfile,sndvolfile,ambsndfile,inimachfile,inimachstate,guifile,guistate,lightname,casttype,poststate:String; border: Boolean)` |
| `0x006ABDBC` | `procedure GetMapNeeded(var filen,zonen,presetn:String;var w,h,c,k0,k1,setind,seasind,watind:Integer;var mapinffile,trigfile,sndvolfile,ambsndfile,inimachfile,inimachstate,guifile,guistate,lightname,casttype,poststate:String;var border,needed:Boolean)` |
| `0x006ABFB0` | `procedure SetMapNeeded(filen,zonen,presetn:String;w,h,c,k0,k1,setind,seasind,watind:Integer;mapinffile,trigfile,sndvolfile,ambsndfile,inimachfile,inimachstate,guifile,guistate,lightname,casttype,poststate:String;border,needed:Boolean)` |
| `0x006AC234` | `procedure RegenerateMapNeeded()` |
| `0x006AC244` | `procedure GenerateMapRandKey(var randkey0: Integer; var randkey1: Integer)` |
| `0x006AC400` | `function GetShadowEnabled(): Boolean` |
| `0x006AC424` | `procedure SetShadowEnabled(enabled: Boolean)` |
| `0x006AC44C` | `function GetShadowMapSize(): Integer` |
| `0x006AC468` | `procedure SetShadowMapSize(size: Integer)` |
| `0x006AC4A8` | `function GetShadowMapScaleHeight(): Float` |
| `0x006AC4CC` | `procedure SetShadowMapScaleHeight(val: Float)` |
| `0x006AC4F0` | `function GetShadowMapAddHeight(): Float` |
| `0x006AC514` | `procedure SetShadowMapAddHeight(val: Float)` |
| `0x006AC538` | `function GetShadowMapLightDepth(): Float` |
| `0x006AC55C` | `procedure SetShadowMapLightDepth(val: Float)` |
| `0x006AC580` | `procedure GetShadowMapPolygonOffset(var scale, bias: Float)` |
| `0x006AC5C4` | `procedure SetShadowMapPolygonOffset(scale, bias: Float)` |
| `0x006AC6A0` | `function IsPositionInMapWorld(x: Float; y: Float; z: Float): Boolean` |
| `0x006AE9BC` | `function GetCurrentGameMapType: Integer` |
| `0x006AE9CC` | `procedure SetCurrentGameMapType(const val: Integer)` |
| `0x006AE9E4` | `procedure ImportSnapShotToCurrentMap(const sfile: String)` |
| `0x006AEE68` | `procedure CleanRecordManager` |
| `0x006AEE7C` | `procedure ClearRecordManager` |
| `0x006AF840` | `procedure SetTerrainBordersStep(step: Float)` |
| `0x006AF864` | `function GetTerrainBordersStep: Float` |
| `0x006AF888` | `procedure TerrainBordersSmooth` |
| `0x006AF8BC` | `procedure TerrainBordersNormalize` |
| `0x006AF8D8` | `procedure SetTerrainBordersEnabled(enabled: Boolean)` |
| `0x006AF8FC` | `function GetTerrainBordersEnabled: Boolean` |
| `0x006AFBE0` | `procedure SetTextureFilteringQuality(const val: String)` |
| `0x006AFC8C` | `function GetTextureFilteringQuality: String` |
| `0x006AFDC8` | `function RayCastTerrain(x1, y1, z1, x2, y2, z2: Float; var xres, yres, zres: Float): Boolean` |
| `0x006AFEF4` | `function GetMapMostFrequentTile(const x, y: Integer; const rad: Float): String` |
| `0x006B0268` | `function GetMapAverageHeight(const x, y: Integer; const rad: Float): Float` |
| `0x006B10AC` | `function GetMapAverageHeightInRect(const minx, miny, maxx, maxy: Float): Float` |
| `0x006B1B1C` | `procedure GetDecalsInArea(const x, y: Integer; const rad: Float)` |
| `0x006B1C48` | `function IsDecalInCircle(const centerx, centery, radius: Float; const materialname: String): Boolean` |
| `0x006B1CD4` | `function GetDecalMaterialNameByHandle(const handle: Integer): String` |
| `0x006B2284` | `function GetRiverMapValue(const i, j: Integer): Boolean` |
| `0x006B2844` | `procedure MapGeneratorSmoothTiles()` |
| `0x006B2F64` | `function GetPatternMapValue(const i, j: Integer): Boolean` |
| `0x006B2F9C` | `procedure ResetPatternMap(const val: Boolean)` |
| `0x006B3010` | `procedure MapGeneratorSmoothTerrain(const x, y, passes: Integer; const radius: Float)` |
| `0x006B3044` | `procedure RaiseTerrain(const x, y: Integer; const round: Boolean; const mb: Integer; const delta: Float)` |
| `0x006B307C` | `procedure LowerTerrain(const x, y: Integer; const round: Boolean; const mb: Integer; const delta: Float)` |
| `0x006B30B4` | `procedure PlateauTerrain(const x, y: Integer; const round: Boolean; const mb: Integer; const reproduce: Boolean)` |
| `0x006B30EC` | `procedure SmoothTerrain(const x, y: Integer; const round: Boolean; const mb: Integer)` |
| `0x006B3158` | `procedure PaintTerrain(const x, y: Float; const tilebrush, cliffbrush, waterbrush: Integer; const ramp: Boolean; const cliffapply, level, size: Integer; const round, reproduce: Boolean)` |
| `0x006B3428` | `function GetTerrainColorMode: Integer` |
| `0x006B3454` | `procedure SetTerrainColorMode(const mode: Integer)` |
| `0x006B3484` | `procedure GetTerrainColorData(const x, y: Integer; var r: Float; var g: Float; var b: Float; var a: Float)` |
| `0x006B35D8` | `procedure SetTerrainColorData(const x, y: Integer; const r, g, b, a: Float)` |
| `0x006B3720` | `procedure TerrainUpdate(const terrainupdate, horizontexture: Boolean)` |
| `0x006B37E4` | `function PutDecalByName(const x, y: Float; const decalname: String): Integer` |
| `0x006B382C` | `procedure DestroyDecalByHandle(const dhandle: Integer)` |
| `0x006B38EC` | `procedure SetTerrainBordersVisible(const val: Boolean)` |
| `0x006B3910` | `function GetTerrainBordersVisible: Boolean` |
| `0x006B3928` | `procedure SetTerrainVisible(const val: Boolean)` |
| `0x006B39BC` | `function GetTerrainVisible: Boolean` |
| `0x006B39D4` | `procedure SetTerrainRayCastPrecison(const val: Float)` |
| `0x006B39F4` | `function GetTerrainRayCastPrecison: Float` |
| `0x006B3A10` | `procedure ViewerBufferRender` |
| `0x006B3A68` | `procedure ViewerBufferInvalidate` |
| `0x006B3AC0` | `procedure ViewerBufferUpdate` |
| `0x006B3E48` | `procedure DecalSetManagerBuildConnections(decalsetname: String; switched, modifypatternmap, updatehorizontexture: Boolean; randkey: Integer)` |
| `0x006B3EFC` | `procedure DecalSetManagerBuildConnections64(decalsetname: String; switched, modifypatternmap, updatehorizontexture: Boolean; randkey0, randkey1: Integer)` |
| `0x006B3FC0` | `function AddNewDecalByLibName(const parenthnd: Integer; const x, z, texrollangle: Float; const libdecalname, decalname: String): Integer` |
| `0x006B406C` | `procedure GetDecalDataByHandle(dechnd: Integer; var w, h, x, z, texoff0, texoff1, scale0, scale1, texscale0, texscale1, texang, eps: Float; var texrot, texscale, texoff, texoffrot: Boolean; var libmat, decname: String)` |
| `0x006B415C` | `procedure SetDecalDataByHandle(dechnd: Integer; w, h, x, z, texoff0, texoff1, scale0, scale1, texscale0, texscale1, texang, eps: Float; texrot, texscale, texoff, texoffrot: Boolean; libmat, decname: String)` |
| `0x006B42C4` | `function GetDecalNameByHandle(dechnd: Integer): String` |
| `0x006B42FC` | `procedure SetDecalNameByHandle(dechnd: Integer; decname: String)` |
| `0x006B435C` | `procedure GetDecalPositionByHandle(dechnd: Integer; var x, z: Float)` |
| `0x006B438C` | `procedure SetDecalPositionByHandle(dechnd: Integer; x, z: Float)` |
| `0x006B4420` | `function GetDecalTexFlipVerticalByHandle(dechnd: Integer): Boolean` |
| `0x006B4444` | `procedure SetDecalTexFlipVerticalByHandle(dechnd: Integer; texflipvertical: Boolean)` |
| `0x006B4468` | `function GetDecalParentHndByHandle(dechnd: Integer): Integer` |
| `0x006B4488` | `procedure SetDecalParentHndByHandle(dechnd, parenthnd: Integer)` |
| `0x006B44E0` | `procedure DoDecalPositionChangedByHandle(dechnd: Integer)` |
| `0x006B4504` | `procedure DoDecalSeasonChangedByHandle(dechnd: Integer)` |
| `0x006B4524` | `function DecalManagerGetDecalIndexByHandle(dechnd: Integer): Integer` |
| `0x006B455C` | `function DecalManagerGetDecalHandleByName(decname: String): Integer` |
| `0x006B45B4` | `function DecalManagerGetDecalHandleByNameExt(decname, libmatname: String): Integer` |
| `0x006B461C` | `function DecalManagerGetDecalHandleByIndex(decindex: Integer): Integer` |
| `0x006B4638` | `function DecalManagerGetDecalCount: Integer` |
| `0x006B464C` | `procedure DecalManagerClear` |
| `0x006B46E0` | `procedure ApplicationProcessMessages` |
| `0x006B4720` | `procedure ResetPerformanceMonitor` |
| `0x006B477C` | `procedure ResourceLODActorLibraryFullRequestPools` |
| `0x006B4804` | `procedure ResourceLODActorLibraryFullReload` |
| `0x006B4950` | `procedure ResourceLODActorLibraryDestroyImposterHandles` |
| `0x006B4968` | `function GetResourceLODActorLibraryCount: Integer` |
| `0x006B4980` | `function GetResourceLODActorLibraryLibActorNameByIndex(index: integer): String` |
| `0x006B49C0` | `function GetResourceLODActorLibraryLibActorHandleByIndex(index: integer): Integer` |
| `0x006B49EC` | `procedure ResourceTexturesReload` |
| `0x006B4A00` | `procedure GetResourceTexturesLODBias(matname, matlib: String; gohnd: Integer; var enabled: Boolean; var min, max: Float; var baselevel, maxlevel: Integer)` |
| `0x006B4AEC` | `procedure SetResourceTexturesLODBias(matname, matlib: String; gohnd: Integer; enabled: Boolean; min, max: Float; baselevel, maxlevel: Integer)` |
| `0x006B4BE4` | `function GetOGLTextureLODBias: Float` |
| `0x006B4BF4` | `procedure SetOGLTextureLODBias(bias: Float)` |
| `0x006B5034` | `procedure LibActorGetMeshPoolDistIMByHandle(libactorhandle: Integer)` |
| `0x006B5108` | `procedure GetLibActorMeshPoolDataByHandle(libactorhandle: Integer; var pooled: Boolean; var childpooled: Integer; var poolmindist: Float; var poolmaxdist: Float; var childpoolmaxdist: Float)` |
| `0x006B515C` | `procedure SetLibActorMeshPoolDataByHandle(libactorhandle: Integer; pooled: Boolean; childpooled: Integer; poolmindist, poolmaxdist, childpoolmaxdist: Float)` |
| `0x006B60D4` | `function GetLibActorLODActorCollectionImposterTextureFillRatioByHandleByIndex(libactorhandle, lodactorcollectionindex: Integer): Float` |
| `0x006B6138` | `procedure GetLibActorLODActorCollectionImposterTextureSizeByHandleByIndex(libactorhandle, lodactorcollectionindex: Integer; var x: Integer; var y: Integer)` |
| `0x006B6398` | `function GetDecalVisibleByHandle(dechnd: Integer): Boolean` |
| `0x006B63B8` | `procedure SetDecalVisibleByHandle(dechnd: Integer; visible: Boolean)` |
| `0x006B6460` | `procedure TopologyCreate` |
| `0x006B64A8` | `function IsTopologyExist: Boolean` |
| `0x006B65A8` | `procedure TopologyGetPath` |
| `0x006B65D4` | `procedure TopologyGetPathExt(quadtree, prior: Integer; tpo: String)` |
| `0x006B6670` | `procedure TopologyBuild` |
| `0x006B669C` | `procedure TopologyRecalcAllQuadTrees` |
| `0x006B66D4` | `procedure TopologyUpdate(minx, miny, maxx, maxy: Float)` |
| `0x006B67B8` | `function TopologyGetZoneSize: Integer` |
| `0x006B67E4` | `procedure TopologySetZoneSize(val: Integer)` |
| `0x006B6878` | `function TopologyGetTopologyQuadTree: Integer` |
| `0x006B68A8` | `procedure TopologySetTopologyQuadTree(val: Integer)` |
| `0x006B68DC` | `function TopologyGetPathQuadTree: Integer` |
| `0x006B690C` | `procedure TopologySetPathQuadTree(val: Integer)` |
| `0x006B6940` | `function TopologyGetTopologyPriority: Integer` |
| `0x006B696C` | `procedure TopologySetTopologyPriority(val: Integer)` |
| `0x006B69A0` | `function TopologyGetPathPriority: Integer` |
| `0x006B69D0` | `procedure TopologySetPathPriority(val: Integer)` |
| `0x006B6A04` | `function TopologyGetPosSearchRadius: Integer` |
| `0x006B6A34` | `procedure TopologySetPosSearchRadius(val: Integer)` |
| `0x006B6A68` | `procedure TopologyGetBypassMap(i, j: Integer; var index, val: Integer)` |
| `0x006B6AE0` | `function TopologyGetPathDistance(stx, sty, endx, endy: Float; birregular: Boolean): Float` |
| `0x006B6B34` | `function TopologyGetBufferSize: Integer` |
| `0x006B6B60` | `procedure TopologySetBufferSize(val: Integer)` |
| `0x006B6B94` | `function TopologyGetConnectionRadius: Integer` |
| `0x006B6BC0` | `procedure TopologySetConnectionRadius(val: Integer)` |
| `0x006B6BF4` | `function TopologyGetZoneIndex(x, y: Float): Integer` |
| `0x006B6C88` | `function TopologyGetZoneIndexByArrayIndices(i, j: Integer): Integer` |
| `0x006B6CE4` | `function TopologyGetZonesCount: Integer` |
| `0x006B6D18` | `procedure TopologyGetZoneCenterByIndex(ind: Integer; var x, y: Float)` |
| `0x006B6F3C` | `function TopologyGetZoneWeightByIndex(ind: Integer): Float` |
| `0x006B6FC8` | `procedure TopologySetZoneWeightByIndex(ind: Integer; val: Float)` |
| `0x006B7048` | `function TopologyGetZoneBufferByIndex(ind: Integer): Pointer` |
| `0x006B70CC` | `function TopologyGetZoneConnectionsCountByIndex(zone: Integer): Integer` |
| `0x006B7154` | `function TopologyGetZoneConnectionByIndex(zone, ind: Integer): Integer` |
| `0x006B7228` | `function TopologyGetZoneConnectionDistByIndex(zone, ind: Integer): Integer` |
| `0x006B72FC` | `function TopologyGetZoneNeighboursCountByIndex(zone: Integer): Integer` |
| `0x006B7384` | `function TopologyGetZoneNeighbourByIndex(zone, ind: Integer): Integer` |
| `0x006B7460` | `function TopologyGetZoneNeedPathByIndex(zone: Integer): Boolean` |
| `0x006B74E4` | `procedure TopologySetZoneNeedPathByIndex(zone: Integer; needpath: Boolean)` |
| `0x006B7564` | `procedure TopologyGetZoneExtents(zone: Integer; var imin, jmin, imax, jmax: Integer)` |
| `0x006B7624` | `function TopologyGetZoneCheckedByIndex(ind: Integer): Boolean` |
| `0x006B76A8` | `procedure TopologySetZoneCheckedByIndex(ind: Integer; val: Boolean)` |
| `0x006B7728` | `function TopologyGetZoneRegionByIndex(ind: Integer): Integer` |
| `0x006B77AC` | `procedure TopologySetZoneRegionByIndex(ind: Integer; val: Integer)` |
| `0x006B782C` | `function TopologyGetPositionInRegion(x, y : Float; region, rad : Integer; var resX, resY : Float) : Boolean` |
| `0x006B7884` | `function TopologyGetDistValue(x, y: Float): Integer` |
| `0x006B791C` | `function TopologyGetZonesPath(stind, endind: Integer): Boolean` |
| `0x006B79FC` | `procedure TopologyGetPathToZone(zone: Integer)` |
| `0x006B7A7C` | `function TopologyGetZonesWeightPath(stind, endind: Integer): Boolean` |
| `0x006B7B10` | `function TopologyGetWeightPathFromZone(zone: Integer; onlyNearest: Boolean): Integer` |
| `0x006B7B78` | `function TopologyGetZonesGraphDist(stind, endind, maxdist: Integer): Integer` |
| `0x006B7BB8` | `procedure TopologyGetPathAroundCollision(xStart, yStart, xEnd, yEnd: Float)` |
| `0x006B8228` | `function GetFOWTextured: Boolean` |
| `0x006B8244` | `procedure SetFOWTextured(val: Boolean)` |
| `0x006B86F8` | `function GetResourceExtDDSBuffEnable: Boolean` |
| `0x006B8700` | `procedure SetResourceExtDDSBuffEnable(const val: Boolean)` |
| `0x006B8984` | `function GetPerfLanSend(index: integer): Float` |
| `0x006B89B0` | `function GetPerfLanRecv(index: integer): Float` |
| `0x006B8A18` | `function ModLibraryGetRootDir: string` |
| `0x006B8A84` | `function ModLibraryGetCount: integer` |
| `0x006B8A94` | `procedure ModLibraryGetData(libind: integer; var tag, dir, last, tit, ownid, desc, tags, url, note: string; var numf, vis: integer; var dis, acc, ban, root: boolean)` |
| `0x006B8C60` | `function DlcLibraryGetRootDir: string` |
| `0x006B8CCC` | `function DlcLibraryGetCount: integer` |
| `0x006B8CDC` | `procedure DlcLibraryGetData(libind: integer; var tag, dir, last, tit, ownid, desc, tags, url, note: string; var numf, vis: integer; var dis, acc, ban, root: boolean)` |
| `0x006BB324` | `function SndGetOrCreateAmbientThread(const name: String): Integer` |
| `0x006BB3C0` | `procedure SetSndAmbientThreadSetPlaying(value: Boolean; thread: Integer)` |
| `0x006BB3DC` | `procedure SetSndAmbientThreadSetPlayingFade(thread: Integer; playing: Boolean; fadetime: Float)` |
| `0x006BB430` | `procedure SetSndAmbientThreadSetPlayingFade2(thread: Integer; fadein: Float; const fadewith: String; fadeout: Float)` |
| `0x006BB4D0` | `function GetSndAmbientThreadSetPlaying(thread: Integer): Boolean` |
| `0x006BB4E4` | `function GetSndAmbientThreadHandleByName(const name: String): Integer` |
| `0x006BB510` | `function AddSndAmbientThreadSound(const name: String; thread: Integer): Integer` |
| `0x006BB530` | `function GetSndAmbientThreadSoundHandleByName(const name: String; thread: Integer): Integer` |
| `0x006BB550` | `function GetSndAmbientThreadSoundHandleByIndex(index: Integer; thread: Integer): Integer` |
| `0x006BB570` | `function SetSndAmbientThreadActiveSoundByName(const name: String; thread: Integer): Boolean` |
| `0x006BB5A8` | `procedure SetSndAmbientThreadPriority(value: Integer; thread: Integer)` |
| `0x006BB5C0` | `function GetSndAmbientThreadPriority(thread: Integer): Integer` |
| `0x006BB5D8` | `procedure SetSndAmbientThreadPause(value: Boolean; thread: Integer)` |
| `0x006BB5F0` | `function GetSndAmbientThreadPause(thread: Integer): Boolean` |
| `0x006BB608` | `procedure SetSndAmbientThreadMute(value: Boolean; thread: Integer)` |
| `0x006BB620` | `function GetSndAmbientThreadMute(thread: Integer): Boolean` |
| `0x006BB638` | `procedure SetSndAmbientThreadLoop(value: Boolean; thread: Integer)` |
| `0x006BB650` | `function GetSndAmbientThreadLoop(thread: Integer): Boolean` |
| `0x006BB668` | `procedure SetSndAmbientThreadSoundVolume(value: Float; threadsound: Integer)` |
| `0x006BB680` | `function GetSndAmbientThreadSoundVolume(threadsound: Integer): Float` |
| `0x006BB6A0` | `procedure SetSndAmbientThreadSoundFrequency(value: Integer; threadsound: Integer)` |
| `0x006BB6B8` | `function GetSndAmbientThreadSoundFrequency(threadsound: Integer): Integer` |
| `0x006BB6D0` | `procedure SetSndAmbientThreadSoundDelay(value: Float; threadsound: Integer)` |
| `0x006BB6E8` | `function GetSndAmbientThreadSoundDelay(threadsound: Integer): Float` |
| `0x006BB708` | `procedure SetSndAmbientThreadUseRanges(thread: Integer; use: Boolean)` |
| `0x006BB720` | `function GetSndAmbientThreadUseRanges(thread: Integer): Boolean` |
| `0x006BB738` | `procedure SetSndAmbientThreadRanges(thread: Integer; low: Float; high: Float)` |
| `0x006BB754` | `procedure GetSndAmbientThreadRanges(thread: Integer; var low: Float; var high: Float)` |
| `0x006BB774` | `function GetSndAmbientThreadCurrentRange(thread: Integer): Integer` |
| `0x006BB790` | `procedure SetSndAmbientThreadCurrentRange(thread: Integer; arange: Integer)` |
| `0x006BB7A4` | `procedure SetSndSoundMute(value: Boolean; sound: Integer)` |
| `0x006BB7BC` | `procedure SetSndAmbientThreadResetCurrentDelay(thread: Integer)` |
| `0x006BB7D0` | `function SndGetOrCreateSound(emittertag: Integer; const libraryname: String; owner: Integer): Integer` |
| `0x006BB854` | `function SndRemoveSound(emittertag: Integer; owner: Integer): Integer` |
| `0x006BB8B8` | `procedure SetSndSoundVolume(value: Float; sound: Integer)` |
| `0x006BB8D4` | `function GetSndSoundVolume(sound: Integer): Float` |
| `0x006BB8F8` | `procedure SetSndSoundFrequency(value: Integer; sound: Integer)` |
| `0x006BB914` | `function GetSndSoundFrequency(sound: Integer): Integer` |
| `0x006BB92C` | `procedure SetSndSoundSourceName(const value: String; sound: Integer)` |
| `0x006BB964` | `function GetSndSoundSourceName(sound: Integer): String` |
| `0x006BB990` | `procedure SetSndSoundFadePlaying(fadein: Boolean; fadetime: Float; sound: Integer)` |
| `0x006BB9C0` | `procedure SetSndSoundPlaying(value: Boolean; sound: Integer)` |
| `0x006BB9DC` | `function GetSndSoundPlaying(sound: Integer): Boolean` |
| `0x006BB9F4` | `function GetSndSoundMute(sound: Integer): Boolean` |
| `0x006BBA0C` | `procedure SetSndSoundPause(value: Boolean; sound: Integer)` |
| `0x006BBA24` | `function GetSndSoundPause(sound: Integer): Boolean` |
| `0x006BBA3C` | `procedure SetSndSoundLoop(value: Boolean; sound: Integer)` |
| `0x006BBA6C` | `function GetSndSoundLoop(sound: Integer): Boolean` |
| `0x006BBA88` | `procedure SetSndSoundPriority(value: Integer; sound: Integer)` |
| `0x006BBAA4` | `function GetSndSoundPriority(sound: Integer): Integer` |
| `0x006BBAEC` | `procedure SetSndSoundRadius(value: Float; sound: Integer)` |
| `0x006BBB24` | `procedure SetSndSoundRadiuses(rmaxvolume: Float; radius: Float; sound: Integer)` |
| `0x006BBB4C` | `function GetSndSoundRadius(sound: Integer): Float` |
| `0x006BBC94` | `procedure SetSndSoundConeOutsideVolume(value: Float; sound: Integer)` |
| `0x006BBCB0` | `function GetSndSoundConeOutsideVolume(sound: Integer): Float` |
| `0x006BBCD4` | `procedure SetSndSoundKillSndOutRad(value: Boolean; sound: Integer)` |
| `0x006BBCF0` | `function GetSndSoundKillSndOutRad(sound: Integer): Boolean` |
| `0x006BBDC4` | `function GetUseSoundManagerListenerAsObject : Boolean` |
| `0x006BBDF4` | `procedure SetUseSoundManagerListenerAsObject(const val : Boolean)` |
| `0x006BBE50` | `procedure GetPosSoundManagerListenerAsObject(var x : Float; var y : Float; var z : Float)` |
| `0x006BBEB4` | `procedure SetPosSoundManagerListenerAsObject(const x, y, z : Float)` |
| `0x006BBF6C` | `function GetSoundManagerListenerHandle : Integer` |
| `0x006BBF80` | `procedure SetSoundManagerPauseMode(const svolumegroup: String; apause: Boolean)` |
| `0x006BC10C` | `function GetSoundManagerPauseMode(const svolumegroup: String): Boolean` |
| `0x006BC288` | `procedure SetSoundManagerMuteMode(const svolumegroup: String; amute: Boolean)` |
| `0x006BC414` | `function GetSoundManagerMuteMode(const svolumegroup: String): Boolean` |
| `0x006BC59C` | `procedure SetSoundManagerHeightFactor(afactor: Float)` |
| `0x006BC5BC` | `function GetSoundManagerHeightFactor: Float` |
| `0x006BC5DC` | `procedure SetSoundManagerScaleFactor(afactor: Float)` |
| `0x006BC5FC` | `function GetSoundManagerScaleFactor: Float` |
| `0x006BC61C` | `function SoundManagerPreloadSource(const slibrary, ssoundname: String): Boolean` |
| `0x006BC6D4` | `procedure SoundManagerUnloadSource(const slibrary, ssoundname: String)` |
| `0x006BC710` | `function SoundManagerPreloadLibrary(const slibrary: String): Boolean` |
| `0x006BC7B8` | `procedure SoundManagerUnloadLibrary(const slibrary: String)` |
| `0x006BC80C` | `function SoundManagerPreloadAmbientThreads: Boolean` |
| `0x006BC8EC` | `function SoundManagerRequestAmbientThreads(): Boolean` |
| `0x006BC970` | `function SoundManagerUnloadAmbientThreads(): Boolean` |
| `0x006BCB54` | `procedure SetFullAmbientSoundVolume(value: Float)` |
| `0x006BCBC0` | `function SoundManagerRequestSource(const slibrary, ssoundname: String): Boolean` |
| `0x006C5D78` | `function GetTriggerManagerEnabled(): Boolean` |
| `0x006C5D98` | `procedure SetTriggerManagerEnabled(enabled: Boolean)` |
| `0x006C5DC0` | `function GetTriggerEnabled(const name: String): Boolean` |
| `0x006C5DF8` | `procedure SetTriggerEnabled(const name: String; enabled: Boolean)` |
| `0x006C5E30` | `procedure TriggerManagerDoRun` |
| `0x006C5E50` | `procedure TriggerManagerClear` |
| `0x006C5E70` | `procedure TriggerManagerAdd(const name: String)` |
| `0x006C5EA4` | `procedure TriggerManagerEventAdd(const triggername, eventname : String; starttime, endtime, period : Float; eventtype, eventmode : Integer; const oneventstate : String; enabled : Boolean)` |
| `0x006DD5A0` | `function GetBehavioursCanAdd(objhnd: Integer; const classname: String): Boolean` |
| `0x006DD5EC` | `function GetEffectsCanAdd(objhnd: Integer; const classname: String): Boolean` |
| `0x006DD638` | `function GetBehaviourUniqueItem(const classname: String): Boolean` |
| `0x006DD66C` | `procedure BehaviourDestroy(behaviour: Integer)` |
| `0x006DD688` | `function BehaviourCreate(gohnd: Integer; const classname: String; uniq: Boolean; usecurrentparser: Boolean): Integer` |
| `0x006DD738` | `function BehaviourCreateWithKey(gohnd: Integer; const classname, key: String; usecurrentparser: Boolean): Integer` |
| `0x006DD844` | `procedure BehaviourClear(gohnd: Integer)` |
| `0x006DD878` | `procedure BehaviourClearRequested(gohnd: Integer)` |
| `0x006DD8E8` | `function GetBehaviourByClassName(gohnd: Integer; const classname: String): Integer` |
| `0x006DD948` | `function GetBehaviourByKey(gohnd: Integer; const key: String): Integer` |
| `0x006DD9AC` | `function GetBehaviourByIndex(gohnd: Integer; const index: Integer): Integer` |
| `0x006DDA04` | `function GetBehaviourCount(gohnd: Integer): Integer` |
| `0x006DDA3C` | `function BaseObjectBehaviourCreate(const objhnd: Integer; const classname: String; uniq: Boolean; usecurrentparser: Boolean): Integer` |
| `0x006DDAE8` | `function BaseObjectBehaviourCreateWithKey(const objhnd: Integer; const classname, key: String; usecurrentparser: Boolean): Integer` |
| `0x006DDBEC` | `procedure BaseObjectBehaviourClear(const objhnd: Integer)` |
| `0x006DDC1C` | `procedure BaseObjectBehavioursAssign(const srchnd, dsthnd: Integer)` |
| `0x006DDC58` | `procedure BaseObjectEffectsAssign(const srchnd, dsthnd: Integer)` |
| `0x006DDC94` | `function GetBaseObjectBehaviourByClassName(const objhnd: Integer; const classname: String): Integer` |
| `0x006DDCF0` | `function GetBaseObjectBehaviourByKey(const objhnd: Integer; const key: String): Integer` |
| `0x006DDD50` | `function GetBaseObjectBehaviourByIndex(const objhnd: Integer; const index: Integer): Integer` |
| `0x006DDDA4` | `function GetBaseObjectBehaviourCount(const objhnd: Integer): Integer` |
| `0x006DDDD4` | `function EffectCreate(gohnd: Integer; const classname: String; uniq: Boolean; usecurrentparser: Boolean): Integer` |
| `0x006DDE74` | `function EffectCreateWithKey(gohnd: Integer; const classname, key: String; usecurrentparser: Boolean): Integer` |
| `0x006DDF5C` | `procedure EffectClear(gohnd: Integer)` |
| `0x006DDF90` | `procedure EffectClearRequested(gohnd: Integer)` |
| `0x006DDFF8` | `function GetEffectByClassName(gohnd: Integer; const classname: String): Integer` |
| `0x006DE058` | `function GetEffectByKey(gohnd: Integer; const key: String): Integer` |
| `0x006DE0BC` | `function GetEffectByIndex(gohnd: Integer; const index: Integer): Integer` |
| `0x006DE114` | `function GetEffectCount(gohnd: Integer): Integer` |
| `0x006DE14C` | `function BaseObjectEffectCreate(objhnd: Integer; const classname: String; uniq: Boolean; usecurrentparser: Boolean): Integer` |
| `0x006DE1E4` | `function BaseObjectEffectCreateWithKey(objhnd: Integer; const classname, key: String; usecurrentparser: Boolean): Integer` |
| `0x006DE2C8` | `procedure BaseObjectEffectClear(objhnd: Integer)` |
| `0x006DE2F8` | `function GetBaseObjectEffectByClassName(objhnd: Integer; const classname: String): Integer` |
| `0x006DE354` | `function GetBaseObjectEffectByKey(objhnd: Integer; const key: String): Integer` |
| `0x006DE3B4` | `function GetBaseObjectEffectByIndex(objhnd: Integer; const index: Integer): Integer` |
| `0x006DE408` | `function GetBaseObjectEffectCount(objhnd: Integer): Integer` |
| `0x006DE438` | `function GetBehaviourIndex(behaviour: Integer): Integer` |
| `0x006DE454` | `procedure SetBehaviourIndex(behaviour, index: Integer)` |
| `0x006DE470` | `function GetBehaviourClassName(behaviour: Integer): String` |
| `0x006DE4B8` | `function GetBehaviourKey(behaviour: Integer): String` |
| `0x006DE4E8` | `procedure SetBehaviourKey(behaviour: Integer; key: String)` |
| `0x006DE538` | `function GetBehaviourBaseObject(behaviour: Integer): Integer` |
| `0x006DE55C` | `function IsEffect(handle: Integer): Boolean` |
| `0x006DE580` | `function IsBehaviour(handle: Integer): Boolean` |
| `0x006DE8C0` | `procedure CalcThrowBehaviourDirection(behaviour: Integer; var x, y, z: Float)` |
| `0x006DE920` | `procedure SetupThrowBehaviourSpeed(behaviour: Integer)` |
| `0x006DE934` | `function GetOrCreateBehaviourInertia(gohnd: Integer): Integer` |
| `0x006DE958` | `procedure BehaviourInertiaApplyTranslationAcceleration(behaviour: Integer; accelx, accely, accelz, accelw: Float)` |
| `0x006DE9AC` | `procedure BehaviourInertiaApplyForce(behaviour: Integer; forcex, forcey, forcez, forcew: Float)` |
| `0x006DEA00` | `procedure BehaviourInertiaApplyTorque(behaviour: Integer; turntorque, rolltorque, pitchtorque: Float)` |
| `0x006DEA48` | `procedure BehaviourInertiaMirrorTranslation(behaviour: Integer)` |
| `0x006DEA60` | `procedure BehaviourInertiaSurfaceBounce(behaviour: Integer; surfacenormalx, surfacenormaly, surfacenormalz, surfacenormalw, restitution: Float)` |
| `0x006DF3C4` | `function GetPFXPerlinPFXManagerTexMapSize(const managername: String): Integer` |
| `0x006DF404` | `procedure SetPFXPerlinPFXManagerTexMapSize(const managername: String; const val: Integer)` |
| `0x006DF768` | `function GetPFXPerlinPFXManagerSpritesPerTexture(const managername: String): String` |
| `0x006DF7C4` | `procedure SetPFXPerlinPFXManagerSpritesPerTexture(const managername: String; const val: String)` |
| `0x006E0398` | `procedure EffectSourcePFXBurst(const effect: Integer; time: Float; nb: Integer)` |
| `0x006E047C` | `procedure EffectFireFXInit(const effect: Integer)` |
| `0x006E06F0` | `function EffectHighlightGetOrCreate(hnd: Integer; key: String; visible: Boolean; mat: String): Integer` |
| `0x006E0808` | `procedure EffectHighlightRemove(hnd: Integer; key: String)` |
| `0x006F89BC` | `procedure SteamAPPUnload` |
| `0x006F89CC` | `function SteamAPPInit: integer` |
| `0x006F89D4` | `function SteamAPPTriggerAchievements(const list: string; const delimiter, quote: char): integer` |
| `0x006F89EC` | `function SteamAPPClearAchievements(const list: string; const delimiter, quote: char): integer` |
| `0x006F8A04` | `function SteamwrapInit(libname: string): boolean` |
| `0x006F8A94` | `function SteamwrapInitSafe(libname: string; var error: integer): boolean` |
| `0x006F8B88` | `procedure SteamwrapFree` |
| `0x006F8BB8` | `function SteamwrapIsSteamRunning: boolean` |
| `0x006F8BCC` | `function SteamwrapInitCallbacksManager: boolean` |
| `0x006F8BE0` | `function SteamwrapRestartAppIfNecessary(ownappid: integer): boolean` |
| `0x006F8C88` | `procedure SteamwrapSubscribeCallbacks(enabled: boolean)` |
| `0x006F8CCC` | `procedure SteamwrapProgressCallbacks` |
| `0x006F8CEC` | `procedure SteamwrapSetupCallbacks(index: integer; const addr: pointer)` |
| `0x006F8D18` | `procedure SteamwrapSetCallbacksAddr(index, addr: integer)` |
| `0x006F8D44` | `function SteamwrapSetCallbacksFunc(index: integer; const func: string): boolean` |
| `0x006F8D74` | `function SteamwrapGetCallbacksAddr(index: integer): integer` |
| `0x006F8DA0` | `function SteamwrapGetCallbacksPtr(index: integer): pointer` |
| `0x006F8DCC` | `procedure SteamwrapClearCallbacks` |
| `0x006F8DEC` | `function SteamwrapGetProgressCallbacks: string` |
| `0x006F8E20` | `procedure SteamwrapSetProgressCallbacks(const val: string)` |
| `0x006F8F84` | `function SteamwrapGetConnectedUniverse: string` |
| `0x006F9004` | `function SteamwrapGetImageSize(image: integer; var width, height: integer): boolean` |
| `0x006F9034` | `function SteamwrapGetImageRGBA(image: integer; var dest: pointer; destbuffersize: integer): boolean` |
| `0x006F9080` | `function SteamwrapGetAppID: integer` |
| `0x006F9098` | `procedure SteamwrapSetOverlayNotificationPosition(notificationposition: integer)` |
| `0x006F90B8` | `function SteamwrapIsAPICallCompleted(const steamapicall: pointer; var failed: boolean): boolean` |
| `0x006F90E8` | `function SteamwrapGetAPICallFailureReason(const steamapicall: pointer): integer` |
| `0x006F9114` | `function SteamwrapGetAPICallResult(const steamapicall: pointer; var callback: pointer; ccallback, callbackexpected: integer; var failed: boolean): boolean` |
| `0x006F9150` | `function SteamwrapGetIPCCallCount: integer` |
| `0x006F9168` | `procedure SteamwrapSetWarningMessageHook(fn: pointer)` |
| `0x006F9188` | `function SteamwrapIsOverlayEnabled: boolean` |
| `0x006F91A0` | `function SteamwrapOverlayNeedsPresent: boolean` |
| `0x006F91B8` | `function SteamwrapShowGamepadTextInput(inputmode, lineinputmode: integer; description: string; charmax: integer; existingtext: string): boolean` |
| `0x006F9240` | `function SteamwrapGetEnteredGamepadTextLength: integer` |
| `0x006F9258` | `function SteamwrapGetEnteredGamepadTextInput(text: string; ctext: integer): boolean` |
| `0x006F92C0` | `function SteamwrapGetSteamUILanguage: string` |
| `0x006F92F4` | `function SteamwrapIsSteamRunningInVR: boolean` |
| `0x006F930C` | `function SteamwrapGetSteamUser: integer` |
| `0x006F933C` | `procedure SteamwrapGetSteamIDAcc(var accountid, accountinstance, accounttype, universe: integer)` |
| `0x006F93B8` | `procedure SteamwrapGetSteamID(var steamid: pointer)` |
| `0x006F9400` | `function SteamwrapGetAccountIDFromSteamID(const steamid: pointer): integer` |
| `0x006F9418` | `function SteamwrapGetAccountInstanceFromSteamID(const steamid: pointer): integer` |
| `0x006F9430` | `function SteamwrapGetAccountTypeFromSteamID(const steamid: pointer): integer` |
| `0x006F9450` | `function SteamwrapGetUniverseFromSteamID(const steamid: pointer): integer` |
| `0x006F9470` | `function SteamwrapInitiateGameConnection(var authblob: pointer; maxauthblob: integer; const steamidgameserver: pointer; ipserver, portserver: integer; secure: boolean): integer` |
| `0x006F94B0` | `procedure SteamwrapTerminateGameConnection(ipserver, portserver: integer)` |
| `0x006F94D8` | `procedure SteamwrapTrackAppUsageEvent(const gameid: pointer; appusageevent: integer; extrainfo: string)` |
| `0x006F9540` | `function SteamwrapGetUserDataFolder(var buffer: string; cbuffer: integer): boolean` |
| `0x006F9580` | `procedure SteamwrapStartVoiceRecording` |
| `0x006F9594` | `procedure SteamwrapStopVoiceRecording` |
| `0x006F95A8` | `function SteamwrapGetAvailableVoice(var compressed, cuncompressed: integer; uncompressedvoicedesiredsamplerate: integer): integer` |
| `0x006F95D8` | `function SteamwrapGetVoice(wantcomp: boolean; var dstbuf: pointer; cdstbufsiz: integer; var bwrt: integer; wantuncomp: boolean; var uncompdstbuf: pointer; cuncompdstbufsiz: integer; var nuncompbwrt: integer; uncompvcedessmprat: integer): integer` |
| `0x006F9624` | `function SteamwrapDecompressVoice(const compressed: pointer; ccompressed: integer; var destbuffer: pointer; destbuffersize: integer; var byteswritten: integer; desiredsamplerate: integer): integer` |
| `0x006F9664` | `function SteamwrapGetVoiceOptimalSampleRate: integer` |
| `0x006F967C` | `function SteamwrapGetAuthSessionTicket(var ticket: pointer; maxticket: integer; var cticket: integer): integer` |
| `0x006F96AC` | `function SteamwrapBeginAuthSession(const authticket: pointer; cauthticket: integer; const steamid: pointer): integer` |
| `0x006F96E0` | `procedure SteamwrapEndAuthSession(const steamid: pointer)` |
| `0x006F9708` | `procedure SteamwrapCancelAuthTicket(authticket: integer)` |
| `0x006F9728` | `function SteamwrapUserHasLicenseForApp(const steamid: pointer; appid: integer): integer` |
| `0x006F9758` | `function SteamwrapIsBehindNAT: boolean` |
| `0x006F9770` | `procedure SteamwrapAdvertiseGame(steamidgameserver: pointer; ipserver: integer; portserver: integer)` |
| `0x006F97A0` | `procedure SteamwrapRequestEncryptedAppTicket(var datatoinclude: pointer; cdatatoinclude: integer; var steamapicall: pointer)` |
| `0x006F97E4` | `function SteamwrapGetEncryptedAppTicket(var ticket: pointer; maxticket: integer; var cticket: integer): boolean` |
| `0x006F9814` | `function SteamwrapGetGameBadgeLevel(series: integer; foil: boolean): integer` |
| `0x006F9858` | `function SteamwrapRequestCurrentStats: boolean` |
| `0x006F9A10` | `function SteamwrapUpdateAvgRateStat(name: string; countthissession, sessionlength: float): boolean` |
| `0x006F9A80` | `function SteamwrapGetAchievement(name: string; var achieved: boolean): boolean` |
| `0x006F9AE8` | `function SteamwrapSetAchievement(name: string): boolean` |
| `0x006F9B4C` | `function SteamwrapClearAchievement(name: string): boolean` |
| `0x006F9C1C` | `function SteamwrapStoreStats: boolean` |
| `0x006F9C34` | `function SteamwrapGetAchievementIcon(name: string): integer` |
| `0x006F9C98` | `function SteamwrapGetAchievementDisplayAttribute(name, key: string): string` |
| `0x006F9D20` | `function SteamwrapIndicateAchievementProgress(name: string; curprogress, maxprogress: integer): boolean` |
| `0x006F9D8C` | `function SteamwrapGetNumAchievements: integer` |
| `0x006F9DA4` | `function SteamwrapGetAchievementName(achievement: integer): string` |
| `0x006F9DDC` | `procedure SteamwrapRequestUserStats(const steamiduser: pointer; var steamapicall: pointer)` |
| `0x006F9F14` | `function SteamwrapGetUserAchievement(const steamiduser: pointer; name: string; var achieved: boolean): boolean` |
| `0x006FA008` | `function SteamwrapResetAllStats(achievementstoo: boolean): boolean` |
| `0x006FA02C` | `procedure SteamwrapFindOrCreateLeaderboard(leaderboardname: string; leaderboardsortmethod: integer; leaderboarddisplaytype: integer; var steamapicall: pointer)` |
| `0x006FA0AC` | `procedure SteamwrapFindLeaderboard(leaderboardname: string; var steamapicall: pointer)` |
| `0x006FA120` | `function SteamwrapGetLeaderboardName(const steamleaderboard: pointer): string` |
| `0x006FA16C` | `function SteamwrapGetLeaderboardEntryCount(const steamleaderboard: pointer): integer` |
| `0x006FA1A0` | `function SteamwrapGetLeaderboardSortMethod(const steamleaderboard: pointer): integer` |
| `0x006FA1D8` | `function SteamwrapGetLeaderboardDisplayType(const steamleaderboard: pointer): integer` |
| `0x006FA210` | `procedure SteamwrapDownloadLeaderboardEntries(const steamleaderboard: pointer; leaderboarddatarequest, rangestart, rangeend: integer; var steamapicall: pointer)` |
| `0x006FA264` | `procedure SteamwrapDownloadLeaderboardEntriesForUsers(const steamleaderboard: pointer; var users: pointer; cusers: integer; var steamapicall: pointer)` |
| `0x006FA2B8` | `function SteamwrapGetDownloadedLeaderboardEntry(const steamleaderboardentries: pointer; index: integer; var leaderboardentry: pointer; var details: integer; detailsmax: integer): boolean` |
| `0x006FA310` | `procedure SteamwrapUploadLeaderboardScore(const steamleaderboard: pointer; leaderboarduploadscoremethod: integer; score: integer; var scoredetails: integer; scoredetailscount: integer; var steamapicall: pointer)` |
| `0x006FA368` | `procedure SteamwrapAttachLeaderboardUGC(const steamleaderboard: pointer; const ugc: pointer; var steamapicall: pointer)` |
| `0x006FA3F8` | `procedure SteamwrapRequestGlobalAchievementPercentages(var steamapicall: pointer)` |
| `0x006FA430` | `function SteamwrapGetMostAchievedAchievementInfo(var name: string; namebuflen: integer; var percent: float; var achieved: boolean): integer` |
| `0x006FA478` | `function SteamwrapGetAchievementAchievedPercent(name: string; var percent: float): boolean` |
| `0x006FA4E0` | `procedure SteamwrapRequestGlobalStats(historydays: integer; var steamapicall: pointer)` |
| `0x006FA598` | `function SteamwrapGetGlobalStatDouble(statname: string; var data: pointer): boolean` |
| `0x006FA694` | `function SteamwrapGetGlobalStatHistoryDouble(statname: string; var data: pointer; cdata: integer): integer` |
| `0x006FA714` | `function SteamwrapFriendsGetPersonaName: string` |
| `0x006FA748` | `function SteamwrapFriendsSetPersonaName(var name: string): integer` |
| `0x006FA788` | `function SteamwrapFriendsGetFriendCount(friendflags: integer): integer` |
| `0x006FA7AC` | `procedure SteamwrapFriendsGetFriendByIndex(friendindex, friendflags: integer; var steamid: pointer)` |
| `0x006FA800` | `function SteamwrapFriendsGetFriendRelationship(const friendid: pointer): integer` |
| `0x006FA868` | `function SteamwrapFriendsGetFriendPersonaName(const friendid: pointer): string` |
| `0x006FA8B4` | `function SteamwrapFriendsGetFriendGamePlayed(const friendid: pointer; var friendgameinfo: pointer): boolean` |
| `0x006FA900` | `function SteamwrapFriendsGetFriendPersonaNameHistory(const friendid: pointer; personanamenum: integer): string` |
| `0x006FA99C` | `function SteamwrapFriendsHasFriend(const friendid: pointer; friendflags: integer): boolean` |
| `0x006FA9D4` | `function SteamwrapIsSubscribed: boolean` |
| `0x006FA9EC` | `function SteamwrapIsLowViolence: boolean` |
| `0x006FAA04` | `function SteamwrapIsCybercafe: boolean` |
| `0x006FAA1C` | `function SteamwrapIsVACBanned: boolean` |
| `0x006FAA34` | `function SteamwrapGetCurrentGameLanguage: string` |
| `0x006FAA68` | `function SteamwrapGetAvailableGameLanguages: string` |
| `0x006FAA9C` | `function SteamwrapIsSubscribedApp(appid: integer): boolean` |
| `0x006FAAC0` | `function SteamwrapIsDlcInstalled(appid: integer): boolean` |
| `0x006FAB08` | `function SteamwrapIsSubscribedFromFreeWeekend: boolean` |
| `0x006FAB20` | `function SteamwrapGetDLCCount: integer` |
| `0x006FAB38` | `function SteamwrapGetDLCDataByIndex(idlc: integer; var appid: integer; var isavailable: boolean; var name: string; namepbuffersize: integer): boolean` |
| `0x006FAB84` | `procedure SteamwrapInstallDLC(appid: integer)` |
| `0x006FABA4` | `procedure SteamwrapUninstallDLC(appid: integer)` |
| `0x006FABC4` | `procedure SteamwrapRequestAppProofOfPurchaseKey(appid: integer)` |
| `0x006FABE4` | `function SteamwrapGetCurrentBetaName(var name: string; namepbuffersize: integer): boolean` |
| `0x006FAC24` | `function SteamwrapMarkContentCorrupt(ismissingfilesonly: boolean): boolean` |
| `0x006FAC48` | `function SteamwrapGetInstalledDepots(appid: integer; var depots: integer; maxdepots: integer): integer` |
| `0x006FAC78` | `function SteamwrapGetAppInstallDir(appid: integer; var folder: string; folderpbuffersize: integer): integer` |
| `0x006FACBC` | `function SteamwrapIsAppInstalled(appid: integer): boolean` |
| `0x006FACE0` | `procedure SteamwrapGetAppOwner(var steamid: pointer)` |
| `0x006FAD28` | `function SteamwrapGetLaunchQueryParam(var key: string): string` |
| `0x006FAD64` | `function SteamwrapAppListGetNumInstalledApps: integer` |
| `0x006FAD7C` | `function SteamwrapAppListGetInstalledApps(var appid: integer; unmaxappids: integer): integer` |
| `0x006FADA8` | `function SteamwrapAppListGetAppName(nappid: integer; var name: string; namemax: integer): integer` |
| `0x006FADEC` | `function SteamwrapAppListGetAppInstallDir(nappid: integer; var directory: string; namemax: integer): integer` |
| `0x006FAE30` | `function SteamwrapAppListGetAppBuildId(nappid: integer): integer` |
| `0x006FAE54` | `function SteamIsWorkshopPrepared: boolean` |
| `0x006FAE74` | `function SteamIsWorkshopDownloading: boolean` |
| `0x006FAE94` | `function SteamIsWorkshopUploading: boolean` |
| `0x006FAEB4` | `function SteamPrepareWorkshop(const loading, autoupdate: boolean): boolean` |
| `0x006FAF78` | `procedure SteamWorkshopCallback(const smhnd: integer; const onrequestugcdetails, oncreateitem, onsubmititemupdate, ongetitemupdateprogress, onworkshopautoupdate: string)` |
| `0x006FB008` | `function SteamSyncWorkshopItems(const parser: integer): integer` |
| `0x006FB040` | `function SteamGetWorkshopAutoupdate: boolean` |
| `0x006FB060` | `procedure SteamSetWorkshopAutoupdate(const val: boolean)` |
| `0x006FB080` | `function SteamGetWorkshopNumsloaded: integer` |
| `0x006FB098` | `function SteamGetWorkshopNumsubscribed: integer` |
| `0x006FB0B0` | `function SteamGetWorkshopCreate: integer` |
| `0x006FB0DC` | `function SteamGetWorkshopUpload: integer` |
| `0x006FB108` | `function SteamGetWorkshopHandle: integer` |
| `0x006FB120` | `function SteamGetWorkshopUpdStatus: integer` |
| `0x006FB138` | `function SteamGetWorkshopUpdBytesDone: integer` |
| `0x006FB198` | `function SteamGetWorkshopUpdBytesTotal: integer` |

## 2. Юниты / объекты / игроки

Пары `My*` (текущий объект) / `*ByHandle` (по хендлу). Позиция, приказы, бой, ресурсы игрока, отряды, страны, сценарии (образец для квестов), ИИ-регионы.

### AIRegion — 67

| VA | Объявление |
|---|---|
| `0x006A9268` | `function GetAIRegionManagerEnabled(): Boolean` |
| `0x006A9288` | `procedure SetAIRegionManager(enabled: Boolean)` |
| `0x006A92B0` | `function GetCurrentAIRegionName:String` |
| `0x006A92EC` | `function GetCurrentAIRegionIncludeEvent:Boolean` |
| `0x006A9744` | `function AutoScanAIRegionEvadePortal(const sonnotify: String): Integer` |
| `0x006A9D60` | `function CountOfAIRegions(): Integer` |
| `0x006A9D84` | `function GetAIRegionNameByIndex(index: Integer): String` |
| `0x006A9DD4` | `function GetAIRegionEnabled(const name: String): Boolean` |
| `0x006A9E10` | `procedure SetAIRegionEnabled(const name: String; enabled: Boolean)` |
| `0x006A9EE4` | `function GetAIRegionCustomNameByIndex(const name: String; index: Integer): String` |
| `0x006A9F44` | `function AIRegionDoScanObjects(const name: String): Integer` |
| `0x006A9F90` | `procedure AIRegionDoClearObjects(const name: String)` |
| `0x006AA15C` | `function GetAIRegionObjectExists(const name: String; const playername: String): Boolean` |
| `0x006AA19C` | `function GetAIRegionObjectExists2(const name: String; const playername: String; const basename: String): Boolean` |
| `0x006AA1E0` | `function GetAIRegionObjectIndex(const name: String; const playername: String; const basename: String): Integer` |
| `0x006AA2EC` | `function GetAIRegionNotifyStateName(const name: String):String` |
| `0x006AA33C` | `procedure GetAIRegionExtends(const name: String; var minx, miny, maxx, maxy: Float)` |
| `0x006AEF28` | `function GetCurrentAIRegionHandle: Integer)` |
| `0x006AEF4C` | `procedure SetAIRegionNameByHandle(const reghnd: Integer; name: String)` |
| `0x006AEFA8` | `function GetAIRegionNameByHandle(const reghnd: Integer): String` |
| `0x006AEFDC` | `function GetAIRegionHandleByName(const name: String): Integer` |
| `0x006AEFF8` | `function GetAIRegionHandleByIndex(const index: Integer): Integer` |
| `0x006AF014` | `function GetAIRegionIndexByHandle(const reghnd: Integer): Integer` |
| `0x006AF038` | `function CreateAIRegion(const name: String): Integer` |
| `0x006AF064` | `function GetAIRegionEnabledByHandle(const reghnd: Integer): Boolean` |
| `0x006AF084` | `procedure SetAIRegionEnabledByHandle(const reghnd: Integer; enabled: Boolean)` |
| `0x006AF120` | `function GetAIRegionGOHandleByGOIndexByHandle(const reghnd, index: Integer): Integer` |
| `0x006AF14C` | `function AIRegionDoScanObjectsByHandle(const reghnd: Integer): Integer` |
| `0x006AF180` | `function AIRegionDoScanObjectsExtByHandle(const reghnd: Integer; const clear, notify: boolean): Integer` |
| `0x006AF1B4` | `procedure AIRegionDoUpdateObject(const reghnd, gohnd: Integer; const notify: boolean)` |
| `0x006AF200` | `procedure AIRegionDoClearObjectsByHandle(const reghnd: Integer)` |
| `0x006AF220` | `function GetAIRegionNotifyStateNameByHandle(const reghnd: Integer): String` |
| `0x006AF254` | `procedure SetAIRegionNotifyStateNameByHandle(const reghnd: Integer; state: String)` |
| `0x006AF2B0` | `procedure GetAIRegionExtendsByHandle(const reghnd: Integer; var minx, miny, maxx, maxy: Float)` |
| `0x006AF304` | `procedure SetAIRegionExtendsByHandle(const reghnd: Integer; minx, miny, maxx, maxy: Float)` |
| `0x006AF348` | `procedure DeleteAIRegionByHandle(const reghnd: Integer)` |
| `0x006AF380` | `procedure DeleteAIRegionByIndex(const airegind: Integer)` |
| `0x006AF39C` | `procedure AIRegionSaveToTextFile(const filename: String)` |
| `0x006AF3B8` | `procedure AIRegionLoadFromTextFile(const filename: String)` |
| `0x006AF3D4` | `procedure AIRegionFromParserStruct(const parser: Integer)` |
| `0x006AF3F0` | `procedure AIRegionToParserStruct(const parser: Integer)` |
| `0x006AF40C` | `function GetAIRegionStateMachineHandle(const reghnd: Integer): Integer` |
| `0x006AF42C` | `function GetAIRegionStateMachineHandleByName(const regname: String): Integer` |
| `0x006AF454` | `function GetAIRegionScanObjectsByHandle(const reghnd: Integer): Boolean` |
| `0x006AF474` | `procedure SetAIRegionScanObjectsByHandle(const reghnd: Integer; const scanobj: Boolean)` |
| `0x006AF494` | `function GetAIRegionOnProgressByHandle(const reghnd: Integer): String` |
| `0x006AF4C8` | `procedure SetAIRegionOnProgressByHandle(const reghnd: Integer; const onprogress: String)` |
| `0x006AF4E8` | `function GetAIRegionIntervalByHandle(const reghnd: Integer): Integer` |
| `0x006AF508` | `procedure SetAIRegionIntervalByHandle(const reghnd, interval: Integer)` |
| `0x006AF57C` | `function GetAIRegionScanModeByHandle(const reghnd: Integer): Integer` |
| `0x006AF59C` | `procedure SetAIRegionScanModeByHandle(const reghnd, scanmode: Integer)` |
| `0x006AF5BC` | `function GetAIRegionOnIncludeByHandle(const reghnd: Integer): String` |
| `0x006AF5F0` | `procedure SetAIRegionOnIncludeByHandle(const reghnd: Integer; const oninclude: String)` |
| `0x006AF610` | `function GetAIRegionOnDecludeByHandle(const reghnd: Integer): String` |
| `0x006AF644` | `procedure SetAIRegionOnDecludeByHandle(const reghnd: Integer; const ondeclude: String)` |
| `0x006AF664` | `function GetAIRegionOnNotifyByHandle(const reghnd: Integer): String` |
| `0x006AF698` | `procedure SetAIRegionOnNotifyByHandle(const reghnd: Integer; const onnotify: String)` |
| `0x006AF6C0` | `function GetAIRegionExecuteAsFuncByHandle(const reghnd: Integer): Boolean` |
| `0x006AF6E0` | `procedure SetAIRegionExecuteAsFuncByHandle(const reghnd: Integer; const execasfunc: Boolean)` |
| `0x006AF700` | `function GetAIRegionUseCollisionByHandle(const reghnd: Integer): Boolean` |
| `0x006AF720` | `procedure SetAIRegionUseCollisionByHandle(const reghnd: Integer; const val: Boolean)` |
| `0x006AF780` | `function GetAIRegionUseInitializedByHandle(const reghnd: Integer): Boolean` |
| `0x006AF7A0` | `procedure SetAIRegionUseInitializedByHandle(const reghnd: Integer; const val: Boolean)` |
| `0x006AF7C0` | `function GetAIRegionUsePlayableObjByHandle(const reghnd: Integer): Boolean` |
| `0x006AF7E0` | `procedure SetAIRegionUsePlayableObjByHandle(const reghnd: Integer; const val: Boolean)` |
| `0x006AF800` | `function GetAIRegionUseVisibleByHandle(const reghnd: Integer): Boolean` |
| `0x006AF820` | `procedure SetAIRegionUseVisibleByHandle(const reghnd: Integer; const val: Boolean)` |

### Country — 5

| VA | Объявление |
|---|---|
| `0x00684170` | `procedure LanSetMyCountry(const acountry: String)` |
| `0x00684B54` | `function LanPublicServerGetClientCountryByIndex(aclientindex: Integer): String` |
| `0x00684BD4` | `function LanPublicServerGetClientCountryByClientID(aclientid: Integer): String` |
| `0x006851B0` | `function LanPublicServerProfCountry: String` |
| `0x006F8FD0` | `function SteamwrapGetIPCountry: string` |

### GameObject — 1006

| VA | Объявление |
|---|---|
| `0x0060DDEC` | `function IsGameObjectByHandle(gohandle: Integer): Boolean` |
| `0x00645BA8` | `function GetGameObjectFrameAnimationNameByHandle(gohandle: Integer): String` |
| `0x00645BDC` | `function GetGameObjectMyFrameAnimationName(): String` |
| `0x00645C10` | `function GameObjectGetMyActorName(): String` |
| `0x00645C44` | `function GameObjectGetActorNameByHandle(gohandle: Integer): String` |
| `0x00645C78` | `procedure SetGameObjectMyActorName(const actorname: String)` |
| `0x00645CA0` | `procedure SetGameObjectActorNameByHandle(gohandle: Integer; const actorname: String)` |
| `0x00645CC0` | `function GetGameObjectMyCurrentFrame(): Integer` |
| `0x00645CE4` | `function GetGameObjectCurrentFrameByHandle(gohandle: Integer): Integer` |
| `0x00645D08` | `procedure SetGameObjectMyCurrentFrame(currentframe: Integer)` |
| `0x00645D70` | `procedure SetGameObjectCurrentFrameByHandle(gohandle: Integer; currentframe: Integer)` |
| `0x00645DBC` | `function GetGameObjectMyAnimationMode(): String` |
| `0x00645DF8` | `function GetGameObjectAnimationModeByHandle(gohandle: Integer): String` |
| `0x00645E34` | `procedure SetGameObjectMyAnimationMode(const animationmode: String)` |
| `0x00645E64` | `procedure SetGameObjectAnimationModeByHandle(gohandle: Integer; const animationmode: String)` |
| `0x00645E94` | `function GetGameObjectAnimationModeIntByHandle(hnd: Integer): Integer` |
| `0x00645EC0` | `procedure SetGameObjectAnimationModeIntByHandle(hnd, mode: Integer)` |
| `0x00645EE0` | `function GetGameObjectMyMaterialName(): String` |
| `0x00645F30` | `function GetGameObjectMaterialNameByHandle(gohandle: Integer): String` |
| `0x00645F74` | `procedure SetGameObjectMyMaterialName(const materialname: String)` |
| `0x00645FB4` | `procedure SetGameObjectMaterialNameByHandle(gohandle: Integer; const materialname: String)` |
| `0x00645FEC` | `function GetGameObjectMyAnimationCycleName(): String` |
| `0x00646028` | `function GetGameObjectAnimationCycleNameByHandle(gohandle: Integer): String` |
| `0x00646060` | `function GetGameObjectMyAnimationControlerEnabled(): Boolean` |
| `0x00646088` | `function GetGameObjectAnimationControlerEnabledByHandle(gohandle: Integer): Boolean` |
| `0x006460B0` | `procedure SetGameObjectMyAnimationControlerEnabled(enabled: Boolean)` |
| `0x006460E0` | `procedure SetGameObjectAnimationControlerEnabledByHandle(gohandle: Integer; enabled: Boolean)` |
| `0x00646108` | `function GetGameObjectMyPlayerName(): String` |
| `0x0064613C` | `function GetGameObjectMyCustomName(): String` |
| `0x00646170` | `function GetGameObjectMyHandle(): Integer` |
| `0x0064618C` | `function GetGameObjectMyStateMachineActive(): Boolean` |
| `0x006461B0` | `function GetGameObjectStateMachineActiveByHandle(gohandle: Integer): Boolean` |
| `0x006461D4` | `procedure SetGameObjectMyStateMachineActive(active: Boolean)` |
| `0x006461FC` | `procedure SetGameObjectStateMachineActiveByHandle(gohandle: Integer; active: Boolean)` |
| `0x0064621C` | `function GetGameObjectMyTrackPointMovementMode(): String` |
| `0x00646260` | `function GetGameObjectTrackPointMovementModeByHandle(gohandle: Integer): String` |
| `0x006462A0` | `function GetGameObjectMyTrackPointMovementModeInt(): Integer` |
| `0x006462CC` | `function GetGameObjectTrackPointMovementModeIntByHandle(gohandle: Integer): Integer` |
| `0x006462FC` | `procedure SetGameObjectMyTrackPointMovementMode(const movementmode: String)` |
| `0x00646330` | `procedure SetGameObjectTrackPointMovementModeByHandle(gohandle: Integer; const movementmode: String)` |
| `0x00646364` | `function GetGameObjectMyTrackPointCurrentPointIndex(): Integer` |
| `0x0064638C` | `function GetGameObjectTrackPointCurrentPointIndexByHandle(gohandle: Integer): Integer` |
| `0x006463B4` | `procedure SetGameObjectMyTrackPointCurrentPointIndex(currentpointindex: Integer)` |
| `0x006463E4` | `procedure SetGameObjectTrackPointCurrentPointIndexByHandle(gohandle: Integer; currentpointindex: Integer)` |
| `0x0064640C` | `function GetGameObjectMyTrackPointAnimationNameMove(): String` |
| `0x0064644C` | `function GetGameObjectTrackPointAnimationNameMoveByHandle(gohandle: Integer): String` |
| `0x00646488` | `procedure SetGameObjectMyTrackPointAnimationNames(const animationnamemove: String; const animationnamestand: String)` |
| `0x006464D4` | `procedure SetGameObjectTrackPointAnimationNamesByHandle(gohandle: Integer; const animationnamemove: String; const animationnamestand: String)` |
| `0x00646514` | `function GetGameObjectMyTrackPointAnimationNameStand(): String` |
| `0x00646554` | `function GetGameObjectTrackPointAnimationNameStandByHandle(gohandle: Integer): String` |
| `0x00646590` | `function GetGameObjectMyTrackPointUseAnimationCycles(): Boolean` |
| `0x006465BC` | `function GetGameObjectTrackPointUseAnimationCyclesByHandle(gohandle: Integer): Boolean` |
| `0x006465E8` | `procedure SetGameObjectMyTrackPointUseAnimationCycles(useanimationcycles: Boolean)` |
| `0x00646640` | `procedure SetGameObjectTrackPointUseAnimationCyclesByHandle(gohandle: Integer; useanimationcycles: Boolean)` |
| `0x00646690` | `function GetGameObjectMyTrackPointStartPointIndex(): Integer` |
| `0x006466B8` | `function GetGameObjectTrackPointStartPointIndexByHandle(gohandle: Integer): Integer` |
| `0x006466E0` | `function GetGameObjectMyTrackPointEndPointIndex(): Integer` |
| `0x00646708` | `function GetGameObjectTrackPointEndPointIndexByHandle(gohandle: Integer): Integer` |
| `0x00646730` | `procedure SetGameObjectTrackPointRaycastArrow(gohandle: Integer; araycast: Boolean)` |
| `0x00646780` | `function GetGameObjectTrackPointRaycastArrow(gohandle: Integer): Boolean` |
| `0x006467AC` | `procedure GameObjectMyTrackPointClear()` |
| `0x00646804` | `procedure GameObjectTrackPointClearByHandle(gohandle: Integer)` |
| `0x00646828` | `procedure GameObjectMyTrackPointAdd(x: Float; y: Float; z: Float)` |
| `0x00646884` | `procedure GameObjectTrackPointAddByHandle(gohandle: Integer; x: Float; y: Float; z: Float)` |
| `0x006468D0` | `procedure GameObjectMyTrackPointInsert(ind: Integer; x: Float; y: Float; z: Float)` |
| `0x00646930` | `procedure GameObjectTrackPointInsertByHandle(gohandle: Integer; ind: Integer; x: Float; y: Float; z: Float)` |
| `0x00646980` | `procedure GameObjectTrackPointSetByHandle(gohandle: Integer; ind: Integer; x: Float; y: Float; z: Float)` |
| `0x006469F4` | `procedure GameObjectTrackPointDeleteByHandle(gohandle: Integer; ind: Integer)` |
| `0x00646A2C` | `function GetGameObjectMyPositionX(): Float` |
| `0x00646A5C` | `function GetGameObjectMyPositionY(): Float` |
| `0x00646A8C` | `function GetGameObjectMyPositionZ(): Float` |
| `0x00646ABC` | `function GetGameObjectPositionYByHandle(gohandle: Integer): Float` |
| `0x00646AEC` | `function GetGameObjectPositionZByHandle(gohandle: Integer): Float` |
| `0x00646B1C` | `function GetGameObjectBoundingSphereByHandle(gohandle: Integer): Float` |
| `0x00646B4C` | `procedure GetGameObjectTLFTransformedPositionZByHandle(gohandle: Integer; var x, y, z: Float)` |
| `0x00646C04` | `procedure GetGameObjectTLFTransformedPositionLocalByHandle(gohnd: Integer; var x, y, z: Float)` |
| `0x00646CC4` | `procedure GetGameObjectTLFPositionByHandle(gohnd: Integer; var x, y, z: Float)` |
| `0x00646D5C` | `procedure GetGameObjectVectorTransformByHandle(gohnd: Integer; var x, y, z: Float)` |
| `0x00646DD4` | `procedure GetGameObjectAbsoluteVectorTransformByHandle(gohnd: Integer; var x, y, z: Float)` |
| `0x00646E4C` | `procedure SetGameObjectMyPosition(x: Float; y: Float; z: Float)` |
| `0x00646EDC` | `procedure SetGameObjectPositionByHandle(gohandle: Integer; x: Float; y: Float; z: Float)` |
| `0x00646F2C` | `procedure GameObjectMyVirtualMove(distance: Float)` |
| `0x00646F54` | `procedure GameObjectVirtualMoveByHandle(gohandle: Integer; distance: Float)` |
| `0x00646F74` | `procedure GameObjectVirtualTurnByHandle(gohandle: Integer; angle: Float)` |
| `0x00646F94` | `procedure GameObjectMyVirtualTurn(angle: Float)` |
| `0x00646FBC` | `procedure GameObjectMyLift(distance: Float)` |
| `0x00646FE4` | `procedure GameObjectLiftByHandle(gohandle: Integer; distance: Float)` |
| `0x00647004` | `procedure GameObjectMyMove(distance: Float)` |
| `0x0064702C` | `procedure GameObjectMoveByHandle(gohandle: Integer; distance: Float)` |
| `0x0064704C` | `procedure GameObjectMyTranslate(tx: Float; ty: Float; tz: Float)` |
| `0x0064707C` | `procedure GameObjectTranslateByHandle(gohandle: Integer; tx: Float; ty: Float; tz: Float)` |
| `0x006470A4` | `procedure GameObjectMyMoveAround(pitchdelta: Float; turndelta: Float; anx: Float; any: Float; anz: Float)` |
| `0x006470EC` | `procedure GameObjectMoveAroundByHandle(gohandle: Integer; pitchdelta: Float; turndelta: Float; anx: Float; any: Float; anz: Float)` |
| `0x00647130` | `procedure GameObjectMyPitch(angle: Float)` |
| `0x00647158` | `procedure GameObjectPitchByHandle(gohandle: Integer; angle: Float)` |
| `0x00647178` | `procedure GameObjectMyRoll(angle: Float)` |
| `0x006471A0` | `procedure GameObjectRollByHandle(gohandle: Integer; angle: Float)` |
| `0x006471C0` | `procedure GameObjectMyTurn(angle: Float)` |
| `0x006471E8` | `procedure GameObjectTurnByHandle(gohandle: Integer; angle: Float)` |
| `0x00647208` | `procedure GameObjectMyResetRotations()` |
| `0x00647228` | `procedure GameObjectResetRotationsByHandle(gohandle: Integer)` |
| `0x00647248` | `procedure GameObjectMyResetAndPitchTurnRoll(degx: Float; degy: Float; degz: Float)` |
| `0x00647278` | `procedure GameObjectResetAndPitchTurnRollByHandle(gohandle: Integer; degx: Float; degy: Float; degz: Float)` |
| `0x006472A0` | `procedure GameObjectMyRotateAbsolute(rx: Float; ry: Float; rz: Float)` |
| `0x006472D0` | `procedure GameObjectRotateAbsoluteByHandle(gohandle: Integer; rx: Float; ry: Float; rz: Float)` |
| `0x006472F8` | `procedure GameObjectMySlide(distance: Float)` |
| `0x00647320` | `procedure GameObjectSlideByHandle(gohandle: Integer; distance: Float)` |
| `0x00647340` | `procedure GameObjectMyPointTo(px: Float; py: Float; pz: Float; upx: Float; upy: Float; upz: Float)` |
| `0x0064739C` | `procedure GameObjectPointToByHandle(gohandle: Integer; px: Float; py: Float; pz: Float; upx: Float; upy: Float; upz: Float)` |
| `0x006473F4` | `function GetGameObjectMyPitchAngle(): Float` |
| `0x00647424` | `function GetGameObjectPitchAngleByHandle(gohandle: Integer): Float` |
| `0x00647454` | `procedure SetGameObjectMyPitchAngle(pitchangle: Float)` |
| `0x0064747C` | `procedure SetGameObjectPitchAngleByHandle(gohandle: Integer; pitchangle: Float)` |
| `0x0064749C` | `function GetGameObjectMyRollAngle(): Float` |
| `0x006474CC` | `function GetGameObjectRollAngleByHandle(gohandle: Integer): Float` |
| `0x006474FC` | `procedure SetGameObjectMyRollAngle(rollangle: Float)` |
| `0x00647524` | `procedure SetGameObjectRollAngleByHandle(gohandle: Integer; rollangle: Float)` |
| `0x00647544` | `function GetGameObjectMyTurnAngle(): Float` |
| `0x00647574` | `function GetGameObjectTurnAngleByHandle(gohandle: Integer): Float` |
| `0x006475A4` | `procedure SetGameObjectMyTurnAngle(turnangle: Float)` |
| `0x006475CC` | `procedure SetGameObjectTurnAngleByHandle(gohandle: Integer; turnangle: Float)` |
| `0x006475EC` | `function GetGameObjectMyScaleX(): Float` |
| `0x0064761C` | `function GetGameObjectScaleXByHandle(gohandle: Integer): Float` |
| `0x0064764C` | `function GetGameObjectMyScaleY(): Float` |
| `0x0064767C` | `function GetGameObjectScaleYByHandle(gohandle: Integer): Float` |
| `0x006476AC` | `function GetGameObjectMyScaleZ(): Float` |
| `0x006476DC` | `function GetGameObjectScaleZByHandle(gohandle: Integer): Float` |
| `0x0064770C` | `procedure SetGameObjectMyScale(x: Float; y: Float; z: Float)` |
| `0x0064773C` | `procedure SetGameObjectScaleByHandle(gohandle: Integer; x: Float; y: Float; z: Float)` |
| `0x00647768` | `function GetGameObjectMyTrackPointMoveStepInterval(): Integer` |
| `0x00647790` | `function GetGameObjectTrackPointMoveStepIntervalByHandle(gohandle: Integer): Integer` |
| `0x006477B8` | `procedure SetGameObjectTrackPointMoveStepIntervalByHandle(gohandle: Integer; movestepinterval: Integer)` |
| `0x006477DC` | `function GetGameObjectPositionXByHandle(gohandle: Integer): Float` |
| `0x0064780C` | `procedure SetGameObjectMyTrackPointMoveStepInterval(movestepinterval: Integer)` |
| `0x00647838` | `function GetGameObjectMyTrackPointMoveStep(): Float` |
| `0x0064786C` | `function GetGameObjectTrackPointMoveStepByHandle(gohandle: Integer): Float` |
| `0x0064789C` | `procedure SetGameObjectMyTrackPointMoveStep(movestep: Float)` |
| `0x006478CC` | `procedure SetGameObjectTrackPointMoveStepByHandle(gohandle: Integer; movestep: Float)` |
| `0x006478F4` | `function GetGameObjectMyTrackPointTurnStepInterval(): Integer` |
| `0x0064791C` | `function GetGameObjectTrackPointTurnStepIntervalByHandle(gohandle: Integer): Integer` |
| `0x00647944` | `procedure SetGameObjectMyTrackPointTurnStepInterval(turnstepinterval: Integer)` |
| `0x00647970` | `procedure SetGameObjectTrackPointTurnStepIntervalByHandle(gohandle: Integer; turnstepinterval: Integer)` |
| `0x00647994` | `function GetGameObjectMyTrackPointTurnStep(): Float` |
| `0x006479C8` | `function GetGameObjectTrackPointTurnStepByHandle(gohandle: Integer): Float` |
| `0x006479F8` | `procedure SetGameObjectMyTrackPointTurnStep(turnstep: Float)` |
| `0x00647A24` | `procedure SetGameObjectTrackPointTurnStepByHandle(gohandle: Integer; turnstep: Float)` |
| `0x00647A48` | `procedure SetGameObjectTrackPointFollowAutoMovement(gohandle: Integer; bauto: Boolean)` |
| `0x00647A70` | `procedure SetGameObjectTrackPointFollowMinMoveStep(gohandle: Integer; min: Float)` |
| `0x00647A98` | `procedure SetGameObjectTrackPointFollowMaxMoveStep(gohandle: Integer; max: Float)` |
| `0x00647AC0` | `procedure SetGameObjectTrackPointFollowMinTurnStep(gohandle: Integer; min: Float)` |
| `0x00647AE8` | `procedure SetGameObjectTrackPointFollowMaxTurnStep(gohandle: Integer; max: Float)` |
| `0x00647B10` | `procedure SetGameObjectTrackPointFollowMoveMaxRange(gohandle: Integer; range: Float)` |
| `0x00647B38` | `procedure SetGameObjectTrackPointFollowAnimMove(gohandle: Integer; const s: String)` |
| `0x00647B68` | `procedure SetGameObjectTrackPointFollowAnimStand(gohandle: Integer; const s: String)` |
| `0x00647B98` | `procedure GameObjectTrackPointAddFollowPointByHandle(gohandle: Integer; x, y, z: Float)` |
| `0x00647BD8` | `procedure GameObjectTrackPointClearFollowPointsByHandle(gohandle: Integer)` |
| `0x00647BFC` | `procedure SetGameObjectTrackPointFollowTheFlagmanByHandle(gohandle: Integer; aindex: Integer)` |
| `0x00647C24` | `function GetGameObjectTrackPointFollowTheFlagmanPointIndexByHandle(gohandle: Integer): Integer` |
| `0x00647C50` | `procedure SetGameObjectOnStateFollowTargetMoveAway(gohandle: Integer; const aevent: String)` |
| `0x00647C80` | `function GetGameObjectMyVirtualUpX(): Float` |
| `0x00647CB0` | `function GetGameObjectMyVirtualUpY(): Float` |
| `0x00647CE0` | `function GetGameObjectMyVirtualUpZ(): Float` |
| `0x00647D10` | `function GetGameObjectVirtualUpXByHandle(gohandle: Integer): Float` |
| `0x00647D40` | `function GetGameObjectVirtualUpYByHandle(gohandle: Integer): Float` |
| `0x00647D70` | `function GetGameObjectVirtualUpZByHandle(gohandle: Integer): Float` |
| `0x00647DA0` | `procedure SetGameObjectMyVirtualUp(x: Float; y: Float; z: Float)` |
| `0x00647DF0` | `procedure SetGameObjectVirtualUpByHandle(gohandle: Integer; x: Float; y: Float; z: Float)` |
| `0x00647E40` | `function GetGameObjectStateTargetPositionXByHandle(gohandle: Integer): Float` |
| `0x00647E70` | `function GetGameObjectStateTargetPositionYByHandle(gohandle: Integer): Float` |
| `0x00647EA0` | `function GetGameObjectStateTargetPositionZByHandle(gohandle: Integer): Float` |
| `0x00647ED0` | `function GetGameObjectMyStateTargetPositionX(): Float` |
| `0x00647F00` | `function GetGameObjectMyStateTargetPositionY(): Float` |
| `0x00647F30` | `function GetGameObjectMyStateTargetPositionZ(): Float` |
| `0x00647F60` | `procedure SetGameObjectMyStateTargetPosition(x: Float; y: Float; z: Float)` |
| `0x00647FA0` | `procedure SetGameObjectStateTargetPositionByHandle(gohandle: Integer; x: Float; y: Float; z: Float)` |
| `0x00647FDC` | `function GetGameObjectMyStateMachineInterval(): Integer` |
| `0x00648000` | `function GetGameObjectStateMachineIntervalByHandle(gohandle: Integer): Integer` |
| `0x00648024` | `procedure SetGameObjectMyStateMachineInterval(interval: Integer)` |
| `0x0064804C` | `procedure SetGameObjectStateMachineIntervalByHandle(gohandle: Integer; interval: Integer)` |
| `0x0064806C` | `function GetGameObjectMyStateName(): String` |
| `0x006480A0` | `function GetGameObjectStateNameByHandle(gohandle: Integer): String` |
| `0x006480D4` | `procedure GameObjectMySwitchToState(const statename: String)` |
| `0x00648134` | `procedure GameObjectSwitchToStateByHandle(gohandle: Integer; const statename: String)` |
| `0x00648194` | `procedure ReloadGameObjectProperties(gohandle: Integer; const aracename, anewbase: String)` |
| `0x0064826C` | `procedure ReloadGameObjectBaseName(gohandle: Integer; const aracename, anewbase: String)` |
| `0x006483B0` | `function GetGameObjectBaseNameByIndex(const playername: String; index: Integer): String` |
| `0x0064840C` | `function GetGameObjectMyBaseName(): String` |
| `0x00648440` | `function GetGameObjectPlayerNameByHandle(gohandle: Integer): String` |
| `0x00648474` | `function GetGameObjectBaseNameByHandle(gohandle: Integer): String` |
| `0x006484A8` | `function GetGameObjectCustomNameByHandle(gohandle: Integer): String` |
| `0x006484DC` | `procedure SetGameObjectCustomNameByHandle(gohandle: Integer; const sname: String)` |
| `0x006484FC` | `function GetGameObjectMyIndex(): Integer` |
| `0x00648520` | `function GetGameObjectCustomNameByIndex(const playername: String; index: Integer): String` |
| `0x0064857C` | `procedure GameObjectByIndexSwitchToState(const playername: String; index: Integer; const statename: String)` |
| `0x00648600` | `procedure SetGameObjectMyPlayerName(const newplayername: String)` |
| `0x00648628` | `procedure SetGameObjectPlayerNameByHandle(gohandle: Integer; const newplayername: String)` |
| `0x00648648` | `procedure SetGameObjectMyVirtualDirection(x: Float; y: Float; z: Float)` |
| `0x00648688` | `procedure SetGameObjectVirtualDirectionByHandle(gohandle: Integer; x: Float; y: Float; z: Float)` |
| `0x006486C4` | `function GetGameObjectMyEpsilonDistance(): Float` |
| `0x006486F8` | `function GetGameObjectEpsilonDistanceByHandle(gohandle: Integer): Float` |
| `0x0064872C` | `procedure SetGameObjectMyEpsilonDistance(epsilondistance: Float)` |
| `0x00648758` | `procedure SetGameObjectEpsilonDistanceByHandle(gohandle: Integer; epsilondistance: Float)` |
| `0x0064877C` | `function GetGameObjectMyEpsilonAngle(): Float` |
| `0x006487B0` | `function GetGameObjectEpsilonAngleByHandle(gohandle: Integer): Float` |
| `0x006487E4` | `procedure SetGameObjectMyEpsilonAngle(epsilonangle: Float)` |
| `0x00648810` | `procedure SetGameObjectEpsilonAngleByHandle(gohandle: Integer; epsilonangle: Float)` |
| `0x00648834` | `procedure GameObjectMyCreatePath(startx: Float; starty: Float; startz: Float; endx: Float; endy: Float; endz: Float)` |
| `0x006489A8` | `procedure GameObjectMyAddPath(endx: Float; endy: Float; endz: Float)` |
| `0x00648B6C` | `procedure SetGameObjectMyOffsetY(y: Float)` |
| `0x00648B9C` | `procedure SetGameObjectOffsetYByHandle(gohandle: Integer; y: Float)` |
| `0x00648BC4` | `function GetGameObjectMyOffsetY: Float` |
| `0x00648BF4` | `function GetGameObjectOffsetYByHandle(const gohandle: Integer): Float` |
| `0x00648C24` | `procedure SetGameObjectMyTargetObjectByHandle(gohandle: Integer)` |
| `0x00648C78` | `procedure SetGameObjectTargetObjectByHandle(gohandle: Integer; targetgohandle: Integer)` |
| `0x00648CAC` | `procedure SetGameObjectMyTargetRotatingMode(const rotatingmode: String)` |
| `0x00648CE0` | `procedure SetGameObjectTargetRotatingModeByHandle(gohandle: Integer; const rotatingmode: String)` |
| `0x00648D14` | `function GameObjectMySetupRotatingToDirection(dirx, diry, dirz: Float; const sturnleft: String; const sturnright: String; const sidle: String; fanimangle: Float; animtimeinterval: Integer; fminturnangle: Float; busecycles: Boolean): Boolean` |
| `0x00648EA4` | `function GameObjectMySetupRotatingToTarget(posx, posy, posz: Float; const sturnleft: String; const sturnright: String; const sidle: String; fanimangle: Float; animtimeinterval: Integer; fminturnangle: Float; busecycles: Boolean): Boolean` |
| `0x00649034` | `function GameObjectSetupRotatingToDirectionByHandle(gohnd: Integer; dirx, diry, dirz: Float; const turnleft, turnright, idle: String; animangle: Float; animtimeinterval: Integer; minturnangle: Float; usecycles: Boolean): Boolean` |
| `0x006491BC` | `function GameObjectSetupRotatingToTargetByHandle(gohnd: Integer; posx, posy, posz: Float; const turnleft, turnright, idle: String; animangle: Float; animtimeinterval: Integer; minturnangle: Float; usecycles: Boolean): Boolean` |
| `0x00649344` | `procedure SetGameObjectMyRotatingTargetVector(x: Float; y: Float; z: Float)` |
| `0x0064939C` | `procedure SetGameObjectRotatingTargetVectorByHandle(gohandle: Integer; x: Float; y: Float; z: Float)` |
| `0x006493EC` | `procedure GetGameObjectMyRotatingTargetVector(var x: Float; var y: Float; var z: Float)` |
| `0x00649438` | `procedure GetGameObjectRotatingTargetVectorByHandle(gohandle: Integer; var x: Float; var y: Float; var z: Float)` |
| `0x00649480` | `procedure SetGameObjectMyRotatingTargetCoords(x: Float; y: Float; z: Float)` |
| `0x006494D8` | `procedure SetGameObjectRotatingTargetCoordsByHandle(gohandle: Integer; x: Float; y: Float; z: Float)` |
| `0x00649528` | `procedure GetGameObjectMyRotatingTargetCoords(var x: Float;var y: Float;var  z: Float)` |
| `0x00649588` | `procedure GetGameObjectRotatingTargetCoordsByHandle(gohandle: Integer; var x: Float; var y: Float; var z: Float)` |
| `0x006495E0` | `function GetGameObjectOnStateFrameChangedByHandle(gohandle: Integer): String` |
| `0x00649618` | `procedure SetGameObjectOnStateFrameChangedByHandle(gohandle: Integer; const state: String)` |
| `0x00649638` | `function GetGameObjectMyOnStateFrameChanged(): String` |
| `0x00649674` | `procedure SetGameObjectMyOnStateFrameChanged(const state: String)` |
| `0x0064969C` | `function GetGameObjectOnStateEndFrameReachedByHandle(gohandle: Integer): String` |
| `0x006496D4` | `procedure SetGameObjectOnStateEndFrameReachedByHandle(gohandle: Integer; const state: String)` |
| `0x006496F4` | `function GetGameObjectMyOnStateEndFrameReached(): String` |
| `0x00649730` | `procedure SetGameObjectMyOnStateEndFrameReached(const state: String)` |
| `0x00649758` | `function GetGameObjectOnStateStartFrameReachedByHandle(gohandle: Integer): String` |
| `0x00649790` | `procedure SetGameObjectOnStateStartFrameReachedByHandle(gohandle: Integer; const state: String)` |
| `0x006497B0` | `function GetGameObjectMyOnStateStartFrameReached(): String` |
| `0x006497EC` | `procedure SetGameObjectMyOnStateStartFrameReached(const state: String)` |
| `0x00649814` | `function GetGameObjectOnStatePointChangedByHandle(gohandle: Integer): String` |
| `0x00649850` | `procedure SetGameObjectOnStatePointChangedByHandle(gohandle: Integer; const state: String)` |
| `0x00649880` | `function GetGameObjectMyOnStatePointChanged(): String` |
| `0x006498C0` | `procedure SetGameObjectMyOnStatePointChanged(const state: String)` |
| `0x006498F0` | `function GetGameObjectOnStateEndPointReachedByHandle(gohandle: Integer): String` |
| `0x0064992C` | `procedure SetGameObjectOnStateEndPointReachedByHandle(gohandle: Integer; const state: String)` |
| `0x00649954` | `function GetGameObjectMyOnStateEndPointReached(): String` |
| `0x00649994` | `procedure SetGameObjectMyOnStateEndPointReached(const state: String)` |
| `0x006499C4` | `function GetGameObjectOnStateStartPointReachedByHandle(gohandle: Integer): String` |
| `0x00649A00` | `procedure SetGameObjectOnStateStartPointReachedByHandle(gohandle: Integer; const state: String)` |
| `0x00649A30` | `function GetGameObjectMyOnStateStartPointReached(): String` |
| `0x00649A70` | `procedure SetGameObjectMyOnStateStartPointReached(const state: String)` |
| `0x00649AA0` | `procedure SetGameObjectMyFly(fly: Boolean)` |
| `0x00649AD0` | `procedure SetGameObjectFlyByHandle(gohandle: Integer; fly: Boolean)` |
| `0x00649AFC` | `procedure SetGameObjectMyArrow(startpositionx: Float; startpositiony: Float; startpositionz: Float; dirx: Float; diry: Float; dirz: Float; angle: Float; speed: Float; time: Float)` |
| `0x00649BC4` | `procedure SetGameObjectArrowByHandle(gohandle: Integer; startpositionx: Float; startpositiony: Float; startpositionz: Float; dirx: Float; diry: Float; dirz: Float; angle: Float; speed: Float; time: Float)` |
| `0x00649C84` | `function GetGameObjectMyTransformedVirtualDirectionX(): Float` |
| `0x00649CB8` | `function GetGameObjectMyTransformedVirtualDirectionY(): Float` |
| `0x00649CEC` | `function GetGameObjectMyTransformedVirtualDirectionZ(): Float` |
| `0x00649D20` | `function GetGameObjectMyInterval(): Integer` |
| `0x00649D48` | `procedure SetGameObjectMyInterval(interval: Integer)` |
| `0x00649D78` | `function GetGameObjectAnimationCyclesModeByHandle(gohandle: Integer): String` |
| `0x00649DB4` | `procedure SetGameObjectAnimationCyclesModeByHandle(gohandle: Integer; const animationcyclesmode: String)` |
| `0x00649DE8` | `function GetGameObjectMyAnimationCyclesMode(): String` |
| `0x00649E28` | `procedure SetGameObjectMyAnimationCyclesMode(const animationcyclesmode: String)` |
| `0x00649E5C` | `function GetGameObjectOnStateEndCyclesReachedByHandle(gohandle: Integer): String` |
| `0x00649E98` | `procedure SetGameObjectOnStateEndCyclesReachedByHandle(gohandle: Integer; const state: String)` |
| `0x00649EC0` | `function GetGameObjectMyOnStateEndCyclesReached(): String` |
| `0x00649F00` | `procedure SetGameObjectMyOnStateEndCyclesReached(const state: String)` |
| `0x00649F30` | `function GetGameObjectOnStateStartCyclesReachedByHandle(gohandle: Integer): String` |
| `0x00649F6C` | `procedure SetGameObjectOnStateStartCyclesReachedByHandle(gohandle: Integer; const state: String)` |
| `0x00649F94` | `function GetGameObjectMyOnStateStartCyclesReached(): String` |
| `0x00649FD4` | `procedure SetGameObjectMyOnStateStartCyclesReached(const state: String)` |
| `0x0064A004` | `function GetGameObjectOnStateDistanceToPointByHandle(gohandle: Integer): String` |
| `0x0064A040` | `procedure SetGameObjectOnStateDistanceToPointByHandle(gohandle: Integer; const state: String; distance: Float)` |
| `0x0064A07C` | `function GetGameObjectMyOnStateDistanceToPoint(): String` |
| `0x0064A0BC` | `procedure SetGameObjectMyOnStateDistanceToPoint(const state: String; distance: Float)` |
| `0x0064A104` | `procedure SetGameObjectMyArrowTargetCoords(startpositionx: Float; startpositiony: Float; startpositionz: Float; targetcoordx: Float; targetcoordy: Float; targetcoordz: Float; speed: Float; time: Float)` |
| `0x0064A214` | `procedure SetGameObjectArrowTargetCoordsByHandle(gohandle: Integer; startpositionx: Float; startpositiony: Float; startpositionz: Float; targetcoordx: Float; targetcoordy: Float; targetcoordz: Float; speed: Float; time: Float)` |
| `0x0064A31C` | `procedure SetGameObjectMyArrowTargetCoordsAngle(startpositionx: Float; startpositiony: Float; startpositionz: Float; targetcoordx: Float; targetcoordy: Float; targetcoordz: Float; angle: Float; time: Float)` |
| `0x0064A448` | `procedure SetGameObjectArrowTargetCoordsAngleByHandle(gohandle: Integer; startpositionx: Float; startpositiony: Float; startpositionz: Float; targetcoordx: Float; targetcoordy: Float; targetcoordz: Float; angle: Float; time: Float)` |
| `0x0064A570` | `procedure SetGameObjectArrowTargetCoordsAngleExByHandle(gohandle: Integer; startpositionx: Float; startpositiony: Float; startpositionz: Float; targetcoordx: Float; targetcoordy: Float; targetcoordz: Float; angle: Float; time: Float; visiblespeed: Float)` |
| `0x0064A690` | `procedure SetGameObjectMyOnStateDirectionReached(const state: String)` |
| `0x0064A6C4` | `function GetGameObjectMyOnStateDirectionReached(): String` |
| `0x0064A704` | `function GetGameObjectOnStateDirectionReachedByHandle(gohandle: Integer): String` |
| `0x0064A744` | `procedure SetGameObjectOnStateDirectionReachedByHandle(gohandle: Integer; const state: String)` |
| `0x0064A774` | `procedure SetGameObjectMyOnStateArrowTargetReached(const state: String)` |
| `0x0064A7A8` | `procedure SetGameObjectOnStateArrowTargetReachedByHandle(gohandle: Integer; const state: String)` |
| `0x0064A7D8` | `function GetGameObjectOnStateArrowTargetReachedByHandle(gohandle: Integer): String` |
| `0x0064A808` | `function GetGameObjectMyOnStateArrowTargetReached(): String` |
| `0x0064A848` | `procedure SetGameObjectMyArrowTargetEpsilonDistance(distance: Float)` |
| `0x0064A878` | `function GetGameObjectMyArrowTargetEpsilonDistance(): Float` |
| `0x0064A8A8` | `procedure SetGameObjectArrowTargetEpsilonDistanceByHandle(gohandle: Integer; distance: Float)` |
| `0x0064A8D0` | `function GetGameObjectMyTargetObjectPlayerName(): String` |
| `0x0064A938` | `function GetGameObjectMyTargetObjectCustomName(): String` |
| `0x0064A9A0` | `procedure GameObjectClearVariablesByHandle(gohandle: Integer)` |
| `0x0064A9CC` | `procedure GameObjectExecuteStateByHandle(gohandle: Integer; const state: String)` |
| `0x0064AA2C` | `function GetGameObjectDelayExecuteStateNameByHandle(gohandle: Integer): String` |
| `0x0064AA74` | `procedure GameObjectDelayExecuteStateByHandle(gohandle: Integer; const state: String; ftime: Float)` |
| `0x0064AB14` | `procedure GameObjectMyDelayExecuteState(const state: String; ftime: Float)` |
| `0x0064ABC0` | `procedure GameObjectCancelDelayExecuteStateByHandle(gohandle: Integer)` |
| `0x0064ABE0` | `procedure GameObjectMyCancelDelayExecuteState` |
| `0x0064AC00` | `procedure SetGameObjectValueByHandle(gohandle: Integer; const key: String; const value: String)` |
| `0x0064AC3C` | `function GetGameObjectValueByHandle(gohandle: Integer; const key: String): String` |
| `0x0064AC80` | `function GetGameObjectPlayableObjectByHandle(gohandle: Integer): Boolean` |
| `0x0064ACA4` | `procedure SetGameObjectPlayableObjectByHandle(gohandle: Integer; playableobject: Boolean)` |
| `0x0064ACC4` | `function GetGameObjectMyPlayableObject(): Boolean` |
| `0x0064ACE8` | `procedure SetGameObjectMyPlayableObject(playableobject: Boolean)` |
| `0x0064AD10` | `procedure SetGameObjectMyOnStateObservationTargetReached(const state: String)` |
| `0x0064AD44` | `function GetGameObjectMyOnStateObservationTargetReached(): String` |
| `0x0064AD78` | `procedure SetGameObjectOnStateObservationTargetReachedByHandle(gohandle: Integer; const state: String)` |
| `0x0064ADA8` | `function GetGameObjectOnStateObservationTargetReachedByHandle(gohandle: Integer): String` |
| `0x0064ADD8` | `function GetGameObjectMyGroupName(): String` |
| `0x0064AE0C` | `function GetGameObjectGroupNameByHandle(gohandle: Integer): String` |
| `0x0064AE40` | `procedure SetGameObjectPickedByHandle(gohandle: Integer; picked: Boolean)` |
| `0x0064AF0C` | `procedure SetGameObjectMyPicked(picked: Boolean)` |
| `0x0064B004` | `function GetGameObjectPickedByHandle(gohandle: Integer): Boolean` |
| `0x0064B028` | `function GetGameObjectMyPicked(): Boolean` |
| `0x0064B04C` | `procedure GameObjectMyExecuteState(const state: String)` |
| `0x0064B0AC` | `function GetGameObjectMyDistanceTo(const toplayername: String; const tocustomname: String): Float` |
| `0x0064B118` | `function GetGameObjectDistanceToByHandle(gohandle: Integer; togohandle: Integer): Float` |
| `0x0064B168` | `procedure GameObjectPFXCreateByHandle(gohandle: Integer; const managername: String; const key: String)` |
| `0x0064B1A4` | `procedure GameObjectPFXInitialVelocityByHandle(gohandle: Integer; const managername: String; const key: String; initialvelocityx: Float; initialvelocityy: Float; initialvelocityz: Float)` |
| `0x0064B224` | `procedure GameObjectPFXVelocityDispersionByHandle(gohandle: Integer; const managername: String; const key: String; velocitydispersion: Float)` |
| `0x0064B278` | `procedure GameObjectPFXInitialPositionByHandle(gohandle: Integer; const managername: String; const key: String; initialpositionx: Float; initialpositiony: Float; initialpositionz: Float)` |
| `0x0064B2F8` | `procedure GameObjectPFXPositionDispersionByHandle(gohandle: Integer; const managername: String; const key: String; positiondispersion: Float)` |
| `0x0064B34C` | `procedure GameObjectPFXPositionDispersionRangeByHandle(gohandle: Integer; const managername: String; const key: String; positiondispersionrangex: Float; positiondispersionrangey: Float; positiondispersionrangez: Float)` |
| `0x0064B3CC` | `procedure GameObjectPFXParticleIntervalByHandle(gohandle: Integer; const managername: String; const key: String; particleinterval: Float)` |
| `0x0064B424` | `procedure GameObjectPFXVelocityModeByHandle(gohandle: Integer; const managername: String; const key: String; const velocitymode: String)` |
| `0x0064B480` | `procedure GameObjectPFXDispersionModeByHandle(gohandle: Integer; const managername: String; const key: String; const dispersionmode: String)` |
| `0x0064B4DC` | `procedure GameObjectPFXEnabledByHandle(gohandle: Integer; const managername: String; const key: String; enabled: Boolean)` |
| `0x0064B530` | `procedure GameObjectPFXClearByHandle(gohandle: Integer)` |
| `0x0064B558` | `procedure GameObjectPFXDeleteByHandle(gohandle: Integer; const managername: String; const key: String)` |
| `0x0064B594` | `procedure MyGameObjectPFXCreate(const managername: String; const key: String)` |
| `0x0064B5D4` | `procedure MyGameObjectPFXInitialVelocity(const managername: String; const key: String; initialvelocityx: Float; initialvelocityy: Float; initialvelocityz: Float)` |
| `0x0064B658` | `procedure MyGameObjectPFXVelocityDispersion(const managername: String; const key: String; velocitydispersion: Float)` |
| `0x0064B6B4` | `procedure MyGameObjectPFXInitialPosition(const managername: String; const key: String; initialpositionx: Float; initialpositiony: Float; initialpositionz: Float)` |
| `0x0064B738` | `procedure MyGameObjectPFXPositionDispersion(const managername: String; const key: String; positiondispersion: Float)` |
| `0x0064B794` | `procedure MyGameObjectPFXPositionDispersionRange(const managername: String; const key: String; positiondispersionrangex: Float; positiondispersionrangey: Float; positiondispersionrangez: Float)` |
| `0x0064B818` | `procedure MyGameObjectPFXParticleInterval(const managername: String; const key: String; particleinterval: Float)` |
| `0x0064B878` | `procedure MyGameObjectPFXVelocityMode(const managername: String; const key: String; const velocitymode: String)` |
| `0x0064B8D8` | `procedure MyGameObjectPFXDispersionMode(const managername: String; const key: String; const dispersionmode: String)` |
| `0x0064B938` | `procedure MyGameObjectPFXEnabled(const managername: String; const key: String; enabled: Boolean)` |
| `0x0064B994` | `procedure MyGameObjectPFXClear()` |
| `0x0064B9B8` | `procedure MyGameObjectPFXDelete(const managername: String; const key: String)` |
| `0x0064B9F8` | `function GetGameObjectMyGrHandle(): Integer` |
| `0x0064BA38` | `function GetGameObjectMyFBAnimationCycleName(): String` |
| `0x0064BA74` | `function GetGameObjectFBAnimationCycleNameByHandle(gohandle: Integer): String` |
| `0x0064BAAC` | `procedure SetGameObjectMyLODActorName(const lodactorname: String)` |
| `0x0064BAD4` | `procedure SetGameObjectLODActorNameByHandle(gohandle: Integer; const lodactorname: String)` |
| `0x0064BC24` | `procedure ReloadGameObjectLodActorByHandle(gohandle: Integer; const asubfrom, asubnew: String)` |
| `0x0064BC40` | `function GetGameObjectMyCountChild(): Integer` |
| `0x0064BC64` | `function GetGameObjectAllChildByCustomNameToArrayByHandle(gohandle: Integer; const scustom: String): Integer` |
| `0x0064BD34` | `function GetGameObjectCountChildByHandle(gohandle: Integer): Integer` |
| `0x0064BD58` | `function GetGameObjectGOHandleChildByHandle(gohandle: Integer; index: Integer): Integer` |
| `0x0064BD80` | `function GetGameObjectGOHandleChildByBaseName(gohandle: Integer; const arace: String; const abase: String): Integer` |
| `0x0064BDB0` | `function GetGameObjectGOHandleChildByCustomName(gohandle: Integer; const aname: String): Integer` |
| `0x0064BDDC` | `function GetGameObjectMyLODActorName(): String` |
| `0x0064BE04` | `function GetGameObjectLODActorNameByHandle(gohandle: Integer): String` |
| `0x0064BE2C` | `function GetGameObjectMyTrackPointCount(): Integer` |
| `0x0064BE54` | `function GetGameObjectTrackPointCountByHandle(gohandle: Integer): Integer` |
| `0x0064BE7C` | `function GetGameObjectTrackPointCurrentPointDirectionXByHandle(gohandle: Integer): Float` |
| `0x0064BEC0` | `function GetGameObjectTrackPointCurrentPointDirectionYByHandle(gohandle: Integer): Float` |
| `0x0064BF00` | `function GetGameObjectTrackPointCurrentPointDirectionZByHandle(gohandle: Integer): Float` |
| `0x0064BF40` | `function GetGameObjectTrackPointIndexDirectionXByHandle(gohandle: Integer; index: Integer): Float` |
| `0x0064BF84` | `function GetGameObjectTrackPointIndexDirectionYByHandle(gohandle: Integer; index: Integer): Float` |
| `0x0064BFC8` | `function GetGameObjectTrackPointIndexDirectionZByHandle(gohandle: Integer; index: Integer): Float` |
| `0x0064C00C` | `function GetGameObjectMyLODActorNameExists(const inputstr: String): Boolean` |
| `0x0064C09C` | `function GetGameObjectLODActorNameExistsByHandle(gohandle: Integer; const inputstr: String): Boolean` |
| `0x0064C12C` | `function GetGameObjectRelativePositionByHandle(gohandle: Integer; gohandlesecond: Integer): String` |
| `0x0064C170` | `function GetGameObjectMyRelativePositionByHandle(gohandle: Integer): String` |
| `0x0064C1B4` | `function GetGameObjectRelativeAngleByHandle(gohandle: Integer; gohandlesecond: Integer): Float` |
| `0x0064C1F4` | `function GetGameObjectMyRelativeAngleByHandle(gohandle: Integer): Float` |
| `0x0064C238` | `procedure SetGameObjectIntValueByHandle(gohandle: Integer; const key: String; value: Integer)` |
| `0x0064C274` | `function GetGameObjectIntValueByHandle(gohandle: Integer; const key: String): Integer` |
| `0x0064C2B0` | `procedure SetGameObjectFloatValueByHandle(gohandle: Integer; const key: String; value: Float)` |
| `0x0064C2EC` | `function GetGameObjectFloatValueByHandle(gohandle: Integer; const key: String): Float` |
| `0x0064C330` | `function GetGameObjectGrHandleByHandle(gohandle: Integer): Integer` |
| `0x0064C358` | `procedure SetGameObjectMyArrowSpeedFactor(speedfactor: Float)` |
| `0x0064C388` | `procedure SetGameObjectArrowSpeedFactorByHandle(gohandle: Integer; speedfactor: Float)` |
| `0x0064C3B0` | `function GetGameObjectRelativeQuarterIntByHandleToPoint(gohandle: Integer; x, y, z, fov: Float): Integer` |
| `0x0064C3E8` | `function GetGameObjectQuarterDistanceByHandleToPoint(gohandle: Integer; x, y, z: Float): Float` |
| `0x0064C45C` | `function GetGameObjectMyRelativeQuarterByHandle(targetgohandle: Integer): String` |
| `0x0064C4A4` | `function GetGameObjectMyRelativeQuarterIntByHandle(targetgohandle: Integer): Integer` |
| `0x0064C4EC` | `function GetGameObjectRelativeQuarterByHandle(gohandle: Integer; targetgohandle: Integer): String` |
| `0x0064C530` | `function GetGameObjectRelativeQuarterIntByHandle(gohandle: Integer; targetgohandle: Integer): Integer` |
| `0x0064C574` | `function GetGameObjectMyEnemyUnit(enemygohandle: Integer): Boolean` |
| `0x0064C5C4` | `function GetGameObjectMyOnStateFBEndCyclesReached(): String` |
| `0x0064C604` | `procedure SetGameObjectMyOnStateFBEndCyclesReached(const state: String)` |
| `0x0064C634` | `procedure SetGameObjectOnStateFBEndCyclesReachedByHandle(gohandle: Integer; const state: String)` |
| `0x0064C65C` | `function GetGameObjectOnStateFBEndCyclesReachedByHandle(gohandle: Integer): String` |
| `0x0064C698` | `function GetGameObjectMySqrDistanceTo(const toplayername: String; const tocustomname: String): Float` |
| `0x0064C704` | `function GetGameObjectSqrDistanceToByHandle(gohandle: Integer; togohandle: Integer): Float` |
| `0x0064C754` | `function GetGameObjectMySqrDistanceToByHandle(togohandle: Integer): Float` |
| `0x0064C7A8` | `function GetGameObjectTransformedVirtualDirectionXByHandle(gohandle: Integer): Float` |
| `0x0064C7E4` | `function GetGameObjectTransformedVirtualDirectionYByHandle(gohandle: Integer): Float` |
| `0x0064C820` | `function GetGameObjectTransformedVirtualDirectionZByHandle(gohandle: Integer): Float` |
| `0x0064C85C` | `function GetGameObjectTransformedVirtualUpXByHandle(gohandle: Integer): Float` |
| `0x0064C898` | `function GetGameObjectTransformedVirtualUpYByHandle(gohandle: Integer): Float` |
| `0x0064C8D4` | `function GetGameObjectTransformedVirtualUpZByHandle(gohandle: Integer): Float` |
| `0x0064C910` | `function GetGameObjectMyRelativeQuarterExtByHandle(targetgohandle: Integer; fov: Float): String` |
| `0x0064C95C` | `function GetGameObjectMyRelativeQuarterIntExtByHandle(targetgohandle: Integer; fov: Float): Integer` |
| `0x0064C9A8` | `function GetGameObjectRelativeQuarterExtByHandle(gohandle: Integer; targetgohandle: Integer; fov: Float): String` |
| `0x0064C9F0` | `function GetGameObjectRelativeQuarterIntExtByHandle(gohandle: Integer; targetgohandle: Integer; fov: Float): Integer` |
| `0x0064CA38` | `function GetGameObjectMyCountCollidedObjects(): Integer` |
| `0x0064CA5C` | `function GetGameObjectCountCollidedObjectsByHandle(gohandle: Integer): Integer` |
| `0x0064CA80` | `function GetGameObjectMyCollidedGOHandle(index: Integer): Integer` |
| `0x0064CAAC` | `function GetGameObjectCollidedGOHandleByHandle(gohandle: Integer; index: Integer): Integer` |
| `0x0064CAD8` | `function GetGameObjectSTOHandleByHandle(gohandle: Integer): Integer` |
| `0x0064CB18` | `procedure SetGameObjectSTOHandleByHandle(gohandle: Integer; stohandle: Integer)` |
| `0x0064CB60` | `function GetGameObjectSTOTypeByHandle(gohandle: Integer): Integer` |
| `0x0064CBBC` | `function GetGameObjectSTArrowAngleByHandle(gohandle: Integer): Float` |
| `0x0064CBEC` | `procedure SetGameObjectSTArrowAngleByHandle(gohandle: Integer; angle: Float)` |
| `0x0064CC0C` | `function GetGameObjectSTArrowAngleLastByteByHandle(gohandle: Integer): Byte` |
| `0x0064CC30` | `procedure SetGameObjectSTArrowAngleLastByteByHandle(gohandle: Integer; b: Byte)` |
| `0x0064CC50` | `function GetGameObjectMyOnStateCollectingPointReached(): String` |
| `0x0064CC90` | `procedure SetGameObjectMyOnStateCollectingPointReached(const state: String)` |
| `0x0064CCC0` | `function GetGameObjectOnStateCollectingPointReachedByHandle(gohandle: Integer): String` |
| `0x0064CCFC` | `procedure SetGameObjectOnStateCollectingPointReachedByHandle(gohandle: Integer; const state: String)` |
| `0x0064CD24` | `function GetGameObjectFromGroupDirectionXByHandle(gohandle: Integer): Float` |
| `0x0064CD5C` | `function GetGameObjectFromGroupDirectionYByHandle(gohandle: Integer): Float` |
| `0x0064CD94` | `function GetGameObjectFromGroupDirectionZByHandle(gohandle: Integer): Float` |
| `0x0064CDCC` | `function GetGameObjectMyFromGroupDirectionX(): Float` |
| `0x0064CE00` | `function GetGameObjectMyFromGroupDirectionY(): Float` |
| `0x0064CE34` | `function GetGameObjectMyFromGroupDirectionZ(): Float` |
| `0x0064CE68` | `function GetGameObjectBoolValueByHandle(gohandle: Integer; const key: String): Boolean` |
| `0x0064CE98` | `procedure SetGameObjectBoolValueByHandle(gohandle: Integer; const key: String; value: Boolean)` |
| `0x0064CEC8` | `procedure SetGameObjectValueIndByHandle(gohandle: Integer; index: Integer; const value: String)` |
| `0x0064CEF8` | `function GetGameObjectValueIndByHandle(gohandle: Integer; index: Integer): String` |
| `0x0064CF34` | `function GetGameObjectIntValueIndByHandle(gohandle: Integer; index: Integer): Integer` |
| `0x0064CF70` | `procedure SetGameObjectIntValueIndByHandle(gohandle: Integer; index: Integer; value: Integer)` |
| `0x0064CFAC` | `function GetGameObjectFloatValueIndByHandle(gohandle: Integer; index: Integer): Float` |
| `0x0064CFE8` | `procedure SetGameObjectFloatValueIndByHandle(gohandle: Integer; index: Integer; value: Float)` |
| `0x0064D018` | `function GetGameObjectBoolValueIndByHandle(gohandle: Integer; index: Integer): Boolean` |
| `0x0064D048` | `procedure SetGameObjectBoolValueIndByHandle(gohandle: Integer; index: Integer; value: Boolean)` |
| `0x0064D078` | `function GetGameObjectKeyNameIndByHandle(gohandle: Integer; index: Integer): String` |
| `0x0064D0B4` | `procedure SetGameObjectKeyNameIndByHandle(gohandle: Integer; index: Integer; const name: String)` |
| `0x0064D0E4` | `function GetGameObjectMyBoolValue(const key: String): Boolean` |
| `0x0064D114` | `procedure SetGameObjectMyBoolValue(const key: String; value: Boolean)` |
| `0x0064D144` | `procedure SetGameObjectMyValueInd(index: Integer; const value: String)` |
| `0x0064D174` | `function GetGameObjectMyValueInd(index: Integer): String` |
| `0x0064D1B0` | `function GetGameObjectMyIntValueInd(index: Integer): Integer` |
| `0x0064D1F4` | `procedure SetGameObjectMyIntValueInd(index: Integer; value: Integer)` |
| `0x0064D238` | `function GetGameObjectMyFloatValueInd(index: Integer): Float` |
| `0x0064D274` | `procedure SetGameObjectMyFloatValueInd(index: Integer; value: Float)` |
| `0x0064D2A4` | `function GetGameObjectMyBoolValueInd(index: Integer): Boolean` |
| `0x0064D2D4` | `procedure SetGameObjectMyBoolValueInd(index: Integer; value: Boolean)` |
| `0x0064D304` | `function GetGameObjectMyKeyNameInd(index: Integer): String` |
| `0x0064D340` | `procedure SetGameObjectMyKeyNameInd(index: Integer; const name: String)` |
| `0x0064D370` | `function GetGameObjectMyCollidedStateName(): String` |
| `0x0064D3A4` | `procedure SetGameObjectMyCollidedStateName(const statename: String)` |
| `0x0064D3CC` | `function GetGameObjectCollidedStateNameByHandle(gohandle: Integer): String` |
| `0x0064D400` | `procedure SetGameObjectCollidedStateNameByHandle(gohandle: Integer; const statename: String)` |
| `0x0064D420` | `function GetGameObjectMyUncollidedStateName(): String` |
| `0x0064D454` | `procedure SetGameObjectMyUncollidedStateName(const statename: String)` |
| `0x0064D47C` | `function GetGameObjectUncollidedStateNameByHandle(gohandle: Integer): String` |
| `0x0064D4B0` | `procedure SetGameObjectUncollidedStateNameByHandle(gohandle: Integer; const statename: String)` |
| `0x0064D4D0` | `function GetGameObjectMyCollisionExecAsFunc(): boolean` |
| `0x0064D4F8` | `procedure SetGameObjectMyCollisionExecAsFunc(val: boolean)` |
| `0x0064D520` | `function GetGameObjectCollisionExecAsFuncByHandle(hnd: integer): boolean` |
| `0x0064D550` | `procedure SetGameObjectCollisionExecAsFuncByHandle(hnd: integer; val: boolean)` |
| `0x0064D570` | `function GetGameObjectVarsCountByHandle(gohandle: Integer): Integer` |
| `0x0064D59C` | `function GetGameObjectMyVarsCount(): Integer` |
| `0x0064D5C4` | `procedure SetGameObjectVarsCountByHandle(gohandle: Integer; count: Integer)` |
| `0x0064D5F0` | `procedure SetGameObjectMyVarsCount(count: Integer)` |
| `0x0064D61C` | `function GetGameObjectPlayerHandleByHandle(gohandle: Integer): Integer` |
| `0x0064D640` | `function GetGameObjectMyStateCollisionObject(): Integer` |
| `0x0064D664` | `function GetGameObjectStateCollisionObjectByHandle(gohandle: Integer): Integer` |
| `0x0064D688` | `procedure SetGameObjectStateCollisionObjectByHandle(gohandle, goscohandle: Integer)` |
| `0x0064D6B8` | `function GetGameObjectMyCollisionRadius(): Float` |
| `0x0064D6E8` | `function GetGameObjectCollisionRadiusByHandle(gohandle: Integer): Float` |
| `0x0064D718` | `function GetGameObjectVisibleByHandle(gohandle: Integer): Boolean` |
| `0x0064D738` | `procedure SetGameObjectVisibleByHandle(gohandle: Integer; visible: Boolean)` |
| `0x0064D758` | `procedure SetGameObjectMyChildVisibleByBaseName(const basename: String; visible: Boolean)` |
| `0x0064D804` | `procedure SetGameObjectMyVisible(visible: Boolean)` |
| `0x0064D82C` | `function GetGameObjectMyVisible(): Boolean` |
| `0x0064D84C` | `function GetGameObjectMyCollisionDetection(): Boolean` |
| `0x0064D874` | `procedure SetGameObjectMyCollisionDetection(collisiondetection: Boolean)` |
| `0x0064D8A4` | `function GetGameObjectCollisionDetectionByHandle(gohandle: Integer): Boolean` |
| `0x0064D8CC` | `procedure SetGameObjectCollisionDetectionByHandle(gohandle: Integer; collisiondetection: Boolean)` |
| `0x0064D8F4` | `function GetGameObjectMyIsObservationRotatingEnd(): Boolean` |
| `0x0064D91C` | `function GetGameObjectIsObservationRotatingEndByHandle(gohandle: Integer): Boolean` |
| `0x0064D944` | `function GetGameObjectMyIsEndPointIndex(): Boolean` |
| `0x0064D96C` | `function GetGameObjectIsEndPointIndexByHandle(gohandle: Integer): Boolean` |
| `0x0064D994` | `function GetGameObjectStateMachineEnabledByHandle(gohandle: Integer): Boolean` |
| `0x0064D9B8` | `function SetGameObjectMyCollisionRadius(r: Float): Float` |
| `0x0064D9E4` | `procedure SetGameObjectCollisionRadiusByHandle(gohandle: Integer; r: Float)` |
| `0x0064DA04` | `procedure GetGameObjectTrackPointCoordsByIndexByHandle(gohandle: Integer; index: Integer; var x: Float; var y: Float; var z: Float)` |
| `0x0064DA78` | `procedure GetGameObjectMyTrackPointCoordsByIndex(index: Integer; var x: Float; var y: Float; var z: Float)` |
| `0x0064DAF8` | `function GetGameObjectMyAutoOffset(): Boolean` |
| `0x0064DB1C` | `procedure SetGameObjectMyAutoOffset(autooffset: Boolean)` |
| `0x0064DB44` | `function GetGameObjectAutoOffsetByHandle(gohandle: Integer): Boolean` |
| `0x0064DB68` | `procedure SetGameObjectAutoOffsetByHandle(gohandle: Integer; autooffset: Boolean)` |
| `0x0064DB88` | `function GetGameObjectMyTrackPointAutoChangeDirection(): Boolean` |
| `0x0064DBB4` | `function SetGameObjectMyArrowAutoChangeDir(arrowautochangedir: Boolean): Boolean` |
| `0x0064DBE8` | `function GetGameObjectMyFeedBackPlayed(): Boolean` |
| `0x0064DC14` | `function GetGameObjectFeedBackPlayedByHandle(gohandle: Integer): Boolean` |
| `0x0064DC40` | `function GetGameObjectMyIsGreenPointIndex(): Boolean` |
| `0x0064DC68` | `function GetGameObjectIsGreenPointIndexByHandle(gohandle: Integer): Boolean` |
| `0x0064DC90` | `function GetGameObjectMyIsStartPointIndex(): Boolean` |
| `0x0064DCB8` | `function GetGameObjectIsStartPointIndexByHandle(gohandle: Integer): Boolean` |
| `0x0064DCE0` | `function GetGameObjectMyEnemyInCollisionList(): Boolean` |
| `0x0064DD04` | `function GetGameObjectEnemyInCollisionListByHandle(gohandle: Integer): Boolean` |
| `0x0064DDD0` | `function GetGameObjectCollidedMySTOCountByHandle(gohandle: Integer): Integer` |
| `0x0064DDF4` | `function GetGameObjectMyCollidedMySTOCount(): Integer` |
| `0x0064DE18` | `function GetGameObjectCollidedFrontFriendsCountByHandle(gohandle: Integer): Integer` |
| `0x0064DE3C` | `function GetGameObjectMyCollidedFrontFriendsCount(): Integer` |
| `0x0064DE60` | `procedure SetGameObjectMyRuleCollidedExecFr(cerq: Integer; fov: Float; bignoremovemode: Boolean)` |
| `0x0064DEAC` | `procedure SetGameObjectMyRuleCollidedExecEn(cerq: Integer; fov: Float; bignoremovemode: Boolean)` |
| `0x0064DEF8` | `procedure SetGameObjectMyRuleCollidedExecNl(cerq: Integer; fov: Float; bignoremovemode: Boolean)` |
| `0x0064DF44` | `procedure SetGameObjectRuleCollidedExecFrByHandle(gohandle: Integer; cerq: Integer; fov: Float; bignoremovemode: Boolean)` |
| `0x0064DF80` | `procedure SetGameObjectRuleCollidedExecEnByHandle(gohandle: Integer; cerq: Integer; fov: Float; bignoremovemode: Boolean)` |
| `0x0064DFBC` | `procedure SetGameObjectRuleCollidedExecNlByHandle(gohandle: Integer; cerq: Integer; fov: Float; bignoremovemode: Boolean)` |
| `0x0064DFF8` | `procedure SetGameObjectMyRuleUnCollidedExecFr(cerq: Integer; fov: Float; bignoremovemode: Boolean)` |
| `0x0064E044` | `procedure SetGameObjectMyRuleUnCollidedExecEn(cerq: Integer; fov: Float; bignoremovemode: Boolean)` |
| `0x0064E090` | `procedure SetGameObjectMyRuleUnCollidedExecNl(cerq: Integer; fov: Float; bignoremovemode: Boolean)` |
| `0x0064E0DC` | `procedure SetGameObjectRuleUnCollidedExecFrByHandle(gohandle: Integer; cerq: Integer; fov: Float; bignoremovemode: Boolean)` |
| `0x0064E118` | `procedure SetGameObjectRuleUnCollidedExecEnByHandle(gohandle: Integer; cerq: Integer; fov: Float; bignoremovemode: Boolean)` |
| `0x0064E154` | `procedure SetGameObjectRuleUnCollidedExecNlByHandle(gohandle: Integer; cerq: Integer; fov: Float; bignoremovemode: Boolean)` |
| `0x0064E190` | `procedure SetGameObjectMyExecuteStateCollidedGameObjects(const state: String)` |
| `0x0064E290` | `procedure SetGameObjectExecuteStateCollidedGameObjectsByHandle(gohandle: Integer; const state: String)` |
| `0x0064E388` | `procedure SetGameObjectLODActorIndexByHandle(gohandle: Integer; index: Integer)` |
| `0x0064E3A8` | `procedure SetGameObjectMyLODActorIndex(index: Integer)` |
| `0x0064E3D0` | `function GetGameObjectSelectionSizeByHandle(gohandle: Integer): Float` |
| `0x0064E424` | `procedure GameObjectPFXDisabledIfOwnerInvisibleByHandle(gohandle: Integer; const managername: String; const key: String; disabledifownerinvisible: Boolean)` |
| `0x0064E478` | `function GameObjectEffectBehaviourByHandle(gohandle: Integer; const key: String): Integer` |
| `0x0064E4C4` | `procedure GameObjectPFXEffectScaleByHandle(gohandle: Integer; const managername: String; const key: String; effectscale: Float)` |
| `0x0064E51C` | `procedure GameObjectPFXRotationDispersionByHandle(gohandle: Integer; const managername: String; const key: String; rotationdispersion: Float)` |
| `0x0064E570` | `procedure MyGameObjectPFXDisabledIfOwnerInvisible(const managername: String; const key: String; disabledifownerinvisible: Boolean)` |
| `0x0064E5CC` | `procedure MyGameObjectPFXEffectScale(const managername: String; const key: String; effectscale: Float)` |
| `0x0064E62C` | `procedure MyGameObjectPFXRotationDispersion(const managername: String; const key: String; rotationdispersion: Float)` |
| `0x0064E688` | `function GetGameObjectHandleByCustomName(const name: String; plhandle: Integer): Integer` |
| `0x0064E6B4` | `function GetGameObjectHandleByIndex(index: Integer; plhandle: Integer): Integer` |
| `0x0064E6E0` | `function GetGameObjectIndexByHandle(gohandle: Integer): Integer` |
| `0x0064E70C` | `procedure MyGameObjectPFXSrcLibCreate(const libsourcename: String; const key: String)` |
| `0x0064E74C` | `procedure GameObjectPFXSrcLibCreateByHandle(gohandle: Integer; const libsourcename: String; const key: String)` |
| `0x0064E788` | `procedure GameObjectPFXScaleByHandle(gohandle: Integer; const managername: String; const key: String; x: Float; y: Float; z: Float)` |
| `0x0064E8A4` | `procedure MyGameObjectPFXScale(const managername: String; const key: String; x: Float; y: Float; z: Float)` |
| `0x0064E9C4` | `function GameObjectPFXIsCreatedHandle(gohandle: Integer; const managername: String; const key: String): Boolean` |
| `0x0064EB18` | `function MyGameObjectPFXIsCreated(const managername: String; const key: String): Boolean` |
| `0x0064ECB0` | `procedure GetGameObjectDirectionByHandle(gohandle: Integer; var x: Float; var y: Float; var z: Float)` |
| `0x0064ECE8` | `procedure MyGameObjectPFXSetLifeTime(const managername: String; const key: String; lifetime: Float)` |
| `0x0064ED44` | `procedure GameObjectPFXSetLifeTimeByHandle(gohandle: Integer; const managername: String; const key: String; lifetime: Float)` |
| `0x0064ED98` | `function GetGameObjectMyTileInPosition(): Integer` |
| `0x0064EDC4` | `function GetGameObjectTileInPositionByHandle(gohandle: Integer): Integer` |
| `0x0064EDF0` | `procedure SetGameObjectCollidedTagByHandle(gohandle: Integer; tag: Integer)` |
| `0x0064EE14` | `function GetGameObjectCollidedTagByHandle(gohandle: Integer):Integer` |
| `0x0064EE38` | `function GetGameObjectAnimationCycleIndexByName(gohandle: Integer; const animname: String): Integer` |
| `0x0064EE68` | `function GetGameObjectAnimationCycleNameByIndex(gohandle: Integer; animindex: Integer): String` |
| `0x0064EED0` | `function GetGameObjectUniqueIdByHandle(gohandle: Integer): Integer` |
| `0x0064EEF4` | `function GetGameObjectHandleByUniqueId(uniqueid: Integer): Integer` |
| `0x0064EF10` | `procedure ClearGameObjectsUniqId` |
| `0x0064EF24` | `function GameObjectMakeUniqId(gohandle: Integer): Integer` |
| `0x0064EF58` | `function GetGameObjectRaceNameByHandle(gohandle: Integer): String` |
| `0x0064EF8C` | `procedure SetGameObjectMyStatesTag(astatestag: Integer)` |
| `0x0064EFB4` | `procedure SetGameObjectStatesTagByHandle(gohandle: Integer; astatestag: Integer)` |
| `0x0064EFD4` | `procedure SetGameObjectMyStatesTagDirect(statestag: Integer)` |
| `0x0064EFFC` | `procedure SetGameObjectStatesTagDirectByHandle(gohnd, statestag: Integer)` |
| `0x0064F020` | `function GetGameObjectMyStatesTag: Integer` |
| `0x0064F044` | `function GetGameObjectStatesTagByHandle(gohandle: Integer): Integer` |
| `0x0064F068` | `function GetGameObjectMyPrevStatesTag: Integer` |
| `0x0064F08C` | `function GetGameObjectPrevStatesTagByHandle(gohandle: Integer): Integer` |
| `0x0064F0B0` | `function GetGameObjectMyStatesTagForceUpdate: Boolean` |
| `0x0064F0D8` | `function GetGameObjectStatesTagForceUpdateByHandle(gohandle: Integer): Boolean` |
| `0x0064F100` | `procedure SetGameObjectMyStatesTagForceUpdate` |
| `0x0064F13C` | `procedure SetGameObjectStatesTagForceUpdateByHandle(gohandle: Integer)` |
| `0x0064F170` | `procedure ResetGameObjectPrevStatesTagByHandle(gohandle: Integer)` |
| `0x0064F190` | `function GetGameObjectStatesTagUpdateSTOByHandle(const gohnd: Integer): Boolean` |
| `0x0064F1B8` | `procedure SetGameObjectStatesTagUpdateSTOByHandle(const gohnd: Integer; const val: Boolean)` |
| `0x0064F204` | `function GetGameObjectStatesTagUpdateSTPByHandle(const gohnd: Integer): Boolean` |
| `0x0064F22C` | `procedure SetGameObjectStatesTagUpdateSTPByHandle(const gohnd: Integer; const val: Boolean)` |
| `0x0064F278` | `function GetGameObjectStatesTagUpdateSTAByHandle(const gohnd: Integer): Boolean` |
| `0x0064F2A0` | `procedure SetGameObjectStatesTagUpdateSTAByHandle(const gohnd: Integer; const val: Boolean)` |
| `0x0064F2EC` | `function GetGameObjectStatesTagUpdateTSByHandle(const gohnd: Integer): Boolean` |
| `0x0064F314` | `procedure SetGameObjectStatesTagUpdateTSByHandle(const gohnd: Integer; const val: Boolean)` |
| `0x0064F360` | `function GetGameObjectStatesTagUpdateRECByHandle(const gohnd: Integer): Boolean` |
| `0x0064F388` | `procedure SetGameObjectStatesTagUpdateRECByHandle(const gohnd: Integer; const val: Boolean)` |
| `0x0064F3D4` | `procedure GameObjectMySetFrameAnimation(const frameanimationname: String; randomoffsetframeanimation: Boolean)` |
| `0x0064F408` | `procedure GameObjectSetFrameAnimationByHandle(gohandle: Integer; const frameanimationname: String; randomoffsetframeanimation: Boolean)` |
| `0x0064F434` | `procedure GameObjectMySetFBFrameAnimation(const frameanimationname: String; randomoffsetframeanimation: Boolean)` |
| `0x0064F464` | `procedure GameObjectSetFBFrameAnimationByHandle(gohandle: Integer; const frameanimationname: String; randomoffsetframeanimation: Boolean)` |
| `0x0064F48C` | `procedure GameObjectMySwitchToFrameAnimation(const frameanimationname: String; randomoffsetframeanimation: Boolean)` |
| `0x0064F4C0` | `procedure GameObjectSwitchToFrameAnimationByHandle(gohandle: Integer; const frameanimationname: String; randomoffsetframeanimation: Boolean)` |
| `0x0064F4EC` | `procedure GameObjectMySwitchToAnimationCycles(const name: String; randomcycles: Boolean; randomframe: Boolean)` |
| `0x0064F540` | `procedure GameObjectSwitchToAnimationCyclesByHandle(gohandle: Integer; const name: String; randomcycles: Boolean; randomframe: Boolean)` |
| `0x0064F584` | `procedure GameObjectMySwitchToTreeAnimationCycles(const name: String; randomcycles: Boolean; randomframe: Boolean; randomfbcycles: Boolean; randomfbframe: Boolean)` |
| `0x0064F600` | `procedure GameObjectSwitchToTreeAnimationCyclesByHandle(gohandle: Integer; const name: String; randomcycles: Boolean; randomframe: Boolean; randomfbcycles: Boolean; randomfbframe: Boolean)` |
| `0x0064F668` | `procedure GameObjectMySwitchToFBAnimationCycles(const name: String; randomcycles: Boolean; randomframe: Boolean)` |
| `0x0064F6BC` | `procedure GameObjectSwitchToFBAnimationCyclesByHandle(gohandle: Integer; const name: String; randomcycles: Boolean; randomframe: Boolean)` |
| `0x0064F700` | `procedure GameObjectMySwitchToAnimationCyclesDefault(const name: String)` |
| `0x0064F734` | `procedure GameObjectSwitchToAnimationCyclesDefaultByHandle(gohandle: Integer; const name: String)` |
| `0x0064F760` | `procedure GameObjectMySwitchToTreeAnimationCyclesDefault(const name: String)` |
| `0x0064F798` | `procedure GameObjectSwitchToTreeAnimationCyclesDefaultByHandle(gohandle: Integer; const name: String)` |
| `0x0064F7C8` | `procedure GameObjectMySwitchToFBAnimationCyclesDefault(const name: String)` |
| `0x0064F7FC` | `procedure GameObjectSwitchToFBAnimationCyclesDefaultByHandle(gohandle: Integer; const name: String)` |
| `0x0064F824` | `procedure GameObjectMySwitchToFrameAnimationBlend(const name: String; const randomframe, smooth: Boolean; const minframeblend, maxframeblend: Integer)` |
| `0x0064F89C` | `procedure GameObjectSwitchToFrameAnimationBlendByHandle(const gohnd: Integer; const name: String; const randomframe, smooth: Boolean; const minframeblend, maxframeblend: Integer)` |
| `0x0064F910` | `procedure GameObjectMySwitchToAnimationCyclesBlend(const name: String; const randomcycles, randomframe: Boolean; const minframeblend, maxframeblend: Integer)` |
| `0x0064F9AC` | `procedure GameObjectSwitchToAnimationCyclesBlendByHandle(const gohnd: Integer; const name: String; const randomcycles, randomframe: Boolean; const minframeblend, maxframeblend: Integer)` |
| `0x0064FA3C` | `procedure GameObjectMySwitchToFBAnimationCyclesBlend(const name: String; const randomcycles, randomframe: Boolean; const minframeblend, maxframeblend: Integer)` |
| `0x0064FAD8` | `procedure GameObjectSwitchToFBAnimationCyclesBlendByHandle(const gohnd: Integer; const name: String; const randomcycles, randomframe: Boolean; const minframeblend, maxframeblend: Integer)` |
| `0x0064FB68` | `procedure GameObjectMySwitchToTreeAnimationCyclesBlend(const name: String; const randomcycles, randomframe, randomfbcycles, randomfbframe: Boolean; const minframeblend, maxframeblend: Integer)` |
| `0x0064FC30` | `procedure GameObjectSwitchToTreeAnimationCyclesBlendByHandle(const gohnd: Integer; const name: String; const randomcycles, randomframe, randomfbcycles, randomfbframe: Boolean; const minframeblend, maxframeblend: Integer)` |
| `0x0064FCEC` | `procedure GameObjectMySwitchToAnimationCyclesBlendDefault(const name: String; const minframeblend, maxframeblend: Integer)` |
| `0x0064FD64` | `procedure GameObjectSwitchToAnimationCyclesBlendDefaultByHandle(const gohnd: Integer; const name: String; const minframeblend, maxframeblend: Integer)` |
| `0x0064FDD4` | `procedure GameObjectMySwitchToFBAnimationCyclesBlendDefault(const name: String; const minframeblend, maxframeblend: Integer)` |
| `0x0064FE4C` | `procedure GameObjectSwitchToFBAnimationCyclesBlendDefaultByHandle(const gohnd: Integer; const name: String; const minframeblend, maxframeblend: Integer)` |
| `0x0064FEBC` | `procedure GameObjectMySwitchToTreeAnimationCyclesBlendDefault(const name: String; const minframeblend, maxframeblend: Integer)` |
| `0x0064FF38` | `procedure GameObjectSwitchToTreeAnimationCyclesBlendDefaultByHandle(const gohnd: Integer; const name: String; const minframeblend, maxframeblend: Integer)` |
| `0x0064FFAC` | `function GetGameObjectDefaultFrameAnimationCyclesNameByHandle(gohandle: Integer): String` |
| `0x0064FFF8` | `procedure GameObjectDoFastFrmAnimProgressChildrenByHandle(gohandle: Integer)` |
| `0x00650038` | `procedure GameObjectLocalToAbsoluteByHandle(gohandle: Integer; var x, y, z: Float)` |
| `0x006500A8` | `procedure GameObjectAbsoluteToLocalByHandle(gohandle: Integer; var x, y, z: Float)` |
| `0x00650118` | `function GetGameObjectStringPropertyClassificationValueByKey(gohandle: Integer; const akey: String): String` |
| `0x00650164` | `function GetGameObjectStringPropertyClassificationValueByIndex(gohandle: Integer; const aindex: Integer): String` |
| `0x006501E0` | `function GetGameObjectStringPropertyClassificationsCount(gohandle: Integer): Integer` |
| `0x0065021C` | `function GetGameObjectStringPropertyTag(gohandle: Integer): Integer` |
| `0x00650250` | `function GetGameObjectFrameAnimationSynchronizeOptionByHandle(gohandle: Integer): Integer` |
| `0x00650288` | `procedure SetGameObjectFrameAnimationSynchronizeOptionByHandle(gohandle: Integer; option: Integer)` |
| `0x006502BC` | `function GetGameObjectActorIndexByHandle(gohandle: Integer): Integer` |
| `0x006502E0` | `procedure SetGameObjectActorIndexByHandle(gohandle: Integer; aindex: Integer)` |
| `0x00650300` | `function GetGameObjectInLoadStateNameByHandle(gohandle: Integer): String` |
| `0x00650340` | `procedure SetGameObjectInLoadStateNameByHandle(gohandle: Integer; state: String)` |
| `0x006503A4` | `procedure SetGameObjectTrackPointOnStateExtPointReached(gohandle: Integer; const state: string)` |
| `0x006503D4` | `function GetGameObjectTrackPointOnStateExtPointReached(gohandle: Integer): String` |
| `0x00650404` | `procedure SetGameObjectTrackPointPresetFBAnimationByHandle(gohandle: Integer; const aanim: string)` |
| `0x00650434` | `function GetGameObjectTrackPointPresetFBAnimationByHandle(gohandle: Integer): String` |
| `0x00650474` | `procedure SetGameObjectTrackPointOnStatePresetSwitchReached(gohandle: Integer; const state: string)` |
| `0x006504A4` | `function GetGameObjectTrackPointOnStatePresetSwitchReached(gohandle: Integer): String` |
| `0x006504D4` | `procedure SetGameObjectTrackPointExtPointEnabled(gohandle: Integer; enabled: boolean)` |
| `0x006504FC` | `function GetGameObjectTrackPointExtPointEnabled(gohandle: Integer): boolean` |
| `0x00650524` | `procedure SetGameObjectTrackPointCurrentPresetByHandle(gohandle: Integer; const apreset: string)` |
| `0x00650568` | `function GetGameObjectTrackPointCurrentPresetByHandle(gohandle: Integer): String` |
| `0x006505AC` | `procedure SetGameObjectTrackPointNewPresetByHandle(gohandle: Integer; const apreset: string)` |
| `0x006505F0` | `function GetGameObjectTrackPointNewPresetByHandle(gohandle: Integer): String` |
| `0x00650634` | `procedure SetGameObjectTrackPointPresetForceUpdate(gohandle: Integer)` |
| `0x00650668` | `procedure SetGameObjectTrackPointExtPoint(gohandle: Integer; x, y, z: Float)` |
| `0x006506A8` | `procedure GetGameObjectTrackPointExtPoint(gohandle: Integer; var x: Float; var y: Float; var z: Float)` |
| `0x006506E0` | `procedure GameObjectDoRayCastTerrainByHandle(gohandle: Integer)` |
| `0x00650708` | `procedure GameObjectMyDoRayCastTerrain` |
| `0x0065073C` | `procedure GameObjectMyFriendCollidedObjectsExecState(collidedtag: Integer; const state: String)` |
| `0x00650864` | `procedure GameObjectFriendCollidedObjectsExecStateByHandle(gohandle, collidedtag: Integer; const state: String)` |
| `0x006509C0` | `function GetGameObjectRootHandleByHandle(gohandle: Integer): Integer` |
| `0x006509E8` | `procedure SetGameObjectRayCastNormalizeFrameChangedByHandle(gohandle: Integer; mode: Boolean)` |
| `0x00650A28` | `procedure SetGameObjectMyRayCastNormalizeFrameChanged(mode: Boolean)` |
| `0x00650A88` | `function GetGameObjectRayCastNormalizeFrameChangedByHandle(gohandle: Integer): Boolean` |
| `0x00650AB0` | `function GetGameObjectMyRayCastNormalizeFrameChanged: Boolean` |
| `0x00650AD8` | `procedure GameObjectDoRayCastNormalize(gohandle: Integer; const useanimation: Boolean)` |
| `0x00650B08` | `procedure GameObjectMyDoRayCastNormalize(const useanimation: Boolean)` |
| `0x00650B40` | `procedure SetGameObjectPCBFullProgressByHandle(gohandle: Integer; const fullprogress: Boolean)` |
| `0x00650B7C` | `function GetGameObjectPCBFullProgressByHandle(gohandle: Integer): Boolean` |
| `0x00650BB8` | `function GameObjectPCBAddPOByHandle(gohandle: Integer; const go: Integer): Integer` |
| `0x00650C14` | `procedure GameObjectPCBDeletePOByHandle(gohandle: Integer; const index: Integer)` |
| `0x00650C50` | `function GameObjectPCBRemovePOByHandle(gohandle: Integer; const go: Integer): Integer` |
| `0x00650C90` | `procedure GameObjectPCBClearPOByHandle(gohandle: Integer)` |
| `0x00650CCC` | `function GameObjectPCBCountPOByHandle(gohandle: Integer): Integer` |
| `0x00650D0C` | `function GameObjectPCBIndexOfPOByHandle(gohandle: Integer; const go: Integer): Integer` |
| `0x00650D68` | `function GameObjectPCBGetPOByHandle(gohandle: Integer; const index: integer): Integer` |
| `0x00650DB0` | `procedure GameObjectPFXProgressModeByHandle(gohandle: Integer; const managername: String; const key: String; const progressmode: String)` |
| `0x00650E0C` | `procedure GameObjectPFXMinExpInitSpeedByHandle(gohandle: Integer; const managername: String; const key: String; const minexpinitspeed: Float)` |
| `0x00650E60` | `procedure GameObjectPFXMaxExpInitSpeedByHandle(gohandle: Integer; const managername: String; const key: String; const maxexpinitspeed: Float)` |
| `0x00650EB4` | `procedure GameObjectPFXExpNumbParticlesByHandle(gohandle: Integer; const managername: String; const key: String; const expnumbparticles: Integer)` |
| `0x00650F08` | `procedure GameObjectPFXSleepTimeByHandle(gohandle: Integer; const managername: String; const key: String; const sleeptime: Float)` |
| `0x00650F5C` | `procedure MyGameObjectPFXProgressMode(const managername: String; const key: String; const progressmode: String)` |
| `0x00650FC8` | `procedure MyGameObjectPFXMinExpInitSpeed(const managername: String; const key: String; const minexpinitspeed: Float)` |
| `0x0065102C` | `procedure MyGameObjectPFXMaxExpInitSpeed(const managername: String; const key: String; const maxexpinitspeed: Float)` |
| `0x00651090` | `procedure MyGameObjectPFXExpNumbParticles(const managername: String; const key: String; const expnumbparticles: Integer)` |
| `0x006510F4` | `procedure MyGameObjectPFXSleepTime(const managername: String; const key: String; const sleeptime: Float)` |
| `0x00651158` | `function GameObjectGetTrackPointMoveDistanceToEndByHandle(gohandle: Integer): Float` |
| `0x0065119C` | `function GameObjectGetTrackPointMoveDistanceToAlignByHandle(gohandle: Integer): Float` |
| `0x006511E0` | `procedure SetGameObjectAlignmentToFlagmanByHandle(gohandle: Integer; aenabled: Boolean)` |
| `0x00651208` | `function GetGameObjectAlignmentToFlagmanByHandle(gohandle: Integer): Boolean` |
| `0x00651230` | `procedure GameObjectChildToParent(const gohandle: Integer)` |
| `0x00651370` | `procedure GameObjectMyChildToParent` |
| `0x006514B0` | `function IsGameObjectWithTLF(const gohandle: Integer): Boolean` |
| `0x006514F4` | `procedure GameObjectTLFToMatrix(const gohandle: Integer)` |
| `0x00651514` | `procedure GameObjectTLFAnimationStop(const gohandle: Integer)` |
| `0x00651554` | `procedure SetGameObjectUniform1f(const gohandle, i: Integer; f: Float; children: Boolean)` |
| `0x00651610` | `procedure SetGameObjectMyUniform1f(const i: Integer; f: Float; children: Boolean)` |
| `0x006516DC` | `procedure SetGameObjectUniform4f(const gohandle, i: Integer; x, y, z, w: Float; children: Boolean)` |
| `0x006517AC` | `procedure SetGameObjectMyUniform4f(const i: Integer; x, y, z, w: Float; children: Boolean)` |
| `0x0065188C` | `procedure SetGameObjectUniform1fByHandle(hnd, ind: Integer; f: Float; children: Boolean)` |
| `0x00651948` | `function GetGameObjectUniform1fByHandle(hnd, ind: Integer): Float` |
| `0x006519A8` | `procedure SetGameObjectUniform3fByHandle(hnd, ind: Integer; x, y, z: Float; children: Boolean)` |
| `0x00651A8C` | `procedure GetGameObjectUniform3fByHandle(hnd, ind: Integer; var x, y, z: Float)` |
| `0x00651B14` | `procedure SetGameObjectUniform4fByHandle(hnd, ind: Integer; x, y, z, w: Float; children: Boolean)` |
| `0x00651BFC` | `procedure GetGameObjectUniform4fByHandle(hnd, ind: Integer; var x, y, z, w: Float)` |
| `0x00651C88` | `function GetGameObjectCIAvoidPointMaxAngleByHandle(const gohandle: Integer): Float` |
| `0x00651CC4` | `procedure SetGameObjectCIAvoidPointMaxAngleByHandle(const gohandle: Integer; maxangle: Float)` |
| `0x00651CF4` | `function GetGameObjectCIMassByHandle(const gohandle: Integer): Float` |
| `0x00651D30` | `procedure SetGameObjectCIMassByHandle(const gohandle: Integer; mass: Float)` |
| `0x00651D60` | `function GetGameObjectCIIntersectRadiusByHandle(const gohandle: Integer): Float` |
| `0x00651D9C` | `procedure SetGameObjectCIIntersectRadiusByHandle(const gohandle: Integer; radius: Float)` |
| `0x00651DCC` | `function GetGameObjectCIMovableByHandle(const gohandle: Integer): Boolean` |
| `0x00651DFC` | `procedure SetGameObjectCIMovableByHandle(const gohandle: Integer; movable: Boolean)` |
| `0x00651E2C` | `function GetGameObjectCIMaxCollideCounterByHandle(const gohandle: Integer): Integer` |
| `0x00651E5C` | `procedure SetGameObjectCIMaxCollideCounterByHandle(const gohandle, maxcollidecounter: Integer)` |
| `0x00651E8C` | `function GetGameObjectCIMaxProcessObjectByHandle(const hnd: Integer): Integer` |
| `0x00651EBC` | `procedure SetGameObjectCIMaxProcessObjectByHandle(const hnd, val: Integer)` |
| `0x00651EEC` | `function GetGameObjectCollisionInertiaByHandle(const gohandle: Integer): Boolean` |
| `0x00651F10` | `procedure SetGameObjectCollisionInertiaByHandle(const gohandle: Integer; collisioninertia: Boolean)` |
| `0x00651F30` | `function GetGameObjectRayCastIntersectEnabledByHandle(const gohnd: Integer): Boolean` |
| `0x00651F54` | `procedure SetGameObjectRayCastIntersectEnabledByHandle(const gohnd: Integer; val: Boolean)` |
| `0x00651F98` | `function GetGameObjectBoundingModeByHandle(const gohnd: Integer): Integer` |
| `0x00651FD8` | `procedure SetGameObjectBoundingModeByHandle(const gohnd: Integer; val: Integer)` |
| `0x00652024` | `function GetGameObjectBoundingDataByHandle(const gohnd: Integer): Integer` |
| `0x00652064` | `procedure SetGameObjectBoundingDataByHandle(const gohnd: Integer; val: Integer)` |
| `0x006520B0` | `function GetGameObjectBoundingSpaceByHandle(const gohnd: Integer): Integer` |
| `0x006520F0` | `procedure SetGameObjectBoundingSpaceByHandle(const gohnd: Integer; val: Integer)` |
| `0x0065213C` | `procedure GetGameObjectCustomBoundingAABBByHandle(const gohnd: Integer; var minx: Float; var miny: Float; var minz: Float; var maxx: Float; var maxy: Float; var maxz: Float)` |
| `0x006521D0` | `procedure SetGameObjectCustomBoundingAABBByHandle(const gohnd: Integer; const minx, miny, minz, maxx, maxy, maxz: Float)` |
| `0x00652244` | `function GetGameObjectRayCastAABBByHandle(const gohnd: Integer; x1, y1, z1, x2, y2, z2: Float): Boolean` |
| `0x0065236C` | `function GetGameObjectRayCastCustAABBByHandle(const hnd: Integer; x1, y1, z1, x2, y2, z2, minx, miny, minz, maxx, maxy, maxz: Float): Boolean` |
| `0x0065241C` | `function GetGameObjectCustomBoundingSphereByHandle(const gohnd: Integer): Float` |
| `0x00652468` | `procedure SetGameObjectCustomBoundingSphereByHandle(const gohnd: Integer; val: Float)` |
| `0x006524B4` | `function GetGameObjectUseCustAABBinSPByHandle(const gohnd: Integer): Boolean` |
| `0x006524F4` | `procedure SetGameObjectUseCustAABBinSPByHandle(const gohnd: Integer; val: Boolean)` |
| `0x006525B4` | `function GetGameObjectUseNoSPCullByHandle(const gohnd: Integer): Boolean` |
| `0x006525F4` | `procedure SetGameObjectUseNoSPCullByHandle(const gohnd: Integer; val: Boolean)` |
| `0x00652634` | `function GetGameObjectUseCustTransformedByHandle(const gohnd: Integer): Boolean` |
| `0x00652674` | `procedure SetGameObjectUseCustTransformedByHandle(const gohnd: Integer; val: Boolean)` |
| `0x006526B4` | `function GetGameObjectUncollideDeltaByHandle(const gohnd: Integer): Float` |
| `0x00652700` | `procedure SetGameObjectUncollideDeltaByHandle(const gohnd: Integer; val: Float)` |
| `0x00652740` | `function GetGameObjectRayCastUsingTLFByHandle(const gohnd: Integer): Boolean` |
| `0x00652784` | `procedure SetGameObjectRayCastUsingTLFByHandle(const gohnd: Integer; val: Boolean)` |
| `0x00652800` | `function GetGameObjectRayCastNotifyStateByHandle(const gohnd: Integer): String` |
| `0x00652854` | `procedure SetGameObjectRayCastNotifyStateByHandle(const gohnd: Integer; val: String)` |
| `0x006528D0` | `function GetGameObjectCIMaxDistKoefByHandle(const gohnd: Integer): Float` |
| `0x0065290C` | `procedure SetGameObjectCIMaxDistKoefByHandle(const gohnd: Integer; val: Float)` |
| `0x0065293C` | `function GetGameObjectCIDeltaStepByHandle(const gohnd: Integer): Float` |
| `0x00652978` | `procedure SetGameObjectCIDeltaStepByHandle(const gohnd: Integer; val: Float)` |
| `0x006529A8` | `function GetGameObjectCIRotationSpeedByHandle(const gohnd: Integer): Float` |
| `0x006529E4` | `procedure SetGameObjectCIRotationSpeedByHandle(const gohnd: Integer; val: Float)` |
| `0x00652A14` | `function GetGameObjectCIStuckAngleByHandle(const gohnd: Integer): Float` |
| `0x00652A50` | `procedure SetGameObjectCIStuckAngleByHandle(const gohnd: Integer; val: Float)` |
| `0x00652A80` | `function GetGameObjectCIEpsilonAngleByHandle(const gohnd: Integer): Float` |
| `0x00652ABC` | `procedure SetGameObjectCIEpsilonAngleByHandle(const gohnd: Integer; val: Float)` |
| `0x00652AEC` | `function GetGameObjectCIEpsilonShiftByHandle(const gohnd: Integer): Float` |
| `0x00652B28` | `procedure SetGameObjectCIEpsilonShiftByHandle(const gohnd: Integer; val: Float)` |
| `0x00652B58` | `function GetGameObjectCIEpsilonMoveByHandle(const gohnd: Integer): Float` |
| `0x00652B94` | `procedure SetGameObjectCIEpsilonMoveByHandle(const gohnd: Integer; val: Float)` |
| `0x00652BC4` | `function GetGameObjectCIDistExtPointEpsilonByHandle(const gohnd: Integer): Float` |
| `0x00652C00` | `procedure SetGameObjectCIDistExtPointEpsilonByHandle(const gohnd: Integer; val: Float)` |
| `0x00652C30` | `function GetGameObjectCIBuildExtPointsByHandle(const gohandle: Integer): Boolean` |
| `0x00652C58` | `procedure SetGameObjectCIBuildExtPointsByHandle(const gohandle: Integer; build: Boolean)` |
| `0x00652C7C` | `function GetGameObjectMyMoveRelativeQuarter: Integer` |
| `0x00652CA8` | `function GetGameObjectMoveRelativeQuarterByHandle(const gohandle: Integer): Integer` |
| `0x00652CD8` | `function GetGameObjectMyIsVolumeClipped: Boolean` |
| `0x00652D30` | `function GetGameObjectIsVolumeClippedByHandle(const gohandle: Integer): Boolean` |
| `0x00652D88` | `procedure GameObjectParentToChildAbsolute(const gochild, goparent: Integer)` |
| `0x00652DD0` | `procedure GameObjectParentToChild(const gohandle, togohandle: Integer)` |
| `0x00652EDC` | `procedure GameObjectMyParentToChild(const togohandle: Integer)` |
| `0x00652FF8` | `function GetGameObjectValueIndExistedByHandle(const gohandle: Integer; index: Integer): Boolean` |
| `0x00653028` | `function GetGameObjectMyValueIndExisted(const index: Integer): Boolean` |
| `0x00653058` | `function GetGameObjectIsParent(const gohandle: Integer): Boolean` |
| `0x0065307C` | `procedure GameObjectMyResetDirUp` |
| `0x006530D8` | `procedure GameObjectResetDirUpByHandle(const gohandle: Integer)` |
| `0x00653134` | `function GetGameObjectChildStrExistsBaseNameByHandle(const gohandle: Integer; const csubbasename: String): Integer` |
| `0x006531EC` | `function GetGameObjectMyChildStrExistsBaseName(const csubbasename: String): Integer` |
| `0x006532AC` | `procedure GameObjectAnimationControllerStatesInclude(const gohandle, state: Integer)` |
| `0x00653304` | `procedure GameObjectAnimationControllerStatesExclude(const gohandle, state: Integer)` |
| `0x0065335C` | `function GameObjectAddNewChild(const gohandle: integer; const racename: string; const basename: string): Integer` |
| `0x00653390` | `function GameObjectCreateTLFAnimationChildrenBehaviour(const gohandle, gobehhandle, gotlfhandle: Integer): Integer` |
| `0x00653474` | `function GetGameObjectCountInTLFAnimationChildrenBehaviour(const gohandle: Integer): Integer` |
| `0x006534C4` | `procedure GameObjectDestroyTLFAnimationChildrenBehaviour(const gohandle: Integer)` |
| `0x00653548` | `function GameObjectCreateTLFAnimationBehaviour(const gohandle, gobehhandle, gotlfhandle: Integer): Integer` |
| `0x0065362C` | `procedure SetGameObjectMatrixByHandle(const gohandle: integer; posx, posy, posz, dirx, diry, dirz, upx, upy, upz: Float)` |
| `0x00653734` | `procedure SetGameObjectUseIdentityMatrix(const gohnd: Integer; const val: Boolean)` |
| `0x00653754` | `function GetGameObjectUseIdentityMatrix(const gohnd: Integer): Boolean` |
| `0x00653778` | `procedure SetGameObjectUseNoChildrenRecTransformationChanged(const gohnd: Integer; const val: Boolean)` |
| `0x00653798` | `function GetGameObjectUseNoChildrenRecTransformationChanged(const gohnd: Integer): Boolean` |
| `0x006537BC` | `function GetGameObjectCountInTLFAnimationBehaviour(const gohandle: Integer): Integer` |
| `0x0065380C` | `procedure GameObjectDestroyTLFAnimationBehaviour(const gohandle: Integer)` |
| `0x00653898` | `procedure GameObjectDestroyByHandle(const gohandle: Integer)` |
| `0x006538B8` | `procedure GameObjectRequestToDestroyByHandle(const gohnd: Integer)` |
| `0x006538E8` | `function GameObjectGetUseableSeasonMaterialCount(const gohandle, season: Integer): Integer` |
| `0x00653990` | `function GameObjectIsSeasonMaterialCompatible(const gohandle, season: Integer): Boolean` |
| `0x00653ABC` | `function GameObjectIsSeasonMaterialSame(const gohandle: Integer): Boolean` |
| `0x00653C5C` | `procedure GameObjectRestartAutoChildrenProperty(const gohandle: Integer)` |
| `0x00653CA0` | `function GetGameObjectsBetweenGroupHandle(const gohandle, targetgohandle: Integer): Integer` |
| `0x00653D18` | `function GameObjectCalcPathAdvByHandle(const gohandle: Integer; const endx, endz: Float; const usethread, useclear: Boolean; const curind, skipcount, maxwavedepth: Integer; const onthreadstate: String; const calcasap: Boolean): Integer` |
| `0x00653DCC` | `function GameObjectCalcPathByHandle(const gohandle: Integer; const endx, endz: Float; usethread, useclear: Boolean): Integer` |
| `0x00653E68` | `function GameObjectCalcPathExtByHandle(const gohandle: Integer; const startx, startz, endx, endz: Float; usethread, useclear: Boolean): Integer` |
| `0x00653F00` | `procedure SetGameObjectTagPathDataThread(const gohandle, tag: Integer)` |
| `0x00653F24` | `function GetGameObjectTagPathDataThread(const gohandle: Integer): Integer` |
| `0x00653F48` | `function GetGameObjectDoProcessFriendsStateLogic0(const gohandle, ffov, fmycountcollidedobjects_greater, fhiscollidedtag_equal, fhiscollidedtag_gequal: Integer; fhisisendpointindex_equal: Boolean; fhisrelativequarter_notequal: Integer): Boolean` |
| `0x0065405C` | `procedure GameObjectDoProcessFriendsStateLogic1(const gohandle, ffov, fcoltag_equal, fcountcolobjs_greater, fgroupstackindextoincval, fcoltagtoset: Integer; const fexecutestate: String; fhisrelquart_equal, fmyrelq_equal: Integer)` |
| `0x00654690` | `function GetGameObjectDoProcessFriendsStateLogic3(const myhandle, gohandle: Integer; ffov, fcountcolobjs_greater: Integer; fisendpind_equal: Boolean; frelquart_notequal: Integer): Integer` |
| `0x006547AC` | `function GetGameObjectDoFindEnemyStateLogic0(const gohandle: Integer; fgameobjectstackindex, fgameobjectstackval_notequal, fgameobjectstackval_equal, fcstatestagstatemove_and, fcenummovewalk_lequal: Integer): Integer` |
| `0x00654854` | `procedure DoGameObjectProcLogic0AnimationReachedInf(const cenumactionfight, cenumactionresurrect: Integer; const continueteststate, dofightdefence2continuestate, resurrectstate: String)` |
| `0x00654998` | `procedure DoGameObjectProcLogic0AnimationReachedInfArch(const cenumactionfight, cenumactionresurrect, cgostack_wpnstate: Integer; const continueteststate, dofightdefence2continuestate, resurrectstate, firecontinuestate: String)` |
| `0x00654B20` | `procedure DoGameObjectProcLogic0AnimationReachedCav(const cenumactionfight, cgostack_action, cenummovewalk, cenummoverun: Integer; const continueteststate, dofightdefence2continuestate, dospeedcontrolstate: String)` |
| `0x00654C84` | `procedure DoGameObjectProcLogic0AnimationReachedCavArch(const cenumactionfight, cgostack_action, cgostack_wpnstate, cenummovewalk, cenummoverun: Integer; const continuetest, dofightdefence2continue, dospeedcontrol, firecontinue: String)` |
| `0x00654E0C` | `function CreatePoolGameObjectHandle(const racename: String; const basename: String; positionx: Float; positiony: Float; positionz: Float): Integer` |
| `0x00654F24` | `procedure FreeToPoolGameObjectHandle(gohandle: Integer)` |
| `0x00655058` | `procedure FreeToPoolGameObjectTimeoutHandle(gohandle: Integer; Timeout: Float)` |
| `0x0065508C` | `function GetGameObjectRaceTag(gohandle: Integer): Integer` |
| `0x006551E8` | `procedure GameObjectResetFrameAnimationBlend(gohandle: Integer)` |
| `0x00655208` | `procedure SetGameObjectOrientationByHandle(gohandle: Integer; up_x: Float; up_y: Float; up_z: Float; dir_x: Float; dir_y: Float; dir_z: Float)` |
| `0x00655248` | `procedure GetGameObjectOrientationByHandle(gohandle: Integer; var up_x: Float; var up_y: Float; var up_z: Float; var dir_x: Float; var dir_y: Float; var dir_z: Float)` |
| `0x006552C8` | `function GetGameObjectParentHandle(gohandle: Integer): Integer` |
| `0x006552E8` | `procedure SetGameObjectBVTestEnabledByHandle(gohandle: Integer; val: Boolean)` |
| `0x00655308` | `function GetGameObjectBVTestEnabledByHandle(gohandle: Integer): Boolean` |
| `0x0065532C` | `procedure SetGameObjectBVTestShpereRadiusByHandle(gohandle: Integer; val: Float)` |
| `0x0065534C` | `function GetGameObjectBVTestShpereRadiusByHandle(gohandle: Integer): Float` |
| `0x0065537C` | `procedure SetGameObjectCollisionPriorityByHandle(gohandle: Integer; aprior: Integer)` |
| `0x0065539C` | `function GetGameObjectCollisionPriorityByHandle(gohandle: Integer): Integer` |
| `0x006553C0` | `function GameObjectCheckLine(gohandle: Integer; lsx, lsz, lex, lez: Float; var resx: Float; var resz: Float): Integer` |
| `0x0065558C` | `procedure SetGameObjectColIntMaskOptionsByHandle(const gohandle: Integer; const optest, opwrite: Boolean)` |
| `0x006555FC` | `procedure SetGameObjectColIntMaskTestTypeOptionByHandle(const gohandle: Integer; const testtypeoption: String)` |
| `0x00655648` | `procedure SetGameObjectColIntMaskTestPriorityOptionByHandle(const gohandle: Integer; const testpriorityoption: String)` |
| `0x00655694` | `procedure SetGameObjectVisualPropertiesByHandle(const gohandle: Integer; const newrace, newbase: String)` |
| `0x00655884` | `function GetGameObjectNearestToPlayerByHandle(const gohandle: Integer; toplayerhnd: Integer): Integer` |
| `0x00655930` | `function GetGameObjectExistPlayerInRadiusByHandle(const gohandle, toplayerhnd: Integer; const rad: Float): Boolean` |
| `0x006559DC` | `procedure GetGameObjectAxisAlignedDimensionsByHandle(const gohandle: Integer; var x, y, z: Float)` |
| `0x00655A34` | `function GetGameObjectOnStateDestroyByHandle(const gohandle: Integer): String` |
| `0x00655A7C` | `procedure SetGameObjectOnStateDestroyByHandle(const gohandle: Integer; const state: String)` |
| `0x00655AB8` | `procedure SetGameObjectPlayerHandleByHandle(const gohandle, newplayerhandle: Integer)` |
| `0x00655B00` | `function GetGameObjectWantWallCellHandleByHandle(const gohandle: Integer): Integer` |
| `0x00655B28` | `function GetGameObjectWantWallHandleByHandle(const gohandle: Integer): Integer` |
| `0x00655B5C` | `function GetGameObjectWallHandleByHandle(const wallhandle: Integer): Integer` |
| `0x00655BE8` | `function GetGameObjectActiveWallCellHandleByHandle(const gohandle: Integer): Integer` |
| `0x00655C10` | `procedure GameObjectDeleteWantWallCellByHandle(const gohandle: Integer)` |
| `0x00655C38` | `function GameObjectCreateProgressStateMachineBehaviour(const gohandle: Integer; const filescript, statename: String; const static, enabled: Boolean; const interval: Integer): Integer` |
| `0x00655D20` | `procedure GameObjectDestroyProgressStateMachineBehaviour(const gohandle: Integer)` |
| `0x00655D94` | `function GetGameObjectBVRayCastIntersectEnabledByHandle(const gohandle: Integer): Boolean` |
| `0x00655DB8` | `procedure SetGameObjectBVRayCastIntersectEnabledByHandle(const gohandle: Integer; const cenabled: Boolean)` |
| `0x00655DFC` | `function GetGameObjectBVUseTrackNodeByHandle(const gohandle: Integer): Boolean` |
| `0x00655E38` | `procedure SetGameObjectBVUseTrackNodeByHandle(const gohandle: Integer; const cbvusetracknode: Boolean)` |
| `0x00655E74` | `function GetGameObjectIntervalFactorByHandle(const gohandle: Integer): Float` |
| `0x00655EAC` | `procedure SetGameObjectIntervalFactorByHandle(const gohandle: Integer; const intervalfactor: Float)` |
| `0x00655ED4` | `function GetGameObjectTrackPointCorrectIntervalByHandle(const gohnd: Integer): Boolean` |
| `0x00655EFC` | `procedure SetGameObjectTrackPointCorrectIntervalByHandle(const gohnd: Integer; const val: Boolean)` |
| `0x00655F24` | `function GetGameObjectStartFrameByHandle(const gohandle: Integer): Integer` |
| `0x00655F48` | `procedure SetGameObjectStartFrameByHandle(const gohandle, startframe: Integer)` |
| `0x00655F94` | `function GetGameObjectEndFrameByHandle(const gohandle: Integer): Integer` |
| `0x00655FB8` | `procedure SetGameObjectEndFrameByHandle(const gohandle, endframe: Integer)` |
| `0x00656004` | `function GetGameObjectCurrentFrameBlendByHandle(const gohandle: Integer): Integer` |
| `0x00656028` | `procedure SetGameObjectCurrentFrameBlendByHandle(const gohandle, currentframeblend: Integer)` |
| `0x00656074` | `function GetGameObjectMaxFrameBlendByHandle(const gohandle: Integer): Integer` |
| `0x0065609C` | `procedure SetGameObjectMaxFrameBlendByHandle(const gohandle, maxframeblend: Integer)` |
| `0x006560C4` | `function GetGameObjectMinFrameBlendByHandle(const gohandle: Integer): Integer` |
| `0x006560EC` | `procedure SetGameObjectMinFrameBlendByHandle(const gohandle, minframeblend: Integer)` |
| `0x00656114` | `function GetGameObjectStartFrameBlendByHandle(const gohandle: Integer): Integer` |
| `0x0065613C` | `procedure SetGameObjectStartFrameBlendByHandle(const gohandle, startframeblend: Integer)` |
| `0x0065618C` | `function GetGameObjectEndFrameBlendByHandle(const gohandle: Integer): Integer` |
| `0x006561B4` | `procedure SetGameObjectEndFrameBlendByHandle(const gohandle, endframeblend: Integer)` |
| `0x00656204` | `function GetGameObjectOrignIntervalByHandle(const gohandle: Integer): Integer` |
| `0x00656234` | `procedure SetGameObjectOrignIntervalByHandle(const gohandle, origninterval: Integer)` |
| `0x00656260` | `procedure SetGameObjectCurrentFrameDeltaByHandle(const gohandle: Integer; const delta: Float)` |
| `0x006562B0` | `function GetGameObjectFrameAnimationDataByHandle(const gohandle: Integer; const name: String; var startframe: Integer; var endframe: Integer): Boolean` |
| `0x00656330` | `function GetGameObjectAnimationCycleCountFrameByHandle(const gohandle: Integer; const name: String): Integer` |
| `0x006563E8` | `function GetGameObjectAnimationCycleLeftFrameByHandle(const gohandle: Integer): Integer` |
| `0x0065650C` | `function GetGameObjectDeferredFrameBlendByHandle(const gohandle: Integer): Boolean` |
| `0x00656534` | `procedure SetGameObjectDeferredFrameBlendByHandle(const gohandle: Integer; const def: Boolean)` |
| `0x0065655C` | `procedure GetGameObjectDeferredFramesByHandle(const gohandle: Integer; var defcurrentframe: Integer; var defstartframe: Integer; var defendframe: Integer)` |
| `0x006565B8` | `procedure SetGameObjectDeferredFramesByHandle(const gohandle: Integer; const defcurrentframe, defstartframe, defendframe: Integer)` |
| `0x006565F4` | `function GameObjectGetOrCreateEffectFXSourceByHandle(const gohnd: Integer; const sourcename, key: String): Integer` |
| `0x00656634` | `function GameObjectGetOrCreateEffectFXManagerByHandle(const gohnd: Integer; const managername, key: String): Integer` |
| `0x00656674` | `function GameObjectThorFXTargetByHandle(const gohnd: Integer; const managername, key: String; const x, y, z: Float): Integer` |
| `0x006566F8` | `function GameObjectThorFXGlowSizeByHandle(const gohnd: Integer; const managername, key: String; const glowsize: Float): Integer` |
| `0x00656754` | `function GameObjectThorFXVibrate(const gohnd: Integer; const managername, key: String; const vibrate: Float): Integer` |
| `0x006567B0` | `function GameObjectThorFXInnerColor(const gohnd: Integer; const managername, key: String; const r, g, b, a: Float): Integer` |
| `0x00656844` | `function GameObjectThorFXOuterColor(const gohnd: Integer; const managername, key: String; const r, g, b, a: Float): Integer` |
| `0x006568D8` | `function GameObjectThorFXCoreColor(const gohnd: Integer; const managername, key: String; const r, g, b, a: Float): Integer` |
| `0x0065696C` | `function GameObjectThorFXCore(const gohnd: Integer; const managername, key: String; const core: Boolean): Integer` |
| `0x006569C8` | `function GameObjectThorFXGlow(const gohnd: Integer; const managername, key: String; const glow: Boolean): Integer` |
| `0x00656A24` | `function GameObjectThorFXWildness(const gohnd: Integer; const managername, key: String; const wildness: Float): Integer` |
| `0x00656A80` | `function GameObjectThorFXZWrite(const gohnd: Integer; const managername, key: String; const zwrite: Boolean): Integer` |
| `0x00656ADC` | `function GameObjectThorFXZTest(const gohnd: Integer; const managername, key: String; const ztest: Boolean): Integer` |
| `0x00656B38` | `function GameObjectThorFXOnCalcPointState(const gohnd: Integer; const managername, key: String; const oncalcpointstate: String): Integer` |
| `0x00656B98` | `function GameObjectThorFXCoreBlendingMode(const gohnd: Integer; const managername, key: String; const coreblendingmode: String): Integer` |
| `0x00656C0C` | `function GameObjectThorFXGlowBlendingMode(const gohnd: Integer; const managername, key: String; const glowblendingmode: String): Integer` |
| `0x00656C80` | `procedure SetGameObjectAnimationCyclesListByHandle(const gohnd: Integer; const animcycleslibname: String)` |
| `0x00656CEC` | `function GetGameObjectAnimationCyclesListByHandle(const gohnd: Integer): String` |
| `0x00656D40` | `function GetGameObjectDecalHandleByHandle(const gohnd: Integer): Integer` |
| `0x00656D64` | `procedure SetGameObjectDecalHandleByHandle(const gohnd, dechnd: Integer)` |
| `0x00656DDC` | `procedure GameObjectDestroyDecalByHandle(const gohnd: Integer)` |
| `0x00656E24` | `procedure GameObjectDeattachDecalByHandle(const gohnd: Integer)` |
| `0x00656E58` | `procedure GetGameObjectAbsolutePositionByHandle(const gohnd: Integer; var x: Float; var y: Float; var z: Float)` |
| `0x00656EB0` | `procedure SetGameObjectAbsolutePositionByHandle(const gohnd: Integer; const x, y, z: Float)` |
| `0x00656EFC` | `procedure GetGameObjectAbsoluteScaleByHandle(const gohnd: Integer; var x: Float; var y: Float; var z: Float)` |
| `0x00656F54` | `procedure GameObjectTryRootUseNoChildrenRecTransformationByHandle(const gohnd: Integer)` |
| `0x00656F74` | `function GameObjectSetupIdentityRecTransformationByHandle(const gohnd: Integer): Integer` |
| `0x00656FA0` | `function GameObjectRootSetupIdentityRecTransformationByHandle(const gohnd: Integer): Integer` |
| `0x00656FD8` | `function GetGameObjectD2ToCamByHandle(const hnd: Integer): Float` |
| `0x00657014` | `function GetGameObjectProgressLastTimeByHandle(const hnd: Integer): Float` |
| `0x00657044` | `procedure GameObjectResetProgressLastTimeByHandle(const gohnd: Integer)` |
| `0x00657080` | `procedure GameObjectDoProgressByHandle(const gohnd: Integer)` |
| `0x006570C0` | `procedure GameObjectDoProgressDeltaByHandle(const gohnd: Integer; delta: Float)` |
| `0x00657114` | `procedure GameObjectChangeUniqIdByHandle(const gohnd, newid: Integer)` |
| `0x00657148` | `function GetGameObjectCollisionMaskWidthByHandle(const gohnd: Integer): Integer` |
| `0x00657188` | `function GetGameObjectCollisionMaskHeightByHandle(const gohnd: Integer): Integer` |
| `0x006571C8` | `function GetGameObjectCollisionMaskValueByHandle(const gohnd, row, col: Integer): Boolean` |
| `0x00657224` | `function GetGameObjectCollisionMaskReflectByHandle(const gohnd: Integer): Boolean` |
| `0x00657264` | `procedure SetGameObjectCollisionMaskReflectByHandle(const gohnd: Integer; val: Boolean)` |
| `0x006572A0` | `function GetGameObjectTrackPointVisibleByHandle(const gohnd: Integer): Boolean` |
| `0x006572C8` | `procedure SetGameObjectTrackPointVisibleByHandle(const gohnd: Integer; const val: Boolean)` |
| `0x006572EC` | `function GetGameObjectMyTrackPointSkipPoints: Boolean` |
| `0x00657314` | `procedure SetGameObjectMyTrackPointSkipPoints(const val: Boolean)` |
| `0x00657344` | `function GetGameObjectTrackPointSkipPointsByHandle(const gohnd: Integer): Boolean` |
| `0x0065736C` | `procedure SetGameObjectTrackPointSkipPointsByHandle(const gohnd: Integer; const val: Boolean)` |
| `0x00657394` | `function GetGameObjectMyTrackPointSkipFactor: Float` |
| `0x006573C8` | `procedure SetGameObjectMyTrackPointSkipFactor(const val: Float)` |
| `0x006573F8` | `function GetGameObjectTrackPointSkipFactorByHandle(const gohnd: Integer): Float` |
| `0x0065742C` | `procedure SetGameObjectTrackPointSkipFactorByHandle(const gohnd: Integer; const val: Float)` |
| `0x00657454` | `function GetGameObjectMyTrackPointSkipEpsilon: Float` |
| `0x00657488` | `procedure SetGameObjectMyTrackPointSkipEpsilon(const val: Float)` |
| `0x006574B8` | `function GetGameObjectTrackPointSkipEpsilonByHandle(const gohnd: Integer): Float` |
| `0x006574EC` | `procedure SetGameObjectTrackPointSkipEpsilonByHandle(const gohnd: Integer; const val: Float)` |
| `0x00657514` | `function GetGameObjectMyTrackPointSkipQuadTree: Integer` |
| `0x0065753C` | `procedure SetGameObjectMyTrackPointSkipQuadTree(const val: Integer)` |
| `0x0065756C` | `function GetGameObjectTrackPointSkipQuadTreeByHandle(const gohnd: Integer): Integer` |
| `0x00657594` | `procedure SetGameObjectTrackPointSkipQuadTreeByHandle(const gohnd: Integer; const val: Integer)` |
| `0x006575BC` | `function GetGameObjectTrackPointTagByIndexByHandle(const gohnd, index: Integer): Byte` |
| `0x00657604` | `procedure SetGameObjectTrackPointTagByIndexByHandle(const gohnd, index: Integer; const val: Byte)` |
| `0x00657670` | `procedure SetGameObjectRotationDampingByHandle(hnd: Integer; constant, linear, quadratic: Float)` |
| `0x006576A0` | `procedure SetGameObjectTranslationDampingByHandle(hnd: Integer; constant, linear, quadratic: Float)` |
| `0x006576D0` | `procedure SetGameObjectTurnSpeedByHandle(hnd: Integer; speed: Float)` |
| `0x006576F4` | `function GetGameObjectTagFloatByHandle(const gohnd: Integer): Float` |
| `0x0065771C` | `procedure SetGameObjectTagFloatByHandle(const gohnd: Integer; const val: Float)` |
| `0x00657740` | `procedure GetGameObjectEulerFromMatrixByHandle(const gohnd: Integer; var turn, pitch, roll: Float)` |
| `0x006577AC` | `function GetGameObjectLibMaterialByHandle(const gohnd: Integer): Integer` |
| `0x00657830` | `procedure GetGameObjectDefScalePropsByHandle(const gohnd: Integer; var x, y, z: Float; var rand: Boolean; var minfact, maxfact, deffact: Float)` |
| `0x00660D14` | `procedure GroupAddGameObjectByHandle(grhandle: Integer; gohandle: Integer)` |
| `0x00660D4C` | `procedure GroupRemoveGameObjectByHandle(grhandle: Integer; gohandle: Integer)` |
| `0x00660D84` | `procedure GroupClearGameObjectsByHandle(grhandle: Integer)` |
| `0x00660DA4` | `function GetGroupCountGameObjectsByHandle(grhandle: Integer): Integer` |
| `0x006611E8` | `function GetGroupGameObjectExistsByHandle(grhandle: Integer; const basename: String): Boolean` |
| `0x0066120C` | `function GetGroupNearestGameObjectByHandle(gohandle: Integer; resgrhandle: Integer): Integer` |
| `0x00661538` | `procedure GroupGameObjectsGridSetColumnsByHandle(grhandle: Integer; columns: Integer)` |
| `0x0066155C` | `function GroupGameObjectsGridGetColumnsByHandle(grhandle: Integer): Integer` |
| `0x00661584` | `function GroupGameObjectsGridGetRowsByHandle(grhandle: Integer): Integer` |
| `0x006615AC` | `procedure GroupGameObjectsGridSetGridFormatByHandle(grhandle: Integer; const gridformat: String)` |
| `0x006615DC` | `function GroupGameObjectsGridGetGridFormatByHandle(grhandle: Integer): String` |
| `0x00661628` | `procedure GroupGameObjectsGridRebuildByHandle(grhandle: Integer)` |
| `0x00661648` | `procedure GroupGameObjectsGridRebuildExtByHandle(grhandle: Integer; x, y, dirx, diry: Float)` |
| `0x00661674` | `procedure GroupGameObjectsGridRebuildExtDefaultByHandle(grhandle: Integer)` |
| `0x00661C2C` | `procedure GroupGameObjectsGridSetNeedDefragmantationByHandle(grhandle: Integer; needdefragmentation: Boolean)` |
| `0x00661C50` | `function GroupGameObjectsGridGetNeedDefragmantationByHandle(grhandle: Integer): Boolean` |
| `0x00661DDC` | `function GetGroupGameObjectsGridIsGameObjectInRowByHandle(grhandle: Integer; gohandle: Integer; index: Integer): Boolean` |
| `0x00661E1C` | `function GetGroupGameObjectsGridIsGameObjectInColByHandle(grhandle: Integer; gohandle: Integer; index: Integer): Boolean` |
| `0x00661E5C` | `function GetGroupGameObjectHandleByGridColRow(grhandle: Integer; col: Integer; row: Integer): Integer` |
| `0x00661E8C` | `function GetGroupGameObjectHandleByGridColRowNearest(grhandle: Integer; col: Integer; row: Integer; colnearest: Boolean; rownearest: Boolean): Integer` |
| `0x00661EE4` | `function GroupGameObjectsGridGetIsDefragmentationNeededByHandle(grhandle: Integer): Boolean` |
| `0x0066229C` | `function GroupGameObjectsGridGetCountNullCellsHandle(grhandle: Integer): Integer` |
| `0x006622CC` | `function GroupGameObjectsGridGetGameObjectHandlePosition(gohandle: Integer; var col: Integer; var row: Integer): Boolean` |
| `0x00662340` | `procedure GroupGameObjectsGridSetGameObjectHandlePosition(gohandle: Integer; const col: Integer; const row: Integer)` |
| `0x006623DC` | `procedure GroupGameObjectsGridDefragmantationByHandle(grhandle: Integer)` |
| `0x006623FC` | `function GroupGameObjectsGridGetIsDefragmentationNeededHByHandle(grhandle: Integer): Boolean` |
| `0x00662420` | `procedure GroupGameObjectsGridDefragmantationHByHandle(grhandle: Integer)` |
| `0x00662E48` | `procedure SetGroupGameObjectsCurrentPointByHandle(grhandle: Integer; index: Integer)` |
| `0x00662E98` | `procedure SetGroupGameObjectsExecuteStateByHandle(grhandle: Integer; const statename: String)` |
| `0x00662F74` | `procedure SetGroupGameObjectsExecuteStateByCollideTagByHandle(grhandle: Integer; atag: Integer; const statename: String)` |
| `0x0066305C` | `procedure SetGroupGameObjectsDelayExecuteStateByHandle(grhandle: Integer; const statename: String; aoffset, anoise, ainc: Float)` |
| `0x00663368` | `procedure SetGroupGameObjectsTrackPointClearByHandle(grhandle: Integer)` |
| `0x006633B0` | `procedure SetGroupGameObjectsSwitchToStateByHandle(grhandle: Integer; const statename: String)` |
| `0x00663430` | `procedure SetGroupGameObjectsIntValueByHandle(grhandle: Integer; const key: String; value: Integer)` |
| `0x00663480` | `procedure SetGroupGameObjectsFloatValueByHandle(grhandle: Integer; const key: String; value: Float)` |
| `0x006634D0` | `procedure SetGroupGameObjectsBoolValueByHandle(grhandle: Integer; const key: String; value: Boolean)` |
| `0x00663520` | `procedure SetGroupGameObjectsValueByHandle(grhandle: Integer; const key: String; const value: String)` |
| `0x00663570` | `procedure SetGroupGameObjectsIntValueIndByHandle(grhandle: Integer; index: Integer; value: Integer)` |
| `0x006635C0` | `procedure SetGroupGameObjectsFloatValueIndByHandle(grhandle: Integer; index: Integer; value: Float)` |
| `0x00663610` | `procedure SetGroupGameObjectsValueIndByHandle(grhandle: Integer; index: Integer; const value: String)` |
| `0x00663660` | `procedure SetGroupGameObjectsBoolValueIndByHandle(grhandle: Integer; index: Integer; value: Boolean)` |
| `0x006636B0` | `procedure SetGroupGameObjectsExecuteStateResetTrackPointByHandle(grhandle: Integer; const statename: String)` |
| `0x00664948` | `function GetGroupMovementGameObjectsCountByHandle(grhandle: Integer): Integer` |
| `0x00665C20` | `procedure GroupGameObjectsGridInitialize(grhandle: Integer; rows, cols: Integer)` |
| `0x0068A144` | `procedure MapDrawCustomMaskCollisionInGameObject(gohandle: Integer; tag : Integer)` |
| `0x00694638` | `procedure PlayerGameObjectsSwitchToState(const playername: String; const statename: String)` |
| `0x00694698` | `procedure PlayerGameObjectByBaseNameSwitchToState(const playername: String; const basename: String; const statename: String)` |
| `0x00694758` | `function GetPlayerCountOfGameObjects(const playername: String): Integer` |
| `0x00694790` | `function CreatePlayerGameObject(const playername: String; const racename: String; const basename: String; positionx: Float; positiony: Float; positionz: Float): String` |
| `0x00694BB8` | `function CreatePlayerGameObject2(const playername: String; const racename: String; const basename: String; const meshname: String; const materialname: String; positionx: Float; positiony: Float; positionz: Float): String` |
| `0x00694D9C` | `function CreatePlayerGameObjectHandle(const playername: String; const racename: String; const basename: String; positionx: Float; positiony: Float; positionz: Float): Integer` |
| `0x00694E10` | `function CreatePlayerGameObjectHandleByHandle(const playerhandle: Integer; const racename: String; const basename: String; positionx: Float; positiony: Float; positionz: Float): Integer` |
| `0x00696294` | `function GetPlayerGameObjectsCountByHandle(playerhandle: Integer): Integer` |
| `0x00699CCC` | `procedure ClearPlayerGameObjectsByHandle(plhandle: Integer)` |
| `0x00699FB0` | `function IsExistsGameObjectProperty(const racename: String; const basename: String): Boolean` |
| `0x006A9E48` | `function GetAIRegionCountOfGameObjects(const name: String): Integer` |
| `0x006AAAA8` | `function GameObjectRayCast(x: Float; z: Float): Integer` |
| `0x006AAAEC` | `function GameObjectRayCastByRadius(x, y, radius: Float): Integer` |
| `0x006AAB30` | `function GameObjectRayCastMouseRay: Integer` |
| `0x006AAD2C` | `procedure GameObjectSortRayCastList` |
| `0x006AAD74` | `function GetGameObjectRayCastByIndex(index: Integer): Integer` |
| `0x006AADA4` | `function GetGameObjectRayCastCount(): Integer` |
| `0x006AADD4` | `function GetRayCastIntersectGameObjectFromMouseRay(): Integer` |
| `0x006AAED8` | `function GetRayCastIntersectGameObject(start_x, start_y, start_z: Float; end_x, end_y, end_z: Float; var int_x, int_y, int_z: Float): Integer` |
| `0x006AAF80` | `function GetStretchGameObject: Integer` |
| `0x006AB650` | `function GetUserStretchIntGameObjectHandleByIndex(index: integer): Integer` |
| `0x006AF0FC` | `function GetAIRegionCountOfGameObjectsByHandle(const reghnd: Integer): Integer` |
| `0x006B18CC` | `procedure GetGameObjectsInArea(const x, y: Integer; const rad: Float; playername: String)` |
| `0x006B1980` | `procedure GetGameObjectsInAreaFloat(const x, y: Float; const rad: Float; playername: String)` |
| `0x006B1A0C` | `procedure GetGameObjectsInAreaByHandle(const x, y, rad: Float; plhnd: Integer)` |
| `0x006B1A60` | `procedure GetGameObjectsInRadius(x, y, r: Float; justcollision, justvisible: Boolean; justplayerhnd, justracetag, justsrcplayerhnd: Integer; justenemy, justfriend, justneutral, justnotenemy, justnotfriend, justnotneutral: Boolean)` |
| `0x006B1AE0` | `function GetGameObjectListByIndex(index: Integer): Integer` |
| `0x006B1B10` | `function GetGameObjectListCount(): Integer` |
| `0x006B37AC` | `function FindUniqIdByGameObject(const gohnd: Integer): Integer` |
| `0x006B37C8` | `function FindGameObjectByUniqId(const id: Integer): Integer` |
| `0x006B64C0` | `procedure TopologyAddPathGameObjectByHandle(gohandle: Integer)` |
| `0x006B6508` | `procedure TopologyClearPathGameObjects` |
| `0x006C3234` | `function GetValidGameObjectHandle(gohandle: Integer): Boolean` |
| `0x006C52DC` | `function GetGameObjectStateMachineHandle(const gohnd: Integer): Integer` |
| `0x006E9DF4` | `function ParserSelectGameObject(const gohandle: Integer): Integer` |
| `0x006E9EEC` | `function ParserCreateGameObject(const gohandle: Integer): Integer` |
| `0x006E9FE8` | `procedure ParserFreeGameObject(const gohandle: Integer)` |

### Group — 331

| VA | Объявление |
|---|---|
| `0x005FB6C0` | `procedure EditorBrushSetShowGroupTransform(const val: Boolean)` |
| `0x005FB6E0` | `function EditorBrushGetShowGroupTransform: Boolean` |
| `0x0060DE08` | `function IsGroupByHandle(grhandle: Integer): Boolean` |
| `0x00660BF0` | `function GetGroupEnabledByHandle(grhandle: Integer): Boolean` |
| `0x00660C10` | `procedure SetGroupEnabledByHandle(grhandle: Integer; Enabled: Boolean)` |
| `0x00660C30` | `function GetGroupCurrentStateByHandle(grhandle: Integer): String` |
| `0x00660C64` | `procedure GroupSwitchToByHandle(grhandle: Integer; const state: String)` |
| `0x00660C88` | `function CreateGroup(const playername: String; const groupname: String): Integer` |
| `0x00660CD8` | `function CreateGroupByPlHandle(const playerhandle: Integer; const groupname: String): Integer` |
| `0x00660DC8` | `function GetGroupGOHandleByGOIndexByHandle(grhandle: Integer; gameobjectindex: Integer): Integer` |
| `0x00660DF4` | `procedure RemoveGroupByHandle(grhandle: Integer)` |
| `0x00660E14` | `function CountGroup(const playername: String): Integer` |
| `0x00660E50` | `function CountGroupByHandle(playerhandle: Integer): Integer` |
| `0x00660E88` | `function GetGroupNameByIndex(const playername: String; groupindex: Integer): String` |
| `0x00660F7C` | `procedure GroupSetMovementModeByHandle(grhandle: Integer; const movementmode: String)` |
| `0x00660FAC` | `function GroupGetMinXByHandle(grhandle: Integer): Float` |
| `0x00660FD4` | `function GroupGetMinYByHandle(grhandle: Integer): Float` |
| `0x00660FFC` | `function GroupGetOffsetXByHandle(grhandle: Integer): Float` |
| `0x00661024` | `function GroupGetOffsetYByHandle(grhandle: Integer): Float` |
| `0x0066104C` | `function GroupGetMovementModeByHandle(grhandle: Integer): String` |
| `0x006610B4` | `function GetGroupCurrentGroupName(): String` |
| `0x006610EC` | `function GetGroupCurrentGRHandle(): Integer` |
| `0x00661110` | `function GetGroupStateTargetPositionXByHandle(grhandle: Integer): Float` |
| `0x00661138` | `function GetGroupStateTargetPositionYByHandle(grhandle: Integer): Float` |
| `0x00661160` | `function GetGroupStateTargetPositionZByHandle(grhandle: Integer): Float` |
| `0x00661188` | `procedure SetGroupValueByHandle(grhandle: Integer; const key: String; const value: String)` |
| `0x006611B0` | `function GetGroupValueByHandle(grhandle: Integer; const key: String): String` |
| `0x0066124C` | `procedure GroupExecuteStateByHandle(grhandle: Integer; const state: String)` |
| `0x006612AC` | `procedure GroupSetDesignTimeByHandle(grhandle: Integer; designtime: Boolean)` |
| `0x006612CC` | `function GroupGetDesignTimeByHandle(grhandle: Integer): Boolean` |
| `0x006612EC` | `procedure GroupSetPositionByHandle(grhandle: Integer; x: Float; y: Float; z: Float)` |
| `0x00661324` | `procedure GroupSetPositionTrackNodesByHandle(grhandle: Integer; x: Float; y: Float; z: Float)` |
| `0x0066137C` | `procedure GroupSetDirectionByHandle(grhandle: Integer; x: Float; y: Float; z: Float)` |
| `0x006613C0` | `procedure GroupSetDirectPosAndDirByHandle(grhandle: Integer; x, y, z, dirx, diry, dirz: Float)` |
| `0x00661410` | `procedure GroupSetObjectsDirectionByHandle(grhandle: Integer; x: Float; y: Float; z: Float)` |
| `0x00661448` | `procedure GroupSetMinXByHandle(grhandle: Integer; minx: Float)` |
| `0x00661468` | `procedure GroupSetMinYByHandle(grhandle: Integer; miny: Float)` |
| `0x00661488` | `function GroupGetCentralPositionXByHandle(grhandle: Integer): Float` |
| `0x006614AC` | `function GroupGetCentralPositionYByHandle(grhandle: Integer): Float` |
| `0x006614D0` | `function GroupGetCentralPositionZByHandle(grhandle: Integer): Float` |
| `0x006614F4` | `procedure GroupSetRandomOffsetByHandle(grhandle: Integer; randomoffset: Boolean)` |
| `0x00661514` | `function GroupGetRandomOffsetByHandle(grhandle: Integer): Boolean` |
| `0x00661608` | `procedure GroupApplyByHandle(grhandle: Integer)` |
| `0x0066169C` | `procedure GroupSetOffsetXByHandle(grhandle: Integer; offsetx: Float)` |
| `0x006616BC` | `procedure GroupSetOffsetyByHandle(grhandle: Integer; offsety: Float)` |
| `0x006616DC` | `procedure GroupSetAngleByHandle(grhandle: Integer; angle: Float)` |
| `0x006616FC` | `function GroupGetAngleByHandle(grhandle: Integer): Float` |
| `0x00661724` | `procedure GroupSetNearestPointByHandle(grhandle: Integer; nearestpoint: Boolean)` |
| `0x00661744` | `function GroupGetNearestPointByHandle(grhandle: Integer): Boolean` |
| `0x00661764` | `function GroupGetDirectionXByHandle(grhandle: Integer): Float` |
| `0x00661788` | `function GroupGetDirectionYByHandle(grhandle: Integer): Float` |
| `0x006617AC` | `function GroupGetDirectionZByHandle(grhandle: Integer): Float` |
| `0x006617D0` | `function GroupGetPermitWidthReflectionByHandle(grhandle: Integer): Boolean` |
| `0x006617F4` | `function GroupGetPermitHeightReflectionByHandle(grhandle: Integer): Boolean` |
| `0x00661818` | `procedure GroupSetPermitWidthReflectionByHandle(grhandle: Integer; permitwidthreflection: Boolean)` |
| `0x0066183C` | `procedure GroupSetPermitHeightReflectionByHandle(grhandle: Integer; permitheightreflection: Boolean)` |
| `0x00661860` | `function GroupGetFindPathByHandle(grhandle: Integer): Boolean` |
| `0x00661884` | `function GroupGetDirectPathByHandle(grhandle: Integer): Boolean` |
| `0x006618A8` | `function GroupGetDirectPathColPointCancel(grhandle: Integer): Boolean` |
| `0x006618CC` | `procedure GroupSetDirectPathColPointCancel(grhandle: Integer; directpathcolpointcancel: Boolean)` |
| `0x006618F0` | `function GroupGetTopLeftCoordXByHandle(grhandle: Integer): Float` |
| `0x00661924` | `function GroupGetTopLeftCoordYByHandle(grhandle: Integer): Float` |
| `0x00661958` | `function GroupGetTopLeftCoordZByHandle(grhandle: Integer): Float` |
| `0x0066198C` | `function GroupGetTopRightCoordXByHandle(grhandle: Integer): Float` |
| `0x006619C0` | `function GroupGetTopRightCoordYByHandle(grhandle: Integer): Float` |
| `0x006619F4` | `function GroupGetTopRightCoordZByHandle(grhandle: Integer): Float` |
| `0x00661A28` | `function GroupGetBottomLeftCoordXByHandle(grhandle: Integer): Float` |
| `0x00661A5C` | `function GroupGetBottomLeftCoordYByHandle(grhandle: Integer): Float` |
| `0x00661A90` | `function GroupGetBottomLeftCoordZByHandle(grhandle: Integer): Float` |
| `0x00661AC4` | `function GroupGetBottomRightCoordXByHandle(grhandle: Integer): Float` |
| `0x00661AF8` | `function GroupGetBottomRightCoordYByHandle(grhandle: Integer): Float` |
| `0x00661B2C` | `function GroupGetBottomRightCoordZByHandle(grhandle: Integer): Float` |
| `0x00661B60` | `function GroupGetRadiusByHandle(grhandle: Integer): Float` |
| `0x00661B88` | `function GroupGetPositionXByHandle(grhandle: Integer): Float` |
| `0x00661BB4` | `function GroupGetPositionYByHandle(grhandle: Integer): Float` |
| `0x00661BE0` | `function GroupGetPositionZByHandle(grhandle: Integer): Float` |
| `0x00661C0C` | `procedure GroupCalcCentralPositionByHandle(grhandle: Integer)` |
| `0x00661C74` | `function GroupGetAbsoluteHeightByHandle(grhandle: Integer): Float` |
| `0x00661C9C` | `function GroupGetAbsoluteWidthByHandle(grhandle: Integer): Float` |
| `0x00661CC4` | `function GroupGetDistanceByHandle(grhandle: Integer; grhandletarget: Integer): Float` |
| `0x00661D0C` | `procedure GroupTurnToGroupByHandle(grhandle: Integer; grhandletarget: Integer)` |
| `0x00661D40` | `procedure GroupSetPickedByHandle(grhandle: Integer; picked: Boolean)` |
| `0x00661DB8` | `function GroupGetPickedByHandle(grhandle: Integer): Boolean` |
| `0x00661EC4` | `procedure GroupApplyExtByHandle(grhandle: Integer)` |
| `0x00661F08` | `function GroupGetCenterFirstRowXByHandle(grhandle: Integer): Float` |
| `0x00661F44` | `function GroupGetCenterFirstRowZByHandle(grhandle: Integer): Float` |
| `0x00661F80` | `function GroupGetCenterLastRowXByHandle(grhandle: Integer): Float` |
| `0x00661FBC` | `function GroupGetCenterLastRowZByHandle(grhandle: Integer): Float` |
| `0x00661FF8` | `procedure GroupFastCalcCentralPositionByHandle(grhandle: Integer)` |
| `0x00662018` | `function GroupGetIsEnemyByHandle(grhandle: Integer; enemygrhandle: Integer): Boolean` |
| `0x00662068` | `function GetGroupIntValueByHandle(grhandle: Integer; const key: String): Integer` |
| `0x00662090` | `procedure SetGroupIntValueByHandle(grhandle: Integer; const key: String; value: Integer)` |
| `0x006620B8` | `procedure SetGroupStateTargetPositionByHandle(grhandle: Integer; x: Float; y: Float; z: Float)` |
| `0x00662104` | `function GetGroupFloatValueByHandle(grhandle: Integer; const key: String): Float` |
| `0x00662138` | `procedure SetGroupFloatValueByHandle(grhandle: Integer; const key: String; value: Float)` |
| `0x00662160` | `function GetGroupCountNearestObjectsByHandle(grhandle: Integer): Integer` |
| `0x00662184` | `procedure GroupClearNearestObjectsByHandle(grhandle: Integer)` |
| `0x006621A4` | `procedure GroupGetNearestObjectsInAreaByHandle(grhandle: Integer; x: Float; y: Float; width: Float; height: Float)` |
| `0x006621D0` | `function GetGroupNearestObjectsByHandle(grhandle: Integer; index: Integer): Integer` |
| `0x006621FC` | `procedure GroupSetDirectionViaAngleByHandle(grhandle: Integer; angle: Float)` |
| `0x00662440` | `procedure SetGroupMakeCollectingPointsByHandle(grhandle: integer; makecollectingpoints: boolean)` |
| `0x00662464` | `function GetGroupMakeCollectingPointsByHandle(grhandle: Integer): Boolean` |
| `0x00662488` | `procedure SetGroupCollectingPointsMinAngleByHandle(grhandle: integer; aminangle: Float)` |
| `0x006624AC` | `function GetGroupCollectingPointsMinAngleByHandle(grhandle: Integer): Float` |
| `0x006624D4` | `procedure SetGroupSmoothPointsStartByHandle(grhandle: integer; smoothpointsstart: boolean)` |
| `0x006624F8` | `function GetGroupSmoothPointsStartByHandle(grhandle: Integer): Boolean` |
| `0x0066251C` | `procedure SetGroupSmoothPointsEndByHandle(grhandle: integer; smoothpointsend: boolean)` |
| `0x00662540` | `function GetGroupSmoothPointsEndByHandle(grhandle: Integer): Boolean` |
| `0x00662564` | `procedure SetGroupUseArrowAngleByHandle(grhandle: integer; usearrowangle: boolean)` |
| `0x00662588` | `function GetGroupUseArrowAngleByHandle(grhandle: Integer): Boolean` |
| `0x006625AC` | `procedure SetGroupStretchFactorByHandle(grhandle: integer; stretchfactor: Float)` |
| `0x006625D0` | `function GetGroupStretchFactorByHandle(grhandle: Integer): Float` |
| `0x006625F8` | `procedure SetGroupCollisionPriorityByHandle(grhandle: integer; collisionpriority: Integer)` |
| `0x0066261C` | `function GetGroupCollisionPriorityByHandle(grhandle: Integer): Integer` |
| `0x00662644` | `procedure SetGroupTestPriorityOptionByHandle(grhandle: integer; tpo: String)` |
| `0x006626BC` | `function GetGroupTestPriorityOptionByHandle(grhandle: Integer): String` |
| `0x00662700` | `function GetGroupUncollidedPositionByHandle(grhandle: Integer; x: Float; y: Float; rad: Integer; var resx: Float; var resy: Float): Boolean` |
| `0x00662768` | `function GetGroupSTOHandleByHandle(grhandle: Integer): Integer` |
| `0x006627AC` | `procedure SetGroupSTOHandleByHandle(grhandle: Integer; stohandle: Integer)` |
| `0x0066280C` | `function GetGroupSTOTypeByHandle(grhandle: Integer): Integer` |
| `0x00662864` | `function GetGroupSTArrowAngleByHandle(grhandle: Integer): Float` |
| `0x00662894` | `procedure SetGroupSTArrowAngleByHandle(grhandle: Integer; angle: Float)` |
| `0x006628B4` | `function GetGroupStateCollectingCounterByHandle(grhandle: integer): Integer` |
| `0x006628D8` | `procedure SetGroupPriorityByHandle(priority: Integer; grhandle: Integer)` |
| `0x006628F8` | `function GetGroupPriorityByHandle(grhandle: Integer): Integer` |
| `0x00662918` | `procedure SetGroupCircularByHandle(grhandle: integer; circular: Boolean)` |
| `0x0066293C` | `function GetGroupCircularByHandle(grhandle: integer): Boolean` |
| `0x00662960` | `function GetGroupCircularBuildedByHandle(grhandle: integer): Boolean` |
| `0x00662984` | `function GetGroupBaseReflectedByHandle(grhandle: integer): Boolean` |
| `0x006629A8` | `function GetGroupFinalReflectedByHandle(grhandle: integer): Boolean` |
| `0x006629CC` | `function GetGroupTagByHandle(grhandle: Integer): Integer` |
| `0x006629F0` | `procedure SetGroupTagByHandle(grhandle: Integer; tag: Integer)` |
| `0x00662A14` | `function GetGroupRelativeQuarterExtByHandle(grhandle1: integer; grhandle2: integer; fov: Float): integer` |
| `0x00662A58` | `function GetGroupRelativeQuarterPointExtByHandle(grhandle: integer; x: Float; y: Float; fov: Float): integer` |
| `0x00662AB4` | `function GetGroupBoolValueByHandle(grhandle: Integer; const key: String): Boolean` |
| `0x00662ADC` | `procedure SetGroupBoolValueByHandle(grhandle: Integer; const key: String; value: Boolean)` |
| `0x00662B04` | `procedure SetGroupValueIndByHandle(grhandle: Integer; index: Integer; const value: String)` |
| `0x00662B2C` | `function GetGroupValueIndByHandle(grhandle: Integer; index: Integer): String` |
| `0x00662B58` | `function GetGroupIntValueIndByHandle(grhandle: Integer; index: Integer): Integer` |
| `0x00662B80` | `procedure SetGroupIntValueIndByHandle(grhandle: Integer; index: Integer; value: Integer)` |
| `0x00662BA8` | `function GetGroupFloatValueIndByHandle(grhandle: Integer; index: Integer): Float` |
| `0x00662BD4` | `procedure SetGroupFloatValueIndByHandle(grhandle: Integer; index: Integer; value: Float)` |
| `0x00662BFC` | `function GetGroupBoolValueIndByHandle(grhandle: Integer; index: Integer): Boolean` |
| `0x00662C28` | `procedure SetGroupBoolValueIndByHandle(grhandle: Integer; index: Integer; value: Boolean)` |
| `0x00662C50` | `function GetGroupKeyNameIndByHandle(grhandle: Integer; index: Integer): String` |
| `0x00662C7C` | `procedure SetGroupKeyNameIndByHandle(grhandle: Integer; index: Integer; const name: String)` |
| `0x00662CA4` | `procedure SetGroupCollidedStateNameByHandle(grhandle: Integer; const statename: String)` |
| `0x00662D24` | `procedure SetGroupUncollidedStateNameByHandle(grhandle: Integer; const statename: String)` |
| `0x00662DA4` | `procedure SetGroupCollisionStateNamesByHandle(grhandle: Integer; const collidedstatename: String; const uncollidedstatename: String)` |
| `0x00662E00` | `function GetGroupVarsCountByHandle(grhandle: Integer): Integer` |
| `0x00662E24` | `procedure SetGroupVarsCountByHandle(grhandle: Integer; count: Integer)` |
| `0x00663724` | `function GetGroupNameByHandle(grhandle: Integer): String` |
| `0x00663758` | `function GetGroupStringTagByHandle(grhandle: Integer): String` |
| `0x00663790` | `procedure SetGroupStringTagByHandle(grhandle: Integer; const tag: String)` |
| `0x00663814` | `procedure SetGroupNameByHandle(grhandle: Integer; const name: String)` |
| `0x0066383C` | `function GetGroupIndexByHandle(grhandle: Integer): Integer` |
| `0x00663860` | `function GetGroupEnemyGRHandleInAreaByHandle(grhandle: Integer; x: Float; y: Float; width: Float; height: Float): Integer` |
| `0x00663934` | `function GetGroupFriendGRHandleInAreaByHandle(grhandle: Integer; x: Float; y: Float; width: Float; height: Float): Integer` |
| `0x00663A14` | `procedure SetGroupCollisionDetectionByHandle(grhandle: Integer; collisiondetection: Boolean)` |
| `0x00663A64` | `function GroupGetAngleViaCentralDirectionByHandle(grhandle: Integer): Float` |
| `0x00663A94` | `function GroupGetInvertAngleViaCentralDirectionByHandle(grhandle: Integer): Float` |
| `0x00663AC4` | `function GroupGetAngleToGroup(grhandle: Integer; togrhandle: Integer): Float` |
| `0x00663B0C` | `procedure GroupInvertTurnPositionToGroupByHandle(grhandle: Integer; togrhandle: Integer; speed: Float; time: Float; var posx: Float; var posz: Float)` |
| `0x00663B94` | `procedure GroupTurnPositionToGroupByHandle(grhandle: Integer; togrhandle: Integer; speed: Float; time: Float; var posx: Float; var posz: Float)` |
| `0x00663C10` | `procedure GroupCalcEnemyGroupDataByHandle(grhandle: Integer; maxdist: Float)` |
| `0x00663C30` | `function GetGroupCountOfEnemyGroupByHandle(grhandle: Integer): Integer` |
| `0x00663C54` | `function GetGroupEnemyGroupDataHandleByHandle(grhandle: Integer; index: Integer): Integer` |
| `0x00663C84` | `function GetGroupEnemyGroupDataDistByHandle(grhandle: Integer; index: Integer): Float` |
| `0x00663CB4` | `function GetGroupEnemyGroupDataMyRQByHandle(grhandle: Integer; index: Integer): Integer` |
| `0x00663CE4` | `function GetGroupEnemyGroupDataHisRQByHandle(grhandle: Integer; index: Integer): Integer` |
| `0x00663D14` | `procedure GroupCalcFriendGroupDataByHandle(grhandle: Integer; maxdist: Float)` |
| `0x00663D34` | `function GetGroupCountOfFriendGroupByHandle(grhandle: Integer): Integer` |
| `0x00663D58` | `function GetGroupFriendGroupDataHandleByHandle(grhandle: Integer; index: Integer): Integer` |
| `0x00663D88` | `function GetGroupFriendGroupDataDistByHandle(grhandle: Integer; index: Integer): Float` |
| `0x00663DB8` | `function GetGroupFriendGroupDataMyRQByHandle(grhandle: Integer; index: Integer): Integer` |
| `0x00663DE8` | `function GetGroupFriendGroupDataHisRQByHandle(grhandle: Integer; index: Integer): Integer` |
| `0x00663E18` | `procedure SetGroupVisibleByHandle(grhandle: Integer; visible: Boolean)` |
| `0x00663E38` | `function GetGroupVisibleByHandle(grhandle: Integer): Boolean` |
| `0x00663E5C` | `function GetGroupDirectPathToGroup(grhandle: Integer; togrhandle: Integer): Boolean` |
| `0x00663E98` | `function GetGroupFastDistanceToGroupByHandle(grhandle: Integer; togrhandle: Integer): Float` |
| `0x00663EE0` | `function GetGroupFriendGroupBetweenGroupByHandle(grhandle: Integer; togrhandle: Integer): Integer` |
| `0x00663F28` | `function GetGroupFriendGroupBetweenGroupLineByHandle(grhandle: Integer; togrhandle: Integer): Integer` |
| `0x00663F70` | `function GetGroupFriendGroupBetweenGroupInMyFOVByHandle(grhandle: Integer; togrhandle: Integer; aFOV: Float): Integer` |
| `0x00663FBC` | `function GetEnemyGroupBetweenGroupByHandle(grhandle: Integer; togrhandle: Integer): Integer` |
| `0x00664004` | `function GetEnemyGroupBetweenGroupLineByHandle(grhandle: Integer; togrhandle: Integer): Integer` |
| `0x0066404C` | `function GetEnemyGroupBetweenGroupInMyFOVByHandle(grhandle: Integer; togrhandle: Integer; afov: Float): Integer` |
| `0x00664098` | `function GetGroupBetweenCoordsHandle(grhandle: Integer; startx, startz, endx, endz: Float): Integer` |
| `0x006640F4` | `function GetGroupMinDistIndexToEnemyGroupByHandle(grhandle: Integer): Integer` |
| `0x00664118` | `function GetGroupMinDistToEnemyGroupByHandle(grhandle: Integer): Float` |
| `0x00664148` | `function GetGroupMinDistHandleToEnemyGroupByHandle(grhandle: Integer): Integer` |
| `0x00664174` | `function GetGroupMinDistIndexToFriendGroupByHandle(grhandle: Integer): Integer` |
| `0x00664198` | `function GetGroupMinDistToFriendGroupByHandle(grhandle: Integer): Float` |
| `0x006641C8` | `function GetGroupMinDistHandleToFriendGroupByHandle(grhandle: Integer): Integer` |
| `0x006641F4` | `function GetGroupGridChangedByHandle(grhandle: Integer): Boolean` |
| `0x00664218` | `procedure GroupGetCenterFirstRowByHandle(grhandle: Integer; var x: Float; var z: Float)` |
| `0x00664264` | `procedure GroupGetCenterLastRowByHandle(grhandle: Integer; var x: Float; var z: Float)` |
| `0x006642B0` | `procedure GroupGetCenterFirstColByHandle(grhandle: Integer; var x: Float; var z: Float)` |
| `0x006642FC` | `procedure GroupGetCenterLastColByHandle(grhandle: Integer; var x: Float; var z: Float)` |
| `0x00664348` | `function GetGroupInFrontOfGroupByHandle(grhandle: Integer; togrhandle: Integer): Boolean` |
| `0x00664384` | `function GetGroupFriendCountInQuarterByHandle(grhandle: Integer; dist: Float; rq: Integer): Integer` |
| `0x006643AC` | `function GetGroupEnemyCountInQuarterByHandle(grhandle: Integer; dist: Float; rq: Integer): Integer` |
| `0x006643D4` | `function GetGroupNearestFriendIndexInQuarterByHandle(grhandle: Integer; dist: Float; rq: Integer): Integer` |
| `0x006643FC` | `function GetGroupNearestEnemyIndexInQuarterByHandle(grhandle: Integer; dist: Float; rq: Integer): Integer` |
| `0x00664424` | `function GetGroupNearestFriendIndexInDistByHandle(grhandle: Integer; dist: Float): Integer` |
| `0x0066444C` | `function GetGroupNearestEnemyIndexInDistByHandle(grhandle: Integer; dist: Float): Integer` |
| `0x00664474` | `function GetGroupExistFriendInDistByHandle(grhandle: Integer; dist: Float): Boolean` |
| `0x00664498` | `function GetGroupExistEnemyInDistByHandle(grhandle: Integer; dist: Float): Boolean` |
| `0x006644BC` | `function GetGroupExistFriendInQuarterByHandle(grhandle: Integer; dist: Float; rq: Integer): Boolean` |
| `0x006644E4` | `function GetGroupExistEnemyInQuarterByHandle(grhandle: Integer; dist: Float; rq: Integer): Boolean` |
| `0x0066450C` | `function GetGroupNearestEnemyIndexInFrontByHandle(grhandle: Integer; dist: Float): Integer` |
| `0x00664534` | `procedure SetGroupHDefragHoleMode(grhandle: Integer; mode: Boolean)` |
| `0x00664580` | `procedure SetGroupVDefragHoleMode(grhandle: Integer; mode: Boolean)` |
| `0x006645CC` | `procedure SetGroupHDefragBalanceMode(grhandle: Integer; mode: Boolean)` |
| `0x00664618` | `procedure SetGroupVDefragBalanceMode(grhandle: Integer; mode: Boolean)` |
| `0x00664664` | `procedure GetGroupDefragHoleModes(grhandle: Integer; var h: Boolean; var v: Boolean)` |
| `0x006646A8` | `procedure GetGroupDefragBalanceModes(grhandle: Integer; var h: Boolean; var v: Boolean)` |
| `0x006646EC` | `function GetGroupMaxHoleHorizontal(grhandle: Integer): Integer` |
| `0x00664710` | `function GetGroupMaxHoleVertical(grhandle: Integer): Integer` |
| `0x00664734` | `function GetGroupMaxUnbalanceHorizontal(grhandle: Integer): Integer` |
| `0x00664758` | `function GetGroupMaxUnbalanceVertical(grhandle: Integer): Integer` |
| `0x0066477C` | `procedure GetGroupEvadeFromGroupByHandle(grhandle: Integer; fromgrhandle: Integer; maxevadedist: Float; var x: Float; var z: Float)` |
| `0x006647E0` | `function GetGroupAdditingModeByHandle(grhandle: Integer): Boolean` |
| `0x00664804` | `procedure SetGroupAdditingModeByHandle(grhandle: Integer; additingmode: Boolean)` |
| `0x00664828` | `function GetGroupNearestEnemyIndexInMyFrontByHandle(grhandle: Integer; dist: Float): Integer` |
| `0x00664850` | `procedure GetGroupComeToGroupByHandle(grhandle: Integer; togrhandle: Integer; maxcomedist: Float; var x: Float; var z: Float)` |
| `0x006648A8` | `procedure GetGroupComeToGroupNoTestByHandle(grhandle: Integer; togrhandle: Integer; maxcomedist: Float; var x: Float; var z: Float)` |
| `0x00664900` | `function GetGroupCCDirToPosByHandle(grhandle: Integer): Boolean` |
| `0x00664924` | `procedure SetGroupCCDirToPosByHandle(grhandle: Integer; ccdirtopos: Boolean)` |
| `0x0066496C` | `function GetGroupPositionChangedByHandle(grhandle: Integer): Boolean` |
| `0x00664990` | `procedure GetGroupCenterDirectionByHandle(grhandle: Integer; var x: Float; var y: Float; var z: Float)` |
| `0x006649D8` | `procedure SetGroupTagControlByHandle(grhandle: Integer; tagcontrol: Integer)` |
| `0x006649F8` | `function GetGroupTagControlByHandle(grhandle: Integer): Integer` |
| `0x00664A18` | `function GetGroupArmyIndexByHandle(grhandle: Integer): Integer` |
| `0x00664A3C` | `procedure SetGroupCancelCollectingByHandle(grhandle: Integer)` |
| `0x00664A5C` | `procedure SetGroupOnStateCollectingPointReachedByHandle(grhandle: Integer; const state: String)` |
| `0x00664A88` | `procedure SetGroupStretchBrushMatName(grhandle: Integer; const matname: String)` |
| `0x00664AF4` | `function GetGroupStretchBrushMatName(grhandle: Integer): String` |
| `0x00664B6C` | `function GetGroupDirectVisibleGroupByHandle(grhandle1: Integer; grhandle2: Integer; offset: Float; priority: integer): Boolean` |
| `0x00664BAC` | `function GetGroupCheckLineToGroup(grhandle1: Integer; grhandle2: Integer; priority: integer): Boolean` |
| `0x00664BEC` | `procedure SetGroupFlagmanHandleByHandle(grhandle: Integer; gohandle: Integer)` |
| `0x00664C20` | `function GetGroupFlagmanHandleByHandle(grhandle: Integer): Integer` |
| `0x00664C44` | `procedure GetGroupsListInArea(x: Float; y: Float; width: Float; height: Float)` |
| `0x00664CC8` | `function GetGroupsListCount: Integer` |
| `0x00664CD4` | `function GetGroupsListGroupHandleByIndex(aindex: Integer): Integer` |
| `0x00664D0C` | `function GetGroupIntersectionKoefByHandle(grhandle: Integer): Float` |
| `0x00664D3C` | `procedure SetGroupIntersectionKoefByHandle(grhandle: Integer; akoef: Float)` |
| `0x00664D60` | `procedure GroupExecuteStateForCirclesByHandle(grhandle: Integer; const state: String)` |
| `0x00664EA0` | `procedure SetGroupExtPointsBuild(grhandle: Integer; avalue: Boolean)` |
| `0x00664EC4` | `procedure SetGroupExtPointsMinDist(grhandle: Integer; avalue: Float)` |
| `0x00664EE8` | `procedure SetGroupExtPointsMaxDist(grhandle: Integer; avalue: Float)` |
| `0x00664F0C` | `procedure SetGroupExtPointsAngle(grhandle: Integer; avalue: Float)` |
| `0x00664F30` | `function GetGroupExtPointsBuild(grhandle: Integer): Boolean)` |
| `0x00664F54` | `function GetGroupExtPointsMinDist(grhandle: Integer): Float)` |
| `0x00664F84` | `function GetGroupExtPointsMaxDist(grhandle: Integer): Float)` |
| `0x00664FB4` | `function GetGroupExtPointsAngle(grhandle: Integer): Float)` |
| `0x00664FE4` | `function GetGroupStretchBrushTrackMode(grhandle: Integer): Boolean` |
| `0x00665008` | `procedure GroupAddTrackPosition(grhandle: Integer)` |
| `0x00665028` | `procedure GroupClearTrackPosition(grhandle: Integer)` |
| `0x00665048` | `function GroupGetTrackPositionByIndex(grhandle: Integer; aindex: Integer; var ax, az: Float): Boolean` |
| `0x006650B0` | `function GroupGetTrackAngleByIndex(grhandle: Integer; aindex: Integer; var aangle: Float): Boolean` |
| `0x006650E8` | `function GroupGetTrackColsByIndex(grhandle: Integer; aindex: Integer; var acols: Integer): Boolean` |
| `0x00665120` | `function GroupGetTrackPositionCount(grhandle: Integer): Integer` |
| `0x00665144` | `procedure GroupDeleteTrackByIndex(grhandle: Integer; aindex: Integer)` |
| `0x00665164` | `function GetGroupIsTrackMode(grhandle: Integer): Boolean` |
| `0x00665190` | `procedure GetGroupTrackTargetProp(grhandle: Integer; var ax, az: Float; var aangle: Float; var acols: Integer)` |
| `0x00665260` | `procedure GetGroupRetreatVector(grhandle: Integer; radius, retreatdistance: Float; var x,y,z: Float)` |
| `0x006652C0` | `procedure GroupRebuildCmds(grhandle: Integer)` |
| `0x006652E0` | `function GetGroupActionsCount(grhandle: Integer):Integer` |
| `0x00665304` | `procedure GroupActionRemoveByIndex(grhandle: Integer; aaction: Integer)` |
| `0x00665324` | `procedure GroupActionsClear(grhandle: Integer)` |
| `0x00665344` | `function GetGroupActionValueByName(grhandle: Integer; aaction: Integer; const aname: String):String` |
| `0x00665390` | `function GetGroupActionIntValueByName(grhandle: Integer; aaction: Integer; const aname: String):Integer` |
| `0x006653EC` | `function GetGroupActionBoolValueByName(grhandle: Integer; aaction: Integer; const aname: String):Boolean` |
| `0x00665448` | `function GetGroupActionFloatValueByName(grhandle: Integer; aaction: Integer; const aname: String):Float` |
| `0x006654B0` | `procedure SetGroupActionValueByName(grhandle: Integer; aaction: Integer; const aname: String; avalue :String)` |
| `0x00665514` | `procedure SetGroupActionIntValueByName(grhandle: Integer; aaction: Integer; const aname: String; avalue :Integer)` |
| `0x0066556C` | `procedure SetGroupActionBoolValueByName(grhandle: Integer; aaction: Integer; const aname: String; avalue :Boolean)` |
| `0x006655C4` | `procedure SetGroupActionFloatValueByName(grhandle: Integer; aaction: Integer; const aname: String; avalue :Float)` |
| `0x00665620` | `function GetGroupEndPointsCount(grhandle: Integer): Integer` |
| `0x006656A0` | `procedure SetGroupAlignmentToFlagmanByHandle(grhandle: Integer; aenabled: Boolean)` |
| `0x006656C4` | `function GetGroupAlignmentToFlagmanByHandle(grhandle: Integer): Boolean` |
| `0x006656E8` | `procedure SetGroupCollectingIndexByHandle(grhandle: Integer; aindex: Integer)` |
| `0x00665708` | `function GetGroupCollectingIndexByHandle(grhandle: Integer): Integer` |
| `0x00665730` | `function GetGroupUnitsMinMaxDistanceByHandle(grhandle: Integer; var amin, amax: Float): Boolean` |
| `0x006657A0` | `procedure CalcGroupUnitsMinMaxDistanceByHandle(grhandle: Integer; var amin, amax: Float)` |
| `0x006658A0` | `procedure GroupResetLastTimeFastCalcCentralPosition(grhandle: Integer)` |
| `0x006658C0` | `procedure GroupCalcCentralDirectionByHandle(grhandle: Integer)` |
| `0x006658E0` | `procedure GroupCalcCentralPositionAndDirection(grhandle: Integer)` |
| `0x00665900` | `function GetGroupControlModeIntByHandle(grhandle: Integer): Integer` |
| `0x0066592C` | `procedure DoGroupProcLogic0(grhandle, grattackhandle: Integer; const state: String)` |
| `0x00665A54` | `function GetGroupBVRayCastIntersectedByHandle(grhandle: Integer): Integer` |
| `0x00665A78` | `function GetGroupDelayExecuteStateNameByHandle(grhandle: Integer): String` |
| `0x00665ABC` | `procedure GroupDelayExecuteStateByHandle(grhandle: Integer; const state: String; ftime: Float)` |
| `0x00665B58` | `procedure GroupCancelDelayExecuteStateByHandle(grhandle: Integer)` |
| `0x00665B78` | `procedure GroupSetStaticGridByHandle(grhandle: Integer; staticgrid: Boolean)` |
| `0x00665B9C` | `function GroupGetStaticGridByHandle(grhandle: Integer): Boolean` |
| `0x00665BC0` | `procedure GroupWidthReflectByHandle(grhandle: Integer)` |
| `0x00665BE0` | `procedure GroupHeightReflectByHandle(grhandle: Integer)` |
| `0x00665C00` | `function GetGroupIDByHandle(grhandle: Integer): Integer` |
| `0x00665C48` | `procedure SetGroupNoRebuildCmdsByHandle(grhandle: Integer; val: Boolean)` |
| `0x00665C6C` | `function GetGroupNoRebuildCmdsByHandle(grhandle: Integer): Boolean` |
| `0x00685828` | `function GetRecordGroupEnabled: Boolean` |
| `0x0068583C` | `procedure SetRecordGroupEnabled(const val: Boolean)` |
| `0x0068AB04` | `function GetTrackNodesCountByGroup(const agroup : String) : Integer` |
| `0x006951B4` | `procedure ApplyGroupStretchBrush(grhandle: Integer)` |
| `0x00699ACC` | `function SLogicFrmRotateGetMaxGroupsDist: Float` |
| `0x00699B00` | `procedure SLogicFrmRotateSetMaxGroupsDist(avalue: Float)` |
| `0x00699B2C` | `function SLogicFrmRotateGetMaxGroupsAngle: Float` |
| `0x00699B60` | `procedure SLogicFrmRotateSetMaxGroupsAngle(avalue: Float)` |
| `0x006AA014` | `function GetAIRegionCountOfGroups(const name: String): Integer` |
| `0x006AA0B0` | `function GetAIRegionGroupNameByGroupIndex(const name: String; groupindex: Integer): String` |
| `0x006AA110` | `function GetAIRegionGRHandleByGroupIndex(const name: String; groupindex: Integer): Integer` |
| `0x006AA224` | `function GetAIRegionGroupExists(const name: String; const playername: String): Boolean` |
| `0x006AA264` | `function GetAIRegionGroupExists2(const name: String; const playername: String; const groupname: String): Boolean` |
| `0x006AA2A8` | `function GetAIRegionGroupIndex(const name: String; const playername: String; const groupname: String): Integer` |
| `0x006AB320` | `function GetStretchGridValueByGroupHandle(grhandle, row, col: Integer): Boolean` |
| `0x006AB3FC` | `procedure SetStretchGridValueByGroupHandle(grhandle, row, col: Integer; val: Boolean)` |
| `0x006AB5E4` | `function GetUserStretchGroupsCount: Integer` |
| `0x006AB5FC` | `function GetUserStretchGroupByIndex(index: integer): Integer` |
| `0x006AB734` | `procedure DeleteUserStretchGroupByGroupHandle(grhandle: Integer)` |
| `0x006AB7B0` | `procedure UserStretchGroupsCopyToTemporary()` |
| `0x006AF0A4` | `function GetAIRegionCountOfGroupsByHandle(const reghnd: Integer): Integer` |
| `0x006AF0C8` | `function GetAIRegionGRHandleByGroupIndexByHandle(const reghnd: Integer; groupindex: Integer): Integer` |
| `0x006B6534` | `procedure TopologyAddPathGroupByHandle(grhandle: Integer)` |
| `0x006B657C` | `procedure TopologyClearPathGroups` |
| `0x006BBABC` | `procedure SetSndSoundGroup(value: Integer; sound: Integer)` |
| `0x006BBAD4` | `function GetSndSoundGroup(sound: Integer): Integer` |
| `0x006C5304` | `function GetGroupStateMachineHandle(const grhnd: Integer): Integer` |
| `0x006E9E3C` | `function ParserSelectGroup(const grhandle: Integer): Integer` |
| `0x006E9F38` | `function ParserCreateGroup(const grhandle: Integer): Integer` |
| `0x006EA014` | `procedure ParserFreeGroup(const grhandle: Integer)` |

### Player — 284

| VA | Объявление |
|---|---|
| `0x005FAD24` | `procedure EditorPlayerImportFromFile(const cplayername, cfilename : String)` |
| `0x005FAD58` | `procedure EditorPlayerExportToFile(const cplayername, cfilename : String)` |
| `0x005FAD80` | `procedure EditorPlayerArmiesImportFromFile(const cplayername, cfilename : String)` |
| `0x005FADA8` | `procedure EditorPlayerArmiesExportToFile(const cplayername, cfilename : String)` |
| `0x0060DE24` | `function IsPlayerByHandle(plhandle: Integer): Boolean` |
| `0x00660F34` | `function GetGRHandleByPlayerHandleByIndex(playerhandle: Integer; groupindex: Integer): Integer` |
| `0x00661078` | `function GetGroupCurrentPlayerName(): String` |
| `0x00662A8C` | `function GetGroupPlayerHandleByHandle(grhandle: integer): integer` |
| `0x00685404` | `function LanMyInfoPlayer: String` |
| `0x006856AC` | `function LanGetClientPlayerNameByIndex(aindex: Integer): String` |
| `0x0068570C` | `procedure LanSetClientPlayerNameByIndex(aindex: Integer; const aname: String)` |
| `0x00694108` | `function GetPlayerEnabled(const playername: String): Boolean` |
| `0x00694140` | `procedure SetPlayerEnabled(const playername: String; enabled: Boolean)` |
| `0x00694178` | `function GetPlayerStatic(const playername: String): Boolean` |
| `0x006941B0` | `procedure SetPlayerStatic(const playername: String; Static: Boolean)` |
| `0x006941E8` | `procedure SetPlayerValueByHandle(plhandle: Integer; const key: String; const value: String)` |
| `0x00694210` | `function GetPlayerValueByHandle(plhandle: Integer; const key: String): String` |
| `0x00694248` | `procedure SetPlayerIntValueByHandle(plhandle: Integer; const key: String; value: Integer)` |
| `0x00694270` | `function GetPlayerIntValueByHandle(plhandle: Integer; const key: String): Integer` |
| `0x00694298` | `procedure SetPlayerFloatValueByHandle(plhandle: Integer; const key: String; value: Float)` |
| `0x006942C0` | `function GetPlayerFloatValueByHandle(plhandle: Integer; const key: String): Float` |
| `0x006942F4` | `function GetPlayerBoolValueByHandle(plhandle: Integer; const key: String): Boolean` |
| `0x0069431C` | `procedure SetPlayerBoolValueByHandle(plhandle: Integer; const key: String; value: Boolean)` |
| `0x00694344` | `procedure SetPlayerValueIndByHandle(plhandle: Integer; index: Integer; const value: String)` |
| `0x0069436C` | `function GetPlayerValueIndByHandle(plhandle: Integer; index: Integer): String` |
| `0x006943A4` | `function GetPlayerIntValueIndByHandle(plhandle: Integer; index: Integer): Integer` |
| `0x006943CC` | `procedure SetPlayerIntValueIndByHandle(plhandle: Integer; index: Integer; value: Integer)` |
| `0x006943F4` | `function GetPlayerFloatValueIndByHandle(plhandle: Integer; index: Integer): Float` |
| `0x00694428` | `procedure SetPlayerFloatValueIndByHandle(plhandle: Integer; index: Integer; value: Float)` |
| `0x00694450` | `function GetPlayerBoolValueIndByHandle(plhandle: Integer; index: Integer): Boolean` |
| `0x00694478` | `procedure SetPlayerBoolValueIndByHandle(plhandle: Integer; index: Integer; value: Boolean)` |
| `0x006944A0` | `procedure PlayerExecuteStateByHandle(plhandle: Integer; const state: String)` |
| `0x006944FC` | `function GetPlayerControlMode(const playername: String): String` |
| `0x0069454C` | `procedure SetPlayerControlMode(const playername: String; const controlmode: String)` |
| `0x00694590` | `function GetPlayerControlModeByHandle(plhandle: Integer): String` |
| `0x006945C8` | `procedure SetPlayerControlModeByHandle(plhandle: Integer; const controlmode: String)` |
| `0x006945F8` | `function GetPlayerControlModeIntByHandle(plhandle: Integer): Integer` |
| `0x00694618` | `procedure SetPlayerControlModeIntByHandle(plhandle: Integer; controlmode: Integer)` |
| `0x00694814` | `function GetPlayerNameByIndex(playerindex: Integer): String` |
| `0x00694860` | `procedure SetPlayerNameByIndex(playerindex: Integer; const newplayername: String)` |
| `0x006948A0` | `function GetPlayerHandleByIndex(playerindex: Integer): Integer` |
| `0x006948D4` | `function GetPlayerControlModeByIndex(playerindex: Integer): String` |
| `0x00694920` | `function GetCountOfPlayers(): Integer` |
| `0x00694944` | `function GetPlayerNameByControlMode(const controlmode: String): String` |
| `0x006949C4` | `function GetPlayerNameInterfaceIO(): String` |
| `0x00694A08` | `function GetPlayerHandleInterfaceIO(): Integer` |
| `0x00694A2C` | `function GetPlayerIndexInterfaceIO(): Integer` |
| `0x00694A58` | `procedure SetPlayerHandleInterfaceIO(const plhandle: Integer)` |
| `0x00694A88` | `function CreatePlayer(const playername, racename, controlmode: String): Integer` |
| `0x00694AE0` | `function CreatePlayerFirst(const playername, racename, controlmode: String): Integer` |
| `0x00694B38` | `function CreatePlayerInsert(const playername, racename, controlmode: String; const index: Integer): Integer` |
| `0x00694B98` | `procedure ExchangePlayerIndex(const index1, index2: Integer)` |
| `0x00694C50` | `procedure ClearPlayers()` |
| `0x00694C64` | `function GetIsEnemyPlayers(const playername1: String; const playername2: String): Boolean` |
| `0x00694CB8` | `function GetIsFriendPlayers(const playername1: String; const playername2: String): Boolean` |
| `0x00694D0C` | `function GetIsFriendPlayersByHandle(playerhandle1: Integer; playerhandle2: Integer): Boolean` |
| `0x00694D54` | `function GetIsEnemyPlayersByHandle(playerhandle1: Integer; playerhandle2: Integer): Boolean` |
| `0x00694E68` | `function GetCurrentPlayerName(): String` |
| `0x00694EA0` | `function GetPlayerCountOfEnemyPlayers(const playername: String): Integer` |
| `0x00694EC8` | `function GetPlayerCountOfEnemyPlayersByHandle(playerhandle: Integer): Integer` |
| `0x00694EFC` | `function GetEnemyPlayerNameByIndex(const playername: String; index: Integer): String` |
| `0x00694F50` | `function GetEnemyPlayerHandleByIndex(playerhandle: Integer; index: Integer): Integer` |
| `0x00694FB4` | `function GetPlayerCountOfFriendPlayersByHandle(playerhandle: Integer): Integer` |
| `0x00694FD8` | `function GetFriendPlayerHandleByIndex(playerhandle: Integer; index: Integer): Integer` |
| `0x0069503C` | `function GetPlayerHandleByName(const playername: String): Integer` |
| `0x00695058` | `procedure SetPlayerStretchBrushRowsCount(plhandle: Integer; count: Integer)` |
| `0x0069507C` | `function GetPlayerStretchBrushRowsCount(plhandle: Integer): Integer` |
| `0x006950A0` | `procedure SetPlayerStretchBrushRowPriority(plhandle: Integer; row: Integer; priority: Integer)` |
| `0x006950C8` | `procedure AddPlayerStretchBrushGroupHandle(grhandle: Integer)` |
| `0x0069510C` | `procedure SetPlayerStretchBrushGroupHandle(grhandle: Integer)` |
| `0x00695148` | `procedure ClearPlayerStretchBrushGroups(plhandle: Integer)` |
| `0x00695168` | `procedure ApplyPlayerStretchBrush(plhandle: Integer)` |
| `0x006951D4` | `procedure SetPlayerStretchBrushCompleted(plhandle: Integer; value: Boolean)` |
| `0x006951F8` | `procedure PlayerStretchBrushRayTrace(plhandle: Integer)` |
| `0x00695228` | `function GetPlayerStretchBrushGroupHandleByIndex(plhandle: Integer; index: Integer): Integer` |
| `0x00695270` | `function GetPlayerStretchBrushCompleted(plhandle: Integer): Boolean` |
| `0x00695294` | `function GetPlayerStretchBrushGroupsCount(plhandle: Integer): Integer` |
| `0x006952B8` | `function GetPlayerStretchBrushGroupCols(grhandle: Integer): Integer` |
| `0x006952E0` | `function GetPlayerStretchBrushGroupRows(grhandle: Integer): Integer` |
| `0x00695304` | `function GetPlayerStretchBrushGroupTargetAngle(grhandle: Integer): Float` |
| `0x00695334` | `function GetPlayerStretchBrushGroupTargetPositionX(grhandle: Integer): Float` |
| `0x00695364` | `function GetPlayerStretchBrushGroupTargetPositionY(grhandle: Integer): Float` |
| `0x00695394` | `procedure SetPlayerStretchBrushGroupCols(grhandle: Integer; cols: Integer)` |
| `0x006953B8` | `procedure SetPlayerStretchBrushGroupTargetAngle(grhandle: Integer; angle: Float)` |
| `0x0069541C` | `procedure SetPlayerStretchBrushGroupTargetPosition(grhandle: Integer; x: Float; z: Float)` |
| `0x00695468` | `procedure SetPlayerStretchBrushGroupWallMode(grhandle: Integer; aval: Boolean)` |
| `0x0069548C` | `function GetPlayerStretchBrushGroupWallMode(grhandle: Integer): Boolean` |
| `0x006954B0` | `procedure SetPlayerStretchBrushAdditiveMode(plhandle: Integer; aval: Boolean)` |
| `0x006954D4` | `function GetPlayerStretchBrushAdditiveMode(plhandle: Integer): Boolean` |
| `0x006954F8` | `function ProcessPlayerSLogicFrmClassicDefence(plhandle: Integer; posx: Float; posy: Float; usedirection: Boolean; dirx: Float; diry: Float): Boolean` |
| `0x006955F0` | `function ProcessPlayerSLogicFrmClassicAttack(plhandle: Integer; posx: Float; posy: Float; usedirection: Boolean; dirx: Float; diry: Float): Boolean` |
| `0x006956E8` | `function ProcessPlayerSLogicFrmDeepDefence(plhandle: Integer; posx: Float; posy: Float; usedirection: Boolean; dirx: Float; diry: Float): Boolean` |
| `0x006957E0` | `function ProcessPlayerSLogicFrmDeepAttack(plhandle: Integer; posx: Float; posy: Float; usedirection: Boolean; dirx: Float; diry: Float): Boolean` |
| `0x006958D8` | `function ProcessPlayerSLogicFrmRightFlankDefence(plhandle: Integer; posx: Float; posy: Float; usedirection: Boolean; dirx: Float; diry: Float): Boolean` |
| `0x006959D0` | `function ProcessPlayerSLogicFrmRightFlankAttack(plhandle: Integer; posx: Float; posy: Float; usedirection: Boolean; dirx: Float; diry: Float): Boolean` |
| `0x00695AC8` | `function ProcessPlayerSLogicFrmLeftFlankDefence(plhandle: Integer; posx: Float; posy: Float; usedirection: Boolean; dirx: Float; diry: Float): Boolean` |
| `0x00695BC0` | `function ProcessPlayerSLogicFrmLeftFlankAttack(plhandle: Integer; posx: Float; posy: Float; usedirection: Boolean; dirx: Float; diry: Float): Boolean` |
| `0x00695CB8` | `function ProcessPlayerSLogicFrmLine(plhandle: Integer; posx: Float; posy: Float; usedirection: Boolean; dirx: Float; diry: Float): Boolean` |
| `0x00695DB0` | `function ProcessPlayerSLogicFrmPoint(plhandle: Integer; posx: Float; posy: Float; usedirection: Boolean; dirx: Float; diry: Float): Boolean` |
| `0x00695EA8` | `function ProcessPlayerSLogicFrmPointDot(plhandle: Integer; posx: Float; posy: Float): Boolean` |
| `0x00695F38` | `function ProcessPlayerSLogicFrmAntiCover(plhandle: Integer): Boolean` |
| `0x00695F74` | `function ProcessPlayerStretchBrushLogicLines(plhandle: Integer; fromx: Float; fromy: Float; tox: Float; toy: Float): Boolean` |
| `0x0069603C` | `procedure ProcessPlayerSLogicFrmRotate(plhandle: Integer; posx: Float; posy: Float; dirx: Float; diry: Float; changepos: Boolean)` |
| `0x006960C0` | `procedure SetPlayersStretchBrushesMinDistance(mindistance: Float)` |
| `0x006961CC` | `procedure PlayerCastCubes2d6ByHandle(playerhandle: Integer)` |
| `0x006961F8` | `function GetPlayerFirstCubeByHandle(playerhandle: Integer): Integer` |
| `0x00696228` | `function GetPlayerSecondCubeByHandle(playerhandle: Integer): Integer` |
| `0x00696258` | `function GetPlayerCubeRandomValue(playerhandle: Integer): Float` |
| `0x006962C8` | `function GetPlayerNameByHandle(plhandle: Integer): String` |
| `0x006962FC` | `function GetPlayerIndexByHandle(plhandle: Integer): Integer` |
| `0x00696324` | `procedure PlayerCalcGroupsInArmiesByHandle(plhandle: Integer; enemyarmies: Boolean)` |
| `0x00696354` | `procedure PlayerCalcRectanglesInArmiesByHandle(plhandle: Integer; enemyarmies: Boolean)` |
| `0x00696388` | `procedure PlayerCalcRectangleInArmyByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean)` |
| `0x006963C0` | `procedure PlayerCalcRectanglesInArmiesExtByHandle(plhandle: Integer; enemyarmies: Boolean; usedirection: Boolean)` |
| `0x006963F8` | `procedure PlayerCalcRectangleInArmyExtByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; usedirection: Boolean)` |
| `0x00696434` | `function GetPlayerArmyDistanceByHandle(plhandle: Integer; armyindex: Integer; toplhandle: Integer; toarmyindex: Integer): Float` |
| `0x00696488` | `function GetPlayerArmyRelativeQuarterByHandle(plhandle: Integer; armyindex: Integer; toplhandle: Integer; toarmyindex: Integer; fov: Float): Integer` |
| `0x006964D8` | `function GetPlayerArmyRelativeQuarterToGroupByHandle(plhandle: Integer; armyindex: Integer; togrhandle: Integer; fov: Float; enemyarmy: Boolean): Integer` |
| `0x00696540` | `function GetPlayerArmyIndexOfNameByHandle(plhandle: Integer; const name: String; enemyarmy: Boolean): Integer` |
| `0x006965C0` | `function GetPlayerArmyNameOfIndex(plhandle, armyindex: Integer; enemyarmy: Boolean): String` |
| `0x00696624` | `function GetPlayerArmiesCountByHandle(plhandle: Integer; enemyarmies: Boolean): Integer` |
| `0x00696658` | `function GetPlayerGroupsCountInArmyByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean): Integer` |
| `0x00696690` | `function GetPlayerGRHandleInArmyByHandle(plhandle: Integer; armyindex: Integer; groupindex: Integer; enemyarmy: Boolean): Integer` |
| `0x006966E4` | `procedure PlayerRemoveGroupFromArmyByHandle(plhandle: Integer; armyindex: Integer; groupindex: Integer; enemyarmy: Boolean)` |
| `0x0069673C` | `procedure GetPlayerArmyDirectionToArmyByHandle(plhandle: Integer; armyindex: Integer; toplhandle: Integer; toarmyindex: Integer; var dirx: Float; var diry: Float; var angle: Float)` |
| `0x00696868` | `procedure GetPlayerArmyDirectionToGroupByHandle(plhandle: Integer; armyindex: Integer; togrhandle: Integer; enemyarmy: Boolean; var dirx: Float; var diry: Float; var angle: Float)` |
| `0x006969D0` | `procedure GetPlayerArmyPositionByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; var posx: Float; var posy: Float)` |
| `0x00696A3C` | `function GetPlayerArmyWidthByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean): Float` |
| `0x00696AAC` | `function GetPlayerArmyHeightByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean): Float` |
| `0x00696B1C` | `procedure GetPlayerArmyDirectionByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; var dirx: Float; var diry: Float)` |
| `0x00696B70` | `function GetPlayerArmyValueByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; const name: String): String` |
| `0x00696C0C` | `procedure SetPlayerArmyValueByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; const name: String; const value: String)` |
| `0x00696CB0` | `function GetPlayerArmyIntValueByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; const name: String): Integer` |
| `0x00696D5C` | `procedure SetPlayerArmyIntValueByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; const name: String; value: Integer)` |
| `0x00696E00` | `function GetPlayerArmyFloatValueByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; const name: String): Float` |
| `0x00696EB8` | `procedure SetPlayerArmyFloatValueByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; const name: String; value: Float)` |
| `0x00696F6C` | `procedure SetPlayerArmyValueIndByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; index: Integer; const value: String)` |
| `0x00697000` | `function GetPlayerArmyValueIndByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; index: Integer): String` |
| `0x00697064` | `function GetPlayerArmyIntValueIndByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; index: Integer): Integer` |
| `0x006970FC` | `procedure SetPlayerArmyIntValueIndByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; index: Integer; value: Integer)` |
| `0x00697194` | `function GetPlayerArmyFloatValueIndByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; index: Integer): Float` |
| `0x00697240` | `procedure SetPlayerArmyFloatValueIndByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; index: Integer; value: Float)` |
| `0x006972E8` | `function GetPlayerArmyDirectPathToArmy(plhandle: Integer; armyindex: Integer; toplhandle: Integer; toarmyindex: Integer): Boolean` |
| `0x00697330` | `function GetPlayerCurrentPlHandle(): Integer` |
| `0x0069734C` | `function GetPlayersInitialArmyDist(): Float` |
| `0x00697370` | `procedure SetPlayersInitialArmyDist(value: Float)` |
| `0x00697390` | `function GetPlayersDistKoef(): Float` |
| `0x006973B4` | `procedure SetPlayersDistKoef(value: Float)` |
| `0x006973D4` | `function GetPlayerGrHandle(const playername: String; const groupname: String): Integer` |
| `0x006973F8` | `function GetPlayerGrHandleByHandle(const playerhandle: Integer; const groupname: String): Integer` |
| `0x00697428` | `procedure PlayerSaveCurrentArmiesRectanglesByHandle(plhandle: Integer; enemyarmies: Boolean)` |
| `0x00697458` | `function GetPlayerArmiesCalcNeededByHandle(plhandle: Integer; enemyarmies: Boolean): Boolean` |
| `0x0069748C` | `function GetPlayerArmyFrontCenterDistToArmyByHandle(plhandle: Integer; armyindex: Integer; toplhandle: Integer; toarmyindex: Integer): Float` |
| `0x006974E0` | `procedure GetPlayerArmyFrontCenterByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; var posx: Float; var posz: Float)` |
| `0x0069753C` | `procedure GetPlayerArmyFrontCenterDirToArmyByHandle(plhandle: Integer; armyindex: Integer; toplhandle: Integer; toarmyindex: Integer; var dirx: Float; var diry: Float; var angle: Float)` |
| `0x00697660` | `procedure PlayerRemoveArmyByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean)` |
| `0x006976A8` | `function PlayerAddArmyByHandle(plhandle: Integer; enemyarmy: Boolean): integer` |
| `0x006976F8` | `function PlayerAddGroupToArmyByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; grouphandle: integer): integer` |
| `0x00697788` | `procedure PlayerArmySetNameByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; name: string)` |
| `0x00697808` | `procedure GetPlayerArmyDistAndDirToArmyByHandle(plhandle: Integer; armyindex: Integer; toplhandle: Integer; toarmyindex: Integer; var dist: Float; var dirx: Float; var diry: Float)` |
| `0x0069787C` | `function GetPlayerArmyDistToEnemyArmyByHandle(plhandle: Integer; armyindex: Integer; enemyarmyindex: Integer): Float` |
| `0x006978E0` | `function GetPlayerArmyRelativeQuarterToEnemyArmyByHandle(plhandle: Integer; armyindex: Integer; enemyarmyindex: Integer; fov: Float): Integer` |
| `0x00697914` | `procedure GetPlayerArmyDirectionToEnemyArmyByHandle(plhandle: Integer; armyindex: Integer; enemyarmyindex: Integer; var dirx: Float; var diry: Float; var angle: Float)` |
| `0x00697A14` | `function GetPlayerArmyDirectPathToEnemyArmy(plhandle: Integer; armyindex: Integer; enemyarmyindex: Integer): Boolean` |
| `0x00697A40` | `function GetPlayerArmyFrontCenterDistToEnemyArmyByHandle(plhandle: Integer; armyindex: Integer; enemyarmyindex: Integer): Float` |
| `0x00697A78` | `procedure GetPlayerArmyFrontCenterDirToEnemyArmyByHandle(plhandle: Integer; armyindex: Integer; enemyarmyindex: Integer; var dirx: Float; var diry: Float; var angle: Float)` |
| `0x00697B6C` | `procedure GetPlayerArmyDistAndDirToEnemyArmyByHandle(plhandle: Integer; armyindex: Integer; enemyarmyindex: Integer; var dist: Float; var dirx: Float; var diry: Float)` |
| `0x00697BC8` | `procedure SetPlayerArmyStretchPosByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; posx: Float; posz: Float)` |
| `0x00697C34` | `procedure GetPlayerArmyStretchPosByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; var posx: Float; var posz: Float)` |
| `0x00697CA0` | `procedure GetPlayerArmyStretchPosDistAndDirToArmy(plhandle: Integer; armyindex: Integer; toplhandle: Integer; toarmyindex: Integer; dist: Float; dirx: Float; diry: Float)` |
| `0x00697CF4` | `procedure GetPlayerArmyStretchPosDistAndDirToEnemyArmy(plhandle: Integer; armyindex: Integer; enemyarmyindex: Integer; var dist: Float; var dirx: Float; var diry: Float)` |
| `0x00697D50` | `function GetPlayersLogicPointMaxDistance: Float` |
| `0x00697D6C` | `function PlayerArmyCheckLineToEnemyArmy(plhandle: Integer; armyindex: Integer; enemyarmyindex: Integer): boolean` |
| `0x00697E0C` | `function PlayerArmyCheckLineToPoint(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; x,y: Float): boolean` |
| `0x00697E88` | `function PlayerArmyCheckLinePointToPoint(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; x1,y1, x2,y2: Float): boolean` |
| `0x00697F0C` | `function PlayerArmyTestLineToEnemyArmy(plhandle: Integer; armyindex: Integer; enemyarmyindex: Integer; var resx, resy: Float): boolean` |
| `0x00697FC4` | `function PlayerArmyTestLineToPoint(plhandle: Integer; armyindex: Integer; x, y: Float; var resx, resy: Float): boolean` |
| `0x00698060` | `function PlayerArmyGroupSideLeftRight(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; groupindex: integer): integer` |
| `0x00698134` | `procedure SetPlayersLogicPointMaxDistance(amaxdistance: Float)` |
| `0x00698150` | `function GetPlayersLogicPointMaxAngle: Float` |
| `0x0069816C` | `procedure SetPlayersLogicPointMaxAngle(amaxangle: Float)` |
| `0x00698188` | `procedure DeletePlayerByHandle(plhandle: Integer)` |
| `0x006981D0` | `procedure AddPlayerEnemyPlayerByHandle(plhandle, enemyplhandle: Integer)` |
| `0x00698208` | `procedure AddPlayerFriendPlayerByHandle(plhandle, friendplhandle: Integer)` |
| `0x00698240` | `procedure DeletePlayerEnemyPlayerByHandle(plhandle, enemyplhandle: Integer)` |
| `0x00698278` | `procedure DeletePlayerFriendPlayerByHandle(plhandle, friendplhandle: Integer)` |
| `0x006982B0` | `procedure ClearEnemyPlayersByHandle(plhandle: Integer)` |
| `0x006982D0` | `procedure ClearFriendPlayersByHandle(plhandle: Integer)` |
| `0x006982F0` | `function GetPlayerRaceNameByHandle(plhandle: Integer): String` |
| `0x00698328` | `function GetPlayerRaceTagByHandle(plhandle: Integer): Integer` |
| `0x0069834C` | `function GetPlayerRaceIndexByHandle(plhnd: Integer): Integer` |
| `0x00698370` | `procedure SetPlayerRaceNameByHandle(const plhnd: Integer; const racename: String)` |
| `0x006983B4` | `procedure SetPlayerRaceTagByHandle(const plhnd, racetag: Integer)` |
| `0x006983F8` | `procedure SetPlayerRaceIndexByHandle(const plhnd, raceindex: Integer)` |
| `0x00698460` | `function GetPlayersGlobalStateMachineEnabled(plhandle: Integer): Boolean` |
| `0x00698480` | `procedure SetPlayersGlobalStateMachineEnabled(plhandle: Integer; enabled: boolean)` |
| `0x006984A0` | `procedure SetPlayerStretchBrushRestrictMode(plhandle: Integer; value: Boolean)` |
| `0x006984C4` | `function GetPlayerStretchBrushRestrictMode(plhandle: Integer): Boolean` |
| `0x006984E8` | `procedure SetPlayerStretchBrushRestrictLTPoint(plhandle: Integer; ltpointx, ltpointy: Float)` |
| `0x00698530` | `procedure SetPlayerStretchBrushRestrictRBPoint(plhandle: Integer; rbpointx, rbpointy: Float)` |
| `0x00698578` | `procedure GetPlayerStretchBrushRestrictLTPoint(plhandle: Integer; var ltpointx: Float; var ltpointy: Float)` |
| `0x006985B4` | `procedure GetPlayerStretchBrushRestrictRBPoint(plhandle: Integer; var rbpointx: Float; var rbpointy: Float)` |
| `0x006985F0` | `function GetPlayerArmyDistanceToPointByHandle(plhandle: Integer; armyindex: Integer; px, pz: Float): Float` |
| `0x0069862C` | `function GetPlayerEnemyArmyDistanceToPointByHandle(plhandle: Integer; armyindex: Integer; px, pz: Float): Float` |
| `0x00698668` | `procedure PlayerMoveToPlayerByHandle(plhandle, toplhandle: Integer)` |
| `0x00698764` | `function GetPlayerArmyValueIndExistedByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; index: Integer): Boolean` |
| `0x006987B8` | `function GetPlayerArmyValueKeyExistedByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; const key: String): Boolean` |
| `0x0069880C` | `procedure SetPlayersSLogicFrmPoint(mindistance, maxdistance, maxangle: Float)` |
| `0x0069884C` | `procedure GetPlayersSLogicFrmPoint(var mindistance: Float; var maxdistance: Float; var maxangle: Float)` |
| `0x00698894` | `procedure SetPlayerStretchBrushUseOffset(plhandle: Integer; useoffset: Boolean; offsetx, offsety, offsetz: Float)` |
| `0x006988C8` | `procedure GetPlayerStretchBrushUseOffset(plhandle: Integer; var useoffset: Boolean; var offsetx: Float; var offsety: Float; var offsetz: Float)` |
| `0x00698B8C` | `procedure GetCastlePlayerBounds(plhandle: Integer; var minx, maxx, miny, maxy: Float)` |
| `0x00698DE8` | `function GetCastlePlayerOuterBarbakanHandle(plhandle: Integer): Integer` |
| `0x0069929C` | `function GetPlayerStretchLogicLinesGO(plhandle: Integer): Integer` |
| `0x006992C8` | `procedure SetPlayerStretchLogicLinesGO(plhandle: Integer; gohandle: Integer)` |
| `0x00699304` | `function GetPlayersStretchLogicLinesWallMode: Boolean` |
| `0x00699328` | `procedure SetPlayersStretchLogicLinesWallMode(awallmode: Boolean)` |
| `0x00699350` | `function GetPlayersStretchTransferDist: Float` |
| `0x0069937C` | `procedure SetPlayersStretchTransferDist(adist: Float)` |
| `0x006993A8` | `function PlayerGetArmySegmentDistanceByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; x1, z1, x2, z2: Float): Float` |
| `0x00699CEC` | `function GetPlayerCountOfGroupsByName(plname: String): Integer` |
| `0x00699D60` | `function GetPlayerCountOfGroupsByHandle(plhandle: Integer): Integer` |
| `0x00699D98` | `procedure SetPlayerArmyTagByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; ctag: String)` |
| `0x00699E18` | `function GetPlayerArmyTagByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean): String` |
| `0x00699E7C` | `function GetPlayerArmyStackCountByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean): Integer` |
| `0x00699ECC` | `procedure GetPlayerArmyStackKeyValueByHandle(plhandle: Integer; armyindex: Integer; enemyarmy: Boolean; stackindex: Integer; var key: String; var value: String)` |
| `0x00699F90` | `procedure FastClearPlayers(const pathdatathreadsafeclean: Boolean)` |
| `0x00699FF4` | `function GetPlayerProgressOnLanByHandle(plhnd: Integer): Boolean` |
| `0x0069A014` | `procedure SetPlayerProgressOnLanByHandle(plhnd: Integer; val: Boolean)` |
| `0x0069A034` | `function GetPlayerProgressOnEditByHandle(plhnd: Integer): Boolean` |
| `0x0069A054` | `procedure SetPlayerProgressOnEditByHandle(plhnd: Integer; val: Boolean)` |
| `0x0069A074` | `function GetPlayerProgressOnceByHandle(plhnd: Integer): Boolean` |
| `0x0069A094` | `procedure SetPlayerProgressOnceByHandle(plhnd: Integer; val: Boolean)` |
| `0x0069A0B4` | `function GetPlayerGlobalBeforeSaveStateName(plhnd: Integer): String` |
| `0x0069A0E8` | `procedure SetPlayerGlobalBeforeSaveStateName(plhnd: Integer; state: String)` |
| `0x0069A144` | `function GetPlayerGlobalAfterLoadStateName(plhnd: Integer): String` |
| `0x0069A178` | `procedure SetPlayerGlobalAfterLoadStateName(plhnd: Integer; state: String)` |
| `0x0069A1D4` | `function GetPlayerGroupsBeforeSaveStateName(plhnd: Integer): String` |
| `0x0069A208` | `procedure SetPlayerGroupsBeforeSaveStateName(plhnd: Integer; state: String)` |
| `0x0069A264` | `function GetPlayerGroupsAfterLoadStateName(plhnd: Integer): String` |
| `0x0069A298` | `procedure SetPlayerGroupsAfterLoadStateName(plhnd: Integer; state: String)` |
| `0x0069A2F4` | `function GetPlayerProgressSectionMax: Integer` |
| `0x0069A2FC` | `procedure SetPlayerProgressSectionMax(val: Integer)` |
| `0x0069A348` | `function GetPlayerProgressSectionMaxByHandle(plhnd: Integer): Integer` |
| `0x0069A370` | `procedure SetPlayerProgressSectionMaxByHandle(plhnd: Integer; val: Integer)` |
| `0x0069A394` | `function GetPlayerProgressSectionAutoClear(plhnd: Integer): Boolean` |
| `0x0069A3C4` | `procedure SetPlayerProgressSectionAutoClear(plhnd: Integer; val: Boolean)` |
| `0x0069A3E4` | `function GetPlayerProgressSectionAutoClearInterval(plhnd: Integer): Integer` |
| `0x0069A408` | `procedure SetPlayerProgressSectionAutoClearInterval(plhnd, val: Integer)` |
| `0x0069A428` | `function GetPlayerProgressSectionCount(plhnd: Integer): Integer` |
| `0x0069A44C` | `function GetPlayerProgressSectionIntervalByIndex(plhnd, psindex: Integer): Integer` |
| `0x0069A48C` | `function GetPlayerProgressSectionCountGOByIndex(plhnd, psindex: Integer): Integer` |
| `0x0069A4D0` | `function GetPlayerProgressSectionIndexByInterval(plhnd, psinterval: Integer): Integer` |
| `0x0069A4F8` | `function GetOrAddPlayerProgressSectionByInterval(plhnd, psinterval: Integer): Integer` |
| `0x0069A520` | `procedure SetPlayerProgressSectionOnReachedFuncByIndex(plhnd, psindex: Integer; psfunc: String)` |
| `0x0069A594` | `function GetPlayerProgressSectionOnReachedFuncByIndex(plhnd, psindex: Integer): String` |
| `0x0069A5E4` | `function GetPlayerProgressSectionGOHandleByIndex(plhnd, psindex, goindex: Integer): Integer` |
| `0x0069A62C` | `function GetProgressPlayersThread: Boolean` |
| `0x0069A63C` | `procedure SetProgressPlayersThread(const v: Boolean)` |
| `0x0069A658` | `function GetProgressPlayersPriority: Integer` |
| `0x0069A66C` | `procedure SetProgressPlayersPriority(const v: Integer)` |
| `0x0069A688` | `function GetProgressPlayersPerformance: Float` |
| `0x006A9E84` | `function GetAIRegionPlayerNameByIndex(const name: String; index: Integer): String` |
| `0x006AA050` | `function GetAIRegionPlayerNameByGroupIndex(const name: String; groupindex: Integer): String` |
| `0x006AC904` | `procedure PlayerSwitchToByHandle(plhandle: Integer; const state: String)` |
| `0x006AF528` | `function GetAIRegionScanPlayerByHandle(const reghnd: Integer): Integer` |
| `0x006AF548` | `procedure SetAIRegionScanPlayerByHandle(const reghnd, plhnd: Integer)` |
| `0x006AF740` | `function GetAIRegionUseScanPlayerByHandle(const reghnd: Integer): Boolean` |
| `0x006AF760` | `procedure SetAIRegionUseScanPlayerByHandle(const reghnd: Integer; const val: Boolean)` |
| `0x006B80DC` | `function GetPatternPlayerName: String` |
| `0x006B8110` | `procedure SetPatternPlayerName(name: String)` |
| `0x006B8268` | `procedure AddFOWPlayers(hnd: Integer)` |
| `0x006B82C4` | `procedure ClearFOWPlayers` |
| `0x006B8888` | `procedure SetUseProgressPlayersThread(const val: boolean)` |
| `0x006B88A0` | `function GetUseProgressPlayersThread: boolean` |
| `0x006C5324` | `function GetPlayerStateMachineHandle(const plhnd: Integer): Integer` |
| `0x006E740C` | `function QueryMachineResultGetTargetPlayerName(const resulthandle : Integer) : String` |
| `0x006E7440` | `procedure QueryMachineResultSetTargetPlayerName(const resulthandle : Integer; const targetplayername : String)` |
| `0x006E9E80` | `function ParserSelectPlayer(const plhandle: Integer): Integer` |
| `0x006E9F8C` | `function ParserCreatePlayer(const plhandle: Integer): Integer` |
| `0x006EA038` | `procedure ParserFreePlayer(const plhandle: Integer)` |
| `0x006F9840` | `function SteamwrapGetPlayerSteamLevel: integer` |
| `0x006FA3C0` | `procedure SteamwrapGetNumberOfCurrentPlayers(var steamapicall: pointer)` |
| `0x006FA950` | `function SteamwrapFriendsGetPlayerNickname(const playerid: pointer): string` |

### Scenario — 6

| VA | Объявление |
|---|---|
| `0x006ACB34` | `procedure SetCurrentScenarioName(const name: String)` |
| `0x006ACB60` | `procedure SetCurrentScenarioIndex(index: Integer)` |
| `0x006ACB8C` | `procedure BeginPlayingCurrentScenario()` |
| `0x006ACBC8` | `procedure EndPlayingCurrentScenario()` |
| `0x006ACC04` | `procedure PlayCurrentScenarioImmediately()` |
| `0x006ACC54` | `function IsPlayingCurrentScenarioImmediately(): Boolean` |

### StateMachine — 1

| VA | Объявление |
|---|---|
| `0x006C4660` | `procedure StateMachineRegisterUnitsToLog(funcs, consts, vars, types: Boolean)` |

## 3. GUI

Машина меню: `StateMachineGetGUISMHandle (0x6C4B00)`, вызов состояния `GUIExecuteState (0x674118)`, параметры `SetGUIValue Status/Press/Tag/Key/ElementHandle`, перезагрузка `StateMachineReloadGUI (0x6C48FC)`. Конструкторы: `AddNewElementTop / Parent / Container / TopByClassName / ByClassNameParent / Layer (0x674250-0x674358)`. Корень дерева: `_gui_GetTop()` -> `gc_gui_element_top` (`TOSWImageGuiControl`), конфиг состояний: `data/gui/menu.cfg` (`DoCreate/DoDestroy/DoProgress/OnHint/OnResize/OnLanEvent`).

### AddNewElement — 6

| VA | Объявление |
|---|---|
| `0x00674250` | `function AddNewElementTop(const buttonname: String; const elementname: String; tag: Integer): Integer` |
| `0x00674274` | `function AddNewElementParent(const buttonname: String; const elementname: String; tag: Integer; parent: Integer): Integer` |
| `0x006742B4` | `function AddNewElementContainer(const elementname: String; parent: Integer): Integer` |
| `0x006742F4` | `function AddNewElementTopByClassName(const elementname: String; const classname: String; tag: Integer): Integer` |
| `0x00674318` | `function AddNewElementByClassNameParent(const elementname: String; const classname: String; tag: Integer; parent: Integer): Integer` |
| `0x00674358` | `function AddNewElementLayer(index: Integer; const buttonname: String): Integer` |

### Camera — 1

| VA | Объявление |
|---|---|
| `0x00678760` | `procedure SetGUICameraControl(index: Integer)` |

### DestroyGUI — 1

| VA | Объявление |
|---|---|
| `0x0067498C` | `procedure DestroyGUIChildren(index: Integer)` |

### GUI misc — ввод/события/сервис — 28

| VA | Объявление |
|---|---|
| `0x00676378` | `procedure SetGUIMinimapZoom(zoom: Float)` |
| `0x0067639C` | `function GetGUIMinimapZoom(): Float` |
| `0x006768F0` | `procedure UnregisterGUIAllShortcuts()` |
| `0x0067878C` | `procedure GetGUIPreviousMouseCoord(var ax, ay: Integer)` |
| `0x006787B8` | `procedure GetGUICurrentMouseCoord(var ax, ay: Integer)` |
| `0x0067883C` | `function GetGUIMinimapUnderMouse:Boolean` |
| `0x0067B93C` | `function GUIAddDataViewerZone: Integer` |
| `0x0067B960` | `function GUIAddDataViewerZoneColor(cinr, cing, cinb, cina, coutr, coutg, coutb, couta: Float): Integer` |
| `0x0067B9D8` | `procedure GUISetDataViewerZoneColor(cindex: Integer; cinr, cing, cinb, cina, coutr, coutg, coutb, couta: Float)` |
| `0x0067BA50` | `function GUIAddDataViewerZoneColorExt(csizescale, cinr, cing, cinb, cina, coutr, coutg, coutb, couta: Float): Integer` |
| `0x0067BACC` | `procedure GUISetDataViewerZoneColorExt(cindex: Integer; csizescale, cinr, cing, cinb, cina, coutr, coutg, coutb, couta: Float)` |
| `0x0067BB48` | `procedure GUIDeleteDataViewerZone(cindex: Integer)` |
| `0x0067BB7C` | `function GUIGetDataViewerZoneCount: Integer` |
| `0x0067C6A0` | `procedure GUILoadTextures` |
| `0x0067C6B8` | `procedure GUIUnloadTextures` |
| `0x0067C6D0` | `procedure GUIReloadTextures` |
| `0x0067C9AC` | `procedure GUIAddDelayState(const state: String; unique, first: Boolean)` |
| `0x0067C9D0` | `procedure GUIRemoveDelayState(const state: String)` |
| `0x0067CA00` | `function GUICountDelayStates: Integer` |
| `0x0067CA14` | `function GUIFindDelayState(const state: String): Integer` |
| `0x0067CA30` | `procedure GUIEvaluateDelayStates` |
| `0x0067DC38` | `function GUIIsEventAccepted(index: Integer): Boolean` |
| `0x0067DE78` | `procedure GUISetCursorPos(screenx, screeny: Integer)` |
| `0x0067DE8C` | `procedure GUIGetCursorPos(var screenx: Integer; var screeny: Integer)` |
| `0x0067DEB0` | `function GUIGetScreenWidth: Integer` |
| `0x0067DEB8` | `function GUIGetScreenHeight: Integer` |
| `0x006858FC` | `procedure RecordSynchBeginGUI()` |
| `0x00685D74` | `function RecordCustomBeginGUI(const state: String): Boolean` |

### GUIAllow — 4

| VA | Объявление |
|---|---|
| `0x00676F2C` | `procedure SetGUIAllowDrag(index: Integer; drag: Boolean)` |
| `0x00676F78` | `procedure SetGUIAllowEvents(index: Integer; mouse: Boolean; keyboard: Boolean; focus: Boolean)` |
| `0x00677028` | `procedure GetGUIAllowEvents(index: Integer; var mouse: Boolean; var keyboard: Boolean; var focus: Boolean)` |
| `0x00677080` | `procedure SetGUIAllowMouseButtons(index: Integer; btnleft, btnright, btnmiddle: Boolean)` |

### GUIBaseControl — 3

| VA | Объявление |
|---|---|
| `0x0067413C` | `function GetGUIBaseControlVisible(): Boolean` |
| `0x00674150` | `procedure SetGUIBaseControlVisible(visible: Boolean)` |
| `0x0067416C` | `procedure GUIBaseControlClear()` |

### GUIBoolValue — 4

| VA | Объявление |
|---|---|
| `0x00673F90` | `function GetGUIBoolValue(const key: String): Boolean` |
| `0x00673FB4` | `procedure SetGUIBoolValue(const key: String; value: Boolean)` |
| `0x006740CC` | `function GetGUIBoolValueInd(index: Integer): Boolean` |
| `0x006740F0` | `procedure SetGUIBoolValueInd(index: Integer; value: Boolean)` |

### GUIClear — 4

| VA | Объявление |
|---|---|
| `0x00674194` | `procedure GUIClearElements()` |
| `0x0067B8FC` | `procedure GUIClearPlayerDataViewerZones` |
| `0x0067BB9C` | `procedure GUIClearDataViewerZones` |
| `0x0067C9EC` | `procedure GUIClearDelayStates` |

### GUIClickStretchLogic — 2

| VA | Объявление |
|---|---|
| `0x00676BEC` | `procedure SetGUIClickStretchLogicByIndex(logicindex: Integer)` |
| `0x00676DD8` | `function GetGUIClickStretchLogicIndex(): Integer` |

### GUIClipboard — 2

| VA | Объявление |
|---|---|
| `0x0067E0B0` | `function GetGUIClipboardAsText: String` |
| `0x0067E0C4` | `procedure SetGUIClipboardAsText(const v: String)` |

### GUICmd — 10

| VA | Объявление |
|---|---|
| `0x006772B0` | `function GetGUICmdCount(): Integer` |
| `0x006772C8` | `function GetGUICmdButtonHandleByCmdIndex(cmdindex: Integer): Integer` |
| `0x0067732C` | `function GetGUICmdIndexByCmdName(const cmdname: String): Integer` |
| `0x0067734C` | `function GetGUICmdNameByCmdIndex(cmdindex: Integer): String` |
| `0x006773B0` | `function GetGUICmdButtonNameByCmdIndex(cmdindex: Integer): String` |
| `0x00677414` | `function GetGUICmdVisibleByCmdIndex(cmdindex: Integer): Boolean` |
| `0x00677460` | `function GetGUICmdEnabledByCmdIndex(cmdindex: Integer): Boolean` |
| `0x006774AC` | `function GetGUICmdStateNameByCmdIndex(cmdindex: Integer): String` |
| `0x00677510` | `function GetGUICmdStateRunByCmdIndex(cmdindex: Integer): Boolean` |
| `0x0067755C` | `procedure SetGUICmdStateNameByCmdIndex(cmdindex: Integer; const value: String)` |

### GUIComboBox — 4

| VA | Объявление |
|---|---|
| `0x0067A068` | `procedure SetGUIComboBoxDropDown(index: Integer; adropdown: Boolean)` |
| `0x0067A0AC` | `function GetGUIComboBoxDropDown(index: Integer): Boolean` |
| `0x0067A23C` | `function GetGUIComboBoxListBoxHandle(index: Integer): Integer` |
| `0x0067A384` | `function GetGUIComboBoxCurrent: Integer` |

### GUICursor — 5

| VA | Объявление |
|---|---|
| `0x0067560C` | `procedure SetGUICursorByName(const cursor: String)` |
| `0x00675664` | `procedure SetGUICursorByIndex(cursor: Integer)` |
| `0x00675684` | `function GetGUICursorByName(): String` |
| `0x006756F0` | `function GetGUICursorByIndex(): Integer` |
| `0x0067C58C` | `function GetGUICursorIndexByName(const cursor: String): Integer` |

### GUIDataViewer — 2

| VA | Объявление |
|---|---|
| `0x0067BBBC` | `procedure GUIDataViewerZonePointListClear(cindex: Integer)` |
| `0x0067BBF0` | `procedure GUIDataViewerZonePointListAdd(cindex: Integer; x, y, z: Float)` |

### GUIDelay — 11

| VA | Объявление |
|---|---|
| `0x0067C950` | `procedure GUIDelayExecuteState(const state: String; const time: Float)` |
| `0x0067C974` | `function GetGUIDelayExecuteState: String` |
| `0x0067C990` | `function GetGUIDelayExecuteTime: Float` |
| `0x0067DCAC` | `function GUIDelayTimeExecAdd(const state: String; const time: Float; const uniq: Boolean): Integer` |
| `0x0067DCD0` | `procedure GUIDelayTimeExecDelete(const ind: Integer; const evaluate: Boolean)` |
| `0x0067DCF0` | `procedure GUIDelayTimeExecClear(const evaluate: Boolean)` |
| `0x0067DD0C` | `function GUIDelayTimeExecCount: Integer` |
| `0x0067DD20` | `function GUIDelayTimeExecFind(const state: String): Integer` |
| `0x0067DD3C` | `procedure GUIDelayTimeExecEvaluate(const ind: Integer)` |
| `0x0067DD58` | `function GUIDelayTimeExecNextIndex: Integer` |
| `0x0067DD6C` | `procedure GUIDelayTimeExecGet(const ind: Integer; var state: String; var time: Float)` |

### GUIDelayClear — 1

| VA | Объявление |
|---|---|
| `0x006741A8` | `procedure GUIDelayClearElements()` |

### GUIDeltaTime — 1

| VA | Объявление |
|---|---|
| `0x0067AFB4` | `function  GetGUIDeltaTime:Float` |

### GUIDirectCursor — 5

| VA | Объявление |
|---|---|
| `0x00675704` | `procedure SetGUIDirectCursorByName(const value: String)` |
| `0x00675780` | `procedure SetGUIDirectCursorByIndex(value: Integer)` |
| `0x006757B4` | `function GetGUIDirectCursorByName(): String` |
| `0x00675820` | `function GetGUIDirectCursorByIndex(): Integer` |
| `0x00675834` | `procedure GUIDirectCursorUpdate` |

### GUIElement — 158

| VA | Объявление |
|---|---|
| `0x006741BC` | `function GetGUIElementParentByIndex(aindex: Integer): Integer` |
| `0x006741DC` | `function GetGUIElementChildrenCount(ahandle: Integer): Integer` |
| `0x00674200` | `function GetGUIElementChildrenByIndex(ahandle: Integer; aindex: Integer): Integer` |
| `0x006743AC` | `function GetGUIElementIndexByNameParent(const elementname: String; parent: Integer): Integer` |
| `0x006743D8` | `function GetGUIElementTopIndexByName(const elementname: String): Integer` |
| `0x00674400` | `function GetGUIElementNameByIndex(index: Integer): String` |
| `0x00674440` | `function GetGUIElementPositionX(index: Integer): Integer` |
| `0x00674464` | `function GetGUIElementPositionY(index: Integer): Integer` |
| `0x00674488` | `procedure SetGUIElementPositionX(index: Integer; x: Integer)` |
| `0x006744AC` | `procedure SetGUIElementPositionY(index: Integer; y: Integer)` |
| `0x006744D0` | `procedure SetGUIElementPosition(index: Integer; x: Integer; y: Integer)` |
| `0x006744FC` | `procedure SetGUIElementScale(index: Integer; x: Float; y: Float)` |
| `0x0067452C` | `procedure GetGUIElementScale(index: Integer; var x: Float; var y: Float)` |
| `0x0067456C` | `function GetGUIElementScaleX(index: Integer): Float` |
| `0x0067459C` | `function GetGUIElementScaleY(index: Integer): Float` |
| `0x006745CC` | `procedure SetGUIElementScaleX(index: Integer; x: Float)` |
| `0x006745F4` | `procedure SetGUIElementScaleY(index: Integer; y: Float)` |
| `0x0067461C` | `function GetGUIElementVAlign(index: Integer): String` |
| `0x0067465C` | `function GetGUIElementHAlign(index: Integer): String` |
| `0x0067469C` | `procedure SetGUIElementVAlign(index: Integer; const valign: String)` |
| `0x006746C8` | `procedure SetGUIElementHAlign(index: Integer; const halign: String)` |
| `0x006746F4` | `procedure SetGUIElementAlign(index: Integer; const halign: String; const valign: String)` |
| `0x0067472C` | `procedure SetGUIElementTextAlign(index: Integer; const halign: String; const valign: String; xoffset: Integer; yoffset: Integer)` |
| `0x0067478C` | `procedure GetGUIElementTextAlign(index: Integer; var halign: String; var valign: String; var xoffset: Integer; var yoffset: Integer)` |
| `0x00674870` | `procedure GetGUIElementAlignPosition(index: Integer; var x: Integer; var y: Integer)` |
| `0x006748A4` | `procedure RemoveGUIElement(index: Integer)` |
| `0x0067495C` | `procedure DestroyGUIElement(index: Integer)` |
| `0x006749F8` | `procedure AttachGUIElementToElement(aindex: Integer; aattachto: Integer)` |
| `0x00674A74` | `function GetGUIElementVisible(index: Integer): Boolean` |
| `0x00674A94` | `procedure SetGUIElementVisible(index: Integer; visible: Boolean)` |
| `0x00674AB4` | `function GetGUIElementInstanced(index: Integer): Boolean` |
| `0x00674AD8` | `procedure SetGUIElementInstanced(index: Integer; instanced: Boolean)` |
| `0x00674AFC` | `function GetGUIElementAbsScaled(index: Integer): Boolean` |
| `0x00674B20` | `procedure SetGUIElementAbsScaled(index: Integer; absscaled: Boolean)` |
| `0x00674B44` | `procedure SetGUIElementBlink(index: Integer; interval: Float; count: Integer)` |
| `0x00674B74` | `function GetGUIElementBlink(index: Integer): Boolean` |
| `0x00674B98` | `procedure SetGUIElementBlinkMode(index: Integer; mode: Integer)` |
| `0x00674BB8` | `function GetGUIElementBlinkMode(index: Integer): Integer` |
| `0x00674F78` | `function GetGUIElementWidth(index: Integer): Integer` |
| `0x00674F9C` | `function GetGUIElementHeight(index: Integer): Integer` |
| `0x00674FC0` | `procedure SetGUIElementWidth(index: Integer; width: Integer)` |
| `0x00674FE4` | `procedure SetGUIElementHeight(index: Integer; height: Integer)` |
| `0x00675008` | `function GetGUIElementLogicWidth(index: Integer): Integer` |
| `0x0067502C` | `function GetGUIElementLogicHeight(index: Integer): Integer` |
| `0x00675050` | `procedure SetGUIElementLogicWidth(index: Integer; width: Integer)` |
| `0x00675074` | `procedure SetGUIElementLogicHeight(index: Integer; height: Integer)` |
| `0x00675098` | `procedure SetGUIElementRect(index: Integer; width: Integer; height: Integer)` |
| `0x006750C4` | `procedure SetGUIElementLogicRect(index: Integer; width: Integer; height: Integer)` |
| `0x006750FC` | `procedure SetGUIElementAllRect(index: Integer; width: Integer; height: Integer)` |
| `0x0067514C` | `procedure SetGUIElementPositionRect(index: Integer; x: Integer; y: Integer; width: Integer; height: Integer)` |
| `0x00675188` | `procedure SetGUIElementLogicPositionRect(index: Integer; x: Integer; y: Integer; width: Integer; height: Integer)` |
| `0x006751D0` | `procedure SetGUIElementAllPositionRect(index: Integer; x: Integer; y: Integer; width: Integer; height: Integer)` |
| `0x00675230` | `procedure GetGUIElementBoundingBox(index: Integer; var x: Integer; var y: Integer; var width: Integer; var height: Integer)` |
| `0x0067528C` | `procedure GetGUIElementBoundingLogicBox(index: Integer; var x: Integer; var y: Integer; var width: Integer; var height: Integer)` |
| `0x006752E8` | `procedure SetGUIElementTileScales(index: Integer; x: Float; y: Float)` |
| `0x0067532C` | `procedure GetGUIElementTileScales(index: Integer; var x: Float; var y: Float)` |
| `0x006754E0` | `procedure SetGUIElementCursorByName(index: Integer; const cursor: String)` |
| `0x00675544` | `procedure SetGUIElementCursorByIndex(index: Integer; cursor: Integer)` |
| `0x00675568` | `function GetGUIElementCursorByName(index: Integer): String` |
| `0x006755E8` | `function GetGUIElementCursorByIndex(index: Integer): Integer` |
| `0x00675854` | `procedure SetGUIElementPressState(index: Integer; const statename: String)` |
| `0x00675880` | `function GetGUIElementPressState(index: Integer): String` |
| `0x006758AC` | `procedure GUIElementEmulatePress(index: Integer)` |
| `0x006758DC` | `function GetGUIElementFont(index: Integer): String` |
| `0x0067592C` | `procedure SetGUIElementFont(index: Integer; const font: String)` |
| `0x006759F0` | `procedure SetGUIElementText(index: Integer; const text: String)` |
| `0x00675A18` | `function GetGUIElementText(index: Integer): String` |
| `0x00675A5C` | `procedure SetGUIElementWideText(index: Integer; afromwidearg: Integer)` |
| `0x00675AA0` | `procedure GetGUIElementWideText(index: Integer; atowidearg: Integer)` |
| `0x00675B00` | `function GetGUIElementTextRect(index: Integer; const text: String; var width: Integer; var height: Integer): Boolean` |
| `0x00675B44` | `function GetGUIElementWideTextRect(index: Integer; arg: Integer; var width: Integer; var height: Integer): Boolean` |
| `0x00675BE4` | `procedure SetGUIElementColor(index: Integer; r: Float; g: Float; b: Float; a: Float)` |
| `0x00675C3C` | `procedure SetGUIElementBlinkColor(index: Integer; r: Float; g: Float; b: Float; a: Float)` |
| `0x00675C94` | `procedure SetGUIElementUserBlend(index: Integer; aalpha: Float)` |
| `0x00675CB8` | `function GetGUIElementUserBlend(index: Integer): Float` |
| `0x00675CEC` | `procedure SetGUIElementUseUserColor(const index: Integer; const useusercolor: Boolean)` |
| `0x00675D24` | `function GetGUIElementUseUserColor(const index: Integer): Boolean` |
| `0x00675D5C` | `procedure SetGUIElementUserColor(const index: Integer; const r, g, b, a: Float)` |
| `0x00675DB4` | `procedure GetGUIElementUserColor(const index: Integer; var r, g, b, a: Float)` |
| `0x00675E10` | `procedure SetGUIElementFadingTimes(index: Integer; fadetime: Float; freezetime: Float)` |
| `0x00675E80` | `procedure SetGUIElementFadeInEnabled(index: Integer; enabled: Boolean)` |
| `0x00675EE4` | `procedure SetGUIElementFadeOutEnabled(index: Integer; enabled: Boolean)` |
| `0x00675F48` | `procedure SetGUIElementFadeRecursiveEnabled(index: Integer; enabled: Boolean)` |
| `0x00675F94` | `procedure SetGUIElementFadeCount(index: Integer; acount: Integer)` |
| `0x00675FCC` | `procedure SetGUIElementFreezeEnabled(index: Integer; enabled: Boolean)` |
| `0x00676030` | `procedure SetGUIElementFadeAutoDestroy(index: Integer; enabled: Boolean)` |
| `0x00676068` | `procedure SetGUIElementFadeStart(index: Integer; enabled: Boolean)` |
| `0x00676624` | `procedure SetGUIElementSelStart(index: Integer; selstart: Integer)` |
| `0x0067665C` | `procedure SetGUIElementEditChar(index: Integer; const editchar: String)` |
| `0x006766DC` | `procedure SetGUIElementEditFilter(index: Integer; const editchar: String)` |
| `0x00676718` | `procedure SetGUIElementEditMultiLineMode(index: Integer; amode: Boolean)` |
| `0x00676750` | `function GetGUIElementEditMultiLineMode(index: Integer): Boolean` |
| `0x00676788` | `procedure SetGUIElementMaxTextLength(index: Integer; maxlen: Integer)` |
| `0x00676AB0` | `procedure SetGUIElementTag(index: Integer; tag: Integer)` |
| `0x00676AD0` | `function GetGUIElementTag(index: Integer): Integer` |
| `0x00676AF0` | `procedure SetGUIElementStringTag(index: Integer; const tag: String)` |
| `0x00676B1C` | `function GetGUIElementStringTag(index: Integer): String` |
| `0x00676B5C` | `function GetGUIElementHint(index: Integer): String` |
| `0x00676BC0` | `procedure SetGUIElementHint(index: Integer; const hint: String)` |
| `0x006770FC` | `procedure SetGUIElementMaterial(index: Integer; const material: String)` |
| `0x00677138` | `function GetGUIElementMaterial(index: Integer): String` |
| `0x00677184` | `procedure SetGUIElementStateMaterial(index: Integer; const anormalmat, ahovermat: String)` |
| `0x006771CC` | `function GetGUIElementStateNormalMaterial(index: Integer): String` |
| `0x0067721C` | `function GetGUIElementStateHoverMaterial(index: Integer): String` |
| `0x0067726C` | `procedure SetGUIElementMaterialOffset(index: Integer; offsx, offsy: Integer)` |
| `0x006775AC` | `procedure SetGUIElementEnabled(index: Integer; value: Boolean)` |
| `0x006775F4` | `function GetGUIElementEnabled(index: Integer): Boolean` |
| `0x00677638` | `procedure GetGUIElementFontTextRect(const fontname: String; const text: String; var width: Integer; var height: Integer)` |
| `0x006776DC` | `procedure GetGUIElementFontWideTextRect(const fontname: String; arg: Integer; var width: Integer; var height: Integer)` |
| `0x006777E0` | `function GetGUIElementFontHeight(const fontname: String): Integer` |
| `0x0067784C` | `procedure SetGUIElementFontHeight(const fontname: String; const val: Integer)` |
| `0x00677BFC` | `procedure SetGUIElementHoverEnabled(index: Integer; value: Boolean)` |
| `0x00677C34` | `procedure SetGUIElementCurrentProperty(index: Integer; const sprop: String)` |
| `0x00677D14` | `procedure SetGUIElementVisibleProperties(index: Integer; const visprop, matname: String; const xoffset, yoffset, textxoffset, textyoffset, cursorind: Integer; const textcolorr, textcolorg, textcolorb, textcolora: Float)` |
| `0x00677E64` | `function GetGUIElementHoverEnabled(index: Integer): Boolean` |
| `0x00677E9C` | `procedure SetGUIElementButtonStyle(index: Integer; const astyle: String)` |
| `0x00677ED8` | `function GetGUIElementButtonStyle(index: Integer): String` |
| `0x00677F28` | `procedure SetGUIElementChecked(index: Integer; const avalue: Boolean)` |
| `0x00677F60` | `function GetGUIElementChecked(index: Integer): Boolean` |
| `0x00678398` | `function GetGUIElementVScroll(index: Integer): Integer` |
| `0x006783D0` | `function GetGUIElementHScroll(index: Integer): Integer` |
| `0x00678408` | `procedure SetGUIElementAllowScroll(index: Integer; allow: Boolean)` |
| `0x00678430` | `function GetGUIElementAllowScroll(index: Integer): Boolean` |
| `0x006784C8` | `procedure SetGUIElementName(index: Integer; const name: String)` |
| `0x006784F4` | `procedure SetGUIElementZOrder(index: Integer; z: Integer)` |
| `0x00678544` | `function GetGUIElementZOrder(index: Integer): Integer` |
| `0x0067856C` | `function GetGUIElementScrollButtonIndex(wndindex: Integer; buttonid: Integer): Integer` |
| `0x00678670` | `procedure GUIElementBringToFront(index: Integer)` |
| `0x00678690` | `procedure GUIElementSendToBack(index: Integer)` |
| `0x00678728` | `function GetGUIElementFadeStarted(index: Integer): Boolean` |
| `0x00678828` | `function GetGUIElementUnderMouse:Integer` |
| `0x0067885C` | `procedure SetGUIElementFocusedHandle(aindex: Integer)` |
| `0x0067889C` | `function GetGUIElementFocusedByHandle(aindex: Integer): Boolean` |
| `0x00678914` | `procedure SetGUIElementBackgroundMaterial(aindex: Integer; side: Integer; const matname: String)` |
| `0x006789F0` | `procedure SetGUIElementBackgroundSideOffset(aindex: Integer; offset: Integer)` |
| `0x00678A28` | `procedure SetGUIElementBackgroundCornerOffset(aindex: Integer; offset: Integer)` |
| `0x00678A60` | `procedure SetGUIElementBackgroundTextureOffset(aindex: Integer; left, right, top, bottom, tilex, tiley: Float)` |
| `0x00678ADC` | `procedure GetGUIElementBackgroundTextureOffset(aindex: Integer; var left, right, top, bottom, tilex, tiley: Float)` |
| `0x0067CA44` | `procedure GUIElementInternalMouseMove(index: Integer)` |
| `0x0067CB20` | `procedure GetGUIElementFontTextFormatRect(const fontname, text: String; var width: Integer; var height: Integer)` |
| `0x0067CBC4` | `procedure GetGUIElementFontWideTextFormatRect(const fontname: String; arg: Integer; var width: Integer; var height: Integer)` |
| `0x0067CE84` | `procedure SetGUIElementColorAttention(index: Integer; r, g, b, a: Float)` |
| `0x0067CEDC` | `procedure SetGUIElementColorInfo(index: Integer; r, g, b, a: Float)` |
| `0x0067CF34` | `procedure SetGUIElementColorExtraInfo(index: Integer; r, g, b, a: Float)` |
| `0x0067CF8C` | `procedure SetGUIElementColorWarning(index: Integer; r, g, b, a: Float)` |
| `0x0067CFE4` | `procedure GetGUIElementColorAttention(index: Integer; var r, g, b, a: Float)` |
| `0x0067D040` | `procedure GetGUIElementColorInfo(index: Integer; var r, g, b, a: Float)` |
| `0x0067D09C` | `procedure GetGUIElementColorExtraInfo(index: Integer; var r, g, b, a: Float)` |
| `0x0067D0F8` | `procedure GetGUIElementColorWarning(index: Integer; var r, g, b, a: Float)` |
| `0x0067D154` | `procedure GetGUIElementColor(index: Integer; var r, g, b, a: Float)` |
| `0x0067D1B0` | `procedure SetGUIElementTextFormatted(index: Integer; formatted: Boolean)` |
| `0x0067D1E8` | `function GetGUIElementTextFormatted(index: Integer): Boolean` |
| `0x0067D4DC` | `procedure FormatGetGUIElementTextPosData(index, pos: Integer; var x, y: Integer; var style: String; var r, g, b, a: Float)` |
| `0x0067D61C` | `function FormatGetGUIElementTextRefData(index, refind: Integer; var refpos: Integer; var refarg, refval: String; var x, y: Integer; var style: String; var r, g, b, a: Float): Boolean` |
| `0x0067D764` | `function FormatGetGUIElementTextTagData(index, tagind: Integer; var tag: String; var tagpos, taglen: Integer; var tagarg: String; var x, y: Integer; var style: String; var r, g, b, a: Float): Boolean` |
| `0x0067DB04` | `procedure GUIElementAddDelayTimeFree(index: Integer; time: Float)` |
| `0x0067DB38` | `function GUIElementIsDelayTimeFree(index: Integer): Boolean` |
| `0x0067DB70` | `procedure GUIElementRemoveDelayTimeFree(index: Integer)` |

### GUIEvent — 6

| VA | Объявление |
|---|---|
| `0x0067DBA0` | `function GUIEventToParent(index: Integer): Boolean` |
| `0x0067DBD4` | `function GUIEventToInherited(index: Integer): Boolean` |
| `0x0067DC08` | `procedure GUIEventAccepted(index: Integer)` |
| `0x0067DC6C` | `function GUIEventInfo: String` |
| `0x0067DC98` | `function GUIEventSender: Integer` |
| `0x0067DE00` | `function GetGUIEventMouseWheelDelta: Integer` |

### GUIEventState — 62

| VA | Объявление |
|---|---|
| `0x0067BCB4` | `function GetGUIEventStateOnCreateGUI: String` |
| `0x0067BCD8` | `function GetGUIEventStateOnDestroyGUI: String` |
| `0x0067BCFC` | `function GetGUIEventStateOnUpdateGUI: String` |
| `0x0067BD20` | `function GetGUIEventStateOnPressGUI: String` |
| `0x0067BD44` | `function GetGUIEventStateOnUnPressGUI: String` |
| `0x0067BD68` | `function GetGUIEventStateOnClickGUI: String` |
| `0x0067BD8C` | `function GetGUIEventStateOnMouseEnterGUI: String` |
| `0x0067BDB0` | `function GetGUIEventStateOnMouseLeaveGUI: String` |
| `0x0067BDD4` | `function GetGUIEventStateOnMouseMove: String` |
| `0x0067BDF8` | `function GetGUIEventStateOnMouseDown: String` |
| `0x0067BE1C` | `function GetGUIEventStateOnMouseUp: String` |
| `0x0067BE40` | `function GetGUIEventStateOnHintGUI: String` |
| `0x0067BE64` | `function GetGUIEventStateOnProcessSelection: String` |
| `0x0067BE88` | `function GetGUIEventStateOnBeginSelection: String` |
| `0x0067BEAC` | `function GetGUIEventStateOnEndSelection: String` |
| `0x0067BED0` | `function GetGUIEventStateOnCameraRotate: String` |
| `0x0067BEF4` | `function GetGUIEventStateOnCameraDistance: String` |
| `0x0067BF18` | `function GetGUIEventStateOnCmdExecute: String` |
| `0x0067BF3C` | `function GetGUIEventStateOnBeforeCmdExecute: String` |
| `0x0067BF60` | `function GetGUIEventStateOnProgressGUI: String` |
| `0x0067BFA8` | `function GetGUIEventStateOnResizeGUI: String` |
| `0x0067BFCC` | `function GetGUIEventStateOnKeyDown: String` |
| `0x0067BFF0` | `function GetGUIEventStateOnChange: String` |
| `0x0067C014` | `function GetGUIEventStateOnLanChange: String` |
| `0x0067C038` | `function GetGUIEventStateOnGUIHookEvent: String` |
| `0x0067C05C` | `function GetGUIEventStateOnBeforeLoadMap: String` |
| `0x0067C080` | `function GetGUIEventStateOnAfterLoadMap: String` |
| `0x0067C0A4` | `function GetGUIEventStateOnAfterFullLoadMap: String` |
| `0x0067C0C8` | `function GetGUIEventStateOnBeforeSaveMap: String` |
| `0x0067C0EC` | `function GetGUIEventStateOnAfterSaveMap: String` |
| `0x0067C110` | `procedure SetGUIEventStateOnCreateGUI(const aname: String)` |
| `0x0067C134` | `procedure SetGUIEventStateOnDestroyGUI(const aname: String)` |
| `0x0067C158` | `procedure SetGUIEventStateOnUpdateGUI(const aname: String)` |
| `0x0067C17C` | `procedure SetGUIEventStateOnPressGUI(const aname: String)` |
| `0x0067C1A0` | `procedure SetGUIEventStateOnUnPressGUI(const aname: String)` |
| `0x0067C1C4` | `procedure SetGUIEventStateOnClickGUI(const aname: String)` |
| `0x0067C1E8` | `procedure SetGUIEventStateOnMouseEnterGUI(const aname: String)` |
| `0x0067C20C` | `procedure SetGUIEventStateOnMouseLeaveGUI(const aname: String)` |
| `0x0067C230` | `procedure SetGUIEventStateOnMouseMove(const aname: String)` |
| `0x0067C254` | `procedure SetGUIEventStateOnMouseDown(const aname: String)` |
| `0x0067C278` | `procedure SetGUIEventStateOnMouseUp(const aname: String)` |
| `0x0067C29C` | `procedure SetGUIEventStateOnHintGUI(const aname: String)` |
| `0x0067C2C0` | `procedure SetGUIEventStateOnProcessSelection(const aname: String)` |
| `0x0067C2E4` | `procedure SetGUIEventStateOnBeginSelection(const aname: String)` |
| `0x0067C308` | `procedure SetGUIEventStateOnEndSelection(const aname: String)` |
| `0x0067C32C` | `procedure SetGUIEventStateOnCameraRotate(const aname: String)` |
| `0x0067C350` | `procedure SetGUIEventStateOnCameraDistance(const aname: String)` |
| `0x0067C374` | `procedure SetGUIEventStateOnCmdExecute(const aname: String)` |
| `0x0067C398` | `procedure SetGUIEventStateOnBeforeCmdExecute(const aname: String)` |
| `0x0067C3BC` | `procedure SetGUIEventStateOnProgressGUI(const aname: String)` |
| `0x0067C404` | `procedure SetGUIEventStateOnResizeGUI(const aname: String)` |
| `0x0067C428` | `procedure SetGUIEventStateOnKeyDown(const aname: String)` |
| `0x0067C44C` | `procedure SetGUIEventStateOnChange(const aname: String)` |
| `0x0067C470` | `procedure SetGUIEventStateOnLanChange(const aname: String)` |
| `0x0067C494` | `procedure SetGUIEventStateOnGUIHookEvent(const aname: String)` |
| `0x0067C4B8` | `procedure SetGUIEventStateOnBeforeLoadMap(const aname: String)` |
| `0x0067C4DC` | `procedure SetGUIEventStateOnAfterLoadMap(const aname: String)` |
| `0x0067C500` | `procedure SetGUIEventStateOnAfterFullLoadMap(const aname: String)` |
| `0x0067C524` | `procedure SetGUIEventStateOnBeforeSaveMap(const aname: String)` |
| `0x0067C548` | `procedure SetGUIEventStateOnAfterSaveMap(const aname: String)` |
| `0x0067DDB8` | `function GetGUIEventStateOnMouseWheel: String` |
| `0x0067DDDC` | `procedure SetGUIEventStateOnMouseWheel(const state: String)` |

### GUIExecuteState — 1

| VA | Объявление |
|---|---|
| `0x00674118` | `procedure GUIExecuteState(const state: String)` |

### GUIFloatValue — 4

| VA | Объявление |
|---|---|
| `0x00673F3C` | `procedure SetGUIFloatValue(const key: String; value: Float)` |
| `0x00673F64` | `function GetGUIFloatValue(const key: String): Float` |
| `0x00674078` | `function GetGUIFloatValueInd(index: Integer): Float` |
| `0x006740A4` | `procedure SetGUIFloatValueInd(index: Integer; value: Float)` |

### GUIFocused — 1

| VA | Объявление |
|---|---|
| `0x00678894` | `function GetGUIFocusedElementHandle: Integer` |

### GUIFont — 6

| VA | Объявление |
|---|---|
| `0x006778B8` | `function GetGUIFontCharOffsetX(const fontname: String; const ch: Integer): Integer` |
| `0x00677928` | `procedure SetGUIFontCharOffsetX(const fontname: String; const ch, val: Integer)` |
| `0x00677994` | `function GetGUIFontCharWidth(const fontname: String; const ch: Integer): Integer` |
| `0x00677A0C` | `procedure SetGUIFontCharWidth(const fontname: String; const ch, val: Integer)` |
| `0x0067DE14` | `function GetGUIFontCollectionFileName: String` |
| `0x0067DE34` | `procedure SetGUIFontCollectionFileName(const val: String)` |

### GUIHintWait — 2

| VA | Объявление |
|---|---|
| `0x0067C630` | `procedure SetGUIHintWaitDelay(const val: Float)` |
| `0x0067C650` | `function GetGUIHintWaitDelay: Float` |

### GUIIntValue — 4

| VA | Объявление |
|---|---|
| `0x00673EF0` | `procedure SetGUIIntValue(const key: String; value: Integer)` |
| `0x00673F18` | `function GetGUIIntValue(const key: String): Integer` |
| `0x0067402C` | `function GetGUIIntValueInd(index: Integer): Integer` |
| `0x00674050` | `procedure SetGUIIntValueInd(index: Integer; value: Integer)` |

### GUIInternalMouseEnter — 1

| VA | Объявление |
|---|---|
| `0x0067CAA4` | `procedure GUIInternalMouseEnter(index: Integer)` |

### GUIInvalidate — 2

| VA | Объявление |
|---|---|
| `0x006788C0` | `procedure GUIInvalidateChildrenPositions(aindex: Integer)` |
| `0x006788F4` | `procedure GUIInvalidateParentPositions(aindex: Integer)` |

### GUIInvokeMouseMove — 1

| VA | Объявление |
|---|---|
| `0x0067C6EC` | `procedure GUIInvokeMouseMove` |

### GUIKey — 4

| VA | Объявление |
|---|---|
| `0x0067C5B8` | `procedure SetGUIKeyRepeatDelay(const val: Float)` |
| `0x0067C5D8` | `function GetGUIKeyRepeatDelay: Float` |
| `0x0067C5F4` | `procedure SetGUIKeyDoubleDelay(const val: Float)` |
| `0x0067C614` | `function GetGUIKeyDoubleDelay: Float` |

### GUIListBox — 42

| VA | Объявление |
|---|---|
| `0x006794D0` | `procedure SetGUIListBoxWideMode(index: Integer; amode: Boolean)` |
| `0x00679524` | `function GetGUIListBoxWideMode(index: Integer): Boolean` |
| `0x00679578` | `procedure SetGUIListBoxSelectedMaterialName(index: Integer; const amaterial: String)` |
| `0x006795D0` | `procedure SetGUIListBoxScrollerMaterialName(index: Integer; const amaterial: String)` |
| `0x0067962C` | `procedure SetGUIListBoxMouseTrackMaterialName(index: Integer; const amaterial: String)` |
| `0x00679684` | `procedure SetGUIListBoxMouseTrackFontColor(index: Integer; r: Float; g: Float; b: Float; a: Float)` |
| `0x006796F8` | `function GetGUIListBoxItemsCount(index: Integer): Integer` |
| `0x0067974C` | `procedure GUIListBoxClear(index: Integer)` |
| `0x0067979C` | `procedure GUIListBoxClearSilent(index: Integer)` |
| `0x00679828` | `procedure GUIListBoxAddItem(index: Integer; const avalue: String; atag: Integer)` |
| `0x00679880` | `procedure GUIListBoxAddWideItem(index: Integer; arg: Integer; atag: Integer)` |
| `0x006798F0` | `procedure GUIListBoxInsertItem(index: Integer; aitemindex: Integer; const avalue: String; atag: Integer)` |
| `0x0067994C` | `procedure GUIListBoxInsertWideItem(index: Integer; aitemindex: Integer; arg: Integer; atag: Integer)` |
| `0x006799C0` | `procedure GUIListBoxDeleteItem(index: Integer; aitemindex: Integer)` |
| `0x00679A14` | `procedure GUIListBoxDeleteItemSilent(index: Integer; aitemindex: Integer)` |
| `0x00679AA4` | `procedure SetGUIListBoxItemValue(index: Integer; aitemindex: Integer; const aitemvalue: String)` |
| `0x00679AFC` | `procedure SetGUIListBoxItemWideValue(index: Integer; aitemindex: Integer; arg: Integer)` |
| `0x00679B6C` | `function GetGUIListBoxItemValue(index: Integer; aitemindex: Integer): String` |
| `0x00679BD8` | `procedure GetGUIListBoxItemWideValue(index: Integer; aitemindex: Integer; arg: Integer)` |
| `0x00679C98` | `procedure SetGUIListBoxItemTag(index: Integer; aitemindex: Integer; aitemtag: Integer)` |
| `0x00679CF0` | `function GetGUIListBoxItemTag(index: Integer; aitemindex: Integer): Integer` |
| `0x00679D48` | `procedure SetGUIListBoxTopIndex(index: Integer; aitemindex: Integer)` |
| `0x00679D9C` | `function GetGUIListBoxTopIndex(index: Integer): Integer` |
| `0x00679DF0` | `procedure SetGUIListBoxItemIndex(index: Integer; aitemindex: Integer)` |
| `0x00679E60` | `procedure SetGUIListBoxItemIndexSilent(index: Integer; aitemindex: Integer)` |
| `0x00679EF0` | `function GetGUIListBoxItemIndex(index: Integer): Integer` |
| `0x00679F44` | `function GetGUIListBoxItemIndexOfValue(index: Integer; const avalue: String): Integer` |
| `0x00679F9C` | `function GetGUIListBoxItemIndexOfWideValue(index: Integer; arg: Integer): Integer` |
| `0x0067A010` | `function GetGUIListBoxItemIndexOfTag(index: Integer; atag: Integer): Integer` |
| `0x0067A0E4` | `procedure SetGUIListBoxRowHeight(index: Integer; arowheight: Integer)` |
| `0x0067A138` | `function GetGUIListBoxRowHeight(index: Integer): Integer` |
| `0x0067A190` | `procedure SetGUIListBoxVisibleRows(index: Integer; avisiblerows: Integer)` |
| `0x0067A1E4` | `function GetGUIListBoxVisibleRows(index: Integer): Integer` |
| `0x0067A28C` | `function GetGUIListBoxComboBoxHandle(index: Integer): Integer` |
| `0x0067A2DC` | `function GetGUIListBoxScrollerHandle(index: Integer): Integer` |
| `0x0067A330` | `procedure SetGUIListBoxMouseTrack(index: Integer; atrack: Integer)` |
| `0x0067A38C` | `procedure SetGUIListBoxItemsFromActiveParser(index: Integer)` |
| `0x0067A448` | `procedure GetGUIListBoxItemsToActiveParser(index: Integer)` |
| `0x0067A558` | `function GetGUIListBoxTabsCount(index: Integer): Integer` |
| `0x0067A5AC` | `procedure GetGUIListBoxTabProperty(index: Integer; atabindex: Integer; var cr, cb, cg, ca: Float; var width: Integer)` |
| `0x0067A65C` | `procedure AddGUIListBoxTabProperty(index: Integer; cr, cb, cg, ca: Float; width: Integer; const atabstyle: String)` |
| `0x0067A6E4` | `procedure DeleteGUIListBoxTab(index: Integer; atabindex: Integer)` |

### GUILoadProgressBar — 5

| VA | Объявление |
|---|---|
| `0x006763C0` | `procedure SetGUILoadProgressBarActiveIndex(index: Integer)` |
| `0x006763D8` | `procedure SetGUILoadProgressBarActiveName(const name: String)` |
| `0x00676498` | `function GetGUILoadProgressBarActiveIndex(): Integer` |
| `0x006764A8` | `function GetGUILoadProgressBarActiveName(): String` |
| `0x0067652C` | `procedure ReloadGUILoadProgressBar()` |

### GUIMiniMap — 42

| VA | Объявление |
|---|---|
| `0x00674A38` | `function GetGUIMiniMapVisible(): Boolean` |
| `0x00674A50` | `procedure SetGUIMiniMapVisible(visible: Boolean)` |
| `0x00674BE4` | `procedure GUIMiniMapUpdate()` |
| `0x00674C00` | `function GetGUIMiniMapWidth(): Float` |
| `0x00674C24` | `function GetGUIMiniMapHeight(): Float` |
| `0x00674C48` | `procedure SetGUIMiniMapWidth(width: Float)` |
| `0x00674C6C` | `procedure SetGUIMiniMapHeight(height: Float)` |
| `0x00674C90` | `procedure SetGUIMiniMapTextureSize(width, height: Integer)` |
| `0x00674CD0` | `function GetGUIMiniMapTextureWidth(): Integer` |
| `0x00674CEC` | `function GetGUIMiniMapTextureHeight(): Integer` |
| `0x00674D08` | `procedure GUIMiniMapSaveToBitmap(const filename: String)` |
| `0x00674D2C` | `function GetGUIMiniMapUseCustomMaterial: Boolean` |
| `0x00674D48` | `procedure SetGUIMiniMapUseCustomMaterial(const val: Boolean)` |
| `0x00674D6C` | `procedure GUIMiniMapLoadCustomMaterialFromTextFile(const filename: String)` |
| `0x00674D90` | `procedure GUIMiniMapLoadCustomTextureFromImageFile(const filename: String)` |
| `0x00674DB4` | `function GetGUIMiniMapVAlign(): String` |
| `0x00674DDC` | `function GetGUIMiniMapHAlign(): String` |
| `0x00674E04` | `procedure SetGUIMiniMapVAlign(const valign: String)` |
| `0x00674E30` | `procedure SetGUIMiniMapHAlign(const halign: String)` |
| `0x00674E5C` | `function GetGUIMiniMapPositionX(): Float` |
| `0x00674E80` | `function GetGUIMiniMapPositionY(): Float` |
| `0x00674EA4` | `function GetGUIMiniMapPositionZ(): Float` |
| `0x00674EC8` | `procedure SetGUIMiniMapPosition(x: Float; y: Float; z: Float)` |
| `0x006760A0` | `function CreateGUIMiniMapPrimitive(const name: String): Integer` |
| `0x006760D0` | `procedure SetGUIMiniMapPrimitivePosition(index: Integer; x: Float; y: Float)` |
| `0x00676104` | `procedure SetGUIMiniMapPrimitiveDirection(index: Integer; x: Float; y: Float)` |
| `0x00676138` | `procedure SetGUIMiniMapPrimitiveTag(index: Integer; tag: Integer)` |
| `0x00676164` | `procedure SetGUIMiniMapPrimitiveName(index: Integer; const aname: String)` |
| `0x006761C4` | `procedure SetGUIMiniMapPrimitiveBlink(index: Integer; ainterval: Float; acount: Integer)` |
| `0x0067621C` | `procedure SetGUIMiniMapPrimitiveVisible(index: Integer; vis: Boolean)` |
| `0x00676248` | `procedure GUIMiniMapPrimitivesClear()` |
| `0x00676264` | `procedure RemoveGUIMiniMapPrimitive(index: Integer)` |
| `0x006762A0` | `function GetGUIMiniMapPrimitiveTag(index: Integer): Integer` |
| `0x006762D0` | `function GetGUIMiniMapPrimitiveVisible(index: Integer): Boolean` |
| `0x00676300` | `function GetGUIMiniMapPrimitivesCount(): Integer` |
| `0x0067631C` | `function GetGUIMiniMapPrimitiveIndexOfTag(atag: Integer): Integer` |
| `0x0067DEC0` | `procedure GUIMiniMapExcludePlayersClear` |
| `0x0067DEE0` | `procedure GUIMiniMapExcludePlayersAdd(const playername: String)` |
| `0x0067DF98` | `procedure GUIMiniMapIncludePlayersClear` |
| `0x0067DFB8` | `procedure GUIMiniMapIncludePlayersAdd(const playername: String)` |
| `0x0067E070` | `function GetGUIMiniMapLayer: Integer` |
| `0x0067E08C` | `procedure SetGUIMiniMapLayer(i: Integer)` |

### GUIMouse — 1

| VA | Объявление |
|---|---|
| `0x0067C6FC` | `procedure GUIMouseMove(x, y: Integer)` |

### GUIPageControl — 5

| VA | Объявление |
|---|---|
| `0x0067A738` | `function GetGUIPageControlAddNewPage(aindex: Integer; const sname: String; atag: Integer): Integer` |
| `0x0067A780` | `procedure GUIPageControlRemovePage(aindex: Integer; const sname: String)` |
| `0x0067A7B8` | `function GetGUIPageControlActivePage(aindex: Integer): Integer` |
| `0x0067A7F0` | `procedure SetGUIPageControlActivePageByName(aindex: Integer; const spagename: String)` |
| `0x0067A828` | `procedure SetGUIPageControlActivePage(aindex: Integer; apageindex: Integer)` |

### GUIPrepareLoad — 1

| VA | Объявление |
|---|---|
| `0x0067C56C` | `procedure GUIPrepareLoad` |

### GUIProgress — 8

| VA | Объявление |
|---|---|
| `0x006754CC` | `procedure GUIProgressShortcuts` |
| `0x006764D8` | `function GetGUIProgressBarElementHandle(): Integer` |
| `0x0067C66C` | `function GetGUIProgressInterval: Integer` |
| `0x0067C680` | `procedure SetGUIProgressInterval(const val: Integer)` |
| `0x0067E0D8` | `function GetGUIProgressControlThread: Boolean` |
| `0x0067E0EC` | `procedure SetGUIProgressControlThread(const v: Boolean)` |
| `0x0067E108` | `function GetGUIProgressControlPriority: Integer` |
| `0x0067E120` | `procedure SetGUIProgressControlPriority(const v: Integer)` |

### GUIResetFonts — 1

| VA | Объявление |
|---|---|
| `0x0067DE50` | `procedure GUIResetFonts` |

### GUISaveProgressBar — 5

| VA | Объявление |
|---|---|
| `0x0067640C` | `procedure SetGUISaveProgressBarActiveIndex(index: Integer)` |
| `0x00676424` | `procedure SetGUISaveProgressBarActiveName(const name: String)` |
| `0x00676458` | `function GetGUISaveProgressBarActiveIndex(): Integer` |
| `0x00676468` | `function GetGUISaveProgressBarActiveName(): String` |
| `0x006765A8` | `procedure ReloadGUISaveProgressBar()` |

### GUIScroll — 8

| VA | Объявление |
|---|---|
| `0x00677F98` | `procedure SetGUIScrollButtonSource(index: Integer; buttonid: Integer; const source: String; autoalign: Boolean)` |
| `0x006782A0` | `procedure SetGUIScrollBarPosition(index: Integer; apos: Float)` |
| `0x006782D8` | `function GetGUIScrollBarPosition(index: Integer): Float` |
| `0x0067831C` | `procedure SetGUIScrollBarAutoScrollSpeed(index: Integer; aspeed: Float)` |
| `0x00678354` | `function GetGUIScrollBarAutoScrollSpeed(index: Integer): Float` |
| `0x00678458` | `procedure SetGUIScrollEnabled(index: Integer; enabled: Boolean)` |
| `0x00678490` | `function GetGUIScrollEnabled(index: Integer): Boolean` |
| `0x006786B0` | `function GetGUIScrollWindowScrollerVisible(index: Integer; byhoriz: Boolean): Boolean` |

### GUISelection — 2

| VA | Объявление |
|---|---|
| `0x00675848` | `procedure SetGUISelectionEnable(enable: Boolean)` |
| `0x00675850` | `function GetGUISelectionEnable(): Boolean` |

### GUISetup — 3

| VA | Объявление |
|---|---|
| `0x00676958` | `procedure GUISetupElementFromFile(index: Integer; const filename: String)` |
| `0x00676990` | `procedure GUISetupElementFromCollection(index: Integer; const itemname: String)` |
| `0x0067BC30` | `procedure GUISetupDataViewerZone(raycastenabled: Boolean; size, offset, step: Float)` |

### GUIShiftState — 7

| VA | Объявление |
|---|---|
| `0x00675374` | `function GetGUIShiftStateLeft(): Boolean` |
| `0x00675390` | `function GetGUIShiftStateRight(): Boolean` |
| `0x006753AC` | `function GetGUIShiftStateMiddle(): Boolean` |
| `0x006753C8` | `function GetGUIShiftStateDouble(): Boolean` |
| `0x006753E4` | `function GetGUIShiftStateShift(): Boolean` |
| `0x00675400` | `function GetGUIShiftStateAlt(): Boolean` |
| `0x0067541C` | `function GetGUIShiftStateCtrl(): Boolean` |

### GUIShortcut — 6

| VA | Объявление |
|---|---|
| `0x006767C0` | `procedure RegisterGUIShortcut(bignorefocus: Boolean; const name: String; const shortcut: String; const presstype: String; const executestate: String; tag: Integer)` |
| `0x0067682C` | `function GetRegisterGUIShortcut(const name: String): String` |
| `0x00676870` | `function IsGUIShortcutPressed(const name: String): Boolean` |
| `0x0067689C` | `procedure RegisterGUIShortcutIgnoreShift(bignorefocus: Boolean; const name: String; const shortcut: String; const signoreshift: String; const presstype: String; const executestate: String; tag: Integer)` |
| `0x006768D4` | `procedure UnregisterGUIShortcut(const name: String)` |
| `0x00676904` | `procedure EmulateGUIShortcut(const name: String)` |

### GUIShowCursor — 1

| VA | Объявление |
|---|---|
| `0x0067DE68` | `procedure GUIShowCursor(show: Boolean)` |

### GUIStore — 1

| VA | Объявление |
|---|---|
| `0x00676920` | `procedure GUIStoreElementToFile(index: Integer; const filename: String)` |

### GUIStretchBrush — 1

| VA | Объявление |
|---|---|
| `0x00676A90` | `procedure SetGUIStretchBrushRenderAddMode(bvalue: Boolean)` |

### GUITestElementUnderMouse — 1

| VA | Объявление |
|---|---|
| `0x0067CAF8` | `function GUITestElementUnderMouse: Integer` |

### GUITexture — 2

| VA | Объявление |
|---|---|
| `0x0067C7D8` | `function GetGUITextureWidth(const libmaterialname: String): Integer` |
| `0x0067C894` | `function GetGUITextureHeight(const libmaterialname: String): Integer` |

### GUIUpdateElementUnderMouse — 1

| VA | Объявление |
|---|---|
| `0x0067CB0C` | `function GUIUpdateElementUnderMouse: Integer` |

### GUIUpdateKeys — 2

| VA | Объявление |
|---|---|
| `0x006754B4` | `procedure GUIUpdateKeys` |
| `0x006754C0` | `function GUIUpdateKeysUpState: Boolean` |

### GUIValue — 4

| VA | Объявление |
|---|---|
| `0x00673EA0` | `procedure SetGUIValue(const key: String; const value: String)` |
| `0x00673EC8` | `function GetGUIValue(const key: String): String` |
| `0x00673FDC` | `procedure SetGUIValueInd(index: Integer; const value: String)` |
| `0x00674004` | `function GetGUIValueInd(index: Integer): String` |

### GUIVisibleStretchBrush — 3

| VA | Объявление |
|---|---|
| `0x006769D0` | `procedure SetGUIVisibleStretchBrushVisualizer(plhandle: Integer; busetarget: Boolean)` |
| `0x00676A60` | `function GetGUIVisibleStretchBrushVisualizer(): Boolean` |
| `0x00676A74` | `procedure SetGUIVisibleStretchBrushRender(brender: Boolean)` |

### GUIWrapped — 4

| VA | Объявление |
|---|---|
| `0x00677A40` | `function GetGUIWrappedTextByFont(const fontname: String; const text: String; width: Integer): String` |
| `0x00677AE0` | `procedure GetGUIWrappedWideTextByFont(const fontname: String; arg: Integer; width: Integer)` |
| `0x0067CCC8` | `function GetGUIWrappedTextFormatByFont(const fontname, text: String; width: Integer): String` |
| `0x0067CD68` | `procedure GetGUIWrappedWideTextFormatByFont(const fontname: String; arg, width: Integer)` |

### GameObject — 3

| VA | Объявление |
|---|---|
| `0x0067AD94` | `function GetGUIGroupHUDCollectionItemByGameObject(aindex: Integer; agameobject: Integer):Integer` |
| `0x0067ADD0` | `function GUIGroupHUDCollectionAddGameObject(aindex: Integer; agameobject: Integer):Integer` |
| `0x0067AE10` | `procedure GUIGroupHUDCollectionDeleteGameObject(aindex: Integer; agameobject: Integer)` |

### Group — 21

| VA | Объявление |
|---|---|
| `0x0067A884` | `procedure SetGUIGroupHUDReset(aindex: Integer)` |
| `0x0067A8D8` | `procedure SetGUIGroupHUDAutoDestroy(aindex: Integer; avalue: Boolean)` |
| `0x0067A930` | `procedure SetGUIGroupHUDMinDistance(aindex: Integer; avalue: Float)` |
| `0x0067A988` | `procedure SetGUIGroupHUDMidDistance(aindex: Integer; avalue: Float)` |
| `0x0067A9E0` | `procedure SetGUIGroupHUDMaxDistance(aindex: Integer; avalue: Float)` |
| `0x0067AA38` | `procedure SetGUIGroupHUDMaxScaleDistance(aindex: Integer; avalue: Float)` |
| `0x0067AA90` | `procedure SetGUIGroupHUDMinScaleDistance(aindex: Integer; avalue: Float)` |
| `0x0067AAE8` | `procedure SetGUIGroupHUDMinScale(aindex: Integer; avalue: Float)` |
| `0x0067AB40` | `procedure SetGUIGroupHUDMaxScale(aindex: Integer; avalue: Float)` |
| `0x0067AB98` | `procedure SetGUIGroupHUDAlwaysShow (aindex: Integer; avalue: Boolean)` |
| `0x0067ABF0` | `procedure SetGUIGroupHUDTerrainOffset(aindex: Integer; avalue: Float)` |
| `0x0067AC48` | `function GetGUIGroupHUDCollectionItemByGroup(aindex: Integer; agroup: Integer):Integer` |
| `0x0067AC90` | `function GUIGroupHUDCollectionAddGroup(aindex: Integer; agroup: Integer):Integer` |
| `0x0067ACD8` | `procedure GUIGroupHUDCollectionDeleteGroup(aindex: Integer; agroup: Integer)` |
| `0x0067AD60` | `procedure GUIGroupHUDCollectionClear(aindex: Integer)` |
| `0x0067AE48` | `procedure SetGUIGroupHUDEnabled(aindex: Integer; avalue: Boolean)` |
| `0x0067AE80` | `procedure GUIGroupHUDRestrictLinesClear(aindex: Integer)` |
| `0x0067AEB4` | `procedure SetGUIGroupHUDRestrictLinesAddBottom(aindex: Integer; x1, x2, y: Integer)` |
| `0x0067AEF4` | `procedure SetGUIGroupHUDRestrictLinesAddTop(aindex: Integer; x1, x2, y: Integer)` |
| `0x0067AF34` | `procedure SetGUIGroupHUDRestrictLinesAddLeft(aindex: Integer; y1, y2, x: Integer)` |
| `0x0067AF74` | `procedure SetGUIGroupHUDRestrictLinesAddRight(aindex: Integer; y1, y2, x: Integer)` |

### GroupDataViewer — 42

| VA | Объявление |
|---|---|
| `0x00678B50` | `procedure GUISetGroupDataViewerMatName(const matname:String)` |
| `0x00678B98` | `procedure GUISetGroupDataViewerBlinked(avalue:boolean)` |
| `0x00678BBC` | `procedure GUISetGroupDataViewerBlinkingCount(avalue:integer)` |
| `0x00678BE0` | `procedure GUISetGroupDataViewerBlinkingFreq(avalue:Float)` |
| `0x00678C04` | `procedure GUISetGroupDataViewerFade(avalue:boolean)` |
| `0x00678C28` | `procedure GUISetGroupDataViewerFadeCount(avalue:integer)` |
| `0x00678C4C` | `procedure GUISetGroupDataViewerFadeFreq(avalue:Float)` |
| `0x00678C70` | `procedure GUISetGroupDataViewerSize(avalue:Float)` |
| `0x00678C94` | `procedure GUISetGroupDataViewerMinDistance(avalue:Float)` |
| `0x00678CB8` | `procedure GUISetGroupDataViewerMidDistance(avalue:Float)` |
| `0x00678CDC` | `procedure GUISetGroupDataViewerMaxDistance(avalue:Float)` |
| `0x00678D00` | `procedure GUISetGroupDataViewerAutoDestroy(avalue:Boolean)` |
| `0x00678D24` | `procedure GUIAddGroupDataViewer(agrhandle:integer)` |
| `0x00678D64` | `procedure GUIDeleteGroupDataViewer(agrhandle:integer)` |
| `0x00678DA0` | `function GUIGetGroupDataViewerExist(agrhandle:integer):Boolean` |
| `0x00678DE8` | `procedure GUIAddGroupDataViewerFixed(agrhandle:integer)` |
| `0x00678E28` | `procedure GUIDeleteGroupDataViewerFixed(agrhandle:integer)` |
| `0x00678E8C` | `function GUIGetGroupDataViewerFixedExist(agrhandle:integer):Boolean` |
| `0x00678ED4` | `procedure GUIClearGroupDataViewerFixed` |
| `0x00678EF4` | `procedure GUIClearGroupDataViewer()` |
| `0x00678F14` | `procedure GUIFullClearGroupDataViewer` |
| `0x00678F30` | `procedure GUIAddGroupDataViewerZone(agrhandle:integer)` |
| `0x00678F6C` | `procedure GUIDeleteGroupDataViewerZone(agrhandle:integer)` |
| `0x00678FB0` | `function GUIGetGroupDataViewerZoneExist(agrhandle:integer):Boolean` |
| `0x00678FF8` | `procedure GUIClearGroupDataViewerZones` |
| `0x00679018` | `procedure GUISetCurrentGroupDataViewerSelectionByPlayerHandle(aplhandle:integer)` |
| `0x0067904C` | `procedure GUIClearAllPlayersGroupDataViewerSelection` |
| `0x00679068` | `procedure GUIClearGroupDataViewerCurrentSelection` |
| `0x006790A4` | `procedure GUIAddGroupDataViewerCurrentSelection(agrhandle:integer)` |
| `0x006790F8` | `procedure GUIDeleteGroupDataViewerCurrentSelection(agrhandle:integer)` |
| `0x0067914C` | `function GUIGetGroupDataViewerCurrentSelectionExist(agrhandle:integer):Boolean` |
| `0x006791AC` | `procedure GUICurrentGroupDataViewerSelectionApplyProperties` |
| `0x006791E8` | `procedure GUISetGroupDataViewerCurrentSelectionEnabled(avalue: Boolean)` |
| `0x0067922C` | `procedure GUICurrentGroupDataViewerSelectionBorderRayCastEnabled(araycastenabled: boolean)` |
| `0x00679270` | `procedure GUICurrentGroupDataViewerSelectionBorderColorInside(r: Float; g: Float; b: Float; a: Float)` |
| `0x006792D4` | `procedure GUICurrentGroupDataViewerSelectionBorderColorOutside(r: Float; g: Float; b: Float; a: Float)` |
| `0x00679338` | `procedure GUICurrentGroupDataViewerSelectionBorderSize(asize: Float)` |
| `0x0067937C` | `procedure GUICurrentGroupDataViewerSelectionBorderOffset(aoffset: Float)` |
| `0x006793C0` | `procedure GUICurrentGroupDataViewerSelectionBorderAngleStep(aanglestep: Float)` |
| `0x00679404` | `procedure GUICurrentGroupDataViewerSelectionBorderTouchLength(atouchlength: Float)` |
| `0x00679448` | `procedure GUICurrentGroupDataViewerSelectionBorderTouchEmptyLength(atouchemptylength: Float)` |
| `0x0067948C` | `procedure GUICurrentGroupDataViewerSelectionBorderTouchEnabled(atouchenabled: boolean)` |

### MiniMap — 4

| VA | Объявление |
|---|---|
| `0x00674F38` | `function GetMiniMapFrustumVisible(): Boolean` |
| `0x00674F54` | `procedure SetMiniMapFrustumVisible(frustumvisible: Boolean)` |
| `0x0067BF84` | `function GetGUIEventStateOnPressMiniMap: String` |
| `0x0067C3E0` | `procedure SetGUIEventStateOnPressMiniMap(const aname: String)` |

### NeedRestartGUI — 1

| VA | Объявление |
|---|---|
| `0x0067B730` | `procedure NeedRestartGUI` |

### Player — 7

| VA | Объявление |
|---|---|
| `0x0067AD1C` | `procedure GUIGroupHUDCollectionDeletePlayer(aindex: Integer; aplayer: Integer)` |
| `0x0067B714` | `procedure SetGUIPlayerByHandle(plhandle: Integer)` |
| `0x0067B78C` | `procedure GUIAddPlayerDataViewerZone(cplhandle: Integer)` |
| `0x0067B7C8` | `procedure GUIAddPlayerWithColorDataViewerZone(cplhandle: Integer; cinr, cing, cinb, cina, coutr, coutg, coutb, couta: Float)` |
| `0x0067B84C` | `procedure GUIDeletePlayerDataViewerZone(cplhandle: Integer)` |
| `0x0067B8B4` | `function GUIGetPlayerDataViewerZoneExist(cplhandle: Integer): Boolean` |
| `0x0067B91C` | `procedure GUIBuildRestrictPlayerDataViewerZones` |

### RebuildGUI — 3

| VA | Объявление |
|---|---|
| `0x006B7F44` | `procedure SetGameManagerSelectionRebuildGUICommands(const rebuild: Boolean)` |
| `0x006B7F60` | `function GetGameManagerSelectionRebuildGUICommands(): Boolean` |
| `0x006B7F74` | `procedure DoGameManagerSelectionRebuildGUI()` |

### ReloadGUI — 1

| VA | Объявление |
|---|---|
| `0x006C48FC` | `procedure StateMachineReloadGUI` |

### RemoveGUI — 1

| VA | Объявление |
|---|---|
| `0x006748E4` | `procedure RemoveGUIChildren(index: Integer)` |

### StateMachine — 1

| VA | Объявление |
|---|---|
| `0x006C4B00` | `function StateMachineGetGUISMHandle: Integer` |

## 4. Камера / окружение / рендер

Крутилки картинки из консоли. Пост-эффекты: `data/posteffects/posteffects.lib` (пресеты `default/winter/desaturate`, `DOF/SSAO/Gamma` по дефолту `False`), шейдеры `data/shaders/tone/*.frag`, свет `data/env/lights/light.cfg`, камеры `data/cameras/camera.cfg`. Рендер — OpenGL, точка хука кадра — `gdi32.SwapBuffers`.

### gfx — графика из Lua

Клиентским скриптам и консоли доступна таблица `gfx` (`core/GfxApi.*`): нативы графики из белого списка
как `gfx.SetShadowMapSize(4096)` плюс группы-обёртки. Графика — дело каждого компьютера: на ход партии
не влияет, поэтому разрешена клиенту и не требует `multiplayer = "required"`.

Группа читается вызовом без аргументов и пишется таблицей:

```lua
gfx.fog{ density = 2.0, power = 1.2, finish = 3000 }   -- записать (finish, т.к. end — ключевое слово)
local f = gfx.fog()                                    -- { enabled = true, density = 2.0, ... }
```

| Группа | Ключи |
| --- | --- |
| `post` | `preset` (запись в posteffects.lib), `preset2`, `ssao`, `dof` |
| `camera` | `dof`, `depth`, `dynamicFocal`, `focal {min,max,power}`, `sceneScale {x,y}`, `angle`, `distance`, `rotateSpeed`, `zoomSpeed`, `bounded`, `autoRayCast`, `wheelRotate`, `wheelZoom`, `profile`, `height` (чтение); методы `fovOf`, `focalOf` |
| `fog` | `enabled`, `density`, `power`, `start`, `finish`, `offset`, `depth` |
| `clouds` | `visible`, `active`, `height`, `horizon`, `fog`, `speed` |
| `sky` | `visible`, `active`, `flareAngle`, `flareZ`, `flare` |
| `shadows` | `enabled`, `size`, `scaleHeight`, `addHeight`, `lightDepth`, `polygonOffset {scale,bias}` |
| `light` | `pattern`, `index`, `blendTo`, `blendTime`; метод `list()` |
| `time` | `game`, `speed`, `season`, `dayNight`, `fogOfWarDay`, `current`/`total`/`real` (чтение) |
| `water` | `name`, `index`, `offset` (чтение) |
| `wind` | `vector {x,y,z}`, `target {x,y,z}`, `random`, `interval` |
| `terrain` | `visible`, `borders`, `bordersVisible`, `bordersStep`, `colorMode`; метод `setColor` |

Сверх групп: `gfx.pfx.brightness/gamma(менеджер [, значение])`, `gfx.highlight{...}`, `gfx.vsync([вкл])`,
`gfx.snapshot()` — снимок всего, что можно записать обратно, и `gfx.apply(профиль)` — применить целиком.
Опечатка в ключе и запись в поле «только чтение» дают ошибку сразу, а не молча ничего не делают.
Пример: `examples/mods/graphics_mod`.

### Camera — 138

| VA | Объявление |
|---|---|
| `0x005FEF88` | `procedure SetCameraProgressEnable(bval: Boolean)` |
| `0x005FEFA8` | `function GetCameraProgressEnable(): Boolean` |
| `0x005FEFBC` | `procedure SetCameraControlMode(const cameracontrolmode: String)` |
| `0x005FEFE0` | `function GetCameraControlMode(): String` |
| `0x005FF000` | `procedure SetCameraControlMouseWheelRotate(val : Boolean)` |
| `0x005FF01C` | `procedure SetCameraControlMouseWheelDistance(val : Boolean)` |
| `0x005FF038` | `function GetCameraControlMouseWheelRotate : Boolean` |
| `0x005FF04C` | `function GetCameraControlMouseWheelDistance : Boolean` |
| `0x005FF060` | `procedure SetCameraTrackListEnable(enable: Boolean)` |
| `0x005FF08C` | `function GetCameraTrackListEnable(): Boolean` |
| `0x005FF0AC` | `procedure SetCameraTrackMovementMode(const name: String; const movementmode: String)` |
| `0x005FF128` | `function GetCameraTrackMovementMode(const name: String): String` |
| `0x005FF16C` | `function GetCameraCurrentTrackIndex(): Integer` |
| `0x005FF18C` | `function GetCameraTrackListCount(): Integer` |
| `0x005FF1B0` | `procedure CameraTrackListClear()` |
| `0x005FF1D0` | `procedure CameraTrackClear(const name: String)` |
| `0x005FF1FC` | `procedure DeleteCameraTrack(index: Integer)` |
| `0x005FF224` | `procedure DeleteCameraTrackPointByIndex(const name: String; index: Integer)` |
| `0x005FF254` | `function GetCameraTrackNameByIndex(index: Integer): String` |
| `0x005FF294` | `function GetCameraTrackIndexByName(const name: String): Integer` |
| `0x005FF2D4` | `procedure SetCameraCurrentTrackIndex(currenttrackindex: Integer)` |
| `0x005FF300` | `procedure SetMainCameraRotateXYZ(x: Float; y: Float; z: Float)` |
| `0x005FF348` | `procedure SetMainCameraRotateToTargetDir(rotatetotargetdir: Boolean)` |
| `0x005FF368` | `procedure SetMainCameraPositionXZ(x: Float; z: Float)` |
| `0x005FF39C` | `procedure SetMainCameraMoveToTargetXZ(x: Float; z: Float)` |
| `0x005FF3E4` | `procedure SetMainCameraMoveToTarget(val: Boolean)` |
| `0x005FF400` | `function GetMainCameraMoveToTarget: Boolean` |
| `0x005FF414` | `procedure SetMainCameraMoveToTargetSpeed(val: Float)` |
| `0x005FF434` | `function GetMainCameraMoveToTargetSpeed: Float` |
| `0x005FF450` | `procedure GetCameraAbsoluteLeftDirection(var x: Float; var y: Float; var z: Float)` |
| `0x005FF488` | `procedure GetCameraAbsoluteRightDirection(var x: Float; var y: Float; var z: Float)` |
| `0x005FF4C8` | `procedure GetCameraAbsoluteForwardDirection(var x: Float; var y: Float; var z: Float)` |
| `0x005FF500` | `procedure GetCameraAbsoluteBackwardDirection(var x: Float; var y: Float; var z: Float)` |
| `0x005FF540` | `procedure GetCameraAbsolutePosition(var x: Float; var y: Float; var z: Float)` |
| `0x005FF594` | `procedure GetCameraPosition(var x: Float; var y: Float; var z: Float)` |
| `0x005FF5C8` | `procedure GetCameraTargetPosition(var x: Float; var y: Float; var z: Float)` |
| `0x005FF600` | `function GetCameraElasticDistance(): Float` |
| `0x005FF61C` | `procedure SetCameraElasticMoveDirection(x: Float; y: Float; z: Float)` |
| `0x005FF664` | `procedure SetCameraElasticDistance(dist: Float)` |
| `0x005FF680` | `procedure SetCameraElasticRotateFactor(factor: Float)` |
| `0x005FF6B4` | `procedure SetCameraElasticVRotateFactor(factor: Float)` |
| `0x005FF6E8` | `procedure SetCameraElasticMoveFactor(factor: Float)` |
| `0x005FF708` | `procedure SetCameraElasticMoveTurnOff()` |
| `0x005FF720` | `procedure SetCameraElasticRotationTurnOff()` |
| `0x005FF74C` | `procedure SetCameraElasticTargetObject(gohandle: Integer)` |
| `0x005FF794` | `function GetCameraElasticTargetObject(): Integer` |
| `0x005FF7A8` | `function GetCameraElasticAbsoluteHeightByXZ(x: Float; z: Float): Float` |
| `0x005FF810` | `function GetCameraAbsoluteHeightByXZ(x: Float; z: Float): Float` |
| `0x005FF850` | `function AddCameraTrack(): Integer` |
| `0x005FF884` | `procedure AddCameraTrackPoint(const name: String; targetx: Float; targety: Float; targetz: Float; eyex: Float; eyey: Float; eyez: Float)` |
| `0x005FF910` | `procedure InsertCameraTrackPoint(const name: String; index: Integer; targetx: Float; targety: Float; targetz: Float; eyex: Float; eyey: Float; eyez: Float)` |
| `0x005FF9A0` | `procedure SetCameraTrackAccelerationFactor(const name: String; accelerationfactor: Float)` |
| `0x005FF9D0` | `procedure SetCameraTrackSmoothMoveStepInterval(const name: String; smoothmovestepinterval: Integer)` |
| `0x005FFA00` | `procedure SetCameraTrackSmoothMoveStep(const name: String; smoothmovestep: Float)` |
| `0x005FFA30` | `procedure SetCameraTrackSmoothMoveTime(const name: String; time: Float)` |
| `0x005FFA64` | `procedure SetCameraTrackSmoothLocalMoveTime(const name: String; time: Float)` |
| `0x005FFA98` | `procedure SetCameraTrackSmoothLocalMoveStepInterval(const name: String; smoothlocalmovestepinterval: Integer)` |
| `0x005FFAC8` | `procedure SetCameraTrackSmoothLocalMoveStep(const name: String; smoothlocalmovestep: Float)` |
| `0x005FFAFC` | `procedure SetCameraTrackSmooth(const name: String; smooth: Boolean)` |
| `0x005FFB30` | `function GetCameraTrackSmooth(const name: String): Boolean` |
| `0x005FFB68` | `function GetCameraTrackSmoothMoveTime(const name: String): Float` |
| `0x005FFBA8` | `function GetCameraTrackSmoothLocalMoveTime(const name: String): Float` |
| `0x005FFBE8` | `procedure SetCameraMoveSpeedToMark(movespeedtomark: Float)` |
| `0x005FFC10` | `function GetCameraMoveSpeedToMark(): Float` |
| `0x005FFC40` | `procedure SetCameraTurnSpeedToMark(turnspeedtomark: Float)` |
| `0x005FFC68` | `function GetCameraTurnSpeedToMark(): Float` |
| `0x005FFC98` | `procedure SetCameraRelativeMarkQuarter(const relativemarkquarter: String)` |
| `0x005FFCC8` | `function GetCameraRelativeMarkQuarter(): String` |
| `0x005FFD04` | `procedure SetCameraMoveToMarkObject(movetomarkobject: Boolean)` |
| `0x005FFD2C` | `function GetCameraMoveToMarkObject(): Boolean` |
| `0x005FFD50` | `procedure SetCameraTurnToMarkObject(turntomarkobject: Boolean)` |
| `0x005FFD78` | `function GetCameraTurnToMarkObject(): Boolean` |
| `0x005FFD9C` | `procedure SetCameraMarkObjectByHandle(gohandle: integer)` |
| `0x005FFDD0` | `function GetCameraMarkObjectHandle(): integer` |
| `0x005FFDF4` | `procedure SetCameraAutoRayCast(autoraycast: Boolean)` |
| `0x005FFE1C` | `function GetCameraAutoRayCast(): Boolean` |
| `0x00600608` | `procedure SetCameraElasticRestrict(leftx: Float; topy: Float; rightx: Float; bottomy: Float)` |
| `0x00600664` | `procedure GetCameraElasticRestrict(var leftx: Float; var topy: Float; var rightx: Float; var bottomy: Float)` |
| `0x006006B4` | `function IsCameraMoveToPosition(): Boolean` |
| `0x006006C8` | `procedure SetCameraElasticTargetDistance(dist: Float)` |
| `0x006006E4` | `function GetCameraElasticTargetDistance(): Float` |
| `0x00600700` | `procedure SetCameraElasticTargetAngle(angle: Float)` |
| `0x0060071C` | `function GetCameraElasticTargetAngle(): Float` |
| `0x00600774` | `function GetCameraBounded(): Boolean` |
| `0x00600788` | `procedure SetCameraBounded(bounded: Boolean)` |
| `0x006007A4` | `function GetCameraHeightTarget : Float` |
| `0x006007C0` | `procedure SetCameraPropertiesFromFile(const sfilename: String)` |
| `0x006007DC` | `function GetCameraPropertieFileName: String` |
| `0x006007FC` | `function GetCameraExist(const cameraname: String) : boolean` |
| `0x00600840` | `function GetCameraFreeRotationMode() : Boolean` |
| `0x00600854` | `function GetCameraDistanceToTargetObject() : Float` |
| `0x00600884` | `function GetCameraDynamicFocalLength() : Boolean` |
| `0x00600898` | `procedure SetCameraDynamicFocalLength(adynamicfocallength : Boolean)` |
| `0x006008B8` | `procedure SetCameraElasticModesTargetRayCast(val : Boolean)` |
| `0x006008D4` | `procedure SetCameraElasticModesCameraRayCast(val : Boolean)` |
| `0x006009E8` | `function GetCameraDepthOfView() : Float` |
| `0x00600A04` | `procedure SetCameraDepthOfView(const d : Float)` |
| `0x00600A20` | `function GetCameraDynamicDOF() : Boolean` |
| `0x00600A34` | `procedure SetCameraDynamicDOF(const dynamicdof : Boolean)` |
| `0x00600A54` | `function GetCameraDynFogDepth() : Boolean` |
| `0x00600A68` | `procedure SetCameraDynFogDepth(const val : Boolean)` |
| `0x00600A88` | `function GetCameraDynFogStart() : Float` |
| `0x00600AA4` | `procedure SetCameraDynFogStart(const val : Float)` |
| `0x00600AC4` | `function GetCameraDynFogEnd() : Float` |
| `0x00600AE0` | `procedure SetCameraDynFogEnd(const val : Float)` |
| `0x00600B00` | `function GetCameraDynFogDensity() : Float` |
| `0x00600B1C` | `procedure SetCameraDynFogDensity(const val : Float)` |
| `0x00600B3C` | `function GetCameraDynFogPower() : Float` |
| `0x00600B58` | `procedure SetCameraDynFogPower(const val : Float)` |
| `0x00600B78` | `function GetCameraDynFogOffset() : Float` |
| `0x00600B94` | `procedure SetCameraDynFogOffset(const val : Float)` |
| `0x00600BB4` | `procedure SetCameraRestrictInfo(const leftx, rightx, forwardy, backwardy, heighttargetmin, sphereheight, sphereheightmin, spherelength, spherelengthmin : Float)` |
| `0x00600C2C` | `procedure GetCameraRestrictInfo(var leftx : Float; var rightx : Float; var forwardy : Float; var backwardy : Float; var heighttargetmin : Float; var sphereheight : Float; var sphereheightmin : Float; var spherelength : Float; var spherelengthmin : Float)` |
| `0x00600CA4` | `procedure SetCameraFreeRotationInfo(const minheightminangle, minheightmaxangle, maxheightminangle, maxheightmaxangle, anglelerppower, mindisttotargetobject, maxdisttotargetobject, maxheightlerpfactor : Float)` |
| `0x00600D20` | `procedure GetCameraFreeRotationInfo(var minheightminangle:Float;var minheightmaxangle:Float;var maxheightminangle:Float;var maxheightmaxangle:Float;var anglelerppower:Float;var MinDistToTarget:Float;var MaxDistToTarget:Float;var maxheightlerpfactor:Float)` |
| `0x00600D90` | `procedure SetCameraFocalLengthInfo(const minfocallength, maxfocallength, focallengthpower : Float)` |
| `0x00600DDC` | `procedure GetCameraFocalLengthInfo(var minfocallength : Float; var maxfocallength : Float; var focallengthpower : Float)` |
| `0x00600E2C` | `procedure SetCameraSceneScale(const scenescalex, scenescaley : Float)` |
| `0x00600E60` | `procedure GetCameraSceneScale(var scenescalex : Float; var scenescaley : Float)` |
| `0x00600E98` | `procedure GetCameraFrustumQuadrangle(var x0 : Float; var y0 : Float; var z0 : Float; var x1 : Float; var y1 : Float; var z1 : Float; var x2 : Float; var y2 : Float; var z2 : Float; var x3 : Float; var y3 : Float; var z3 : Float)` |
| `0x00600F28` | `function GetCameraFieldOfViewByFocalLength(const focallength, viewportdimension : Float) : Float` |
| `0x00600F8C` | `function GetCameraFocalLengthByFieldOfView(const fieldofview, viewportdimension : Float) : Float` |
| `0x00600FCC` | `function GetCameraHandle : Integer` |
| `0x00600FDC` | `function GetCameraTargetHandle : Integer` |
| `0x00600FF0` | `function GetCameraMouseDistanceSpeed : Float` |
| `0x0060100C` | `procedure SetCameraMouseDistanceSpeed(const val : Float)` |
| `0x00601028` | `function GetCameraMouseRotateFactor : Float` |
| `0x00601044` | `procedure SetCameraMouseRotateFactor(const val : Float)` |
| `0x00601060` | `procedure SetCameraEventWheelDelta(const wheeldelta : Integer)` |
| `0x006010EC` | `procedure SetCameraEventDistance(const dist : Float)` |
| `0x0067B744` | `procedure SetStateOnCameraRotate(const state: String)` |
| `0x0067B768` | `procedure SetStateOnCameraDistance(const state: String)` |
| `0x006AF9C0` | `procedure ImportCameras(const filename: String; clear: Boolean)` |
| `0x006AFA1C` | `procedure ExportCameras(const filename: String)` |
| `0x006AFA78` | `procedure ImportTextCameras(const filename: String; clear: Boolean)` |
| `0x006AFABC` | `procedure ExportTextCameras(const filename: String)` |
| `0x006BBD3C` | `function GetUseSoundManagerListenerAsCamera : Boolean` |
| `0x006BBD68` | `procedure SetUseSoundManagerListenerAsCamera(const val : Boolean)` |

### CameraInfo — 18

| VA | Объявление |
|---|---|
| `0x005FFE40` | `procedure AddCameraInfo(const cameraname: String)` |
| `0x005FFE7C` | `function GetCameraInfoCount: Integer` |
| `0x005FFE90` | `function GetCameraInfoNameByIndex(const index : Integer) : String` |
| `0x005FFEE0` | `procedure CameraInfoSaveFromCurrentView(const cameraname: String)` |
| `0x005FFFAC` | `procedure CameraInfoNormalizeToElastic(const cameraname: String)` |
| `0x00600020` | `procedure CameraInfoNormalizeToFreeRotation(const cameraname: String)` |
| `0x00600094` | `function CameraInfoLoadWithProperties(tx: Float; ty: Float; tz: Float; cx: Float; cy: Float; cz: Float): Boolean` |
| `0x006001E0` | `function CameraInfoSaveWithProperties(const cameraname: String; tx: Float; ty: Float; tz: Float; cx: Float; cy: Float; cz: Float): Boolean` |
| `0x006002DC` | `function CameraInfoReadProperties(const cameraname: String; var tx, ty, tz, cx, cy, cz: Float): Boolean` |
| `0x00600390` | `procedure CameraInfoLoadToCurrentView(const cameraname: String)` |
| `0x00600450` | `procedure CameraInfoAssignFromCamera(const cameraname, fromcameraname: String)` |
| `0x00600508` | `procedure DeleteCameraInfo(const cameraname: String)` |
| `0x00600580` | `procedure SetCameraInfoSmoothingTime(time: Float)` |
| `0x006005B8` | `procedure SetCameraInfoSmoothingChange(change: Boolean)` |
| `0x006005D8` | `function GetCameraInfoSmoothingTime(): Float` |
| `0x006005F4` | `function GetCameraInfoSmoothingChange(): Boolean` |
| `0x006008F0` | `function CameraInfoReadDepthOfView(const cameraname: String) : Float` |
| `0x00600970` | `procedure CameraInfoWriteDepthOfView(const cameraname: String; const d : Float)` |

### Clouds — 13

| VA | Объявление |
|---|---|
| `0x00603258` | `procedure SetCloudsSpeedFactor(f : Float)` |
| `0x0060328C` | `function GetCloudsSpeedFactor(): Float` |
| `0x006032C8` | `procedure SetCloudsVisible(visible: boolean)` |
| `0x006032FC` | `function GetCloudsVisible(): Boolean` |
| `0x00603328` | `procedure SetCloudsActive(active: boolean)` |
| `0x0060335C` | `function GetCloudsActive(): Boolean` |
| `0x0060338C` | `procedure SetCloudsHorizont(horizont : Float)` |
| `0x006033C0` | `function GetCloudsHorizont : Float` |
| `0x006033F4` | `procedure SetCloudsHeight(height : Float)` |
| `0x00603428` | `function GetCloudsHeight : Float` |
| `0x0060345C` | `procedure SetCloudsFogDensity(fogdensity : Float)` |
| `0x00603490` | `function GetCloudsFogDensity : Float` |
| `0x0060398C` | `procedure MakeRandomClouds` |

### Env misc — 22

| VA | Объявление |
|---|---|
| `0x00602D9C` | `procedure SetAirWeather(weather: Integer)` |
| `0x00602DD0` | `function GetAirWeather(): Integer` |
| `0x00602DFC` | `procedure SetAirWeatherTarget(weathertarget: Integer)` |
| `0x00602E30` | `function GetAirWeatherTarget(): Integer` |
| `0x00602E5C` | `procedure SetAirWeatherIntervalTarget(weatherintervaltarget: integer)` |
| `0x00602E90` | `function GetAirWeatherIntervalTarget(): integer` |
| `0x00602EBC` | `procedure SetAirWeatherRandom(weatherrandom: boolean)` |
| `0x00602EF0` | `function GetAirWeatherRandom(): boolean` |
| `0x00602F1C` | `procedure SetAirWeatherRandomStart(weatherrandomstart: integer)` |
| `0x00602F50` | `function GetAirWeatherRandomStart : Integer` |
| `0x00602F7C` | `procedure SetAirWeatherRandomEnd(weatherrandomend: integer)` |
| `0x00602FB0` | `function GetAirWeatherRandomEnd : Integer` |
| `0x00602FDC` | `procedure SetAirWindVector(x: Float; y: Float; z: Float)` |
| `0x00603028` | `procedure GetAirWindVector(var x, y, z: Float)` |
| `0x0060308C` | `procedure SetAirWindVectorTarget(x: Float; y: Float; z: Float)` |
| `0x006030D8` | `procedure GetAirWindVectorTarget(var x, y, z: Float)` |
| `0x0060313C` | `procedure SetAirWindIntervalTarget(windintervaltarget: integer)` |
| `0x00603170` | `function GetAirWindIntervalTarget(): integer` |
| `0x0060319C` | `procedure SetAirWindRandom(windrandom: boolean)` |
| `0x006031D0` | `function GetAirWindRandom(): boolean` |
| `0x006031FC` | `procedure SetAirActive(active: boolean)` |
| `0x0060322C` | `function GetAirActive(): boolean` |

### Environment — 8

| VA | Объявление |
|---|---|
| `0x00602D04` | `procedure SetEnvironmentVisible(visible: boolean)` |
| `0x00602D2C` | `function GetEnvironmentVisible(): Boolean` |
| `0x00602D50` | `procedure SetEnvironmentActive(active: boolean)` |
| `0x00602D78` | `function GetEnvironmentActive(): Boolean` |
| `0x006AEE94` | `procedure EnvironmentLoadLensFlareFromFile(const afile: String)` |
| `0x006AEEB0` | `procedure EnvironmentSetSkyDomeMaterial(const amatname: String)` |
| `0x006AEED8` | `function  EnvironmentGetSkyDomeMaterial: String` |
| `0x006AEF04` | `procedure EnvironmentSetFogDensity(avalue: Float)` |

### GameObject — 6

| VA | Объявление |
|---|---|
| `0x0064DD28` | `function GetGameObjectMyPositionInWater(): Boolean` |
| `0x0064DD4C` | `function GetGameObjectPositionInWaterByHandle(gohandle: Integer): Boolean` |
| `0x0064DD70` | `function GetGameObjectMyDepthUnderWater(): Float` |
| `0x0064DDA0` | `function GetGameObjectDepthUnderWaterByHandle(gohandle: Integer): Float` |
| `0x00652534` | `function GetGameObjectUseCameraCollisionByHandle(const gohnd: Integer): Boolean` |
| `0x00652574` | `procedure SetGameObjectUseCameraCollisionByHandle(const gohnd: Integer; val: Boolean)` |

### Group — 2

| VA | Объявление |
|---|---|
| `0x00600738` | `function GetCameraDistToGroups(): Float` |
| `0x00600754` | `procedure SetCameraDistToGroups(disttogroups: Float)` |

### LensFlare — 7

| VA | Объявление |
|---|---|
| `0x0060381C` | `procedure SetLensFlareAngle(angle : Float)` |
| `0x00603844` | `function GetLensFlareAngle : Float` |
| `0x00603874` | `procedure SetLensFlareZOffset(zoffset : Float)` |
| `0x0060389C` | `function GetLensFlareZOffset : Float` |
| `0x006038CC` | `procedure SetLensFlareFileName(filename : String)` |
| `0x00603928` | `function GetLensFlareFileName : String` |
| `0x00603B84` | `procedure LensFlareDataListClear` |

### LightPattern — 9

| VA | Объявление |
|---|---|
| `0x006039C4` | `procedure SetLightPattern(const id : String)` |
| `0x006039F0` | `procedure SetBlendToLightPatternInterval(interval : Integer)` |
| `0x00603A1C` | `function GetBlendToLightPatternInterval : Integer` |
| `0x00603A40` | `procedure SetBlendToLightPattern(const id : String)` |
| `0x00603A6C` | `function GetBlendToLightPattern : String` |
| `0x00603AA4` | `function GetLightPatternsCount : Integer` |
| `0x00603ACC` | `function GetLightPatternID(index : Integer) : String` |
| `0x00603B34` | `procedure SetLightPatternByIndex(index : Integer)` |
| `0x00603B60` | `procedure ResetBlendToLightPattern` |

### ParticleCube — 11

| VA | Объявление |
|---|---|
| `0x0060358C` | `procedure SetParticleCubeVisbleByName(const name: String; visible: boolean)` |
| `0x006035CC` | `function GetParticleCubeVisbleByName(const name: String): Boolean` |
| `0x0060360C` | `procedure SetParticleCubeActiveByName(const name: String; active: boolean)` |
| `0x00603614` | `function GetParticleCubeActiveByName(const name: String): Boolean` |
| `0x00603658` | `function GetParticleCubesCount(): Integer` |
| `0x0060368C` | `function GetParticleCubeNameByIndex(index: Integer): String` |
| `0x006036E0` | `function GetParticleCubeIndexByName(const name: String): Integer` |
| `0x0060371C` | `procedure SetParticleCubeVisbleByIndex(index: Integer; visible: boolean)` |
| `0x0060375C` | `function GetParticleCubeVisbleByIndex(index: Integer): Boolean` |
| `0x0060379C` | `procedure SetParticleCubeActiveByIndex(index: Integer; active: boolean)` |
| `0x006037DC` | `function GetParticleCubeActiveByIndex(index: Integer): Boolean` |

### SkyDome — 4

| VA | Объявление |
|---|---|
| `0x006034C4` | `procedure SetSkyDomeVisible(visible: boolean)` |
| `0x006034F8` | `function GetSkyDomeVisible(): Boolean` |
| `0x00603528` | `procedure SetSkyDomeActive(active: boolean)` |
| `0x0060355C` | `function GetSkyDomeActive(): Boolean` |

### Water — 8

| VA | Объявление |
|---|---|
| `0x006039A4` | `function GetCurrentWaterOffset : Float` |
| `0x00603BAC` | `procedure SetCurrentWaterName(const name : String)` |
| `0x00603BD4` | `function GetCurrentWaterName : String` |
| `0x00603C0C` | `procedure SetCurrentWaterIndex(const index : Integer)` |
| `0x00603C34` | `function GetCurrentWaterIndex : Integer` |
| `0x006AFE80` | `function RayCastWater(x, y: Float; var h: Float): Boolean` |
| `0x006B1DF8` | `function GetWater(const i, j: Integer): Boolean` |
| `0x006B2048` | `function GetWaterExt(const x, y: Float; var woffset: Float): Boolean` |

### WaterField — 13

| VA | Объявление |
|---|---|
| `0x00603C58` | `procedure WaterFieldsClear()` |
| `0x00603C78` | `function WaterFieldGetCount : Integer` |
| `0x00603C9C` | `function WaterFieldGetIndexByName(const name : String) : Integer` |
| `0x00603CCC` | `function WaterFieldGetNameByIndex(const index : Integer) : String` |
| `0x00603D30` | `function WaterFieldAdd(const name : String; const tx, tz, bx, bz, offsety : Float) : Integer` |
| `0x00603DA0` | `procedure WaterFieldDelete(const index : Integer)` |
| `0x00603DC8` | `procedure WaterFieldSetCoord(const index : Integer; const tx, tz, bx, bz, offsety : Float)` |
| `0x00603E30` | `procedure WaterFieldGetCoord(const index : Integer; var minx : Float; var minz : Float; var maxx : Float; var maxz : Float; var offsety : Float)` |
| `0x00603EDC` | `procedure WaterFieldSetName(const index : Integer; const name : String)` |
| `0x00603F30` | `procedure WaterFieldSetPosition(const index : Integer; const x, y, z : Float)` |
| `0x00603FA8` | `procedure WaterFieldGetPosition(const index : Integer; var x : Float; var y : Float; var z : Float)` |
| `0x0060400C` | `procedure WaterFieldSetOffsetY(const index : Integer; const offsety : Float)` |
| `0x0060405C` | `procedure WaterFieldGetOffsetY(const index : Integer; var offsety : Float)` |

## 5. Прочее

Редактор (`Editor*`, тот же движок, `editor.exe`). Геймплей в сети — риск десинка (`NetGateMode +0xF1`), графика — безопасна.

### Editor — 57

| VA | Объявление |
|---|---|
| `0x005FAD04` | `function EditorExecuteMenu(const smenu: String):Boolean` |
| `0x005FAD10` | `procedure EditorLoadMap(const sMap: String)` |
| `0x005FAD18` | `procedure EditorSaveMap` |
| `0x005FAD1C` | `procedure EditorSaveMapAs(const map : String)` |
| `0x005FADD0` | `procedure EditorRegisterMenu(const smenu: String; const sstate: String; const sshortcut: String)` |
| `0x005FADD8` | `procedure EditorUnRegisterMenu(const smenu: String)` |
| `0x005FADE0` | `procedure EditorMouseMove(x, y: Integer)` |
| `0x005FAE00` | `procedure EditorMousePress(btn: Integer; press: Integer)` |
| `0x005FAF54` | `procedure EditorKeyboardType(const avalue: String)` |
| `0x005FAF68` | `procedure EditorExecuteShortCut(const sshortcut: String)` |
| `0x005FB18C` | `procedure EditorShowMessage(const smsg: String)` |
| `0x005FB1B0` | `procedure EditorFormClear(const scaption: String)` |
| `0x005FB25C` | `function EditorFormExecute: Boolean` |
| `0x005FB2EC` | `procedure EditorProfManagerStart` |
| `0x005FB2F8` | `procedure EditorProfManagerStop` |
| `0x005FB304` | `procedure EditorProfManagerShowReport` |
| `0x005FB310` | `function EditorProfManagerGetProfilerHandleByName(const sname: String): Integer` |
| `0x005FB324` | `function EditorProfManagerCreateProfiler(const sname: String): Integer` |
| `0x005FB338` | `procedure EditorProfManagerDestroyProfiler(const sname: String)` |
| `0x005FB354` | `procedure EditorProfilerBegin(profhandle: Integer)` |
| `0x005FB368` | `procedure EditorProfilerEnd(profhandle: Integer)` |
| `0x005FB37C` | `procedure EditorStartCapture` |
| `0x005FB380` | `procedure EditorStopCapture` |
| `0x005FB384` | `function EditorGetCaptureMode : Integer` |
| `0x005FB388` | `function EditorGetWorldViewerVisible: Boolean` |
| `0x005FB3A0` | `procedure EditorSetWorldViewerVisible(val: Boolean)` |
| `0x005FB3C4` | `function EditorGetWorldViewerCollisionVisible: Boolean` |
| `0x005FB3E0` | `procedure EditorSetWorldViewerCollisionVisible(val: Boolean)` |
| `0x005FB404` | `function EditorGetWorldViewerTopologyVisible: Boolean` |
| `0x005FB420` | `procedure EditorSetWorldViewerTopologyVisible(val: Boolean)` |
| `0x005FB444` | `function EditorGetWorldViewerCollisionOffset: Float` |
| `0x005FB468` | `procedure EditorSetWorldViewerCollisionOffset(val: Float)` |
| `0x005FB48C` | `function EditorGetWorldViewerTopologyOffset: Float` |
| `0x005FB4B0` | `procedure EditorSetWorldViewerTopologyOffset(val: Float)` |
| `0x005FB4D4` | `procedure EditorGetWorldViewerCollisionColor(var r, g, b, a: Float)` |
| `0x005FB554` | `procedure EditorSetWorldViewerCollisionColor(r, g, b, a: Float)` |
| `0x005FB594` | `procedure EditorGetWorldViewerTopologyColor(var r, g, b, a: Float)` |
| `0x005FB614` | `procedure EditorSetWorldViewerTopologyColor(r, g, b, a: Float)` |
| `0x005FB654` | `function EditorBrushGetVisible: Boolean` |
| `0x005FB668` | `procedure EditorBrushSetVisible(const val: Boolean)` |
| `0x005FB688` | `function EditorBrushGetMode: Integer` |
| `0x005FB6A0` | `procedure EditorBrushSetMode(const val: Integer)` |
| `0x005FB6F8` | `procedure EditorBrushSetShowWorldTransform(const val: Boolean)` |
| `0x005FB718` | `function EditorBrushGetShowWorldTransform: Boolean` |
| `0x005FB730` | `procedure EditorBrushSetShowBoundingBox(const val: Boolean)` |
| `0x005FB750` | `function EditorBrushGetShowBoundingBox: Boolean` |
| `0x005FB768` | `procedure EditorBrushSetShowCustAABBinSP(const val: Boolean)` |
| `0x005FB788` | `function EditorBrushGetShowCustAABBinSP: Boolean` |
| `0x005FB7A0` | `procedure EditorBrushSetShowTerrainBrush(const val: Boolean)` |
| `0x005FB7C0` | `function EditorBrushGetShowTerrainBrush: Boolean` |
| `0x005FB7D8` | `procedure EditorBrushSetShowTrackPoints(const val: Boolean)` |
| `0x005FB7F8` | `function EditorBrushGetShowTrackPoints: Boolean` |
| `0x005FB810` | `procedure EditorBrushClearTargetObjects` |
| `0x005FB828` | `procedure EditorBrushAddTargetObject(const hnd: Integer)` |
| `0x005FB848` | `procedure EditorBrushRemoveTargetObject(const hnd: Integer)` |
| `0x005FB868` | `function EditorBrushIndexOfTargetObject(const hnd: Integer): Integer` |
| `0x005FB888` | `procedure EditorSetWindowSize(left, top, width, height: Integer)` |

## 6. TOSW из functions.txt

`functions.txt`: 27083 строк, ~18542 `sub_*` (сама игра), остальное — RTL/VCL/импорты + ~1064 TOSW-класса. Искать в `.i64` по именам:

```text
TOSWSceneBuffer.SetAntiAliasing / SetDirectAntiAliasing / SetLighting / SetFogEnable
  SetShadeModel / SetRenderTexture / SetRenderDepthTexture / SetRenderTextureFormat
  SetColorDepth / SetDepthPrecision / SetBackgroundColor / SetAmbientColor
TOSWCamera.SetDepthOfView / SetFocalLength / SetCameraStyle / SetSceneScaleX/Y
TOSWFogEnvironment.SetFogColor / SetFogStart / SetFogEnd / SetFogMode / SetFogDistance
TOSWLightSource.SetAmbient / SetDiffuse / SetSpecular / SetShining + Attenuation
TOSWNonVisualViewer.SetBeforeRender / SetPostRender / SetAfterRender + SetCamera + SetBuffer
TOSWBaseGui / TOSWBaseGuiControl / TOSWBaseGuiTextControl
TXGuiScroll / TXGuiHScroll / TXGuiVScroll / TXGuiLayer / TXGuiListBox / TXGuiComboBox / TXGuiPageControl / TXGuiBackground
gdi32.SwapBuffers + opengl32.wglMakeCurrent / wglCreateContext
```

## 7. Перехват GUI

Чистое создание (свои панели): `AddNewElementTopByClassName('MyMod_Top','TOSWImageGuiControl',tag)` -> `SetGUIElementAllPositionRect` -> `SetGUIElementMaterial/Text/Visible`. Образцы — `_gui_CreateImage/Button/Text/ListBox/Window*` в `data/scripts/lib/gui.script`. Удалять только свое: `DestroyGUIElement`.

Перехват игры:

1. `GetGUIEventStateOnCreateGUI (0x67BCB4)` прочитать, `SetGUIEventStateOnCreateGUI (0x67C110)` подменить `DoCreate` на свой state. Аналогично `OnClick/OnPress/DoProgress/OnHint/OnResize/OnLanChange/OnMouseHook/OnBefore+AfterLoadMap`. Дефолты — `data/gui/menu.cfg`.
2. Хук `GUIExecuteState (0x674118)` + лог `GetGUIValue('Status'/'Press'/'Tag')` — все клики игры.
3. Хук `AddNewElementTop/Parent/TopByClassName (0x674250/0x674274/0x6742F4)` через MinHook (`__stdcall`) — лог, скрытие `SetGUIElementVisible(h,False)`, переподвес `AttachGUIElementToElement`.
4. `StateMachineReloadGUI (0x6C48FC)` — применить без рестарта.
