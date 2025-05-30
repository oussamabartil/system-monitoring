# Script de demarrage de la stack de monitoring
# Auteur: Monitoring Team
# Date: 2024

# Verification des prerequis
Write-Host "Verification des prerequis..." -ForegroundColor Yellow

# Verification de Docker
try {
    docker --version | Out-Null
    Write-Host "OK: Docker est installe" -ForegroundColor Green
} catch {
    Write-Host "ERREUR: Docker n'est pas installe ou non accessible" -ForegroundColor Red
    exit 1
}

# Verification de Docker Compose
try {
    docker-compose --version | Out-Null
    Write-Host "OK: Docker Compose est installe" -ForegroundColor Green
} catch {
    Write-Host "ERREUR: Docker Compose n'est pas installe ou non accessible" -ForegroundColor Red
    exit 1
}

# Verification que Docker est en cours d'execution
try {
    docker ps | Out-Null
    Write-Host "OK: Docker daemon est en cours d'execution" -ForegroundColor Green
} catch {
    Write-Host "ERREUR: Docker daemon n'est pas en cours d'execution" -ForegroundColor Red
    exit 1
}

# Creation des repertoires necessaires
Write-Host "Creation des repertoires necessaires..." -ForegroundColor Yellow
$directories = @(
    "prometheus/data",
    "grafana/data",
    "alertmanager/data"
)

foreach ($dir in $directories) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "OK: Repertoire cree: $dir" -ForegroundColor Green
    }
}

# Arret des conteneurs existants
Write-Host "Arret des conteneurs existants..." -ForegroundColor Yellow
docker-compose down 2>$null

# Suppression des volumes orphelins
Write-Host "Nettoyage des volumes orphelins..." -ForegroundColor Yellow
docker volume prune -f 2>$null

# Demarrage de la stack
Write-Host "Demarrage de la stack de monitoring..." -ForegroundColor Yellow
docker-compose up -d

# Attente que les services soient prets
Write-Host "Attente du demarrage des services..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Verification de l'etat des services
Write-Host "Verification de l'etat des services..." -ForegroundColor Yellow
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
            Write-Host "OK: $($service.Name) est operationnel sur le port $($service.Port)" -ForegroundColor Green
        }
    } catch {
        Write-Host "ATTENTION: $($service.Name) n'est pas encore pret sur le port $($service.Port)" -ForegroundColor Yellow
    }
}

Write-Host "`nStack de monitoring demarree avec succes!" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "Acces aux interfaces:" -ForegroundColor White
Write-Host "   - Grafana:      http://localhost:3000 (admin/admin123)" -ForegroundColor Cyan
Write-Host "   - Prometheus:   http://localhost:9090" -ForegroundColor Cyan
Write-Host "   - AlertManager: http://localhost:9093" -ForegroundColor Cyan
Write-Host "   - cAdvisor:     http://localhost:8080" -ForegroundColor Cyan
Write-Host "`nConseils:" -ForegroundColor White
Write-Host "   - Changez le mot de passe Grafana par defaut" -ForegroundColor Yellow
Write-Host "   - Configurez les notifications d'alertes" -ForegroundColor Yellow
Write-Host "   - Personnalisez les dashboards selon vos besoins" -ForegroundColor Yellow
Write-Host "`nPour arreter: docker-compose down" -ForegroundColor White
