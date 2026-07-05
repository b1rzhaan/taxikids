@echo off
chcp 65001 >nul
title KidsTransfer Web (cabinet)
cd /d "%~dp0web"

REM --- First run: install npm dependencies ---
if not exist "node_modules" (
    echo [setup] Installing web dependencies...
    call npm install
)

REM --- Ensure local env exists ---
if not exist ".env.local" copy ".env.local.example" ".env.local" >nul

echo.
echo ============================================================
echo  Web cabinet: http://localhost:3000
echo  Login:       operator@kids.kz / operator12345
echo  (Make sure the backend is running first!)
echo ============================================================
echo.

call npm run dev
pause
