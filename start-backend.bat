@echo off
chcp 65001 >nul
title KidsTransfer Backend
cd /d "%~dp0backend"

REM --- Guard: never run two backends at once (split databases break payments!) ---
netstat -ano | findstr /R /C:":8000 .*LISTENING" >nul
if not errorlevel 1 (
    echo [ERROR] Port 8000 is already in use — backend is probably running in Docker.
    echo         Two backends = two databases: the app and the cabinet stop seeing
    echo         each other's trips and payments.
    echo.
    echo         Use the Docker backend, or stop it first: docker compose stop backend
    pause
    exit /b 1
)

REM --- First run: create venv and install dependencies ---
if not exist ".venv\Scripts\python.exe" (
    echo [setup] Creating virtual environment...
    python -m venv .venv
    echo [setup] Installing Python dependencies...
    ".venv\Scripts\python.exe" -m pip install --upgrade pip
    ".venv\Scripts\python.exe" -m pip install -r requirements.txt
)

REM --- Local run without Docker: SQLite database ---
set USE_SQLITE=1

echo [db] Applying migrations...
".venv\Scripts\python.exe" manage.py migrate
echo [db] Seeding demo data (if empty)...
".venv\Scripts\python.exe" manage.py seed_demo --if-empty

echo.
echo ============================================================
echo  Backend:  http://localhost:8000
echo  API docs: http://localhost:8000/api/docs/
echo  Admin:    http://localhost:8000/admin/  (admin@kids.kz / admin12345)
echo  Emulator reaches it at 10.0.2.2:8000
echo ============================================================
echo.

".venv\Scripts\python.exe" manage.py runserver 0.0.0.0:8000
pause
