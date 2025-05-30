# Script pour ouvrir toutes les interfaces web du système de monitoring
Write-Output "🌐 Ouverture des interfaces web du système de monitoring..."
Write-Output ""

# Ouvrir AlertManager
Write-Output "📱 Ouverture d'AlertManager..."
Start-Process "http://localhost:9093"
Start-Sleep -Seconds 2

# Ouvrir Prometheus
Write-Output "📊 Ouverture de Prometheus..."
Start-Process "http://localhost:9090"
Start-Sleep -Seconds 2

# Ouvrir Prometheus Alerts
Write-Output "🚨 Ouverture des alertes Prometheus..."
Start-Process "http://localhost:9090/alerts"
Start-Sleep -Seconds 2

# Ouvrir Grafana
Write-Output "📈 Ouverture de Grafana..."
Start-Process "http://localhost:3000"

Write-Output ""
Write-Output "✅ Toutes les interfaces ont été ouvertes dans votre navigateur!"
Write-Output ""
Write-Output "📋 Récapitulatif des interfaces:"
Write-Output "- AlertManager: http://localhost:9093 (gestion des alertes)"
Write-Output "- Prometheus: http://localhost:9090 (métriques)"
Write-Output "- Alertes Prometheus: http://localhost:9090/alerts (règles d'alertes)"
Write-Output "- Grafana: http://localhost:3000 (tableaux de bord)"
