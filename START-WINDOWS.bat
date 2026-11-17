@echo off
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo Bitte Node.js 20 oder neuer installieren und erneut starten.
  pause
  exit /b 1
)
start "" http://localhost:4173
node scripts/serve.mjs
pause
