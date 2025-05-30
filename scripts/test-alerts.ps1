# Script de Test des Alertes
# Alerts Testing Script

param(
    [string]$PrometheusUrl = "http://localhost:9090",
    [string]$AlertManagerUrl = "http://localhost:9093",
    [string]$TestEmail = "oussamabartil.04@gmail.com",
    [switch]$SimulateCpuAlert = $false,
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

function Simulate-HighCpuUsage($durationSeconds = 30) {
    Write-Host "Simulation de charge CPU élevée pendant $durationSeconds secondes..." -ForegroundColor Yellow
    
    $jobs = @()
    $coreCount = (Get-WmiObject -Class Win32_ComputerSystem).NumberOfLogicalProcessors
    
    for ($i = 0; $i -lt $coreCount; $i++) {
        $jobs += Start-Job -ScriptBlock {
            param($duration)
            $end = (Get-Date).AddSeconds($duration)
            while ((Get-Date) -lt $end) {
                $result = 1
                for ($j = 0; $j -lt 1000000; $j++) {
                    $result = $result * 1.1
                }
            }
        } -ArgumentList $durationSeconds
    }
    
    Write-Host "Jobs de charge CPU démarrés (PID: $($jobs.Id -join ', '))" -ForegroundColor Gray
    
    # Attendre la fin
    $jobs | Wait-Job | Out-Null
    $jobs | Remove-Job
    
    Write-Host "Simulation de charge CPU terminée" -ForegroundColor Green
}

Write-TestHeader "PHASE 5: TEST DU SYSTÈME D'ALERTES"

Write-TestStep "5.1" "Vérification d'AlertManager"

try {
    $response = Invoke-WebRequest -Uri $AlertManagerUrl -TimeoutSec 10 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-TestResult "AlertManager Interface" "PASS" "Interface accessible"
    } else {
        Write-TestResult "AlertManager Interface" "FAIL" "Status Code: $($response.StatusCode)"
    }
} catch {
    Write-TestResult "AlertManager Interface" "FAIL" $_.Exception.Message
}

Write-TestStep "5.2" "Test de l'API AlertManager"

try {
    $alerts = Invoke-RestMethod -Uri "$AlertManagerUrl/api/v1/alerts" -TimeoutSec 10
    Write-TestResult "AlertManager API" "PASS" "$($alerts.Count) alerte(s) active(s)"
    
    if ($alerts.Count -gt 0) {
        foreach ($alert in $alerts) {
            Write-TestResult "Alerte: $($alert.labels.alertname)" "INFO" "Status: $($alert.status.state)"
        }
    }
} catch {
    Write-TestResult "AlertManager API" "FAIL" $_.Exception.Message
}

Write-TestStep "5.3" "Vérification des règles d'alerte Prometheus"

try {
    $rules = Invoke-RestMethod -Uri "$PrometheusUrl/api/v1/rules" -TimeoutSec 10
    
    if ($rules.status -eq "success") {
        $alertRules = $rules.data.groups | ForEach-Object { $_.rules } | Where-Object { $_.type -eq "alerting" }
        Write-TestResult "Règles d'alerte Prometheus" "PASS" "$($alertRules.Count) règle(s) d'alerte configurée(s)"
        
        foreach ($rule in $alertRules) {
            $status = switch ($rule.health) {
                "ok" { "PASS" }
                "err" { "FAIL" }
                default { "WARN" }
            }
            Write-TestResult "Règle: $($rule.name)" $status "Health: $($rule.health)"
        }
    } else {
        Write-TestResult "Règles d'alerte Prometheus" "FAIL" $rules.error
    }
} catch {
    Write-TestResult "Règles d'alerte Prometheus" "FAIL" $_.Exception.Message
}

Write-TestStep "5.4" "Test de la configuration email"

# Vérifier la configuration AlertManager
try {
    $configPath = "alertmanager/alertmanager.yml"
    if (Test-Path $configPath) {
        $config = Get-Content $configPath -Raw
        if ($config -match $TestEmail) {
            Write-TestResult "Configuration Email" "PASS" "Email $TestEmail trouvé dans la configuration"
        } else {
            Write-TestResult "Configuration Email" "WARN" "Email $TestEmail non trouvé dans la configuration"
        }
        
        if ($config -match "smtp_smarthost") {
            Write-TestResult "Configuration SMTP" "PASS" "Configuration SMTP trouvée"
        } else {
            Write-TestResult "Configuration SMTP" "FAIL" "Configuration SMTP manquante"
        }
    } else {
        Write-TestResult "Fichier de configuration AlertManager" "FAIL" "Fichier non trouvé"
    }
} catch {
    Write-TestResult "Configuration Email" "FAIL" $_.Exception.Message
}

if ($SimulateCpuAlert) {
    Write-TestStep "5.5" "Simulation d'alerte CPU"
    
    Write-Host "ATTENTION: Cette simulation va utiliser intensivement le CPU!" -ForegroundColor Red
    Write-Host "Appuyez sur Ctrl+C pour annuler dans les 5 prochaines secondes..." -ForegroundColor Yellow
    
    for ($i = 5; $i -gt 0; $i--) {
        Write-Host "$i..." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
    
    # Mesurer le CPU avant
    Write-Host "Mesure du CPU avant simulation..." -ForegroundColor Gray
    $cpuBefore = Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 3
    $avgCpuBefore = ($cpuBefore.CounterSamples.CookedValue | Measure-Object -Average).Average
    Write-TestResult "CPU Usage Avant" "INFO" "$([math]::Round($avgCpuBefore, 2))%"
    
    # Simuler la charge
    Simulate-HighCpuUsage -durationSeconds 60
    
    # Mesurer le CPU après
    Write-Host "Mesure du CPU après simulation..." -ForegroundColor Gray
    Start-Sleep -Seconds 5  # Laisser le temps au système de se stabiliser
    $cpuAfter = Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 3
    $avgCpuAfter = ($cpuAfter.CounterSamples.CookedValue | Measure-Object -Average).Average
    Write-TestResult "CPU Usage Après" "INFO" "$([math]::Round($avgCpuAfter, 2))%"
    
    # Attendre et vérifier les alertes
    Write-Host "Attente de 2 minutes pour la génération d'alertes..." -ForegroundColor Yellow
    Start-Sleep -Seconds 120
    
    try {
        $alerts = Invoke-RestMethod -Uri "$AlertManagerUrl/api/v1/alerts" -TimeoutSec 10
        $cpuAlerts = $alerts | Where-Object { $_.labels.alertname -like "*cpu*" -or $_.labels.alertname -like "*CPU*" }
        
        if ($cpuAlerts.Count -gt 0) {
            Write-TestResult "Génération d'alerte CPU" "PASS" "$($cpuAlerts.Count) alerte(s) CPU générée(s)"
        } else {
            Write-TestResult "Génération d'alerte CPU" "WARN" "Aucune alerte CPU générée (peut prendre plus de temps)"
        }
    } catch {
        Write-TestResult "Vérification alertes CPU" "FAIL" $_.Exception.Message
    }
}

Write-TestStep "5.6" "Test manuel des notifications"

Write-Host "`nPour tester manuellement les notifications:" -ForegroundColor Yellow
Write-Host "1. Ouvrez AlertManager: $AlertManagerUrl" -ForegroundColor White
Write-Host "2. Créez une alerte de test via l'API:" -ForegroundColor White

$testAlert = @"
[
  {
    "labels": {
      "alertname": "TestAlert",
      "service": "test",
      "severity": "warning",
      "instance": "localhost"
    },
    "annotations": {
      "summary": "Test alert for monitoring system",
      "description": "This is a test alert to verify email notifications"
    },
    "generatorURL": "http://localhost:9090/graph"
  }
]
"@

Write-Host "`n3. Utilisez cette commande PowerShell pour envoyer une alerte de test:" -ForegroundColor White
Write-Host @"
`$headers = @{'Content-Type' = 'application/json'}
`$body = '$($testAlert -replace "`n", "" -replace "`r", "")'
Invoke-RestMethod -Uri '$AlertManagerUrl/api/v1/alerts' -Method POST -Headers `$headers -Body `$body
"@ -ForegroundColor Gray

Write-Host "`n4. Vérifiez votre email: $TestEmail" -ForegroundColor White

Write-Host "`n" + "="*60 -ForegroundColor Green
Write-Host " RÉSUMÉ DES TESTS D'ALERTES" -ForegroundColor Green
Write-Host "="*60 -ForegroundColor Green

Write-Host "`nPour un test complet des alertes:" -ForegroundColor Cyan
Write-Host "1. Exécutez: .\scripts\test-alerts.ps1 -SimulateCpuAlert" -ForegroundColor White
Write-Host "2. Surveillez AlertManager: $AlertManagerUrl" -ForegroundColor White
Write-Host "3. Vérifiez votre email pour les notifications" -ForegroundColor White

Write-Host "`nPour tester les performances:" -ForegroundColor Cyan
Write-Host "  .\scripts\test-performance.ps1" -ForegroundColor White
