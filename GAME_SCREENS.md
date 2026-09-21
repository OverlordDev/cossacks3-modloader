# Экраны игры

Сгенерировано `tools/gen_screens.py` из `data/gui/menu.inc`. Не править руками.

Экран = `Show<Имя>` (строит) + `Event<Имя>` (кнопки). Работа с ними — `screens.*` (api/15_screens.lua).

Тэги Show/Hide/Close (8001–8003) есть у всех экранов с Event-состоянием.

## AIAssistant

`ShowAIAssistant` / `EventAIAssistant`

| кнопка | тэг |
|---|---|
| TurnAdviser | 100 |
| Expand | 101 |
| Unexpand | 102 |
| HideAssistant | 103 |
| ShowAssistant | 104 |

## AIAssistantAdvices

`ShowAIAssistantAdvices` / `EventAIAssistantAdvices`

| кнопка | тэг |
|---|---|
| Trade | 103 |
| Squad | 104 |
| Unit | 1000 |
| Upgrade | 2000 |

## AIAssistantSettings

`ShowAIAssistantSettings` / `EventAIAssistantSettings`

| кнопка | тэг |
|---|---|
| CheckBoxEconomy | 101 |
| CheckBoxConstruct | 102 |
| CheckBoxUpgrades | 103 |
| CheckBoxShowUnaffordable | 104 |
| CheckBoxQuartermeister | 105 |
| CheckBoxSetGuards | 106 |
| CheckBoxHireOfficers | 107 |
| CheckBoxShowSquads | 108 |
| BtnManageEconomy | 201 |

## AIAssistantSettingsAdvanced

`ShowAIAssistantSettingsAdvanced` / `EventAIAssistantSettingsAdvanced`

## AIDebug

`ShowAIDebug` / `—`

## Announcement

`ShowAnnouncement` / `EventAnnouncement`

| кнопка | тэг |
|---|---|
| DontShow | 102 |

## Campaign

`ShowCampaign` / `EventCampaign`

| кнопка | тэг |
|---|---|
| Select | 101 |
| Back | 102 |

## ChatConsole

`ShowChatConsole` / `EventChatConsole`

## Clans

`—` / `EventClans`

| кнопка | тэг |
|---|---|
| CreateRoom | 102 |
| JoinRoom | 103 |
| LeaveRoom | 104 |
| CloseRoom | 106 |
| SwitchToRoom | 107 |
| Ranking | 108 |
| Profile | 109 |
| ToSimple | 110 |
| ToAdvanced | 111 |
| AutoSearch | 112 |
| StopAutoSearch | 113 |
| AutoSearchSettings | 114 |
| AutoSearchApprove | 115 |
| AutoSearchCancel | 116 |
| AutoSearchJoin | 117 |
| ToRooms | 118 |
| NotTraining | 119 |
| ChangeProfile | 120 |
| CreateHistoricalRoom | 121 |
| CreateCustomRoom | 122 |
| OpenTournamentWindow | 123 |
| CloseTournamentWindow | 124 |

## ConnectStateMessage

`ShowConnectStateMessage` / `EventConnectStateMessage`

| кнопка | тэг |
|---|---|
| Disconnect | 102 |
| ModsSyncApprove | 110 |

## CreateJoinRoom

`ShowCreateJoinRoom` / `EventCreateJoinRoom`

| кнопка | тэг |
|---|---|
| Create | 101 |
| Join | 102 |
| AddPass | 103 |
| RatingRoom | 104 |
| CreateBattle | 105 |

## Credits

`ShowCredits` / `EventCredits`

| кнопка | тэг |
|---|---|
| CreateRoom | 102 |
| JoinRoom | 103 |
| LeaveRoom | 104 |
| CloseRoom | 106 |
| SwitchToRoom | 107 |
| Ranking | 108 |
| Profile | 109 |
| ToSimple | 110 |
| ToAdvanced | 111 |
| AutoSearch | 112 |
| StopAutoSearch | 113 |
| AutoSearchSettings | 114 |
| AutoSearchApprove | 115 |
| AutoSearchCancel | 116 |
| AutoSearchJoin | 117 |
| ToRooms | 118 |
| NotTraining | 119 |
| ChangeProfile | 120 |
| CreateHistoricalRoom | 121 |
| CreateCustomRoom | 122 |
| OpenTournamentWindow | 123 |
| CloseTournamentWindow | 124 |

## CustomGame

`ShowCustomGame` / `EventCustomGame`

| кнопка | тэг |
|---|---|
| BackToMainMenu | 101 |
| SwitchToShell | 102 |
| StartGame | 103 |
| CloseRoom | 104 |
| LeaveRoom | 105 |
| ReadyGame | 106 |
| StartAutoSearch | 107 |
| StopAutoSearch | 108 |
| BaseTagChangeColor | 200 |
| Kick | 1000 |

## Debug

`ShowDebug` / `—`

## DebugAnimations

`ShowDebugAnimations` / `EventDebugAnimations`

| кнопка | тэг |
|---|---|
| PlayAnim | 200 |
| PlayAnimOnce | 201 |
| ChangeState | 202 |

## EditorControl

`ShowEditorControl` / `EventEditorControl`

| кнопка | тэг |
|---|---|
| RollUp | 100 |
| RollDown | 101 |

## EditorInfo

`ShowEditorInfo` / `—`

## EndGame

`ShowEndGame` / `EventEndGame`

| кнопка | тэг |
|---|---|
| Campaign | 101 |
| ExitToMainMenuApprove | 106 |

## EndGameStatistics

`ShowEndGameStatistics` / `EventEndGameStatistics`

| кнопка | тэг |
|---|---|
| BackToGame | 101 |
| Replay | 102 |
| SaveReplay | 103 |
| ExitToMenu | 104 |
| Prev | 105 |
| Next | 106 |

## HUD

`ShowHUD` / `EventHUD`

## HistoricalBattle

`ShowHistoricalBattle` / `EventHistoricalBattle`

| кнопка | тэг |
|---|---|
| BackToMainMenu | 101 |
| SwitchToShell | 102 |
| StartGame | 103 |
| CloseRoom | 104 |
| LeaveRoom | 105 |
| ReadyGame | 106 |
| StartAutoSearch | 107 |
| StopAutoSearch | 108 |
| GoPickPositions | 109 |
| BaseTagChangeColor | 200 |
| ChangePosition | 501 |
| ChangeTeam | 502 |
| Kick | 1000 |

## InternetShell

`ShowInternetShell` / `EventInternetShell`

| кнопка | тэг |
|---|---|
| CreateRoom | 102 |
| JoinRoom | 103 |
| LeaveRoom | 104 |
| CloseRoom | 106 |
| SwitchToRoom | 107 |
| Ranking | 108 |
| Profile | 109 |
| ToSimple | 110 |
| ToAdvanced | 111 |
| AutoSearch | 112 |
| StopAutoSearch | 113 |
| AutoSearchSettings | 114 |
| AutoSearchApprove | 115 |
| AutoSearchCancel | 116 |
| AutoSearchJoin | 117 |
| ToRooms | 118 |
| NotTraining | 119 |
| ChangeProfile | 120 |
| CreateHistoricalRoom | 121 |
| CreateCustomRoom | 122 |
| OpenTournamentWindow | 123 |
| CloseTournamentWindow | 124 |
| OpenTopPanel | 125 |
| CloseTopPanel | 126 |

## LoadGame

`ShowLoadGame` / `EventLoadGame`

| кнопка | тэг |
|---|---|
| Save | 101 |
| Load | 102 |
| Delete | 103 |
| SaveReplay | 104 |
| LoadReplay | 105 |
| SwitchToReplay | 106 |
| SwitchToSaves | 107 |
| SaveApproved | 501 |
| LoadApproved | 502 |
| DeleteApproved | 503 |

## MainMenu

`ShowMainMenu` / `EventMainMenu`

| кнопка | тэг |
|---|---|
| UnitsStats | 100 |
| Campaign | 101 |
| RandomMap | 102 |
| Multiplayer | 103 |
| Settings | 104 |
| LoadGame | 105 |
| LoadReplay | 106 |
| Editor | 107 |
| ModManager | 108 |
| Exit | 109 |
| Tutorial | 110 |
| Credits | 111 |

## Menu

`ShowMenu` / `EventMenu`

| кнопка | тэг |
|---|---|
| Continue | 101 |
| Settings | 102 |
| SaveGame | 103 |
| LoadGame | 104 |
| ExitToMainMenu | 105 |
| ExitToMainMenuApprove | 106 |
| Surrender | 107 |
| SurrenderApprove | 108 |
| Statistics | 109 |
| SaveReplay | 110 |
| TradeResources | 111 |
| MainMenuApproved | 510 |
| SurrenderApproved | 511 |

## Minimap

`—` / `EventMinimap`

## Missions

`ShowMissions` / `EventMissions`

## ModalMessage

`ShowModalMessage` / `EventModalMessage`

| кнопка | тэг |
|---|---|
| Disconnect | 102 |
| ExitToMainMenuApprove | 106 |
| SurrenderApprove | 108 |
| ResolutionApprove | 401 |
| ResolutionRevert | 402 |
| SaveApproved | 501 |
| LoadApproved | 502 |
| DeleteApproved | 503 |
| MainMenuApproved | 510 |
| SurrenderApproved | 511 |

## MultiplayerChat

`ShowMultiplayerChat` / `EventMultiplayerChat`

| кнопка | тэг |
|---|---|
| CreateRoom | 102 |
| JoinRoom | 103 |
| LeaveRoom | 104 |
| StartRoom | 105 |
| CloseRoom | 106 |
| SwitchToRoom | 107 |
| CleanRecipient | 108 |
| ShowFriendsChannel | 109 |

## MultiplayerLogin

`ShowMultiplayerLogin` / `EventMultiplayerLogin`

| кнопка | тэг |
|---|---|
| Register | 102 |
| Login | 103 |
| CheckEmail | 104 |
| Forgot | 105 |
| ChangeProfile | 106 |

## News

`ShowNews` / `EventNews`

| кнопка | тэг |
|---|---|
| Prev | 100 |
| Next | 101 |
| ButtonOpenURL | 102 |
| HideEventPanel | 103 |
| ShowEventPanel | 104 |
| OpenVK | 105 |
| OpenFB | 106 |
| OpenSteam | 107 |
| OpenUrl | 200 |

## Pause

`ShowPause` / `—`

## Profile

`ShowProfile` / `EventProfile`

| кнопка | тэг |
|---|---|
| Accept | 90 |
| SelectCreate | 101 |
| Delete | 102 |

## QueryWindow

`ShowQueryWindow` / `EventQueryWindow`

## RallyPoints

`ShowRallyPoints` / `—`

## ResourcePanel

`ShowResourcePanel` / `EventResourcePanel`

| кнопка | тэг |
|---|---|
| MenuShow | 100 |
| MenuClose | 101 |
| IdlePeasants | 110 |
| IdleMines | 111 |
| ShowHideObjectives | 112 |

## ScenarioEditor

`ShowScenarioEditor` / `EventScenarioEditor`

| кнопка | тэг |
|---|---|
| NewTrigger | 200 |
| EditTrigger | 201 |
| DeleteTrigger | 202 |
| NewCondition | 203 |
| NewAction | 204 |
| DeleteCondition | 205 |
| DeleteAction | 206 |
| EditCondition | 207 |
| EditAction | 208 |
| MoveUp | 209 |
| MoveDown | 210 |
| Enable | 211 |
| Disable | 212 |
| Execute | 213 |
| CopyAction | 214 |
| PasteAction | 215 |
| CopyCondition | 216 |
| PasteCondition | 217 |
| EnableAction | 218 |
| DisableAction | 219 |
| EnableCondition | 220 |
| DisableCondition | 221 |
| CopyTrigger | 222 |
| PasteTrigger | 223 |
| BaseHelperType | 300 |

## ScenarioHelper

`ShowScenarioHelper` / `EventScenarioHelper`

| кнопка | тэг |
|---|---|
| Apply | 101 |
| Cancel | 102 |
| Preview | 103 |
| GroupClear | 110 |
| GroupAddSel | 111 |
| GroupRemoveSel | 112 |
| GroupSetSel | 113 |
| GroupSelectGroupUnits | 114 |

## ScenarioTriggerEditor

`ShowScenarioTriggerEditor` / `EventScenarioTriggerEditor`

| кнопка | тэг |
|---|---|
| Apply | 101 |
| Cancel | 102 |

## ScenarioUI

`ShowScenarioUI` / `EventScenarioUI`

| кнопка | тэг |
|---|---|
| GroupClear | 110 |
| GroupAddSel | 111 |
| GroupRemoveSel | 112 |
| GroupSetSel | 113 |
| GroupSelectGroupUnits | 114 |
| NewTrigger | 200 |
| BaseHelperType | 300 |

## Settings

`ShowSettings` / `EventSettings`

| кнопка | тэг |
|---|---|
| Accept | 90 |
| Cancel | 91 |
| Default | 92 |
| Profile | 101 |
| TabVideo | 102 |
| TabSound | 103 |
| TabControl | 104 |
| TabKeyBinding | 105 |
| CheckboxShadows | 110 |
| CheckboxAntialiasing | 111 |
| CheckboxVSync | 112 |
| CheckboxFreeZoom | 113 |
| CheckboxClampingMouse | 113 |
| TabHotkeys | 114 |
| CheckboxSSAO | 114 |
| ConstantHotkeys | 115 |
| CheckboxFXAO | 115 |
| CustomizableHotkeys | 116 |
| CheckboxMute | 120 |

## Statistics

`ShowStatistics` / `—`

## TournamentsWindow

`ShowTournamentsWindow` / `EventTournamentsWindow`

| кнопка | тэг |
|---|---|
| EvaluateTournaments | 100 |
| EvaluateStreams | 101 |
| ButtonOpenURL | 102 |
| HideEventPanel | 103 |
| ShowEventPanel | 104 |
| OpenVK | 105 |
| OpenFB | 106 |
| OpenSteam | 107 |

## TradeResources

`ShowTradeResources` / `EventTradeResources`

| кнопка | тэг |
|---|---|
| Sell | 100 |
| Numbers | 110 |
| Accept | 120 |
| Clear | 130 |
| Exit | 140 |
| Players | 1000 |
| PlayersButton | 10000 |

## UnitControl

`ShowUnitControl` / `EventUnitControl`

| кнопка | тэг |
|---|---|
| Rally | 50 |
| IdlePeasants | 60 |
| IdleMines | 61 |
| Unit | 100 |
| Upgrade | 200 |
| ControlHoldPosition | 300 |
| ControlCancelHoldPosition | 301 |
| ControlGoWithAttack | 302 |
| ControlEnableAttack | 303 |
| ControlDisableAttack | 304 |
| ControlPatrol | 305 |
| ControlGuard | 306 |
| ControlCancelGuard | 307 |
| ControlSquadFill | 310 |
| ControlSquadDisband | 311 |
| ControlSquadFormLine | 312 |
| ControlSquadFormColumn | 313 |
| ControlSquadFormSquare | 314 |
| ControlSquadGroups | 315 |
| ControlArtilleryPreparation | 316 |
| ControlSquadFormationUnit | 317 |
| ControlOpenGate | 318 |
| ControlCloseGate | 319 |
| ControlOfficerDecreaseSize | 320 |
| ControlOfficerIncreaseSize | 321 |
| ControlUnloadAll | 322 |
| MarketAccept | 430 |
| MarketClear | 440 |

## UnitsStats

`ShowUnitsStats` / `EventUnitsStats`

| кнопка | тэг |
|---|---|
| BackToGame | 101 |
| Replay | 102 |
| SaveReplay | 103 |
| ExitToMenu | 104 |
| Prev | 105 |
| Next | 106 |

