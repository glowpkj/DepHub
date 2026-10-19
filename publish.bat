@echo off
REM Double-click this file to build and publish DepHub.
REM It runs publish.ps1 with a bypass so no PowerShell policy edit is needed.
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0publish.ps1" %*
echo.
pause
