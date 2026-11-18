@echo off
rem Arranca el Cacahuete Comando. Si aun no esta montado, lo monta primero.
cd /d "%~dp0"
if exist "Cacahuete.exe" (
  start "" "Cacahuete.exe"
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0cacahuete.ps1" -Build
)
