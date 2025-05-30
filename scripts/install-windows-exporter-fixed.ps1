# Script pour installer Windows Exporter sur l'hote Windows
# Windows Exporter Installation Script

param(
    [string]$Version = "0.25.1",
    [string]$InstallPath = "C:\Program Files\windows_exporter",
    [switch]$StartService = $true,
    [switch]$Detailed
)

Write-Host "=== Installation de Windows Exporter ===" -ForegroundColor Green

# Verifier les privileges administrateur
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Ce script doit etre execute en tant qu'administrateur!"
    exit 1
}

# URLs et chemins
$downloadUrl = "https://github.com/prometheus-community/windows_exporter/releases/download/v$Version/windows_exporter-$Version-amd64.exe"
$exePath = Join-Path $InstallPath "windows_exporter.exe"
$serviceName = "windows_exporter"

try {
    # Creer le repertoire d'installation
    if (!(Test-Path $InstallPath)) {
        Write-Host "Creation du repertoire d'installation: $InstallPath" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    }

    # Arreter le service s'il existe deja
    $existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($existingService) {
        Write-Host "Arret du service existant..." -ForegroundColor Yellow
        Stop-Service -Name $serviceName -Force
        sc.exe delete $serviceName | Out-Null
        Start-Sleep -Seconds 2
    }

    # Telecharger Windows Exporter
    Write-Host "Telechargement de Windows Exporter v$Version..." -ForegroundColor Yellow
    Write-Host "URL: $downloadUrl" -ForegroundColor Gray

    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($downloadUrl, $exePath)

    if (!(Test-Path $exePath)) {
        throw "Echec du telechargement de Windows Exporter"
    }

    Write-Host "Telechargement termine: $exePath" -ForegroundColor Green

    # Installer comme service Windows
    Write-Host "Installation du service Windows..." -ForegroundColor Yellow

    # Utiliser New-Service au lieu de sc.exe pour une meilleure compatibilite
    try {
        New-Service -Name $serviceName -BinaryPathName $exePath -DisplayName "Prometheus Windows Exporter" -StartupType Automatic -Description "Prometheus Windows Exporter - Collecte des metriques systeme Windows"
        Write-Host "Service cree avec succes!" -ForegroundColor Green
    } catch {
        # Fallback vers sc.exe avec syntaxe corrigee
        Write-Host "Tentative avec sc.exe..." -ForegroundColor Yellow
        $scCommand = "sc.exe create `"$serviceName`" binPath= `"$exePath`" DisplayName= `"Prometheus Windows Exporter`" start= auto"
        Invoke-Expression $scCommand
        if ($LASTEXITCODE -ne 0) {
            throw "Echec de la creation du service avec sc.exe"
        }
        # Configurer la description du service
        sc.exe description $serviceName "Prometheus Windows Exporter - Collecte des metriques systeme Windows" | Out-Null
    }

    # Demarrer le service si demande
    if ($StartService) {
        Write-Host "Demarrage du service..." -ForegroundColor Yellow
        Start-Service -Name $serviceName

        # Verifier que le service fonctionne
        Start-Sleep -Seconds 3
        $service = Get-Service -Name $serviceName
        if ($service.Status -eq "Running") {
            Write-Host "Service demarre avec succes!" -ForegroundColor Green
        } else {
            Write-Warning "Le service n'a pas pu demarrer. Statut: $($service.Status)"
        }
    }

    # Verifier la connectivite
    Write-Host "Test de connectivite..." -ForegroundColor Yellow
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:9182/metrics" -TimeoutSec 10 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Host "Windows Exporter repond sur http://localhost:9182/metrics" -ForegroundColor Green

            if ($Detailed) {
                Write-Host "`nApercu des metriques disponibles:" -ForegroundColor Cyan
                $metrics = $response.Content -split "`n" | Where-Object { $_ -match "^windows_" -and $_ -notmatch "^#" } | Select-Object -First 10
                foreach ($metric in $metrics) {
                    Write-Host "  $metric" -ForegroundColor Gray
                }
                Write-Host "  ... et beaucoup d'autres metriques" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Warning "Impossible de se connecter a Windows Exporter sur le port 9182"
        Write-Host "Verifiez que le pare-feu Windows autorise le port 9182" -ForegroundColor Yellow
    }

    # Instructions finales
    Write-Host "`n=== Installation terminee ===" -ForegroundColor Green
    Write-Host "Windows Exporter est installe et configure comme service Windows" -ForegroundColor White
    Write-Host "Port d'ecoute: 9182" -ForegroundColor White
    Write-Host "URL des metriques: http://localhost:9182/metrics" -ForegroundColor White
    Write-Host "`nPour activer la collecte dans Prometheus:" -ForegroundColor Yellow
    Write-Host "1. Decommentez la section 'windows-exporter' dans prometheus/prometheus.yml" -ForegroundColor White
    Write-Host "2. Redemarrez Prometheus: docker-compose restart prometheus" -ForegroundColor White

    # Commandes utiles
    Write-Host "`nCommandes utiles:" -ForegroundColor Yellow
    Write-Host "- Arreter le service: Stop-Service -Name $serviceName" -ForegroundColor Gray
    Write-Host "- Demarrer le service: Start-Service -Name $serviceName" -ForegroundColor Gray
    Write-Host "- Statut du service: Get-Service -Name $serviceName" -ForegroundColor Gray
    Write-Host "- Desinstaller: sc.exe delete $serviceName" -ForegroundColor Gray

} catch {
    Write-Error "Erreur lors de l'installation: $($_.Exception.Message)"
    exit 1
}
