# Script de Test Complet du Système de Monitoring
# Complete Monitoring System Test Script

param(
    [switch]$SkipWindowsExporter = $false,
    [switch]$SkipAlerts = $false,
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Continue"
$testResults = @()

function Write-TestHeader($title) {
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host " $title" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
}

function Write-TestStep($step, $description) {
    Write-Host "`n[$step] $description" -ForegroundColor Yellow
}

function Write-TestResult($test, $status, $details = "") {
    $global:testResults += [PSCustomObject]@{
        Test = $test
        Status = $status
        Details = $details
        Timestamp = Get-Date
    }
    
    $color = if ($status -eq "PASS") { "Green" } elseif ($status -eq "FAIL") { "Red" } else { "Yellow" }
    Write-Host "  ✓ $test : $status" -ForegroundColor $color
    if ($details) {
        Write-Host "    → $details" -ForegroundColor Gray
    }
}

function Test-ServiceHealth($serviceName, $port, $endpoint = "") {
    try {
        $url = "http://localhost:$port$endpoint"
        $response = Invoke-WebRequest -Uri $url -TimeoutSec 10 -UseBasicParsing
        return @{
            Success = $true
            StatusCode = $response.StatusCode
            ResponseTime = (Measure-Command { Invoke-WebRequest -Uri $url -TimeoutSec 5 -UseBasicParsing }).TotalMilliseconds
        }
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# =============================================================================
# PHASE 1: INFRASTRUCTURE DE BASE
# =============================================================================

Write-TestHeader "PHASE 1: VÉRIFICATION DE L'INFRASTRUCTURE DE BASE"

Write-TestStep "1.1" "Vérification des services Docker"

# Test Docker Compose
try {
    $composeStatus = docker-compose ps --format json | ConvertFrom-Json
    if ($composeStatus) {
        Write-TestResult "Docker Compose" "PASS" "Services détectés"
        
        foreach ($service in $composeStatus) {
            $status = if ($service.State -eq "running") { "PASS" } else { "FAIL" }
            Write-TestResult "Service $($service.Service)" $status $service.State
        }
    } else {
        Write-TestResult "Docker Compose" "FAIL" "Aucun service détecté"
    }
} catch {
    Write-TestResult "Docker Compose" "FAIL" $_.Exception.Message
}

Write-TestStep "1.2" "Test de connectivité réseau"

# Test des ports principaux
$ports = @{
    "Prometheus" = 9090
    "Grafana" = 3000
    "AlertManager" = 9093
    "cAdvisor" = 8082
}

foreach ($service in $ports.Keys) {
    $port = $ports[$service]
    $result = Test-ServiceHealth $service $port
    
    if ($result.Success) {
        Write-TestResult "$service (Port $port)" "PASS" "Response time: $([math]::Round($result.ResponseTime, 2))ms"
    } else {
        Write-TestResult "$service (Port $port)" "FAIL" $result.Error
    }
}

Write-TestStep "1.3" "Vérification des volumes Docker"

try {
    $volumes = docker volume ls --format "{{.Name}}" | Where-Object { $_ -like "*monitoring*" }
    foreach ($volume in $volumes) {
        $inspect = docker volume inspect $volume | ConvertFrom-Json
        if ($inspect) {
            Write-TestResult "Volume $volume" "PASS" "Mountpoint: $($inspect[0].Mountpoint)"
        }
    }
} catch {
    Write-TestResult "Volumes Docker" "FAIL" $_.Exception.Message
}

# =============================================================================
# PHASE 2: WINDOWS EXPORTER
# =============================================================================

if (-not $SkipWindowsExporter) {
    Write-TestHeader "PHASE 2: TEST DE WINDOWS EXPORTER"
    
    Write-TestStep "2.1" "Vérification du service Windows Exporter"
    
    try {
        $service = Get-Service -Name "windows_exporter" -ErrorAction SilentlyContinue
        if ($service) {
            $status = if ($service.Status -eq "Running") { "PASS" } else { "FAIL" }
            Write-TestResult "Service Windows Exporter" $status $service.Status
        } else {
            Write-TestResult "Service Windows Exporter" "FAIL" "Service non trouvé"
        }
    } catch {
        Write-TestResult "Service Windows Exporter" "FAIL" $_.Exception.Message
    }
    
    Write-TestStep "2.2" "Test des métriques Windows"
    
    $result = Test-ServiceHealth "Windows Exporter" 9182 "/metrics"
    if ($result.Success) {
        Write-TestResult "Windows Exporter Metrics" "PASS" "Métriques accessibles"
        
        # Test de métriques spécifiques
        try {
            $metrics = Invoke-WebRequest -Uri "http://localhost:9182/metrics" -UseBasicParsing
            $metricsText = $metrics.Content
            
            $expectedMetrics = @("windows_cpu_time_total", "windows_memory_available_bytes", "windows_logical_disk_free_bytes")
            foreach ($metric in $expectedMetrics) {
                if ($metricsText -match $metric) {
                    Write-TestResult "Métrique $metric" "PASS" "Présente"
                } else {
                    Write-TestResult "Métrique $metric" "FAIL" "Absente"
                }
            }
        } catch {
            Write-TestResult "Analyse des métriques" "FAIL" $_.Exception.Message
        }
    } else {
        Write-TestResult "Windows Exporter Metrics" "FAIL" $result.Error
    }
}

# =============================================================================
# PHASE 3: PROMETHEUS
# =============================================================================

Write-TestHeader "PHASE 3: TEST DE PROMETHEUS"

Write-TestStep "3.1" "Vérification de la configuration Prometheus"

$prometheusResult = Test-ServiceHealth "Prometheus" 9090
if ($prometheusResult.Success) {
    Write-TestResult "Prometheus API" "PASS" "Accessible"
    
    # Test des targets
    try {
        $targets = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/targets" -TimeoutSec 10
        if ($targets.status -eq "success") {
            Write-TestResult "Prometheus Targets API" "PASS" "API fonctionnelle"
            
            foreach ($target in $targets.data.activeTargets) {
                $status = if ($target.health -eq "up") { "PASS" } else { "FAIL" }
                Write-TestResult "Target $($target.labels.job)" $status "$($target.health) - $($target.scrapeUrl)"
            }
        }
    } catch {
        Write-TestResult "Prometheus Targets" "FAIL" $_.Exception.Message
    }
    
    # Test des règles d'alerte
    try {
        $rules = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/rules" -TimeoutSec 10
        if ($rules.status -eq "success") {
            $ruleCount = ($rules.data.groups | Measure-Object).Count
            Write-TestResult "Règles d'alerte" "PASS" "$ruleCount groupes de règles chargés"
        }
    } catch {
        Write-TestResult "Règles d'alerte" "FAIL" $_.Exception.Message
    }
} else {
    Write-TestResult "Prometheus API" "FAIL" $prometheusResult.Error
}

Write-Host "`n" + "="*60 -ForegroundColor Green
Write-Host " RÉSUMÉ DES TESTS" -ForegroundColor Green
Write-Host "="*60 -ForegroundColor Green

$passCount = ($testResults | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = ($testResults | Where-Object { $_.Status -eq "FAIL" }).Count
$totalCount = $testResults.Count

Write-Host "`nTests réussis: $passCount/$totalCount" -ForegroundColor Green
Write-Host "Tests échoués: $failCount/$totalCount" -ForegroundColor Red

if ($failCount -gt 0) {
    Write-Host "`nTests échoués:" -ForegroundColor Red
    $testResults | Where-Object { $_.Status -eq "FAIL" } | ForEach-Object {
        Write-Host "  - $($_.Test): $($_.Details)" -ForegroundColor Red
    }
}

Write-Host "`nPour continuer les tests, exécutez:" -ForegroundColor Yellow
Write-Host "  .\scripts\test-grafana.ps1" -ForegroundColor White
Write-Host "  .\scripts\test-alerts.ps1" -ForegroundColor White
