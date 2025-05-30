# Script complet pour tester le système de monitoring et d'alertes
Write-Output "🚀 TEST COMPLET DU SYSTÈME DE MONITORING"
Write-Output "========================================"
Write-Output ""

# Vérifier que tous les services sont en cours d'exécution
Write-Output "1️⃣ Vérification des services Docker..."
$containers = docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
Write-Output $containers
Write-Output ""

# Vérifier AlertManager
Write-Output "2️⃣ Test de connectivité AlertManager..."
try {
    $alertManagerStatus = Invoke-RestMethod -Uri 'http://localhost:9093/api/v2/status' -Method Get -ErrorAction Stop
    Write-Output "✅ AlertManager accessible"
} catch {
    Write-Output "❌ AlertManager non accessible: $($_.Exception.Message)"
    exit 1
}

# Vérifier Prometheus
Write-Output "3️⃣ Test de connectivité Prometheus..."
try {
    $prometheusStatus = Invoke-WebRequest -Uri 'http://localhost:9090/-/healthy' -UseBasicParsing -ErrorAction Stop
    Write-Output "✅ Prometheus accessible"
} catch {
    Write-Output "❌ Prometheus non accessible: $($_.Exception.Message)"
    exit 1
}

# Vérifier Grafana
Write-Output "4️⃣ Test de connectivité Grafana..."
try {
    $grafanaStatus = Invoke-WebRequest -Uri 'http://localhost:3000/api/health' -UseBasicParsing -ErrorAction Stop
    Write-Output "✅ Grafana accessible"
} catch {
    Write-Output "❌ Grafana non accessible: $($_.Exception.Message)"
    exit 1
}

Write-Output ""
Write-Output "5️⃣ État actuel des alertes..."
try {
    $alerts = Invoke-RestMethod -Uri 'http://localhost:9093/api/v2/alerts' -Method Get
    Write-Output "Nombre total d'alertes actives: $($alerts.Count)"
    
    $alertGroups = $alerts | Group-Object { $_.labels.alertname }
    foreach ($group in $alertGroups) {
        Write-Output "  - $($group.Name): $($group.Count) alertes"
    }
} catch {
    Write-Output "❌ Impossible de récupérer les alertes: $($_.Exception.Message)"
}

Write-Output ""
Write-Output "6️⃣ Configuration des récepteurs d'alertes..."
try {
    $receivers = Invoke-RestMethod -Uri 'http://localhost:9093/api/v2/receivers' -Method Get
    Write-Output "Récepteurs configurés:"
    foreach ($receiver in $receivers) {
        Write-Output "  - $($receiver.name)"
    }
} catch {
    Write-Output "❌ Impossible de récupérer les récepteurs: $($_.Exception.Message)"
}

Write-Output ""
Write-Output "📋 RÉSUMÉ DE LA CONFIGURATION"
Write-Output "============================="
Write-Output "✅ AlertManager: http://localhost:9093"
Write-Output "✅ Prometheus: http://localhost:9090"
Write-Output "✅ Grafana: http://localhost:3000"
Write-Output "📧 Email configuré: oussamabartil.04@gmail.com"
Write-Output "🚨 Seuil CPU: 85% pendant 5 minutes"
Write-Output ""

Write-Output "🎯 PROCHAINES ÉTAPES POUR TESTER LES ALERTES:"
Write-Output "1. Démarrer le serveur SMTP de test:"
Write-Output "   python smtp_test_server.py"
Write-Output ""
Write-Output "2. Dans un autre terminal, lancer le test de charge CPU:"
Write-Output "   powershell -ExecutionPolicy Bypass -File cpu_stress_test.ps1"
Write-Output ""
Write-Output "3. Surveiller les interfaces web:"
Write-Output "   - AlertManager: http://localhost:9093"
Write-Output "   - Prometheus: http://localhost:9090/alerts"
Write-Output "   - Grafana: http://localhost:3000"
Write-Output ""

$startTests = Read-Host "Voulez-vous démarrer le serveur SMTP de test maintenant? (y/N)"
if ($startTests -eq 'y' -or $startTests -eq 'Y') {
    Write-Output ""
    Write-Output "🚀 Démarrage du serveur SMTP de test..."
    Write-Output "Appuyez sur Ctrl+C pour arrêter"
    python smtp_test_server.py
}
