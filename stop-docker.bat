@echo off
chcp 65001 >nul
title KidsTransfer — Stop
cd /d "%~dp0"

echo Останавливаю сервисы KidsTransfer...
docker compose down

echo.
echo Остановлено. Данные в базе сохранены (том pgdata).
echo Полностью удалить данные: docker compose down -v
pause
