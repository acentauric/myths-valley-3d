@echo off
cd /d "%~dp0"
python tools\jev\jogar.py --robot --seconds 0 %*
if errorlevel 1 pause
