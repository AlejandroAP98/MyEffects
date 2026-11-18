@echo off
title Temas RGB
:menu
cls
echo  ==========================================
echo   TEMAS RGB (SignalRGB)
echo  ==========================================
echo   1. Ver temas configurados
echo   2. Siguiente tema (ya)
echo   3. Tema anterior (ya)
echo   4. Reiniciar motor (aplica cambios de temas.txt)
echo   5. Abrir temas.txt para editar
echo   6. Ver registro (temas.log)
echo   7. Salir
echo  ==========================================
set /p op="> "
if "%op%"=="1" goto ver
if "%op%"=="2" goto sig
if "%op%"=="3" goto ant
if "%op%"=="4" goto reini
if "%op%"=="5" goto editar
if "%op%"=="6" goto log
if "%op%"=="7" exit
goto menu

:ver
findstr /V "^#" "%~dp0temas.txt" | findstr /V "^$"
pause
goto menu

:sig
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Temas-RGB.ps1" -Siguiente
pause
goto menu

:ant
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Temas-RGB.ps1" -Anterior
pause
goto menu

:reini
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -match 'Temas-RGB.ps1 -Motor' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }; Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','\"%~dp0Temas-RGB.ps1\"','-Motor'"
echo Motor reiniciado
pause
goto menu

:editar
notepad "%~dp0temas.txt"
goto menu

:log
if exist "%~dp0temas.log" (powershell.exe -NoProfile -Command "Get-Content '%~dp0temas.log' | Select-Object -Last 20") else (echo sin registro aun)
pause
goto menu
