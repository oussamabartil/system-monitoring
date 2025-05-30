# Script PowerShell pour tester la configuration Mailtrap
# Envoie un email de test via AlertManager vers Mailtrap

param(
    [string]$TestEmail = "oussamabartil.04@gmail.com"
)

Write-Host "🧪 Test de la configuration Mailtrap" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Cyan

# Vérifier que Docker est en cours d'exécution
try {
    $dockerStatus = docker ps --format "table {{.Names}}\t{{.Status}}" | Select-String "alertmanager"
    if ($dockerStatus) {
        Write-Host "✅ AlertManager est en cours d'exécution" -ForegroundColor Green
    } else {
        Write-Host "❌ AlertManager n'est pas en cours d'exécution" -ForegroundColor Red
        Write-Host "Démarrez les services avec: docker-compose up -d" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "❌ Docker n'est pas accessible" -ForegroundColor Red
    exit 1
}

# Fonction pour envoyer une alerte de test
function Send-TestAlert {
    param([string]$Email)
    
    Write-Host "📧 Envoi d'une alerte de test vers $Email..." -ForegroundColor Yellow
    
    # Créer une alerte de test via l'API AlertManager
    $alertData = @{
        alerts = @(
            @{
                labels = @{
                    alertname = "MailtrapTest"
                    severity = "warning"
                    alert_type = "cpu_high"
                    instance = "localhost:9182"
                }
                annotations = @{
                    summary = "Test d'alerte Mailtrap - CPU élevé simulé"
                    description = "Ceci est un test pour vérifier que les emails sont bien envoyés vers Mailtrap"
                }
                startsAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            }
        )
    } | ConvertTo-Json -Depth 10
    
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:9093/api/v1/alerts" -Method Post -Body $alertData -ContentType "application/json"
        Write-Host "✅ Alerte de test envoyée avec succès" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ Erreur lors de l'envoi de l'alerte: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Vérifier la configuration AlertManager
Write-Host "`n🔍 Vérification de la configuration AlertManager..." -ForegroundColor Yellow

$configPath = "alertmanager\alertmanager.yml"
if (Test-Path $configPath) {
    $config = Get-Content $configPath -Raw
    
    if ($config -match "sandbox.smtp.mailtrap.io") {
        Write-Host "✅ Configuration Mailtrap détectée" -ForegroundColor Green
    } else {
        Write-Host "❌ Configuration Mailtrap non trouvée" -ForegroundColor Red
        Write-Host "Exécutez d'abord: .\scripts\configure-mailtrap.ps1" -ForegroundColor Yellow
        exit 1
    }
    
    if ($config -match $TestEmail) {
        Write-Host "✅ Email de test configuré: $TestEmail" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Email de test non trouvé dans la configuration" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ Fichier de configuration AlertManager non trouvé" -ForegroundColor Red
    exit 1
}

# Envoyer l'alerte de test
Write-Host "`n🚀 Envoi de l'alerte de test..." -ForegroundColor Yellow
if (Send-TestAlert -Email $TestEmail) {
    Write-Host "`n✅ Test terminé avec succès!" -ForegroundColor Green
    Write-Host "`n📋 Prochaines étapes:" -ForegroundColor Cyan
    Write-Host "1. Connectez-vous à votre compte Mailtrap" -ForegroundColor White
    Write-Host "2. Vérifiez votre inbox pour l'email d'alerte" -ForegroundColor White
    Write-Host "3. L'email devrait arriver dans les 30 secondes" -ForegroundColor White
    
    Write-Host "`n🌐 Liens utiles:" -ForegroundColor Yellow
    Write-Host "- Mailtrap: https://mailtrap.io/inboxes" -ForegroundColor White
    Write-Host "- AlertManager: http://localhost:9093" -ForegroundColor White
    Write-Host "- Prometheus: http://localhost:9090" -ForegroundColor White
} else {
    Write-Host "`n❌ Échec du test" -ForegroundColor Red
    Write-Host "Vérifiez les logs d'AlertManager: docker-compose logs alertmanager" -ForegroundColor Yellow
}

Write-Host "`n📊 Pour surveiller les alertes en temps réel:" -ForegroundColor Yellow
Write-Host "docker-compose logs -f alertmanager" -ForegroundColor White
