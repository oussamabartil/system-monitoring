# Simple script to test alerts in AlertManager
Write-Host "=== TESTING ALERTMANAGER SETUP ===" -ForegroundColor Green
Write-Host ""

# Check if services are running
Write-Host "1. Checking Docker containers status..." -ForegroundColor Yellow
docker ps --format "table {{.Names}}\t{{.Status}}"
Write-Host ""

# Wait for Prometheus to be ready
Write-Host "2. Waiting for Prometheus to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Check Prometheus targets
Write-Host "3. Opening Prometheus interfaces..." -ForegroundColor Yellow
Write-Host "   - Prometheus Targets: http://localhost:9090/targets"
Write-Host "   - Prometheus Alerts: http://localhost:9090/alerts"
Write-Host "   - AlertManager: http://localhost:9093"
Write-Host ""

# Open the interfaces
Start-Process "http://localhost:9090/targets"
Start-Sleep -Seconds 2
Start-Process "http://localhost:9090/alerts"
Start-Sleep -Seconds 2
Start-Process "http://localhost:9093"

Write-Host "4. Instructions to see alerts:" -ForegroundColor Cyan
Write-Host "   a) Check Prometheus Targets page - ensure 'windows-exporter' target is UP"
Write-Host "   b) Check Prometheus Alerts page - you should see alert rules loaded"
Write-Host "   c) To trigger CPU alert, run: powershell -File cpu_stress_test.ps1"
Write-Host "   d) Wait 2-3 minutes for alerts to appear in AlertManager"
Write-Host ""

Write-Host "5. Common issues and solutions:" -ForegroundColor Red
Write-Host "   - If no targets: Check if Windows Exporter service is running"
Write-Host "   - If no alerts: Check alert rules syntax in prometheus/rules/alerts.yml"
Write-Host "   - If alerts don't fire: Verify metric names match Windows Exporter metrics"
Write-Host ""

$choice = Read-Host "Do you want to start a CPU stress test now? (y/N)"
if ($choice -eq 'y' -or $choice -eq 'Y') {
    Write-Host "Starting CPU stress test..." -ForegroundColor Green
    if (Test-Path "cpu_stress_test.ps1") {
        & ".\cpu_stress_test.ps1"
    } else {
        Write-Host "CPU stress test script not found. Creating a simple one..." -ForegroundColor Yellow
        # Simple CPU stress
        Write-Host "Running CPU stress for 3 minutes..."
        $jobs = @()
        for ($i = 1; $i -le 4; $i++) {
            $jobs += Start-Job -ScriptBlock {
                $end = (Get-Date).AddMinutes(3)
                while ((Get-Date) -lt $end) {
                    $result = 1
                    for ($j = 1; $j -le 1000; $j++) {
                        $result = $result * $j
                    }
                }
            }
        }
        Write-Host "CPU stress jobs started. Monitor the Prometheus alerts page."
        Write-Host "Jobs will complete in 3 minutes."
    }
}

Write-Host ""
Write-Host "=== MONITORING SETUP COMPLETE ===" -ForegroundColor Green
Write-Host "Keep the browser tabs open to monitor alerts!"
