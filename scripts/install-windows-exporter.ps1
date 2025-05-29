# Script pour installer Windows Exporter sur l'hôte Windows
# Windows Exporter Installation Script

param(
    [string]$Version = "0.25.1",
    [string]$InstallPath = "C:\Program Files\windows_exporter",
    [switch]$StartService = $true
)

Write-Host "=== Installation de Windows Exporter ===" -ForegroundColor Green

# Vérifier les privilèges administrateur
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Ce script doit être exécuté en tant qu'administrateur!"
    exit 1
}

# URLs et chemins
$downloadUrl = "https://github.com/prometheus-community/windows_exporter/releases/download/v$Version/windows_exporter-$Version-amd64.exe"
$exePath = Join-Path $InstallPath "windows_exporter.exe"
$serviceName = "windows_exporter"

try {
    # Créer le répertoire d'installation
    if (!(Test-Path $InstallPath)) {
        Write-Host "Création du répertoire d'installation: $InstallPath" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    }

    # Arrêter le service s'il existe déjà
    $existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($existingService) {
        Write-Host "Arrêt du service existant..." -ForegroundColor Yellow
        Stop-Service -Name $serviceName -Force
        sc.exe delete $serviceName | Out-Null
        Start-Sleep -Seconds 2
    }

    # Télécharger Windows Exporter
    Write-Host "Téléchargement de Windows Exporter v$Version..." -ForegroundColor Yellow
    Write-Host "URL: $downloadUrl" -ForegroundColor Gray
    
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($downloadUrl, $exePath)
    
    if (!(Test-Path $exePath)) {
        throw "Échec du téléchargement de Windows Exporter"
    }

    Write-Host "Téléchargement terminé: $exePath" -ForegroundColor Green

    # Installer comme service Windows
    Write-Host "Installation du service Windows..." -ForegroundColor Yellow
    
    $serviceArgs = @(
        "create",
        $serviceName,
        "binPath= `"$exePath`"",
        "DisplayName= `"Prometheus Windows Exporter`"",
        "start= auto"
    )
    
    $result = & sc.exe @serviceArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Échec de la création du service: $result"
    }

    # Configurer la description du service
    sc.exe description $serviceName "Prometheus Windows Exporter - Collecte des métriques système Windows" | Out-Null

    # Démarrer le service si demandé
    if ($StartService) {
        Write-Host "Démarrage du service..." -ForegroundColor Yellow
        Start-Service -Name $serviceName
        
        # Vérifier que le service fonctionne
        Start-Sleep -Seconds 3
        $service = Get-Service -Name $serviceName
        if ($service.Status -eq "Running") {
            Write-Host "✓ Service démarré avec succès!" -ForegroundColor Green
        } else {
            Write-Warning "Le service n'a pas pu démarrer. Statut: $($service.Status)"
        }
    }

    # Vérifier la connectivité
    Write-Host "Test de connectivité..." -ForegroundColor Yellow
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:9182/metrics" -TimeoutSec 10 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Host "✓ Windows Exporter répond sur http://localhost:9182/metrics" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Impossible de se connecter à Windows Exporter sur le port 9182"
        Write-Host "Vérifiez que le pare-feu Windows autorise le port 9182" -ForegroundColor Yellow
    }

    # Instructions finales
    Write-Host "`n=== Installation terminée ===" -ForegroundColor Green
    Write-Host "Windows Exporter est installé et configuré comme service Windows" -ForegroundColor White
    Write-Host "Port d'écoute: 9182" -ForegroundColor White
    Write-Host "URL des métriques: http://localhost:9182/metrics" -ForegroundColor White
    Write-Host "`nPour activer la collecte dans Prometheus:" -ForegroundColor Yellow
    Write-Host "1. Décommentez la section 'windows-exporter' dans prometheus/prometheus.yml" -ForegroundColor White
    Write-Host "2. Redémarrez Prometheus: docker-compose restart prometheus" -ForegroundColor White
    
    # Commandes utiles
    Write-Host "`nCommandes utiles:" -ForegroundColor Yellow
    Write-Host "- Arrêter le service: Stop-Service -Name $serviceName" -ForegroundColor Gray
    Write-Host "- Démarrer le service: Start-Service -Name $serviceName" -ForegroundColor Gray
    Write-Host "- Statut du service: Get-Service -Name $serviceName" -ForegroundColor Gray
    Write-Host "- Désinstaller: sc.exe delete $serviceName" -ForegroundColor Gray

} catch {
    Write-Error "Erreur lors de l'installation: $($_.Exception.Message)"
    exit 1
}
