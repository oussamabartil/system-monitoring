@echo off
echo Stopping Monitoring Stack...
echo ============================

docker-compose down

echo.
echo Monitoring stack stopped.
echo To remove all data: docker-compose down -v
pause
