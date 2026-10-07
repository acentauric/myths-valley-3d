@echo off
cd /d "%~dp0"
python tools\jev\jogar.py %*
if errorlevel 1 pause
