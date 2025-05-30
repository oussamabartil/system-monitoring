# Script de Test de Performance
# Performance Testing Script

param(
    [int]$TestDurationMinutes = 5,
    [int]$QueryInterval = 10,
    [switch]$StressTest = $false,
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Continue"

function Write-TestHeader($title) {
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host " $title" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
}

function Write-TestStep($step, $description) {
    Write-Host "`n[$step] $description" -ForegroundColor Yellow
}

function Write-TestResult($test, $status, $details = "") {
    $color = if ($status -eq "PASS") { "Green" } elseif ($status -eq "FAIL") { "Red" } else { "Yellow" }
    Write-Host "  ✓ $test : $status" -ForegroundColor $color
    if ($details) {
        Write-Host "    → $details" -ForegroundColor Gray
    }
}

function Measure-ServicePerformance($serviceName, $url, $samples = 10) {
    $results = @()
    
    for ($i = 1; $i -le $samples; $i++) {
        try {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $response = Invoke-WebRequest -Uri $url -TimeoutSec 30 -UseBasicParsing
            $stopwatch.Stop()
            
            $results += [PSCustomObject]@{
                Sample = $i
                ResponseTime = $stopwatch.ElapsedMilliseconds
                StatusCode = $response.StatusCode
                Success = $true
            }
            
            if ($Verbose) {
                Write-Host "    Sample $i : $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Gray
            }
        } catch {
            $results += [PSCustomObject]@{
                Sample = $i
                ResponseTime = -1
                StatusCode = -1
                Success = $false
                Error = $_.Exception.Message
            }
        }
        
        Start-Sleep -Seconds 1
    }
    
    return $results
}

function Get-SystemResources {
    try {
        # CPU Usage
        $cpu = Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 1
        $cpuUsage = [math]::Round($cpu.CounterSamples[0].CookedValue, 2)
        
        # Memory Usage
        $memory = Get-WmiObject -Class Win32_OperatingSystem
        $totalMemory = [math]::Round($memory.TotalVisibleMemorySize / 1MB, 2)
        $freeMemory = [math]::Round($memory.FreePhysicalMemory / 1MB, 2)
        $usedMemory = $totalMemory - $freeMemory
        $memoryUsagePercent = [math]::Round(($usedMemory / $totalMemory) * 100, 2)
        
        # Disk Usage
        $disk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"
        $diskUsagePercent = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 2)
        
        return [PSCustomObject]@{
            CPU = $cpuUsage
            MemoryPercent = $memoryUsagePercent
            MemoryUsedGB = [math]::Round($usedMemory, 2)
            MemoryTotalGB = $totalMemory
            DiskPercent = $diskUsagePercent
            Timestamp = Get-Date
        }
    } catch {
        Write-Warning "Erreur lors de la collecte des ressources système: $($_.Exception.Message)"
        return $null
    }
}

Write-TestHeader "PHASE 6: TESTS DE PERFORMANCE ET ROBUSTESSE"

Write-TestStep "6.1" "Mesure des performances de base"

$services = @{
    "Prometheus" = "http://localhost:9090"
    "Grafana" = "http://localhost:3000"
    "AlertManager" = "http://localhost:9093"
    "cAdvisor" = "http://localhost:8082"
}

$performanceResults = @{}

foreach ($service in $services.Keys) {
    Write-Host "Test de performance pour $service..." -ForegroundColor Yellow
    $results = Measure-ServicePerformance $service $services[$service] 5
    
    $successfulResults = $results | Where-Object { $_.Success }
    if ($successfulResults.Count -gt 0) {
        $avgResponseTime = ($successfulResults.ResponseTime | Measure-Object -Average).Average
        $maxResponseTime = ($successfulResults.ResponseTime | Measure-Object -Maximum).Maximum
        $minResponseTime = ($successfulResults.ResponseTime | Measure-Object -Minimum).Minimum
        $successRate = ($successfulResults.Count / $results.Count) * 100
        
        $performanceResults[$service] = [PSCustomObject]@{
            AvgResponseTime = [math]::Round($avgResponseTime, 2)
            MaxResponseTime = $maxResponseTime
            MinResponseTime = $minResponseTime
            SuccessRate = $successRate
        }
        
        $status = if ($avgResponseTime -lt 1000 -and $successRate -eq 100) { "PASS" } 
                 elseif ($avgResponseTime -lt 3000 -and $successRate -ge 80) { "WARN" } 
                 else { "FAIL" }
        
        Write-TestResult "$service Performance" $status "Avg: $([math]::Round($avgResponseTime, 2))ms, Success: $successRate%"
    } else {
        Write-TestResult "$service Performance" "FAIL" "Aucune réponse réussie"
    }
}

Write-TestStep "6.2" "Monitoring des ressources système"

Write-Host "Collecte des métriques système pendant $TestDurationMinutes minutes..." -ForegroundColor Yellow

$resourceMetrics = @()
$endTime = (Get-Date).AddMinutes($TestDurationMinutes)

while ((Get-Date) -lt $endTime) {
    $metrics = Get-SystemResources
    if ($metrics) {
        $resourceMetrics += $metrics
        
        if ($Verbose) {
            Write-Host "CPU: $($metrics.CPU)%, RAM: $($metrics.MemoryPercent)%, Disk: $($metrics.DiskPercent)%" -ForegroundColor Gray
        }
    }
    
    Start-Sleep -Seconds $QueryInterval
}

if ($resourceMetrics.Count -gt 0) {
    $avgCpu = ($resourceMetrics.CPU | Measure-Object -Average).Average
    $maxCpu = ($resourceMetrics.CPU | Measure-Object -Maximum).Maximum
    $avgMemory = ($resourceMetrics.MemoryPercent | Measure-Object -Average).Average
    $maxMemory = ($resourceMetrics.MemoryPercent | Measure-Object -Maximum).Maximum
    
    Write-TestResult "CPU Usage" "INFO" "Avg: $([math]::Round($avgCpu, 2))%, Max: $([math]::Round($maxCpu, 2))%"
    Write-TestResult "Memory Usage" "INFO" "Avg: $([math]::Round($avgMemory, 2))%, Max: $([math]::Round($maxMemory, 2))%"
    
    # Vérifier les seuils
    if ($maxCpu -lt 80) {
        Write-TestResult "CPU Performance" "PASS" "CPU usage acceptable"
    } elseif ($maxCpu -lt 95) {
        Write-TestResult "CPU Performance" "WARN" "CPU usage élevé"
    } else {
        Write-TestResult "CPU Performance" "FAIL" "CPU usage critique"
    }
    
    if ($maxMemory -lt 80) {
        Write-TestResult "Memory Performance" "PASS" "Memory usage acceptable"
    } elseif ($maxMemory -lt 95) {
        Write-TestResult "Memory Performance" "WARN" "Memory usage élevé"
    } else {
        Write-TestResult "Memory Performance" "FAIL" "Memory usage critique"
    }
}

Write-TestStep "6.3" "Test de charge des conteneurs Docker"

try {
    $containers = docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | Select-Object -Skip 1
    Write-TestResult "Conteneurs Docker" "INFO" "$($containers.Count) conteneur(s) en cours d'exécution"
    
    # Vérifier l'utilisation des ressources Docker
    $dockerStats = docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" | Select-Object -Skip 1
    
    foreach ($stat in $dockerStats) {
        if ($stat -match "(\S+)\s+([\d.]+)%\s+(\S+)\s+/\s+(\S+)\s+([\d.]+)%") {
            $containerName = $matches[1]
            $cpuPercent = [double]$matches[2]
            $memPercent = [double]$matches[5]
            
            $status = if ($cpuPercent -lt 50 -and $memPercent -lt 70) { "PASS" } 
                     elseif ($cpuPercent -lt 80 -and $memPercent -lt 85) { "WARN" } 
                     else { "FAIL" }
            
            Write-TestResult "Container $containerName" $status "CPU: $cpuPercent%, MEM: $memPercent%"
        }
    }
} catch {
    Write-TestResult "Docker Stats" "FAIL" $_.Exception.Message
}

if ($StressTest) {
    Write-TestStep "6.4" "Test de stress (optionnel)"
    
    Write-Host "ATTENTION: Test de stress activé!" -ForegroundColor Red
    Write-Host "Ce test va générer une charge importante sur le système" -ForegroundColor Yellow
    
    # Test de stress avec requêtes multiples
    $stressJobs = @()
    
    for ($i = 1; $i -le 5; $i++) {
        $stressJobs += Start-Job -ScriptBlock {
            param($serviceUrl, $duration)
            $endTime = (Get-Date).AddMinutes($duration)
            $requests = 0
            $errors = 0
            
            while ((Get-Date) -lt $endTime) {
                try {
                    Invoke-WebRequest -Uri $serviceUrl -TimeoutSec 5 -UseBasicParsing | Out-Null
                    $requests++
                } catch {
                    $errors++
                }
                Start-Sleep -Milliseconds 100
            }
            
            return @{
                Requests = $requests
                Errors = $errors
            }
        } -ArgumentList "http://localhost:9090", 2
    }
    
    Write-Host "Test de stress en cours (2 minutes)..." -ForegroundColor Yellow
    $stressResults = $stressJobs | Wait-Job | Receive-Job
    $stressJobs | Remove-Job
    
    $totalRequests = ($stressResults.Requests | Measure-Object -Sum).Sum
    $totalErrors = ($stressResults.Errors | Measure-Object -Sum).Sum
    $errorRate = if ($totalRequests -gt 0) { ($totalErrors / $totalRequests) * 100 } else { 0 }
    
    Write-TestResult "Stress Test" "INFO" "$totalRequests requêtes, $totalErrors erreurs ($([math]::Round($errorRate, 2))% erreur)"
    
    if ($errorRate -lt 5) {
        Write-TestResult "Stress Test Performance" "PASS" "Taux d'erreur acceptable"
    } elseif ($errorRate -lt 15) {
        Write-TestResult "Stress Test Performance" "WARN" "Taux d'erreur élevé"
    } else {
        Write-TestResult "Stress Test Performance" "FAIL" "Taux d'erreur critique"
    }
}

Write-Host "`n" + "="*60 -ForegroundColor Green
Write-Host " RÉSUMÉ DES TESTS DE PERFORMANCE" -ForegroundColor Green
Write-Host "="*60 -ForegroundColor Green

Write-Host "`nPerformances des services:" -ForegroundColor Yellow
foreach ($service in $performanceResults.Keys) {
    $perf = $performanceResults[$service]
    Write-Host "  $service : $($perf.AvgResponseTime)ms (avg), $($perf.SuccessRate)% success" -ForegroundColor White
}

if ($resourceMetrics.Count -gt 0) {
    Write-Host "`nUtilisation des ressources:" -ForegroundColor Yellow
    Write-Host "  CPU moyen: $([math]::Round($avgCpu, 2))%" -ForegroundColor White
    Write-Host "  Mémoire moyenne: $([math]::Round($avgMemory, 2))%" -ForegroundColor White
}

Write-Host "`nRecommandations:" -ForegroundColor Cyan
Write-Host "- Surveillez régulièrement les performances avec ces scripts" -ForegroundColor White
Write-Host "- Configurez des alertes pour les seuils de performance" -ForegroundColor White
Write-Host "- Effectuez des tests de charge périodiques" -ForegroundColor White
