# Собирает lua.exe из external/lua для tools/api_test/run.lua.
#   powershell -File tools/api_test/build_lua.ps1
# Нужен Visual Studio (cl.exe): скрипт сам поднимает его окружение.
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
& "$vs\Common7\Tools\Launch-VsDevShell.ps1" -Arch amd64 -SkipAutomaticLocation | Out-Null
$src = Join-Path $root "external\lua"
$files = Get-ChildItem $src -Filter *.c | Where-Object { $_.Name -notin 'onelua.c', 'luac.c' } | ForEach-Object { $_.FullName }
Push-Location $PSScriptRoot
& cl /nologo /O1 /MD /Fe:lua.exe $files | Select-Object -Last 1
Remove-Item *.obj -ErrorAction SilentlyContinue
Pop-Location
Write-Host "lua.exe -> $PSScriptRoot"
