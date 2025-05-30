# Script de diagnostic pour Node Exporter / Windows Exporter
# Vérification de l'état des exporters de métriques système

param(
    [switch]$InstallWindowsExporter,
    [switch]$EnablePrometheusConfig,
    [switch]$Detailed
)

Write-Host "🔍 Diagnostic Node Exporter / Windows Exporter" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Cyan

function Test-WindowsExporter {
    Write-Host "`n📊 Vérification de Windows Exporter..." -ForegroundColor Yellow

    # Vérifier si le service Windows Exporter existe
    $service = Get-Service -Name "windows_exporter" -ErrorAction SilentlyContinue

    if ($service) {
        Write-Host "✅ Service Windows Exporter trouvé" -ForegroundColor Green
        Write-Host "   Statut: $($service.Status)" -ForegroundColor White
        Write-Host "   Mode de démarrage: $($service.StartType)" -ForegroundColor White

        if ($service.Status -eq "Running") {
            # Tester la connectivité
            try {
                $response = Invoke-WebRequest -Uri "http://localhost:9182/metrics" -TimeoutSec 5 -UseBasicParsing
                if ($response.StatusCode -eq 200) {
                    Write-Host "✅ Windows Exporter répond correctement sur le port 9182" -ForegroundColor Green

                    # Vérifier les métriques CPU
                    if ($response.Content -match "windows_cpu_time_total") {
                        Write-Host "✅ Métriques CPU disponibles" -ForegroundColor Green
                    } else {
                        Write-Host "⚠️  Métriques CPU non trouvées" -ForegroundColor Yellow
                    }

                    return $true
                } else {
                    Write-Host "❌ Windows Exporter ne répond pas correctement (Code: $($response.StatusCode))" -ForegroundColor Red
                }
            } catch {
                Write-Host "❌ Impossible de se connecter à Windows Exporter: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "❌ Service Windows Exporter arrêté" -ForegroundColor Red
            Write-Host "   Commande pour démarrer: Start-Service -Name windows_exporter" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Service Windows Exporter non installé" -ForegroundColor Red
        Write-Host "   Utilisez: .\install-windows-exporter.ps1 pour l'installer" -ForegroundColor Yellow
    }

    return $false
}

function Test-NodeExporter {
    Write-Host "`n🐧 Vérification de Node Exporter (Linux)..." -ForegroundColor Yellow

    # Vérifier si Node Exporter est configuré dans docker-compose
    $dockerCompose = Get-Content "docker-compose.yml" -Raw -ErrorAction SilentlyContinue

    if ($dockerCompose -and $dockerCompose -match "node-exporter:" -and $dockerCompose -notmatch "#.*node-exporter:") {
        Write-Host "✅ Node Exporter configuré dans docker-compose.yml" -ForegroundColor Green

        # Vérifier si le conteneur est en cours d'exécution
        try {
            $containers = docker ps --filter "name=node-exporter" --format "{{.Names}}" 2>$null
            if ($containers -contains "node-exporter") {
                Write-Host "✅ Conteneur Node Exporter en cours d'exécution" -ForegroundColor Green

                # Tester la connectivité
                try {
                    $response = Invoke-WebRequest -Uri "http://localhost:9100/metrics" -TimeoutSec 5 -UseBasicParsing
                    if ($response.StatusCode -eq 200) {
                        Write-Host "✅ Node Exporter répond correctement sur le port 9100" -ForegroundColor Green
                        return $true
                    }
                } catch {
                    Write-Host "❌ Node Exporter ne répond pas sur le port 9100" -ForegroundColor Red
                }
            } else {
                Write-Host "❌ Conteneur Node Exporter non trouvé" -ForegroundColor Red
            }
        } catch {
            Write-Host "❌ Erreur lors de la vérification Docker: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "ℹ️  Node Exporter désactivé (normal sur Windows)" -ForegroundColor Cyan
        Write-Host "   Node Exporter est conçu pour Linux uniquement" -ForegroundColor Gray
    }

    return $false
}

function Test-PrometheusConfiguration {
    Write-Host "`n⚙️  Vérification de la configuration Prometheus..." -ForegroundColor Yellow

    $prometheusConfig = Get-Content "prometheus\prometheus.yml" -Raw -ErrorAction SilentlyContinue

    if ($prometheusConfig) {
        # Vérifier la configuration Windows Exporter
        if ($prometheusConfig -match "job_name: 'windows-exporter'" -and $prometheusConfig -notmatch "#.*job_name: 'windows-exporter'") {
            Write-Host "✅ Windows Exporter configuré dans Prometheus" -ForegroundColor Green
        } else {
            Write-Host "❌ Windows Exporter non configuré dans Prometheus" -ForegroundColor Red
            Write-Host "   La section windows-exporter est commentée" -ForegroundColor Yellow
        }

        # Vérifier la configuration Node Exporter
        if ($prometheusConfig -match "job_name: 'node-exporter'" -and $prometheusConfig -notmatch "#.*job_name: 'node-exporter'") {
            Write-Host "✅ Node Exporter configuré dans Prometheus" -ForegroundColor Green
        } else {
            Write-Host "ℹ️  Node Exporter désactivé dans Prometheus (normal sur Windows)" -ForegroundColor Cyan
        }
    } else {
        Write-Host "❌ Fichier prometheus.yml non trouvé" -ForegroundColor Red
    }
}

function Test-PrometheusTargets {
    Write-Host "`n🎯 Vérification des cibles Prometheus..." -ForegroundColor Yellow

    try {
        $targets = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/targets" -Method Get -TimeoutSec 10

        if ($targets.status -eq "success") {
            $activeTargets = $targets.data.activeTargets

            # Rechercher Windows Exporter
            $windowsExporter = $activeTargets | Where-Object { $_.job -eq "windows-exporter" }
            if ($windowsExporter) {
                $health = $windowsExporter.health
                Write-Host "✅ Windows Exporter trouvé dans Prometheus" -ForegroundColor Green
                Write-Host "   Statut: $health" -ForegroundColor White
                Write-Host "   URL: $($windowsExporter.scrapeUrl)" -ForegroundColor White

                if ($health -eq "up") {
                    Write-Host "✅ Windows Exporter opérationnel" -ForegroundColor Green
                    return $true
                } else {
                    Write-Host "❌ Windows Exporter en erreur: $($windowsExporter.lastError)" -ForegroundColor Red
                }
            } else {
                Write-Host "❌ Windows Exporter non trouvé dans les cibles Prometheus" -ForegroundColor Red
            }

            # Rechercher Node Exporter
            $nodeExporter = $activeTargets | Where-Object { $_.job -eq "node-exporter" }
            if ($nodeExporter) {
                Write-Host "✅ Node Exporter trouvé dans Prometheus (Statut: $($nodeExporter.health))" -ForegroundColor Green
            }

        } else {
            Write-Host "❌ Erreur lors de la récupération des cibles Prometheus" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Impossible de se connecter à Prometheus: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   Vérifiez que Prometheus est en cours d'exécution sur le port 9090" -ForegroundColor Yellow
    }

    return $false
}

function Show-CPUMetrics {
    Write-Host "`n📈 Test des métriques CPU..." -ForegroundColor Yellow

    try {
        # Tester les métriques Windows
        $windowsMetrics = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/query?query=100-(avg(irate(windows_cpu_time_total{mode='idle'}[5m]))*100)" -Method Get -TimeoutSec 10

        if ($windowsMetrics.status -eq "success" -and $windowsMetrics.data.result.Count -gt 0) {
            $cpuUsage = [math]::Round([double]$windowsMetrics.data.result[0].value[1], 2)
            Write-Host "✅ Métriques CPU Windows disponibles" -ForegroundColor Green
            Write-Host "   Utilisation CPU actuelle: $cpuUsage pourcent" -ForegroundColor White

            if ($cpuUsage -gt 85) {
                Write-Host "WARNING: CPU au-dessus du seuil d'alerte (85 pourcent)" -ForegroundColor Red
            }

            return $true
        } else {
            Write-Host "❌ Métriques CPU Windows non disponibles" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Erreur lors de la récupération des métriques CPU: $($_.Exception.Message)" -ForegroundColor Red
    }

    return $false
}

# Exécution des vérifications
Write-Host "🖥️  Système: Windows" -ForegroundColor Cyan
Write-Host "📅 Date: $(Get-Date)" -ForegroundColor Cyan

$windowsExporterOK = Test-WindowsExporter
$nodeExporterOK = Test-NodeExporter
Test-PrometheusConfiguration
$prometheusTargetsOK = Test-PrometheusTargets

if ($Detailed) {
    Show-CPUMetrics
}

# Résumé et recommandations
Write-Host "`n📋 RÉSUMÉ" -ForegroundColor Green
Write-Host "=========" -ForegroundColor Cyan

if ($windowsExporterOK) {
    Write-Host "✅ Windows Exporter opérationnel" -ForegroundColor Green
} else {
    Write-Host "❌ Windows Exporter non opérationnel" -ForegroundColor Red
    Write-Host "   RECOMMANDATION: Installer Windows Exporter" -ForegroundColor Yellow
    Write-Host "   Commande: .\scripts\install-windows-exporter.ps1" -ForegroundColor White
}

if (-not $prometheusTargetsOK -and $windowsExporterOK) {
    Write-Host "❌ Configuration Prometheus incomplète" -ForegroundColor Red
    Write-Host "   RECOMMANDATION: Activer Windows Exporter dans Prometheus" -ForegroundColor Yellow
    Write-Host "   Utilisez le paramètre -EnablePrometheusConfig" -ForegroundColor White
}

# Actions automatiques si demandées
if ($InstallWindowsExporter -and -not $windowsExporterOK) {
    Write-Host "`n🚀 Installation de Windows Exporter..." -ForegroundColor Green
    & ".\scripts\install-windows-exporter.ps1"
}

if ($EnablePrometheusConfig) {
    Write-Host "`n⚙️  Activation de Windows Exporter dans Prometheus..." -ForegroundColor Green
    # Cette fonctionnalité sera implémentée dans la prochaine version
    Write-Host "   Fonctionnalité en cours de développement" -ForegroundColor Yellow
}

Write-Host "`nDiagnostic termine" -ForegroundColor Green
