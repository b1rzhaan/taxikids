@echo off
chcp 65001 >nul
title KidsTransfer — Docker (backend + site)
cd /d "%~dp0"

if not exist ".env" copy ".env.example" ".env" >nul

echo ============================================================
echo   Запуск KidsTransfer через Docker
echo   Сервисы: Postgres + Redis + Backend + Сайт (кабинет)
echo   Первый запуск дольше (скачивание образов и npm install).
echo ============================================================
echo.

docker compose up --build -d
if errorlevel 1 (
    echo.
    echo [ОШИБКА] Не удалось запустить. Проверьте, что Docker Desktop запущен.
    pause
    exit /b 1
)

echo.
echo   Ждём готовности сервисов (первый запуск ~1-3 мин)...
timeout /t 15 /nobreak >nul

start "" http://localhost:3000
start "" http://localhost:8000/api/docs/

echo.
echo ============================================================
echo   Сайт (кабинет):  http://localhost:3000
echo   API / Swagger:   http://localhost:8000/api/docs/
echo   Django admin:    http://localhost:8000/admin/
echo.
echo   Логины кабинета:
echo     Оператор:   operator@kids.kz  / operator12345
echo     Админ:      admin@kids.kz     / admin12345
echo     Бухгалтер:  accountant@kids.kz/ accountant12345
echo ============================================================
echo.
echo   Ниже — живые логи. Закрыть логи: Ctrl+C (сервисы продолжат работать).
echo   Полностью остановить: запустите stop-docker.bat
echo.

docker compose logs -f
