# Script PowerShell pour arrêter la stack de monitoring
# Supervision des Systèmes avec Prometheus & Grafana

Write-Host "🛑 Arrêt de la stack de monitoring Prometheus & Grafana" -ForegroundColor Red
Write-Host "=================================================" -ForegroundColor Cyan

# Arrêt des conteneurs
Write-Host "🔄 Arrêt des conteneurs..." -ForegroundColor Yellow
docker-compose down

# Vérification que tous les conteneurs sont arrêtés
Write-Host "🔍 Vérification de l'arrêt des conteneurs..." -ForegroundColor Yellow
$containers = docker ps --filter "name=prometheus" --filter "name=grafana" --filter "name=alertmanager" --filter "name=node-exporter" --filter "name=cadvisor" --filter "name=windows-exporter" --format "table {{.Names}}\t{{.Status}}"

if ($containers) {
    Write-Host "⚠️  Certains conteneurs sont encore en cours d'exécution:" -ForegroundColor Yellow
    Write-Host $containers
} else {
    Write-Host "✅ Tous les conteneurs de monitoring sont arrêtés" -ForegroundColor Green
}

# Option pour supprimer les volumes (données)
$removeData = Read-Host "`n❓ Voulez-vous supprimer les données (volumes) ? (y/N)"
if ($removeData -eq "y" -or $removeData -eq "Y") {
    Write-Host "🗑️  Suppression des volumes de données..." -ForegroundColor Red
    docker-compose down -v
    docker volume prune -f
    Write-Host "✅ Volumes supprimés" -ForegroundColor Green
} else {
    Write-Host "💾 Données conservées" -ForegroundColor Green
}

Write-Host "`n✅ Stack de monitoring arrêtée" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Cyan
