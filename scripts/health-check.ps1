# Script PowerShell pour vérifier la santé de la stack de monitoring
# Supervision des Systèmes avec Prometheus & Grafana

Write-Host "🏥 Vérification de santé de la stack de monitoring" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Cyan

# Fonction pour tester la connectivité HTTP
function Test-HttpEndpoint {
    param(
        [string]$Name,
        [string]$Url,
        [int]$ExpectedStatusCode = 200,
        [int]$TimeoutSeconds = 10
    )
    
    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec $TimeoutSeconds -UseBasicParsing
        if ($response.StatusCode -eq $ExpectedStatusCode) {
            Write-Host "✅ $Name - OK ($($response.StatusCode))" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️  $Name - Statut inattendu ($($response.StatusCode))" -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "❌ $Name - Erreur: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Fonction pour vérifier l'état des conteneurs Docker
function Test-DockerContainers {
    Write-Host "`n🐳 État des conteneurs Docker:" -ForegroundColor Yellow
    
    $containers = @(
        "prometheus",
        "grafana", 
        "alertmanager",
        "node-exporter",
        "cadvisor",
        "windows-exporter"
    )
    
    $allHealthy = $true
    
    foreach ($container in $containers) {
        try {
            $status = docker inspect --format='{{.State.Status}}' $container 2>$null
            $health = docker inspect --format='{{.State.Health.Status}}' $container 2>$null
            
            if ($status -eq "running") {
                if ($health -and $health -ne "<no value>") {
                    if ($health -eq "healthy") {
                        Write-Host "✅ $container - Running & Healthy" -ForegroundColor Green
                    } else {
                        Write-Host "⚠️  $container - Running but $health" -ForegroundColor Yellow
                        $allHealthy = $false
                    }
                } else {
                    Write-Host "✅ $container - Running" -ForegroundColor Green
                }
            } else {
                Write-Host "❌ $container - $status" -ForegroundColor Red
                $allHealthy = $false
            }
        } catch {
            Write-Host "❌ $container - Non trouvé" -ForegroundColor Red
            $allHealthy = $false
        }
    }
    
    return $allHealthy
}

# Fonction pour vérifier les métriques Prometheus
function Test-PrometheusMetrics {
    Write-Host "`n📊 Vérification des métriques Prometheus:" -ForegroundColor Yellow
    
    $targets = @(
        @{Name="Prometheus"; Query="up{job='prometheus'}"},
        @{Name="Node Exporter"; Query="up{job='node-exporter'}"},
        @{Name="cAdvisor"; Query="up{job='cadvisor'}"},
        @{Name="Windows Exporter"; Query="up{job='windows-exporter'}"},
        @{Name="Grafana"; Query="up{job='grafana'}"}
    )
    
    $allTargetsUp = $true
    
    foreach ($target in $targets) {
        try {
            $url = "http://localhost:9090/api/v1/query?query=$($target.Query)"
            $response = Invoke-RestMethod -Uri $url -TimeoutSec 5
            
            if ($response.status -eq "success" -and $response.data.result.Count -gt 0) {
                $value = $response.data.result[0].value[1]
                if ($value -eq "1") {
                    Write-Host "✅ $($target.Name) - Métriques OK" -ForegroundColor Green
                } else {
                    Write-Host "❌ $($target.Name) - Target DOWN" -ForegroundColor Red
                    $allTargetsUp = $false
                }
            } else {
                Write-Host "⚠️  $($target.Name) - Pas de données" -ForegroundColor Yellow
                $allTargetsUp = $false
            }
        } catch {
            Write-Host "❌ $($target.Name) - Erreur de requête" -ForegroundColor Red
            $allTargetsUp = $false
        }
    }
    
    return $allTargetsUp
}

# Fonction pour vérifier les alertes actives
function Test-ActiveAlerts {
    Write-Host "`n🚨 Vérification des alertes actives:" -ForegroundColor Yellow
    
    try {
        $url = "http://localhost:9090/api/v1/alerts"
        $response = Invoke-RestMethod -Uri $url -TimeoutSec 5
        
        if ($response.status -eq "success") {
            $activeAlerts = $response.data.alerts | Where-Object { $_.state -eq "firing" }
            
            if ($activeAlerts.Count -eq 0) {
                Write-Host "✅ Aucune alerte active" -ForegroundColor Green
                return $true
            } else {
                Write-Host "⚠️  $($activeAlerts.Count) alerte(s) active(s):" -ForegroundColor Yellow
                foreach ($alert in $activeAlerts) {
                    Write-Host "   • $($alert.labels.alertname) - $($alert.annotations.summary)" -ForegroundColor Red
                }
                return $false
            }
        }
    } catch {
        Write-Host "❌ Impossible de récupérer les alertes" -ForegroundColor Red
        return $false
    }
}

# Fonction pour vérifier l'espace disque
function Test-DiskSpace {
    Write-Host "`n💽 Vérification de l'espace disque:" -ForegroundColor Yellow
    
    $drives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
    $allDrivesOk = $true
    
    foreach ($drive in $drives) {
        $freeSpacePercent = [math]::Round(($drive.FreeSpace / $drive.Size) * 100, 2)
        
        if ($freeSpacePercent -gt 20) {
            Write-Host "✅ Disque $($drive.DeviceID) - $freeSpacePercent% libre" -ForegroundColor Green
        } elseif ($freeSpacePercent -gt 10) {
            Write-Host "⚠️  Disque $($drive.DeviceID) - $freeSpacePercent% libre (Attention)" -ForegroundColor Yellow
            $allDrivesOk = $false
        } else {
            Write-Host "❌ Disque $($drive.DeviceID) - $freeSpacePercent% libre (CRITIQUE)" -ForegroundColor Red
            $allDrivesOk = $false
        }
    }
    
    return $allDrivesOk
}

# Exécution des vérifications
$results = @{}

# Vérification des conteneurs
$results.Containers = Test-DockerContainers

# Vérification des endpoints HTTP
Write-Host "`n🌐 Vérification des endpoints HTTP:" -ForegroundColor Yellow
$results.Grafana = Test-HttpEndpoint -Name "Grafana" -Url "http://localhost:3000/api/health"
$results.Prometheus = Test-HttpEndpoint -Name "Prometheus" -Url "http://localhost:9090/-/healthy"
$results.AlertManager = Test-HttpEndpoint -Name "AlertManager" -Url "http://localhost:9093/-/healthy"
$results.NodeExporter = Test-HttpEndpoint -Name "Node Exporter" -Url "http://localhost:9100/metrics"
$results.cAdvisor = Test-HttpEndpoint -Name "cAdvisor" -Url "http://localhost:8080/healthz"
$results.WindowsExporter = Test-HttpEndpoint -Name "Windows Exporter" -Url "http://localhost:9182/metrics"

# Vérification des métriques
$results.Metrics = Test-PrometheusMetrics

# Vérification des alertes
$results.Alerts = Test-ActiveAlerts

# Vérification de l'espace disque
$results.DiskSpace = Test-DiskSpace

# Résumé final
Write-Host "`n📋 Résumé de la vérification de santé:" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

$overallHealth = $true
foreach ($check in $results.GetEnumerator()) {
    if ($check.Value) {
        Write-Host "✅ $($check.Key) - OK" -ForegroundColor Green
    } else {
        Write-Host "❌ $($check.Key) - PROBLÈME" -ForegroundColor Red
        $overallHealth = $false
    }
}

Write-Host "`n🎯 État général du système:" -ForegroundColor White
if ($overallHealth) {
    Write-Host "✅ SYSTÈME EN BONNE SANTÉ" -ForegroundColor Green
    exit 0
} else {
    Write-Host "⚠️  PROBLÈMES DÉTECTÉS - Vérifiez les détails ci-dessus" -ForegroundColor Red
    exit 1
}
