# Script PowerShell pour sauvegarder la configuration et les données de monitoring
# Supervision des Systèmes avec Prometheus & Grafana

param(
    [string]$BackupPath = ".\backups\monitoring-backup-$(Get-Date -Format 'yyyy-MM-dd-HH-mm-ss')"
)

Write-Host "💾 Sauvegarde de la stack de monitoring" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "📁 Répertoire de sauvegarde: $BackupPath" -ForegroundColor Yellow

# Création du répertoire de sauvegarde
if (!(Test-Path $BackupPath)) {
    New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
    Write-Host "✅ Répertoire de sauvegarde créé" -ForegroundColor Green
}

# Sauvegarde des configurations
Write-Host "📋 Sauvegarde des configurations..." -ForegroundColor Yellow
$configDirs = @(
    "prometheus",
    "grafana/provisioning", 
    "grafana/dashboards",
    "alertmanager",
    "scripts"
)

foreach ($dir in $configDirs) {
    if (Test-Path $dir) {
        $destPath = Join-Path $BackupPath $dir
        Copy-Item -Path $dir -Destination $destPath -Recurse -Force
        Write-Host "✅ $dir sauvegardé" -ForegroundColor Green
    }
}

# Sauvegarde du docker-compose.yml
Copy-Item -Path "docker-compose.yml" -Destination $BackupPath -Force
Write-Host "✅ docker-compose.yml sauvegardé" -ForegroundColor Green

# Sauvegarde des volumes Docker (données)
Write-Host "💽 Sauvegarde des volumes Docker..." -ForegroundColor Yellow

# Vérification que les conteneurs sont en cours d'exécution
$runningContainers = docker ps --filter "name=prometheus" --filter "name=grafana" --format "{{.Names}}"

if ($runningContainers) {
    Write-Host "📊 Sauvegarde des données Prometheus..." -ForegroundColor Yellow
    docker exec prometheus tar czf /tmp/prometheus-data.tar.gz -C /prometheus .
    docker cp prometheus:/tmp/prometheus-data.tar.gz "$BackupPath\prometheus-data.tar.gz"
    
    Write-Host "📈 Sauvegarde des données Grafana..." -ForegroundColor Yellow
    docker exec grafana tar czf /tmp/grafana-data.tar.gz -C /var/lib/grafana .
    docker cp grafana:/tmp/grafana-data.tar.gz "$BackupPath\grafana-data.tar.gz"
    
    Write-Host "✅ Données sauvegardées" -ForegroundColor Green
} else {
    Write-Host "⚠️  Les conteneurs ne sont pas en cours d'exécution" -ForegroundColor Yellow
    Write-Host "   Seules les configurations ont été sauvegardées" -ForegroundColor Yellow
}

# Création d'un fichier d'information sur la sauvegarde
$backupInfo = @"
Sauvegarde de la stack de monitoring Prometheus & Grafana
=========================================================
Date de sauvegarde: $(Get-Date)
Version Docker: $(docker --version)
Version Docker Compose: $(docker-compose --version)

Contenu de la sauvegarde:
- Configurations Prometheus
- Configurations Grafana (provisioning + dashboards)
- Configuration AlertManager
- Scripts de gestion
- docker-compose.yml
$(if ($runningContainers) { "- Données Prometheus (prometheus-data.tar.gz)" })
$(if ($runningContainers) { "- Données Grafana (grafana-data.tar.gz)" })

Instructions de restauration:
1. Copier tous les fichiers dans un nouveau répertoire
2. Extraire les données si nécessaire:
   - tar -xzf prometheus-data.tar.gz
   - tar -xzf grafana-data.tar.gz
3. Exécuter: docker-compose up -d
"@

$backupInfo | Out-File -FilePath "$BackupPath\README.txt" -Encoding UTF8

# Compression de la sauvegarde
Write-Host "🗜️  Compression de la sauvegarde..." -ForegroundColor Yellow
$zipPath = "$BackupPath.zip"
Compress-Archive -Path $BackupPath -DestinationPath $zipPath -Force

# Nettoyage du répertoire temporaire
Remove-Item -Path $BackupPath -Recurse -Force

Write-Host "`n✅ Sauvegarde terminée avec succès!" -ForegroundColor Green
Write-Host "📦 Archive créée: $zipPath" -ForegroundColor Cyan
Write-Host "📏 Taille: $([math]::Round((Get-Item $zipPath).Length / 1MB, 2)) MB" -ForegroundColor White

Write-Host "`n💡 Conseils:" -ForegroundColor White
Write-Host "   • Stockez cette sauvegarde dans un lieu sûr" -ForegroundColor Yellow
Write-Host "   • Testez régulièrement la restauration" -ForegroundColor Yellow
Write-Host "   • Automatisez les sauvegardes avec une tâche planifiée" -ForegroundColor Yellow
