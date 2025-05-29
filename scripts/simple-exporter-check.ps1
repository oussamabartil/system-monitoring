# Script simple de verification Node Exporter / Windows Exporter
# Simple diagnostic script for Node/Windows Exporter

Write-Host "=== Diagnostic Exporter ===" -ForegroundColor Green

# 1. Verifier Windows Exporter Service
Write-Host "`n1. Verification Windows Exporter Service..." -ForegroundColor Yellow
$service = Get-Service -Name "windows_exporter" -ErrorAction SilentlyContinue

if ($service) {
    Write-Host "Service Windows Exporter trouve: $($service.Status)" -ForegroundColor Green
    
    if ($service.Status -eq "Running") {
        # Test connectivite
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:9182/metrics" -TimeoutSec 5 -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                Write-Host "Windows Exporter repond correctement sur port 9182" -ForegroundColor Green
                
                # Verifier metriques CPU
                if ($response.Content -match "windows_cpu_time_total") {
                    Write-Host "Metriques CPU disponibles" -ForegroundColor Green
                } else {
                    Write-Host "Metriques CPU non trouvees" -ForegroundColor Yellow
                }
            }
        } catch {
            Write-Host "Erreur connexion Windows Exporter: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "Service Windows Exporter arrete" -ForegroundColor Red
        Write-Host "Pour demarrer: Start-Service -Name windows_exporter" -ForegroundColor Yellow
    }
} else {
    Write-Host "Service Windows Exporter NON INSTALLE" -ForegroundColor Red
    Write-Host "Pour installer: .\scripts\install-windows-exporter.ps1" -ForegroundColor Yellow
}

# 2. Verifier configuration Prometheus
Write-Host "`n2. Verification configuration Prometheus..." -ForegroundColor Yellow
$prometheusConfig = Get-Content "prometheus\prometheus.yml" -Raw -ErrorAction SilentlyContinue

if ($prometheusConfig) {
    if ($prometheusConfig -match "job_name: 'windows-exporter'" -and $prometheusConfig -notmatch "#.*job_name: 'windows-exporter'") {
        Write-Host "Windows Exporter configure dans Prometheus" -ForegroundColor Green
    } else {
        Write-Host "Windows Exporter NON configure dans Prometheus" -ForegroundColor Red
        Write-Host "La section windows-exporter est commentee" -ForegroundColor Yellow
    }
} else {
    Write-Host "Fichier prometheus.yml non trouve" -ForegroundColor Red
}

# 3. Verifier conteneurs Docker
Write-Host "`n3. Verification conteneurs Docker..." -ForegroundColor Yellow
try {
    $containers = docker ps --format "table {{.Names}}\t{{.Status}}" 2>$null
    if ($containers) {
        Write-Host "Conteneurs actifs:" -ForegroundColor White
        Write-Host $containers -ForegroundColor Gray
        
        # Verifier Prometheus
        if ($containers -match "prometheus") {
            Write-Host "Prometheus en cours d'execution" -ForegroundColor Green
        } else {
            Write-Host "Prometheus NON actif" -ForegroundColor Red
        }
    } else {
        Write-Host "Aucun conteneur Docker actif" -ForegroundColor Red
    }
} catch {
    Write-Host "Erreur Docker: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Test connectivite Prometheus
Write-Host "`n4. Test connectivite Prometheus..." -ForegroundColor Yellow
try {
    $prometheusStatus = Invoke-WebRequest -Uri "http://localhost:9090/-/ready" -TimeoutSec 5 -UseBasicParsing
    if ($prometheusStatus.StatusCode -eq 200) {
        Write-Host "Prometheus accessible sur port 9090" -ForegroundColor Green
        
        # Verifier targets
        try {
            $targets = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/targets" -Method Get -TimeoutSec 10
            if ($targets.status -eq "success") {
                $activeTargets = $targets.data.activeTargets
                $windowsExporter = $activeTargets | Where-Object { $_.job -eq "windows-exporter" }
                
                if ($windowsExporter) {
                    Write-Host "Windows Exporter trouve dans Prometheus: $($windowsExporter.health)" -ForegroundColor Green
                } else {
                    Write-Host "Windows Exporter NON trouve dans les targets Prometheus" -ForegroundColor Red
                }
            }
        } catch {
            Write-Host "Erreur recuperation targets: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "Prometheus NON accessible: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. Test metriques CPU
Write-Host "`n5. Test metriques CPU..." -ForegroundColor Yellow
try {
    # Test metriques Windows via Prometheus
    $cpuQuery = "100-(avg(irate(windows_cpu_time_total{mode='idle'}[5m]))*100)"
    $windowsMetrics = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/query?query=$cpuQuery" -Method Get -TimeoutSec 10
    
    if ($windowsMetrics.status -eq "success" -and $windowsMetrics.data.result.Count -gt 0) {
        $cpuUsage = [math]::Round([double]$windowsMetrics.data.result[0].value[1], 2)
        Write-Host "Utilisation CPU actuelle: $cpuUsage%" -ForegroundColor White
        
        if ($cpuUsage -gt 85) {
            Write-Host "ATTENTION: CPU au-dessus du seuil d'alerte (85%)" -ForegroundColor Red
        } else {
            Write-Host "CPU en dessous du seuil d'alerte" -ForegroundColor Green
        }
    } else {
        Write-Host "Metriques CPU Windows non disponibles via Prometheus" -ForegroundColor Red
    }
} catch {
    Write-Host "Erreur recuperation metriques CPU: $($_.Exception.Message)" -ForegroundColor Red
}

# Resume
Write-Host "`n=== RESUME ===" -ForegroundColor Green

# Verifier si Windows Exporter est operationnel
$windowsExporterOK = $false
if ($service -and $service.Status -eq "Running") {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:9182/metrics" -TimeoutSec 5 -UseBasicParsing
        if ($response.StatusCode -eq 200 -and $response.Content -match "windows_cpu_time_total") {
            $windowsExporterOK = $true
        }
    } catch { }
}

if ($windowsExporterOK) {
    Write-Host "Windows Exporter: OPERATIONNEL" -ForegroundColor Green
} else {
    Write-Host "Windows Exporter: NON OPERATIONNEL" -ForegroundColor Red
    Write-Host "SOLUTION: Executer .\scripts\install-windows-exporter.ps1" -ForegroundColor Yellow
}

# Verifier configuration Prometheus
if ($prometheusConfig -and $prometheusConfig -match "job_name: 'windows-exporter'" -and $prometheusConfig -notmatch "#.*job_name: 'windows-exporter'") {
    Write-Host "Configuration Prometheus: OK" -ForegroundColor Green
} else {
    Write-Host "Configuration Prometheus: INCOMPLETE" -ForegroundColor Red
    Write-Host "SOLUTION: Decommenter la section windows-exporter dans prometheus.yml" -ForegroundColor Yellow
}

Write-Host "`nDiagnostic termine." -ForegroundColor Green
