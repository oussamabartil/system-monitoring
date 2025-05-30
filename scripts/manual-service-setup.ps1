# Manual Windows Exporter Service Setup
# Run this in Administrator PowerShell

$serviceName = "windows_exporter"
$exePath = "C:\Program Files\windows_exporter\windows_exporter.exe"

Write-Host "=== Configuration manuelle du service Windows Exporter ===" -ForegroundColor Green

# Verifier que le fichier existe
if (!(Test-Path $exePath)) {
    Write-Error "Windows Exporter non trouve a: $exePath"
    Write-Host "Executez d'abord le script d'installation pour telecharger le fichier" -ForegroundColor Yellow
    exit 1
}

# Arreter et supprimer le service existant s'il existe
$existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "Suppression du service existant..." -ForegroundColor Yellow
    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
    sc.exe delete $serviceName | Out-Null
    Start-Sleep -Seconds 2
}

# Creer le service avec New-Service
try {
    Write-Host "Creation du service Windows Exporter..." -ForegroundColor Yellow
    New-Service -Name $serviceName -BinaryPathName $exePath -DisplayName "Prometheus Windows Exporter" -StartupType Automatic -Description "Prometheus Windows Exporter - Collecte des metriques systeme Windows"
    Write-Host "Service cree avec succes!" -ForegroundColor Green
} catch {
    Write-Error "Erreur lors de la creation du service: $($_.Exception.Message)"
    exit 1
}

# Demarrer le service
try {
    Write-Host "Demarrage du service..." -ForegroundColor Yellow
    Start-Service -Name $serviceName
    Start-Sleep -Seconds 3
    
    $service = Get-Service -Name $serviceName
    if ($service.Status -eq "Running") {
        Write-Host "Service demarre avec succes!" -ForegroundColor Green
    } else {
        Write-Warning "Le service n'a pas pu demarrer. Statut: $($service.Status)"
    }
} catch {
    Write-Error "Erreur lors du demarrage du service: $($_.Exception.Message)"
}

# Test de connectivite
Write-Host "Test de connectivite..." -ForegroundColor Yellow
try {
    Start-Sleep -Seconds 5  # Attendre que le service soit pret
    $response = Invoke-WebRequest -Uri "http://localhost:9182/metrics" -TimeoutSec 10 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host "Windows Exporter repond sur http://localhost:9182/metrics" -ForegroundColor Green
        
        Write-Host "`nApercu des metriques disponibles:" -ForegroundColor Cyan
        $metrics = $response.Content -split "`n" | Where-Object { $_ -match "^windows_" -and $_ -notmatch "^#" } | Select-Object -First 10
        foreach ($metric in $metrics) {
            Write-Host "  $metric" -ForegroundColor Gray
        }
        Write-Host "  ... et beaucoup d'autres metriques" -ForegroundColor Gray
    }
} catch {
    Write-Warning "Impossible de se connecter a Windows Exporter sur le port 9182"
    Write-Host "Le service peut avoir besoin de plus de temps pour demarrer" -ForegroundColor Yellow
}

Write-Host "`n=== Configuration terminee ===" -ForegroundColor Green
Write-Host "Windows Exporter est maintenant configure comme service Windows" -ForegroundColor White
Write-Host "Port d'ecoute: 9182" -ForegroundColor White
Write-Host "URL des metriques: http://localhost:9182/metrics" -ForegroundColor White
