# Script complet pour configurer le monitoring CPU avec alertes email
# Complete setup script for CPU monitoring with email alerts

param(
    [switch]$Force
)

Write-Host "=== Configuration Monitoring CPU ===" -ForegroundColor Green
Write-Host "Email d'alerte: oussamabartil.04@gmail.com" -ForegroundColor Cyan
Write-Host "Seuil d'alerte: 85% CPU" -ForegroundColor Cyan

# Verification des privileges administrateur
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERREUR: Ce script doit etre execute en tant qu'administrateur!" -ForegroundColor Red
    Write-Host "Clic droit sur PowerShell -> Executer en tant qu'administrateur" -ForegroundColor Yellow
    exit 1
}

# Etape 1: Verifier si Windows Exporter est deja installe
Write-Host "`n1. Verification Windows Exporter..." -ForegroundColor Yellow
$service = Get-Service -Name "windows_exporter" -ErrorAction SilentlyContinue

if ($service -and $service.Status -eq "Running" -and -not $Force) {
    Write-Host "Windows Exporter deja installe et actif" -ForegroundColor Green
    
    # Test connectivite
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:9182/metrics" -TimeoutSec 5 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Host "Windows Exporter operationnel" -ForegroundColor Green
            $skipInstall = $true
        }
    } catch {
        Write-Host "Windows Exporter ne repond pas, reinstallation necessaire" -ForegroundColor Yellow
        $skipInstall = $false
    }
} else {
    $skipInstall = $false
}

# Etape 2: Installer Windows Exporter si necessaire
if (-not $skipInstall) {
    Write-Host "`n2. Installation Windows Exporter..." -ForegroundColor Yellow
    
    try {
        & ".\scripts\install-windows-exporter.ps1" -StartService
        Write-Host "Windows Exporter installe avec succes" -ForegroundColor Green
    } catch {
        Write-Host "ERREUR lors de l'installation: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "`n2. Installation Windows Exporter... IGNORE (deja installe)" -ForegroundColor Green
}

# Etape 3: Redemarrer Prometheus pour prendre en compte la nouvelle configuration
Write-Host "`n3. Redemarrage Prometheus..." -ForegroundColor Yellow
try {
    docker-compose restart prometheus
    Write-Host "Prometheus redémarre..." -ForegroundColor Green
    
    # Attendre que Prometheus soit pret
    $maxRetries = 12
    $retryCount = 0
    
    do {
        $retryCount++
        Start-Sleep -Seconds 5
        try {
            $prometheusStatus = Invoke-WebRequest -Uri "http://localhost:9090/-/ready" -TimeoutSec 5 -UseBasicParsing
            if ($prometheusStatus.StatusCode -eq 200) {
                Write-Host "Prometheus pret" -ForegroundColor Green
                break
            }
        } catch {
            if ($retryCount -lt $maxRetries) {
                Write-Host "Attente Prometheus... ($retryCount/$maxRetries)" -ForegroundColor Yellow
            } else {
                Write-Host "TIMEOUT: Prometheus ne repond pas" -ForegroundColor Red
                exit 1
            }
        }
    } while ($retryCount -lt $maxRetries)
    
} catch {
    Write-Host "ERREUR redemarrage Prometheus: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Etape 4: Redemarrer AlertManager pour les nouvelles alertes
Write-Host "`n4. Redemarrage AlertManager..." -ForegroundColor Yellow
try {
    docker-compose restart alertmanager
    Start-Sleep -Seconds 10
    Write-Host "AlertManager redémarre" -ForegroundColor Green
} catch {
    Write-Host "ERREUR redemarrage AlertManager: $($_.Exception.Message)" -ForegroundColor Red
}

# Etape 5: Verification finale
Write-Host "`n5. Verification finale..." -ForegroundColor Yellow

# Verifier Windows Exporter
try {
    $response = Invoke-WebRequest -Uri "http://localhost:9182/metrics" -TimeoutSec 5 -UseBasicParsing
    if ($response.StatusCode -eq 200 -and $response.Content -match "windows_cpu_time_total") {
        Write-Host "Windows Exporter: OK" -ForegroundColor Green
    } else {
        Write-Host "Windows Exporter: ERREUR" -ForegroundColor Red
    }
} catch {
    Write-Host "Windows Exporter: NON ACCESSIBLE" -ForegroundColor Red
}

# Verifier Prometheus targets
try {
    $targets = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/targets" -Method Get -TimeoutSec 10
    if ($targets.status -eq "success") {
        $windowsExporter = $targets.data.activeTargets | Where-Object { $_.job -eq "windows-exporter" }
        if ($windowsExporter -and $windowsExporter.health -eq "up") {
            Write-Host "Prometheus target Windows Exporter: OK" -ForegroundColor Green
        } else {
            Write-Host "Prometheus target Windows Exporter: ERREUR" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "Prometheus targets: NON ACCESSIBLE" -ForegroundColor Red
}

# Verifier metriques CPU
try {
    $cpuQuery = "100-(avg(irate(windows_cpu_time_total{mode='idle'}[5m]))*100)"
    $windowsMetrics = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/query?query=$cpuQuery" -Method Get -TimeoutSec 10
    
    if ($windowsMetrics.status -eq "success" -and $windowsMetrics.data.result.Count -gt 0) {
        $cpuUsage = [math]::Round([double]$windowsMetrics.data.result[0].value[1], 2)
        Write-Host "Metriques CPU: OK (Utilisation actuelle: $cpuUsage%)" -ForegroundColor Green
        
        if ($cpuUsage -gt 85) {
            Write-Host "ATTENTION: CPU au-dessus du seuil d'alerte!" -ForegroundColor Red
        }
    } else {
        Write-Host "Metriques CPU: NON DISPONIBLES" -ForegroundColor Red
    }
} catch {
    Write-Host "Metriques CPU: ERREUR" -ForegroundColor Red
}

# Verifier AlertManager
try {
    $alertmanagerStatus = Invoke-WebRequest -Uri "http://localhost:9093/-/ready" -TimeoutSec 5 -UseBasicParsing
    if ($alertmanagerStatus.StatusCode -eq 200) {
        Write-Host "AlertManager: OK" -ForegroundColor Green
    } else {
        Write-Host "AlertManager: ERREUR" -ForegroundColor Red
    }
} catch {
    Write-Host "AlertManager: NON ACCESSIBLE" -ForegroundColor Red
}

# Resume final
Write-Host "`n=== CONFIGURATION TERMINEE ===" -ForegroundColor Green
Write-Host "Monitoring CPU configure avec succes!" -ForegroundColor White
Write-Host "Email d'alerte: oussamabartil.04@gmail.com" -ForegroundColor Cyan
Write-Host "Seuil d'alerte: 85% CPU" -ForegroundColor Cyan
Write-Host "Delai avant alerte: 5 minutes" -ForegroundColor Cyan

Write-Host "`nURLs utiles:" -ForegroundColor Yellow
Write-Host "- Prometheus: http://localhost:9090" -ForegroundColor White
Write-Host "- Grafana: http://localhost:3000 (admin/admin123)" -ForegroundColor White
Write-Host "- AlertManager: http://localhost:9093" -ForegroundColor White
Write-Host "- Windows Exporter: http://localhost:9182/metrics" -ForegroundColor White

Write-Host "`nPour tester les alertes:" -ForegroundColor Yellow
Write-Host ".\scripts\simple-exporter-check.ps1" -ForegroundColor White

Write-Host "`nIMPORTANT: Configurez les parametres SMTP dans alertmanager.yml" -ForegroundColor Red
Write-Host "pour que les emails soient effectivement envoyes." -ForegroundColor Red
