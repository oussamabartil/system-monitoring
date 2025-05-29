# Script PowerShell pour tester et gérer le monitoring CPU
# Surveillance CPU avec alerte email à 85%

param(
    [switch]$TestAlert,
    [switch]$CheckConfig,
    [switch]$RestartServices,
    [string]$EmailTest = "oussamabartil.04@gmail.com"
)

Write-Host "🖥️  Script de gestion du monitoring CPU" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Cyan

function Test-CPUAlert {
    Write-Host "🧪 Test de l'alerte CPU..." -ForegroundColor Yellow
    
    # Vérification que les services sont en cours d'exécution
    $prometheusRunning = docker ps --filter "name=prometheus" --format "{{.Names}}" | Where-Object { $_ -eq "prometheus" }
    $alertmanagerRunning = docker ps --filter "name=alertmanager" --format "{{.Names}}" | Where-Object { $_ -eq "alertmanager" }
    
    if (-not $prometheusRunning) {
        Write-Host "❌ Prometheus n'est pas en cours d'exécution" -ForegroundColor Red
        return $false
    }
    
    if (-not $alertmanagerRunning) {
        Write-Host "❌ AlertManager n'est pas en cours d'exécution" -ForegroundColor Red
        return $false
    }
    
    Write-Host "✅ Services de monitoring actifs" -ForegroundColor Green
    
    # Vérification de la configuration des alertes
    Write-Host "📋 Vérification de la configuration des alertes..." -ForegroundColor Yellow
    
    try {
        $prometheusConfig = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/status/config" -Method Get
        Write-Host "✅ Configuration Prometheus accessible" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Impossible d'accéder à la configuration Prometheus" -ForegroundColor Red
        return $false
    }
    
    try {
        $alertmanagerConfig = Invoke-RestMethod -Uri "http://localhost:9093/api/v1/status" -Method Get
        Write-Host "✅ AlertManager accessible" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Impossible d'accéder à AlertManager" -ForegroundColor Red
        return $false
    }
    
    # Affichage de l'état actuel du CPU
    $cpuUsage = Get-Counter "\Processor(_Total)\% Processor Time" | Select-Object -ExpandProperty CounterSamples | Select-Object -ExpandProperty CookedValue
    $cpuUsage = [math]::Round(100 - $cpuUsage, 2)
    
    Write-Host "📊 Utilisation CPU actuelle: $cpuUsage%" -ForegroundColor White
    
    if ($cpuUsage -gt 85) {
        Write-Host "⚠️  ATTENTION: CPU au-dessus du seuil d'alerte (85%)" -ForegroundColor Red
        Write-Host "   Une alerte devrait être envoyée à $EmailTest" -ForegroundColor Yellow
    } else {
        Write-Host "✅ CPU en dessous du seuil d'alerte" -ForegroundColor Green
    }
    
    return $true
}

function Check-Configuration {
    Write-Host "🔍 Vérification de la configuration..." -ForegroundColor Yellow
    
    # Vérification du fichier d'alertes Prometheus
    $alertsFile = "prometheus\rules\alerts.yml"
    if (Test-Path $alertsFile) {
        $alertsContent = Get-Content $alertsFile -Raw
        if ($alertsContent -match "alert_type: cpu_high" -and $alertsContent -match "> 85") {
            Write-Host "✅ Règle d'alerte CPU configurée correctement (seuil: 85%)" -ForegroundColor Green
        } else {
            Write-Host "❌ Règle d'alerte CPU non configurée correctement" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Fichier d'alertes non trouvé" -ForegroundColor Red
    }
    
    # Vérification de la configuration AlertManager
    $alertmanagerFile = "alertmanager\alertmanager.yml"
    if (Test-Path $alertmanagerFile) {
        $alertmanagerContent = Get-Content $alertmanagerFile -Raw
        if ($alertmanagerContent -match "cpu-alerts-user" -and $alertmanagerContent -match $EmailTest) {
            Write-Host "✅ Configuration AlertManager correcte pour $EmailTest" -ForegroundColor Green
        } else {
            Write-Host "❌ Configuration AlertManager incorrecte" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Fichier AlertManager non trouvé" -ForegroundColor Red
    }
}

function Restart-MonitoringServices {
    Write-Host "🔄 Redémarrage des services de monitoring..." -ForegroundColor Yellow
    
    try {
        # Redémarrage des conteneurs pour appliquer la nouvelle configuration
        docker-compose restart prometheus alertmanager
        
        Write-Host "✅ Services redémarrés avec succès" -ForegroundColor Green
        
        # Attendre que les services soient prêts
        Write-Host "⏳ Attente de la disponibilité des services..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        
        # Vérification que les services sont accessibles
        $maxRetries = 6
        $retryCount = 0
        
        do {
            $retryCount++
            try {
                $prometheusStatus = Invoke-RestMethod -Uri "http://localhost:9090/-/ready" -Method Get -TimeoutSec 5
                $alertmanagerStatus = Invoke-RestMethod -Uri "http://localhost:9093/-/ready" -Method Get -TimeoutSec 5
                Write-Host "✅ Services prêts et accessibles" -ForegroundColor Green
                break
            }
            catch {
                if ($retryCount -lt $maxRetries) {
                    Write-Host "⏳ Tentative $retryCount/$maxRetries - Services en cours de démarrage..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 10
                } else {
                    Write-Host "❌ Timeout: Les services ne répondent pas après $maxRetries tentatives" -ForegroundColor Red
                }
            }
        } while ($retryCount -lt $maxRetries)
        
    }
    catch {
        Write-Host "❌ Erreur lors du redémarrage: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Exécution des actions selon les paramètres
if ($CheckConfig) {
    Check-Configuration
}

if ($RestartServices) {
    Restart-MonitoringServices
}

if ($TestAlert) {
    Test-CPUAlert
}

if (-not $CheckConfig -and -not $RestartServices -and -not $TestAlert) {
    Write-Host "💡 Utilisation du script:" -ForegroundColor White
    Write-Host "   -CheckConfig     : Vérifier la configuration" -ForegroundColor Yellow
    Write-Host "   -RestartServices : Redémarrer les services" -ForegroundColor Yellow
    Write-Host "   -TestAlert       : Tester l'alerte CPU" -ForegroundColor Yellow
    Write-Host "" -ForegroundColor White
    Write-Host "📧 Email configuré: $EmailTest" -ForegroundColor Cyan
    Write-Host "🎯 Seuil d'alerte: 85% CPU" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor White
    Write-Host "Exemples:" -ForegroundColor White
    Write-Host "   .\cpu-monitoring-test.ps1 -CheckConfig" -ForegroundColor Gray
    Write-Host "   .\cpu-monitoring-test.ps1 -RestartServices" -ForegroundColor Gray
    Write-Host "   .\cpu-monitoring-test.ps1 -TestAlert" -ForegroundColor Gray
}

Write-Host "`n✅ Script terminé" -ForegroundColor Green
