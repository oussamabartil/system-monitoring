# Check Windows Exporter metrics and Prometheus connectivity
Write-Host "=== CHECKING METRICS AND CONNECTIVITY ===" -ForegroundColor Green
Write-Host ""

# Test Windows Exporter directly
Write-Host "1. Testing Windows Exporter (port 9182)..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:9182/metrics" -UseBasicParsing -TimeoutSec 5
    $metrics = $response.Content

    # Check for CPU metrics
    $cpuMetrics = $metrics | Select-String "windows_cpu_time_total" | Select-Object -First 3
    if ($cpuMetrics) {
        Write-Host "   ✅ Windows CPU metrics found:" -ForegroundColor Green
        $cpuMetrics | ForEach-Object { Write-Host "      $($_.Line)" }
    } else {
        Write-Host "   ❌ No windows_cpu_time_total metrics found" -ForegroundColor Red
        # Check for alternative CPU metrics
        $altCpuMetrics = $metrics | Select-String "windows_cpu" | Select-Object -First 3
        if ($altCpuMetrics) {
            Write-Host "   📊 Alternative CPU metrics found:" -ForegroundColor Yellow
            $altCpuMetrics | ForEach-Object { Write-Host "      $($_.Line)" }
        }
    }

    # Check for memory metrics
    $memMetrics = $metrics | Select-String "windows_cs_physical_memory_bytes|windows_os_physical_memory_free_bytes" | Select-Object -First 2
    if ($memMetrics) {
        Write-Host "   ✅ Windows memory metrics found:" -ForegroundColor Green
        $memMetrics | ForEach-Object { Write-Host "      $($_.Line)" }
    } else {
        Write-Host "   ❌ No expected memory metrics found" -ForegroundColor Red
    }

} catch {
    Write-Host "   ❌ Failed to connect to Windows Exporter: $($_.Exception.Message)" -ForegroundColor Red
}

} catch {
    Write-Host "   ❌ Failed to connect to Windows Exporter: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test Prometheus connectivity
Write-Host "2. Testing Prometheus (port 9090)..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:9090/api/v1/targets" -UseBasicParsing -TimeoutSec 5
    $targets = $response.Content | ConvertFrom-Json

    $windowsTarget = $targets.data.activeTargets | Where-Object { $_.job -eq "windows-exporter" }
    if ($windowsTarget) {
        Write-Host "   ✅ Windows Exporter target found:" -ForegroundColor Green
        Write-Host "      Health: $($windowsTarget.health)"
        Write-Host "      Last Scrape: $($windowsTarget.lastScrape)"
        if ($windowsTarget.lastError) {
            Write-Host "      Last Error: $($windowsTarget.lastError)" -ForegroundColor Red
        }
    } else {
        Write-Host "   ❌ Windows Exporter target not found in Prometheus" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ Failed to connect to Prometheus: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test AlertManager
Write-Host "3. Testing AlertManager (port 9093)..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:9093/api/v1/alerts" -UseBasicParsing -TimeoutSec 5
    $alerts = $response.Content | ConvertFrom-Json

    if ($alerts.data -and $alerts.data.Count -gt 0) {
        Write-Host "   ✅ AlertManager has $($alerts.data.Count) alerts:" -ForegroundColor Green
        $alerts.data | ForEach-Object {
            Write-Host "      - $($_.labels.alertname): $($_.status.state)"
        }
    } else {
        Write-Host "   ℹ️ AlertManager is running but no alerts are currently active" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ❌ Failed to connect to AlertManager: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Check Prometheus rules
Write-Host "4. Testing Prometheus rules..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:9090/api/v1/rules" -UseBasicParsing -TimeoutSec 5
    $rules = $response.Content | ConvertFrom-Json

    if ($rules.data -and $rules.data.groups) {
        $totalRules = ($rules.data.groups | ForEach-Object { $_.rules.Count } | Measure-Object -Sum).Sum
        Write-Host "   ✅ Prometheus has $totalRules rules loaded in $($rules.data.groups.Count) groups" -ForegroundColor Green

        $rules.data.groups | ForEach-Object {
            Write-Host "      Group: $($_.name) ($($_.rules.Count) rules)"
        }
    } else {
        Write-Host "   ❌ No rules found in Prometheus" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ Failed to get rules from Prometheus: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Green
Write-Host "If all tests pass, alerts should work. If not:"
Write-Host "1. Ensure Windows Exporter service is running"
Write-Host "2. Check Prometheus configuration for correct target"
Write-Host "3. Verify alert rules use correct metric names"
Write-Host "4. Wait 2-5 minutes for metrics to be collected and rules to evaluate"
