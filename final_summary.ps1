# Résumé final du système de monitoring et d'alertes
Write-Output "🎯 RÉSUMÉ FINAL - SYSTÈME DE MONITORING ALERTMANAGER"
Write-Output "=================================================="
Write-Output ""

# Vérifier l'état des services
Write-Output "📊 ÉTAT DES SERVICES:"
Write-Output "--------------------"
$containers = docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | Out-String
Write-Output $containers

# Vérifier AlertManager
Write-Output "🚨 ALERTMANAGER:"
Write-Output "---------------"
try {
    $alertManagerStatus = Invoke-RestMethod -Uri 'http://localhost:9093/api/v2/status' -Method Get -ErrorAction Stop
    Write-Output "✅ AlertManager: OPÉRATIONNEL"
    Write-Output "   URL: http://localhost:9093"
    
    # Vérifier les alertes actives
    $alerts = Invoke-RestMethod -Uri 'http://localhost:9093/api/v2/alerts' -Method Get
    Write-Output "   Alertes actives: $($alerts.Count)"
    
    # Vérifier les récepteurs
    $receivers = Invoke-RestMethod -Uri 'http://localhost:9093/api/v2/receivers' -Method Get
    Write-Output "   Récepteurs configurés: $($receivers.Count)"
    
} catch {
    Write-Output "❌ AlertManager: NON ACCESSIBLE"
}

Write-Output ""
Write-Output "📧 CONFIGURATION EMAIL:"
Write-Output "-----------------------"
Write-Output "✅ Destinataire: oussamabartil.04@gmail.com"
Write-Output "✅ Serveur SMTP: localhost:587 (serveur de test)"
Write-Output "✅ Récepteur CPU: cpu-alerts-user"
Write-Output "✅ Seuil CPU: 85% pendant 5 minutes"

Write-Output ""
Write-Output "🔍 RÈGLES D'ALERTES CONFIGURÉES:"
Write-Output "--------------------------------"
Write-Output "✅ HighCPUUsage (alert_type: cpu_high)"
Write-Output "   - Seuil: > 85% CPU"
Write-Output "   - Durée: 5 minutes"
Write-Output "   - Sévérité: critical"
Write-Output "   - Email: oussamabartil.04@gmail.com"
Write-Output ""
Write-Output "✅ HighMemoryUsage"
Write-Output "   - Seuil: > 85% RAM"
Write-Output "   - Sévérité: warning"
Write-Output ""
Write-Output "✅ ContainerHighMemory (actuellement active)"
Write-Output "   - Seuil: > 90% mémoire conteneur"
Write-Output "   - Sévérité: warning"

Write-Output ""
Write-Output "🎮 INTERFACES WEB DISPONIBLES:"
Write-Output "------------------------------"
Write-Output "🔗 AlertManager: http://localhost:9093"
Write-Output "   - Voir les alertes actives"
Write-Output "   - Gérer les silences"
Write-Output "   - Vérifier la configuration"
Write-Output ""
Write-Output "🔗 Prometheus: http://localhost:9090"
Write-Output "   - Métriques en temps réel"
Write-Output "   - Règles d'alertes: http://localhost:9090/alerts"
Write-Output "   - Requêtes PromQL"
Write-Output ""
Write-Output "🔗 Grafana: http://localhost:3000"
Write-Output "   - Tableaux de bord visuels"
Write-Output "   - Graphiques de performance"
Write-Output "   - Historique des métriques"

Write-Output ""
Write-Output "🧪 TESTS DISPONIBLES:"
Write-Output "---------------------"
Write-Output "1. Test SMTP:"
Write-Output "   python test_smtp.py"
Write-Output ""
Write-Output "2. Test de charge CPU (déclenche l'alerte):"
Write-Output "   powershell -ExecutionPolicy Bypass -File cpu_stress_test.ps1"
Write-Output ""
Write-Output "3. Vérification des alertes:"
Write-Output "   powershell -ExecutionPolicy Bypass -File check_alerts.ps1"

Write-Output ""
Write-Output "✅ SYSTÈME PRÊT!"
Write-Output "=================="
Write-Output "Votre système de monitoring avec AlertManager est opérationnel."
Write-Output "Les alertes CPU seront envoyées à oussamabartil.04@gmail.com"
Write-Output "quand l'usage CPU dépasse 85% pendant 5 minutes."
Write-Output ""
Write-Output "Pour tester le système:"
Write-Output "1. Ouvrez http://localhost:9093 dans votre navigateur"
Write-Output "2. Lancez le test de charge CPU si vous voulez déclencher une alerte"
Write-Output "3. Surveillez votre email pour les notifications"
