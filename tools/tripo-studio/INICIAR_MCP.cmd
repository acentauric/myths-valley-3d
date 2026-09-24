@echo off
setlocal
cd /d "%~dp0"
call "%~dp0node_modules\.bin\playwright-mcp.cmd" --extension --output-dir "%~dp0output" --file-paths absolute --timeout-action 10000 --timeout-navigation 120000
