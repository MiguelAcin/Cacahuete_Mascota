@echo off
rem Vuelve a montar Cacahuete.exe (usalo cuando haya una version nueva del cacahuete)
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0cacahuete.ps1" -Build
