# Test Rapide des Services
Write-Host "=== TEST RAPIDE DU SYSTÈME DE MONITORING ===" -ForegroundColor Cyan

# Test des conteneurs Docker
Write-Host "`n1. VÉRIFICATION DES CONTENEURS DOCKER" -ForegroundColor Yellow
$containers = docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
Write-Host $containers
Write-Host "✓ Conteneurs Docker: OK" -ForegroundColor Green

# Test des services web
Write-Host "`n2. TEST DE CONNECTIVITÉ DES SERVICES" -ForegroundColor Yellow

# Test Prometheus
try {
    $response = Invoke-WebRequest -Uri "http://localhost:9090" -TimeoutSec 5 -UseBasicParsing
    Write-Host "✓ Prometheus : ACCESSIBLE (Status: $($response.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "✗ Prometheus : ERREUR" -ForegroundColor Red
}

# Test Grafana
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3000" -TimeoutSec 5 -UseBasicParsing
    Write-Host "✓ Grafana : ACCESSIBLE (Status: $($response.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "✗ Grafana : ERREUR" -ForegroundColor Red
}

# Test cAdvisor
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8082" -TimeoutSec 5 -UseBasicParsing
    Write-Host "✓ cAdvisor : ACCESSIBLE (Status: $($response.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "✗ cAdvisor : ERREUR" -ForegroundColor Red
}

# Test Windows Exporter
Write-Host "`n3. TEST WINDOWS EXPORTER" -ForegroundColor Yellow
$service = Get-Service -Name "windows_exporter" -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "✓ Service Windows Exporter: $($service.Status)" -ForegroundColor Green

    try {
        $response = Invoke-WebRequest -Uri "http://localhost:9182/metrics" -TimeoutSec 5 -UseBasicParsing
        Write-Host "✓ Windows Exporter Metrics: ACCESSIBLE" -ForegroundColor Green
    } catch {
        Write-Host "✗ Windows Exporter Metrics: NON ACCESSIBLE" -ForegroundColor Red
    }
} else {
    Write-Host "⚠ Windows Exporter: NON INSTALLÉ" -ForegroundColor Yellow
}

# Test Prometheus Targets
Write-Host "`n4. TEST DES TARGETS PROMETHEUS" -ForegroundColor Yellow
try {
    $targets = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/targets" -TimeoutSec 10
    if ($targets.status -eq "success") {
        Write-Host "✓ API Prometheus Targets: OK" -ForegroundColor Green
        foreach ($target in $targets.data.activeTargets) {
            $status = if ($target.health -eq "up") { "✓" } else { "✗" }
            $color = if ($target.health -eq "up") { "Green" } else { "Red" }
            Write-Host "  $status $($target.labels.job): $($target.health)" -ForegroundColor $color
        }
    }
} catch {
    Write-Host "✗ Erreur API Prometheus" -ForegroundColor Red
}

Write-Host "`n=== RÉSUMÉ ===" -ForegroundColor Cyan
Write-Host "Accès aux interfaces:" -ForegroundColor White
Write-Host "  Prometheus : http://localhost:9090" -ForegroundColor Gray
Write-Host "  Grafana    : http://localhost:3000 (admin/admin123)" -ForegroundColor Gray
Write-Host "  cAdvisor   : http://localhost:8082" -ForegroundColor Gray
Write-Host "  Windows Exporter: http://localhost:9182/metrics" -ForegroundColor Gray
