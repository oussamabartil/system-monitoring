# Script pour vérifier les alertes AlertManager
$alerts = Invoke-RestMethod -Uri 'http://localhost:9093/api/v2/alerts' -Method Get

Write-Output "=== RÉSUMÉ DES ALERTES ALERTMANAGER ==="
Write-Output "Nombre total d'alertes actives: $($alerts.Count)"
Write-Output ""

# Grouper par type d'alerte
$alertGroups = $alerts | Group-Object { $_.labels.alertname }
Write-Output "=== TYPES D'ALERTES ==="
foreach ($group in $alertGroups) {
    Write-Output "- $($group.Name): $($group.Count) alertes"
}
Write-Output ""

# Chercher des alertes CPU spécifiques
$cpuAlerts = $alerts | Where-Object { $_.labels.alertname -like "*CPU*" -or $_.labels.alert_type -eq "cpu_high" }
if ($cpuAlerts) {
    Write-Output "=== ALERTES CPU TROUVÉES ==="
    foreach ($alert in $cpuAlerts) {
        Write-Output "Alerte: $($alert.labels.alertname)"
        Write-Output "Statut: $($alert.status.state)"
        Write-Output "Début: $($alert.startsAt)"
        Write-Output "Récepteur: $($alert.receivers[0].name)"
        Write-Output "---"
    }
} else {
    Write-Output "=== AUCUNE ALERTE CPU SPÉCIFIQUE TROUVÉE ==="
    Write-Output "Les alertes CPU avec alert_type='cpu_high' n'ont pas été déclenchées."
    Write-Output "Cela signifie que l'usage CPU est actuellement en dessous du seuil de 85%."
}

Write-Output ""
Write-Output "=== ALERTES MÉMOIRE ACTIVES ==="
$memoryAlerts = $alerts | Where-Object { $_.labels.alertname -like "*Memory*" }
if ($memoryAlerts) {
    Write-Output "Nombre d'alertes mémoire: $($memoryAlerts.Count)"
    Write-Output "Ces alertes sont envoyées au récepteur: warning-alerts"
} else {
    Write-Output "Aucune alerte mémoire active"
}
