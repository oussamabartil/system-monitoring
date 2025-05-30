# Script pour tester l'alerte CPU avec le nouveau seuil de 30%
Write-Output "🎯 TEST D'ALERTE CPU - SEUIL 30%"
Write-Output "================================"
Write-Output ""

# Redémarrer Prometheus pour prendre en compte les nouvelles règles
Write-Output "🔄 Redémarrage de Prometheus pour appliquer les nouvelles règles..."
try {
    docker restart prometheus | Out-Null
    Start-Sleep -Seconds 10
    Write-Output "✅ Prometheus redémarré"
} catch {
    Write-Output "❌ Erreur lors du redémarrage de Prometheus: $($_.Exception.Message)"
}

Write-Output ""
Write-Output "📊 Vérification de l'état des services..."
$containers = docker ps --format "table {{.Names}}\t{{.Status}}" 2>$null
if ($containers) {
    Write-Output $containers
} else {
    Write-Output "❌ Impossible de vérifier l'état des conteneurs"
}

Write-Output ""
Write-Output "🔍 Vérification des nouvelles règles d'alerte..."
Write-Output "Nouvelle configuration:"
Write-Output "- Seuil CPU: > 30% (au lieu de 85%)"
Write-Output "- Durée: 2 minutes (au lieu de 5 minutes)"
Write-Output "- Email: oussamabartil.04@gmail.com"

Write-Output ""
Write-Output "🌐 Ouverture des interfaces pour surveillance..."

# Ouvrir Prometheus Alerts
Write-Output "📊 Ouverture de Prometheus Alerts..."
Start-Process "http://localhost:9090/alerts" -ErrorAction SilentlyContinue

Start-Sleep -Seconds 2

# Ouvrir AlertManager
Write-Output "🚨 Ouverture d'AlertManager..."
Start-Process "http://localhost:9093" -ErrorAction SilentlyContinue

Write-Output ""
Write-Output "⏱️ Attente de 30 secondes pour que Prometheus charge les nouvelles règles..."
Start-Sleep -Seconds 30

Write-Output ""
Write-Output "🔍 Vérification de l'usage CPU actuel..."
try {
    # Vérifier l'usage CPU via WMI
    $cpuUsage = Get-WmiObject -Class Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average
    Write-Output "Usage CPU actuel: $cpuUsage%"
    
    if ($cpuUsage -gt 30) {
        Write-Output "🚨 CPU > 30% détecté! L'alerte devrait se déclencher dans 2 minutes."
    } else {
        Write-Output "💡 CPU < 30%. Vous pouvez lancer le test de charge pour déclencher l'alerte."
    }
} catch {
    Write-Output "❌ Impossible de vérifier l'usage CPU: $($_.Exception.Message)"
}

Write-Output ""
Write-Output "🧪 INSTRUCTIONS POUR TESTER:"
Write-Output "=============================="
Write-Output "1. Surveillez les interfaces ouvertes:"
Write-Output "   - Prometheus Alerts: http://localhost:9090/alerts"
Write-Output "   - AlertManager: http://localhost:9093"
Write-Output ""
Write-Output "2. Pour déclencher manuellement l'alerte, lancez:"
Write-Output "   powershell -ExecutionPolicy Bypass -File cpu_stress_test.ps1"
Write-Output ""
Write-Output "3. Avec le nouveau seuil de 30%, l'alerte devrait se déclencher"
Write-Output "   plus facilement lors d'une utilisation normale du système."
Write-Output ""
Write-Output "4. Surveillez votre email oussamabartil.04@gmail.com"
Write-Output "   (assurez-vous que le serveur SMTP de test est en cours d'exécution)"

Write-Output ""
Write-Output "🚀 DÉMARRAGE DU SERVEUR SMTP DE TEST..."
$smtpChoice = Read-Host "Voulez-vous démarrer le serveur SMTP de test maintenant? (y/N)"
if ($smtpChoice -eq 'y' -or $smtpChoice -eq 'Y') {
    Write-Output "Démarrage du serveur SMTP..."
    Write-Output "Appuyez sur Ctrl+C pour arrêter le serveur SMTP"
    python smtp_test_server.py
} else {
    Write-Output ""
    Write-Output "✅ Configuration terminée!"
    Write-Output "N'oubliez pas de démarrer le serveur SMTP avec: python smtp_test_server.py"
}
