@echo off
rem Zips this PC's Flap logs next to the game (pack_logs.ps1 does the work).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pack_logs.ps1"
pause
