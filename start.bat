@echo off
echo Starting Monitoring Stack with Prometheus and Grafana...
echo =====================================================

echo Checking Docker...
docker --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not installed or not running
    echo Please install Docker Desktop and start it
    pause
    exit /b 1
)

echo Docker found, starting services...
docker-compose up -d

echo.
echo Waiting for services to start...
timeout /t 30 /nobreak >nul

echo.
echo Services started! Access points:
echo - Grafana:      http://localhost:3000 (admin/admin123)
echo - Prometheus:   http://localhost:9090
echo - AlertManager: http://localhost:9093
echo - cAdvisor:     http://localhost:8080
echo.
echo To stop: docker-compose down
pause
