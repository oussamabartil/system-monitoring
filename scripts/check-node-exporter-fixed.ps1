# Script de diagnostic pour Node Exporter / Windows Exporter
# Verification de l'etat des exporters de metriques systeme

param(
    [switch]$InstallWindowsExporter,
    [switch]$EnablePrometheusConfig,
    [switch]$Detailed
)

Write-Host "Diagnostic Node Exporter / Windows Exporter" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Cyan

function Test-WindowsExporter {
    Write-Host "`nVerification de Windows Exporter..." -ForegroundColor Yellow

    # Verifier si le service Windows Exporter existe
    $service = Get-Service -Name "windows_exporter" -ErrorAction SilentlyContinue

    if ($service) {
        Write-Host "Service Windows Exporter trouve" -ForegroundColor Green
        Write-Host "   Statut: $($service.Status)" -ForegroundColor White
        Write-Host "   Mode de demarrage: $($service.StartType)" -ForegroundColor White

        if ($service.Status -eq "Running") {
            # Tester la connectivite
            try {
                $response = Invoke-WebRequest -Uri "http://localhost:9182/metrics" -TimeoutSec 5 -UseBasicParsing
                if ($response.StatusCode -eq 200) {
                    Write-Host "Windows Exporter repond correctement sur le port 9182" -ForegroundColor Green

                    # Verifier les metriques CPU
                    if ($response.Content -match "windows_cpu_time_total") {
                        Write-Host "Metriques CPU disponibles" -ForegroundColor Green
                    } else {
                        Write-Host "Metriques CPU non trouvees" -ForegroundColor Yellow
                    }

                    return $true
                } else {
                    Write-Host "Windows Exporter ne repond pas correctement (Code: $($response.StatusCode))" -ForegroundColor Red
                }
            } catch {
                Write-Host "Impossible de se connecter a Windows Exporter: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "Service Windows Exporter arrete" -ForegroundColor Red
            Write-Host "   Commande pour demarrer: Start-Service -Name windows_exporter" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Service Windows Exporter non installe" -ForegroundColor Red
        Write-Host "   Utilisez: .\install-windows-exporter.ps1 pour l'installer" -ForegroundColor Yellow
    }

    return $false
}

function Test-NodeExporter {
    Write-Host "`nVerification de Node Exporter (Linux)..." -ForegroundColor Yellow

    # Verifier si Node Exporter est configure dans docker-compose
    $dockerCompose = Get-Content "docker-compose.yml" -Raw -ErrorAction SilentlyContinue

    if ($dockerCompose -and $dockerCompose -match "node-exporter:" -and $dockerCompose -notmatch "#.*node-exporter:") {
        Write-Host "Node Exporter configure dans docker-compose.yml" -ForegroundColor Green

        # Verifier si le conteneur est en cours d'execution
        try {
            $containers = docker ps --filter "name=node-exporter" --format "{{.Names}}" 2>$null
            if ($containers -contains "node-exporter") {
                Write-Host "Conteneur Node Exporter en cours d'execution" -ForegroundColor Green

                # Tester la connectivite
                try {
                    $response = Invoke-WebRequest -Uri "http://localhost:9100/metrics" -TimeoutSec 5 -UseBasicParsing
                    if ($response.StatusCode -eq 200) {
                        Write-Host "Node Exporter repond correctement sur le port 9100" -ForegroundColor Green
                        return $true
                    }
                } catch {
                    Write-Host "Node Exporter ne repond pas sur le port 9100" -ForegroundColor Red
                }
            } else {
                Write-Host "Conteneur Node Exporter non trouve" -ForegroundColor Red
            }
        } catch {
            Write-Host "Erreur lors de la verification Docker: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "Node Exporter desactive (normal sur Windows)" -ForegroundColor Cyan
        Write-Host "   Node Exporter est concu pour Linux uniquement" -ForegroundColor Gray
    }

    return $false
}

function Test-PrometheusConfiguration {
    Write-Host "`nVerification de la configuration Prometheus..." -ForegroundColor Yellow

    $prometheusConfig = Get-Content "prometheus\prometheus.yml" -Raw -ErrorAction SilentlyContinue

    if ($prometheusConfig) {
        # Verifier la configuration Windows Exporter
        if ($prometheusConfig -match "job_name: 'windows-exporter'" -and $prometheusConfig -notmatch "#.*job_name: 'windows-exporter'") {
            Write-Host "Windows Exporter configure dans Prometheus" -ForegroundColor Green
        } else {
            Write-Host "Windows Exporter non configure dans Prometheus" -ForegroundColor Red
            Write-Host "   La section windows-exporter est commentee" -ForegroundColor Yellow
        }

        # Verifier la configuration Node Exporter
        if ($prometheusConfig -match "job_name: 'node-exporter'" -and $prometheusConfig -notmatch "#.*job_name: 'node-exporter'") {
            Write-Host "Node Exporter configure dans Prometheus" -ForegroundColor Green
        } else {
            Write-Host "Node Exporter desactive dans Prometheus (normal sur Windows)" -ForegroundColor Cyan
        }
    } else {
        Write-Host "Fichier prometheus.yml non trouve" -ForegroundColor Red
    }
}

function Test-PrometheusTargets {
    Write-Host "`nVerification des cibles Prometheus..." -ForegroundColor Yellow

    try {
        $targets = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/targets" -Method Get -TimeoutSec 10

        if ($targets.status -eq "success") {
            $activeTargets = $targets.data.activeTargets

            # Rechercher Windows Exporter
            $windowsExporter = $activeTargets | Where-Object { $_.job -eq "windows-exporter" }
            if ($windowsExporter) {
                $health = $windowsExporter.health
                Write-Host "Windows Exporter trouve dans Prometheus" -ForegroundColor Green
                Write-Host "   Statut: $health" -ForegroundColor White
                Write-Host "   URL: $($windowsExporter.scrapeUrl)" -ForegroundColor White

                if ($health -eq "up") {
                    Write-Host "Windows Exporter operationnel" -ForegroundColor Green
                    return $true
                } else {
                    Write-Host "Windows Exporter en erreur: $($windowsExporter.lastError)" -ForegroundColor Red
                }
            } else {
                Write-Host "Windows Exporter non trouve dans les cibles Prometheus" -ForegroundColor Red
            }

            # Rechercher Node Exporter
            $nodeExporter = $activeTargets | Where-Object { $_.job -eq "node-exporter" }
            if ($nodeExporter) {
                Write-Host "Node Exporter trouve dans Prometheus (Statut: $($nodeExporter.health))" -ForegroundColor Green
            }

        } else {
            Write-Host "Erreur lors de la recuperation des cibles Prometheus" -ForegroundColor Red
        }
    } catch {
        Write-Host "Impossible de se connecter a Prometheus: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   Verifiez que Prometheus est en cours d'execution sur le port 9090" -ForegroundColor Yellow
    }

    return $false
}

function Show-CPUMetrics {
    Write-Host "`nTest des metriques CPU..." -ForegroundColor Yellow

    try {
        # Tester les metriques Windows
        $windowsMetrics = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/query?query=100-(avg(irate(windows_cpu_time_total{mode='idle'}[5m]))*100)" -Method Get -TimeoutSec 10

        if ($windowsMetrics.status -eq "success" -and $windowsMetrics.data.result.Count -gt 0) {
            $cpuUsage = [math]::Round([double]$windowsMetrics.data.result[0].value[1], 2)
            Write-Host "Metriques CPU Windows disponibles" -ForegroundColor Green
            Write-Host "   Utilisation CPU actuelle: $cpuUsage pourcent" -ForegroundColor White

            if ($cpuUsage -gt 85) {
                Write-Host "WARNING: CPU au-dessus du seuil d'alerte (85 pourcent)" -ForegroundColor Red
            }

            return $true
        } else {
            Write-Host "Metriques CPU Windows non disponibles" -ForegroundColor Red
        }
    } catch {
        Write-Host "Erreur lors de la recuperation des metriques CPU: $($_.Exception.Message)" -ForegroundColor Red
    }

    return $false
}

# Execution des verifications
Write-Host "Systeme: Windows" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date)" -ForegroundColor Cyan

$windowsExporterOK = Test-WindowsExporter
$nodeExporterOK = Test-NodeExporter
Test-PrometheusConfiguration
$prometheusTargetsOK = Test-PrometheusTargets

if ($Detailed) {
    Show-CPUMetrics
}

# Resume et recommandations
Write-Host "`nRESUME" -ForegroundColor Green
Write-Host "=========" -ForegroundColor Cyan

if ($windowsExporterOK) {
    Write-Host "Windows Exporter operationnel" -ForegroundColor Green
} else {
    Write-Host "Windows Exporter non operationnel" -ForegroundColor Red
    Write-Host "   RECOMMANDATION: Installer Windows Exporter" -ForegroundColor Yellow
    Write-Host "   Commande: .\scripts\install-windows-exporter.ps1" -ForegroundColor White
}

if (-not $prometheusTargetsOK -and $windowsExporterOK) {
    Write-Host "Configuration Prometheus incomplete" -ForegroundColor Red
    Write-Host "   RECOMMANDATION: Activer Windows Exporter dans Prometheus" -ForegroundColor Yellow
    Write-Host "   Utilisez le parametre -EnablePrometheusConfig" -ForegroundColor White
}

# Actions automatiques si demandees
if ($InstallWindowsExporter -and -not $windowsExporterOK) {
    Write-Host "`nInstallation de Windows Exporter..." -ForegroundColor Green
    & ".\scripts\install-windows-exporter.ps1"
}

if ($EnablePrometheusConfig) {
    Write-Host "`nActivation de Windows Exporter dans Prometheus..." -ForegroundColor Green
    # Cette fonctionnalite sera implementee dans la prochaine version
    Write-Host "   Fonctionnalite en cours de developpement" -ForegroundColor Yellow
}

Write-Host "`nDiagnostic termine" -ForegroundColor Green
