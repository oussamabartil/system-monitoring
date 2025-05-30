# Script pour simuler une charge CPU élevée et tester les alertes
Write-Output "=== TEST DE CHARGE CPU POUR DÉCLENCHER LES ALERTES ==="
Write-Output "Ce script va créer une charge CPU élevée pendant 10 minutes"
Write-Output "pour déclencher l'alerte HighCPUUsage configurée dans Prometheus."
Write-Output ""
Write-Output "L'alerte sera déclenchée si le CPU dépasse 85% pendant 5 minutes."
Write-Output "Une fois déclenchée, elle sera envoyée à oussamabartil.04@gmail.com"
Write-Output ""

$confirmation = Read-Host "Voulez-vous continuer? (y/N)"
if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    Write-Output "Test annulé."
    exit
}

Write-Output "Démarrage du test de charge CPU..."
Write-Output "Appuyez sur Ctrl+C pour arrêter le test"
Write-Output ""

# Obtenir le nombre de processeurs
$processorCount = (Get-WmiObject -Class Win32_ComputerSystem).NumberOfLogicalProcessors
Write-Output "Nombre de processeurs logiques détectés: $processorCount"

# Créer des jobs pour charger chaque processeur
$jobs = @()
for ($i = 0; $i -lt $processorCount; $i++) {
    $job = Start-Job -ScriptBlock {
        $endTime = (Get-Date).AddMinutes(10)
        while ((Get-Date) -lt $endTime) {
            # Calculs intensifs pour charger le CPU
            $result = 0
            for ($j = 0; $j -lt 1000000; $j++) {
                $result += [Math]::Sqrt($j)
            }
        }
    }
    $jobs += $job
    Write-Output "Job $($i+1) démarré (ID: $($job.Id))"
}

Write-Output ""
Write-Output "Charge CPU en cours... Surveillez les métriques dans:"
Write-Output "- Prometheus: http://localhost:9090"
Write-Output "- AlertManager: http://localhost:9093"
Write-Output "- Grafana: http://localhost:3000"
Write-Output ""

# Surveiller les jobs pendant 10 minutes
$startTime = Get-Date
$endTime = $startTime.AddMinutes(10)

while ((Get-Date) -lt $endTime) {
    $runningJobs = $jobs | Where-Object { $_.State -eq "Running" }
    $elapsedMinutes = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
    
    Write-Output "[$elapsedMinutes min] Jobs actifs: $($runningJobs.Count)/$($jobs.Count)"
    
    # Vérifier s'il y a de nouvelles alertes CPU
    try {
        $alerts = Invoke-RestMethod -Uri 'http://localhost:9093/api/v2/alerts' -Method Get -ErrorAction SilentlyContinue
        $cpuAlerts = $alerts | Where-Object { $_.labels.alertname -eq "HighCPUUsage" -or $_.labels.alert_type -eq "cpu_high" }
        if ($cpuAlerts) {
            Write-Output "🚨 ALERTE CPU DÉTECTÉE! Nombre d'alertes: $($cpuAlerts.Count)"
            foreach ($alert in $cpuAlerts) {
                Write-Output "   - Statut: $($alert.status.state)"
                Write-Output "   - Début: $($alert.startsAt)"
                Write-Output "   - Récepteur: $($alert.receivers[0].name)"
            }
        }
    } catch {
        # Ignorer les erreurs de connexion
    }
    
    Start-Sleep -Seconds 30
}

Write-Output ""
Write-Output "Arrêt des jobs de charge CPU..."
$jobs | Stop-Job
$jobs | Remove-Job

Write-Output "Test terminé. Vérifiez AlertManager pour voir les alertes générées."
