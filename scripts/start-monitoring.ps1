# Script PowerShell pour démarrer la stack de monitoring
# Supervision des Systèmes avec Prometheus & Grafana

Write-Host "🚀 Démarrage de la stack de monitoring Prometheus & Grafana" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Cyan

# Vérification de Docker
Write-Host "🔍 Vérification de Docker..." -ForegroundColor Yellow
try {
    $dockerVersion = docker --version
    Write-Host "✅ Docker détecté: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker n'est pas installé ou n'est pas démarré" -ForegroundColor Red
    Write-Host "Veuillez installer Docker Desktop et le démarrer avant de continuer." -ForegroundColor Red
    exit 1
}

# Vérification de Docker Compose
Write-Host "🔍 Vérification de Docker Compose..." -ForegroundColor Yellow
try {
    $composeVersion = docker-compose --version
    Write-Host "✅ Docker Compose détecté: $composeVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker Compose n'est pas disponible" -ForegroundColor Red
    exit 1
}

# Création des répertoires nécessaires
Write-Host "📁 Création des répertoires..." -ForegroundColor Yellow
$directories = @(
    "prometheus/rules",
    "grafana/provisioning/datasources",
    "grafana/provisioning/dashboards", 
    "grafana/dashboards/system",
    "grafana/dashboards/docker",
    "grafana/dashboards/applications",
    "alertmanager"
)

foreach ($dir in $directories) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "✅ Répertoire créé: $dir" -ForegroundColor Green
    }
}

# Arrêt des conteneurs existants (si ils existent)
Write-Host "🛑 Arrêt des conteneurs existants..." -ForegroundColor Yellow
docker-compose down 2>$null

# Suppression des volumes orphelins
Write-Host "🧹 Nettoyage des volumes orphelins..." -ForegroundColor Yellow
docker volume prune -f 2>$null

# Démarrage de la stack
Write-Host "🚀 Démarrage de la stack de monitoring..." -ForegroundColor Yellow
docker-compose up -d

# Attente que les services soient prêts
Write-Host "⏳ Attente du démarrage des services..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Vérification de l'état des services
Write-Host "🔍 Vérification de l'état des services..." -ForegroundColor Yellow
$services = @(
    @{Name="Prometheus"; Port=9090; URL="http://localhost:9090"},
    @{Name="Grafana"; Port=3000; URL="http://localhost:3000"},
    @{Name="AlertManager"; Port=9093; URL="http://localhost:9093"},
    @{Name="Node Exporter"; Port=9100; URL="http://localhost:9100"},
    @{Name="cAdvisor"; Port=8080; URL="http://localhost:8080"},
    @{Name="Windows Exporter"; Port=9182; URL="http://localhost:9182"}
)

foreach ($service in $services) {
    try {
        $response = Invoke-WebRequest -Uri "$($service.URL)/metrics" -TimeoutSec 5 -UseBasicParsing 2>$null
        if ($response.StatusCode -eq 200) {
            Write-Host "✅ $($service.Name) est opérationnel sur le port $($service.Port)" -ForegroundColor Green
        }
    } catch {
        Write-Host "⚠️  $($service.Name) n'est pas encore prêt sur le port $($service.Port)" -ForegroundColor Yellow
    }
}

Write-Host "`n🎉 Stack de monitoring démarrée avec succès!" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "📊 Accès aux interfaces:" -ForegroundColor White
Write-Host "   • Grafana:      http://localhost:3000 (admin/admin123)" -ForegroundColor Cyan
Write-Host "   • Prometheus:   http://localhost:9090" -ForegroundColor Cyan
Write-Host "   • AlertManager: http://localhost:9093" -ForegroundColor Cyan
Write-Host "   • cAdvisor:     http://localhost:8080" -ForegroundColor Cyan
Write-Host "`n💡 Conseils:" -ForegroundColor White
Write-Host "   • Changez le mot de passe Grafana par défaut" -ForegroundColor Yellow
Write-Host "   • Configurez les notifications d'alertes" -ForegroundColor Yellow
Write-Host "   • Personnalisez les dashboards selon vos besoins" -ForegroundColor Yellow
Write-Host "`n🔧 Pour arrêter: docker-compose down" -ForegroundColor White
