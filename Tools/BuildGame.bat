@echo off
rem Double-click to build. Optional argument: version, e.g. BuildGame.bat 1.0
if "%~1"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0BuildGame.ps1"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0BuildGame.ps1" -Version %1
)
pause
