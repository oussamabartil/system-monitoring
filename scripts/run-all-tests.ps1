# Script de Test Complet - Orchestrateur
# Complete Test Suite Orchestrator

param(
    [switch]$SkipWindowsExporter = $false,
    [switch]$SkipPerformance = $false,
    [switch]$SkipStressTest = $true,
    [switch]$SimulateCpuAlert = $false,
    [switch]$Interactive = $true,
    [switch]$GenerateReport = $true,
    [string]$ReportPath = "test-results.html"
)

$ErrorActionPreference = "Continue"
$testStartTime = Get-Date

function Write-Banner {
    Write-Host @"

 ███╗   ███╗ ██████╗ ███╗   ██╗██╗████████╗ ██████╗ ██████╗ ██╗███╗   ██╗ ██████╗ 
 ████╗ ████║██╔═══██╗████╗  ██║██║╚══██╔══╝██╔═══██╗██╔══██╗██║████╗  ██║██╔════╝ 
 ██╔████╔██║██║   ██║██╔██╗ ██║██║   ██║   ██║   ██║██████╔╝██║██╔██╗ ██║██║  ███╗
 ██║╚██╔╝██║██║   ██║██║╚██╗██║██║   ██║   ██║   ██║██╔══██╗██║██║╚██╗██║██║   ██║
 ██║ ╚═╝ ██║╚██████╔╝██║ ╚████║██║   ██║   ╚██████╔╝██║  ██║██║██║ ╚████║╚██████╔╝
 ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝ 
                                                                                   
                        SUITE DE TESTS COMPLÈTE
"@ -ForegroundColor Cyan
}

function Write-TestPhase($phase, $description) {
    Write-Host "`n" + "="*80 -ForegroundColor Magenta
    Write-Host " PHASE $phase : $description" -ForegroundColor Magenta
    Write-Host "="*80 -ForegroundColor Magenta
}

function Confirm-Continue($message) {
    if ($Interactive) {
        Write-Host "`n$message" -ForegroundColor Yellow
        $response = Read-Host "Continuer? (O/n)"
        return ($response -eq "" -or $response -eq "O" -or $response -eq "o" -or $response -eq "Y" -or $response -eq "y")
    }
    return $true
}

function Generate-HtmlReport($results, $outputPath) {
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Rapport de Tests - Système de Monitoring</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #2c3e50; color: white; padding: 20px; border-radius: 5px; }
        .phase { margin: 20px 0; padding: 15px; border-left: 4px solid #3498db; background: #f8f9fa; }
        .pass { color: #27ae60; font-weight: bold; }
        .fail { color: #e74c3c; font-weight: bold; }
        .warn { color: #f39c12; font-weight: bold; }
        .info { color: #3498db; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .summary { background: #ecf0f1; padding: 15px; border-radius: 5px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Rapport de Tests - Système de Monitoring</h1>
        <p>Généré le: $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")</p>
    </div>
    
    <div class="summary">
        <h2>Résumé Exécutif</h2>
        <p><strong>Durée totale:</strong> $((Get-Date) - $testStartTime)</p>
        <p><strong>Tests exécutés:</strong> $($results.Count)</p>
        <p><strong>Succès:</strong> <span class="pass">$($results | Where-Object {$_.Status -eq "PASS"} | Measure-Object | Select-Object -ExpandProperty Count)</span></p>
        <p><strong>Échecs:</strong> <span class="fail">$($results | Where-Object {$_.Status -eq "FAIL"} | Measure-Object | Select-Object -ExpandProperty Count)</span></p>
        <p><strong>Avertissements:</strong> <span class="warn">$($results | Where-Object {$_.Status -eq "WARN"} | Measure-Object | Select-Object -ExpandProperty Count)</span></p>
    </div>
    
    <h2>Détails des Tests</h2>
    <table>
        <tr>
            <th>Test</th>
            <th>Statut</th>
            <th>Détails</th>
            <th>Timestamp</th>
        </tr>
"@

    foreach ($result in $results) {
        $statusClass = $result.Status.ToLower()
        $html += @"
        <tr>
            <td>$($result.Test)</td>
            <td><span class="$statusClass">$($result.Status)</span></td>
            <td>$($result.Details)</td>
            <td>$($result.Timestamp.ToString("HH:mm:ss"))</td>
        </tr>
"@
    }

    $html += @"
    </table>
</body>
</html>
"@

    $html | Out-File -FilePath $outputPath -Encoding UTF8
    Write-Host "Rapport HTML généré: $outputPath" -ForegroundColor Green
}

# =============================================================================
# DÉBUT DES TESTS
# =============================================================================

Write-Banner

Write-Host "Configuration des tests:" -ForegroundColor Yellow
Write-Host "  - Windows Exporter: $(if ($SkipWindowsExporter) { "IGNORÉ" } else { "INCLUS" })" -ForegroundColor White
Write-Host "  - Tests de performance: $(if ($SkipPerformance) { "IGNORÉS" } else { "INCLUS" })" -ForegroundColor White
Write-Host "  - Test de stress: $(if ($SkipStressTest) { "IGNORÉ" } else { "INCLUS" })" -ForegroundColor White
Write-Host "  - Simulation CPU: $(if ($SimulateCpuAlert) { "ACTIVÉE" } else { "DÉSACTIVÉE" })" -ForegroundColor White
Write-Host "  - Mode interactif: $(if ($Interactive) { "ACTIVÉ" } else { "DÉSACTIVÉ" })" -ForegroundColor White

if (-not (Confirm-Continue "Démarrer la suite de tests complète?")) {
    Write-Host "Tests annulés par l'utilisateur." -ForegroundColor Yellow
    exit 0
}

$allResults = @()

# =============================================================================
# PHASE 1: INFRASTRUCTURE ET SERVICES DE BASE
# =============================================================================

Write-TestPhase "1" "INFRASTRUCTURE ET SERVICES DE BASE"

if (Confirm-Continue "Tester l'infrastructure de base?") {
    try {
        $output = & ".\scripts\test-complete-monitoring.ps1" -SkipWindowsExporter:$SkipWindowsExporter
        Write-Host $output
    } catch {
        Write-Host "Erreur lors de l'exécution des tests de base: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# =============================================================================
# PHASE 2: GRAFANA
# =============================================================================

Write-TestPhase "2" "INTERFACE GRAFANA"

if (Confirm-Continue "Tester Grafana?") {
    try {
        $output = & ".\scripts\test-grafana.ps1"
        Write-Host $output
    } catch {
        Write-Host "Erreur lors de l'exécution des tests Grafana: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# =============================================================================
# PHASE 3: SYSTÈME D'ALERTES
# =============================================================================

Write-TestPhase "3" "SYSTÈME D'ALERTES"

if (Confirm-Continue "Tester le système d'alertes?") {
    try {
        $alertParams = @{}
        if ($SimulateCpuAlert) {
            $alertParams["SimulateCpuAlert"] = $true
        }
        
        $output = & ".\scripts\test-alerts.ps1" @alertParams
        Write-Host $output
    } catch {
        Write-Host "Erreur lors de l'exécution des tests d'alertes: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# =============================================================================
# PHASE 4: PERFORMANCE
# =============================================================================

if (-not $SkipPerformance) {
    Write-TestPhase "4" "TESTS DE PERFORMANCE"
    
    if (Confirm-Continue "Tester les performances?") {
        try {
            $perfParams = @{}
            if (-not $SkipStressTest) {
                $perfParams["StressTest"] = $true
            }
            
            $output = & ".\scripts\test-performance.ps1" @perfParams
            Write-Host $output
        } catch {
            Write-Host "Erreur lors de l'exécution des tests de performance: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# =============================================================================
# PHASE 5: VÉRIFICATIONS FINALES
# =============================================================================

Write-TestPhase "5" "VÉRIFICATIONS FINALES"

Write-Host "Vérification finale de l'état du système..." -ForegroundColor Yellow

# Vérifier que tous les services sont toujours en cours d'exécution
try {
    $services = @("prometheus", "grafana", "alertmanager", "cadvisor")
    foreach ($service in $services) {
        $container = docker ps --filter "name=$service" --format "{{.Status}}"
        if ($container -match "Up") {
            Write-Host "✓ $service : En cours d'exécution" -ForegroundColor Green
        } else {
            Write-Host "✗ $service : Problème détecté" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "Erreur lors de la vérification finale: $($_.Exception.Message)" -ForegroundColor Red
}

# =============================================================================
# RAPPORT FINAL
# =============================================================================

$testEndTime = Get-Date
$totalDuration = $testEndTime - $testStartTime

Write-Host "`n" + "="*80 -ForegroundColor Green
Write-Host " TESTS TERMINÉS" -ForegroundColor Green
Write-Host "="*80 -ForegroundColor Green

Write-Host "`nDurée totale: $($totalDuration.ToString("hh\:mm\:ss"))" -ForegroundColor White
Write-Host "Heure de fin: $($testEndTime.ToString("dd/MM/yyyy HH:mm:ss"))" -ForegroundColor White

Write-Host "`nACCÈS AUX SERVICES:" -ForegroundColor Cyan
Write-Host "  Prometheus : http://localhost:9090" -ForegroundColor White
Write-Host "  Grafana    : http://localhost:3000 (admin/admin123)" -ForegroundColor White
Write-Host "  AlertManager: http://localhost:9093" -ForegroundColor White
Write-Host "  cAdvisor   : http://localhost:8082" -ForegroundColor White

Write-Host "`nPROCHAINES ÉTAPES:" -ForegroundColor Yellow
Write-Host "1. Vérifiez manuellement les interfaces web" -ForegroundColor White
Write-Host "2. Configurez vos dashboards personnalisés" -ForegroundColor White
Write-Host "3. Testez les notifications d'alertes" -ForegroundColor White
Write-Host "4. Planifiez des tests réguliers" -ForegroundColor White

if ($GenerateReport -and $allResults.Count -gt 0) {
    Generate-HtmlReport $allResults $ReportPath
}

Write-Host "`nSystème de monitoring prêt à l'utilisation! 🎉" -ForegroundColor Green
