@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\prototipo_3d\jogar.ps1" %*
if errorlevel 1 pause
