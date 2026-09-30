@echo off
rem Сборка и запуск стенда TextureShrink. Пример: run.bat "C:\Program Files (x86)\Steam\steamapps\common\Cossacks 3" 1024
setlocal
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars32.bat" >nul
set OUT=%TEMP%\texshrink_test
if not exist "%OUT%" mkdir "%OUT%"
cl /nologo /O2 /EHsc /std:c++17 /I "%~dp0." "%~dp0main.cpp" /Fo"%OUT%\\" /Fe"%OUT%\texshrink_test.exe" || exit /b 1
"%OUT%\texshrink_test.exe" %*
