# Script de Test Grafana
# Grafana Testing Script

param(
    [string]$GrafanaUrl = "http://localhost:3000",
    [string]$Username = "admin",
    [string]$Password = "admin123",
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

function Get-GrafanaAuthHeaders($username, $password) {
    $base64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${username}:${password}"))
    return @{
        "Authorization" = "Basic $base64"
        "Content-Type" = "application/json"
    }
}

Write-TestHeader "PHASE 4: TEST DE GRAFANA"

Write-TestStep "4.1" "Test de connectivité Grafana"

try {
    $response = Invoke-WebRequest -Uri $GrafanaUrl -TimeoutSec 10 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-TestResult "Grafana Web Interface" "PASS" "Interface accessible"
    } else {
        Write-TestResult "Grafana Web Interface" "FAIL" "Status Code: $($response.StatusCode)"
    }
} catch {
    Write-TestResult "Grafana Web Interface" "FAIL" $_.Exception.Message
    exit 1
}

Write-TestStep "4.2" "Test d'authentification"

$headers = Get-GrafanaAuthHeaders $Username $Password

try {
    $response = Invoke-RestMethod -Uri "$GrafanaUrl/api/user" -Headers $headers -TimeoutSec 10
    if ($response.login -eq $Username) {
        Write-TestResult "Authentification Grafana" "PASS" "Utilisateur: $($response.login)"
    } else {
        Write-TestResult "Authentification Grafana" "FAIL" "Utilisateur inattendu"
    }
} catch {
    Write-TestResult "Authentification Grafana" "FAIL" $_.Exception.Message
}

Write-TestStep "4.3" "Vérification des sources de données"

try {
    $datasources = Invoke-RestMethod -Uri "$GrafanaUrl/api/datasources" -Headers $headers -TimeoutSec 10
    
    if ($datasources.Count -gt 0) {
        Write-TestResult "Sources de données" "PASS" "$($datasources.Count) source(s) configurée(s)"
        
        foreach ($ds in $datasources) {
            # Test de connectivité de la source de données
            try {
                $testResult = Invoke-RestMethod -Uri "$GrafanaUrl/api/datasources/$($ds.id)/health" -Headers $headers -TimeoutSec 10
                $status = if ($testResult.status -eq "OK") { "PASS" } else { "FAIL" }
                Write-TestResult "DataSource: $($ds.name)" $status $testResult.message
            } catch {
                Write-TestResult "DataSource: $($ds.name)" "FAIL" $_.Exception.Message
            }
        }
    } else {
        Write-TestResult "Sources de données" "FAIL" "Aucune source de données trouvée"
    }
} catch {
    Write-TestResult "Sources de données" "FAIL" $_.Exception.Message
}

Write-TestStep "4.4" "Vérification des dashboards"

try {
    $dashboards = Invoke-RestMethod -Uri "$GrafanaUrl/api/search?type=dash-db" -Headers $headers -TimeoutSec 10
    
    if ($dashboards.Count -gt 0) {
        Write-TestResult "Dashboards" "PASS" "$($dashboards.Count) dashboard(s) trouvé(s)"
        
        foreach ($dashboard in $dashboards) {
            Write-TestResult "Dashboard: $($dashboard.title)" "INFO" "UID: $($dashboard.uid)"
        }
        
        # Test d'accès à un dashboard spécifique
        $firstDashboard = $dashboards[0]
        try {
            $dashboardDetail = Invoke-RestMethod -Uri "$GrafanaUrl/api/dashboards/uid/$($firstDashboard.uid)" -Headers $headers -TimeoutSec 10
            Write-TestResult "Accès dashboard détaillé" "PASS" "Dashboard accessible"
        } catch {
            Write-TestResult "Accès dashboard détaillé" "FAIL" $_.Exception.Message
        }
    } else {
        Write-TestResult "Dashboards" "WARN" "Aucun dashboard trouvé"
    }
} catch {
    Write-TestResult "Dashboards" "FAIL" $_.Exception.Message
}

Write-TestStep "4.5" "Test des plugins"

try {
    $plugins = Invoke-RestMethod -Uri "$GrafanaUrl/api/plugins" -Headers $headers -TimeoutSec 10
    
    $expectedPlugins = @("grafana-clock-panel", "grafana-simple-json-datasource")
    
    foreach ($expectedPlugin in $expectedPlugins) {
        $plugin = $plugins | Where-Object { $_.id -eq $expectedPlugin }
        if ($plugin) {
            $status = if ($plugin.enabled) { "PASS" } else { "WARN" }
            Write-TestResult "Plugin: $expectedPlugin" $status "Version: $($plugin.info.version)"
        } else {
            Write-TestResult "Plugin: $expectedPlugin" "FAIL" "Plugin non trouvé"
        }
    }
} catch {
    Write-TestResult "Plugins" "FAIL" $_.Exception.Message
}

Write-TestStep "4.6" "Test de requête de données"

try {
    # Test d'une requête simple vers Prometheus
    $query = @{
        queries = @(
            @{
                expr = "up"
                refId = "A"
            }
        )
        from = [string]([DateTimeOffset]::Now.AddMinutes(-5).ToUnixTimeMilliseconds())
        to = [string]([DateTimeOffset]::Now.ToUnixTimeMilliseconds())
    }
    
    $queryJson = $query | ConvertTo-Json -Depth 3
    $response = Invoke-RestMethod -Uri "$GrafanaUrl/api/ds/query" -Method POST -Headers $headers -Body $queryJson -TimeoutSec 15
    
    if ($response.results) {
        Write-TestResult "Requête de données" "PASS" "Données récupérées avec succès"
    } else {
        Write-TestResult "Requête de données" "FAIL" "Aucune donnée retournée"
    }
} catch {
    Write-TestResult "Requête de données" "FAIL" $_.Exception.Message
}

Write-Host "`n" + "="*60 -ForegroundColor Green
Write-Host " INSTRUCTIONS POUR TESTER MANUELLEMENT" -ForegroundColor Green
Write-Host "="*60 -ForegroundColor Green

Write-Host "`n1. Ouvrez votre navigateur et allez à: $GrafanaUrl" -ForegroundColor Yellow
Write-Host "2. Connectez-vous avec:" -ForegroundColor Yellow
Write-Host "   - Utilisateur: $Username" -ForegroundColor White
Write-Host "   - Mot de passe: $Password" -ForegroundColor White
Write-Host "3. Vérifiez que vous pouvez voir les dashboards" -ForegroundColor Yellow
Write-Host "4. Testez la navigation entre les différents dashboards" -ForegroundColor Yellow
Write-Host "5. Vérifiez que les graphiques affichent des données" -ForegroundColor Yellow

Write-Host "`nPour continuer les tests:" -ForegroundColor Cyan
Write-Host "  .\scripts\test-alerts.ps1" -ForegroundColor White
