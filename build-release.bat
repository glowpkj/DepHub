@echo off
REM Double-click this file to build a release of DepHub.
REM It runs build-release.ps1 with a bypass so no PowerShell policy edit is needed.
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-release.ps1" %*
echo.
pause
