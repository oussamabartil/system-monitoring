# Script PowerShell pour configurer Mailtrap avec AlertManager
# Ce script configure AlertManager pour utiliser Mailtrap au lieu du serveur SMTP local

param(
    [Parameter(Mandatory=$true)]
    [string]$MailtrapUsername,
    
    [Parameter(Mandatory=$true)]
    [string]$MailtrapPassword,
    
    [string]$TestEmail = "oussamabartil.04@gmail.com"
)

Write-Host "🔧 Configuration de Mailtrap pour AlertManager" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Cyan

# Vérifier que les fichiers existent
$alertmanagerFile = "alertmanager\alertmanager.yml"
$envFile = ".env"

if (-not (Test-Path $alertmanagerFile)) {
    Write-Host "❌ Fichier AlertManager non trouvé: $alertmanagerFile" -ForegroundColor Red
    exit 1
}

Write-Host "📧 Configuration des paramètres Mailtrap..." -ForegroundColor Yellow

# Backup du fichier AlertManager
$backupFile = "$alertmanagerFile.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item $alertmanagerFile $backupFile
Write-Host "✅ Sauvegarde créée: $backupFile" -ForegroundColor Green

# Lire le contenu du fichier AlertManager
$content = Get-Content $alertmanagerFile -Raw

# Remplacer la configuration SMTP
$content = $content -replace "smtp_smarthost: 'localhost:587'", "smtp_smarthost: 'sandbox.smtp.mailtrap.io:2525'"
$content = $content -replace "smtp_smarthost: 'sandbox.smtp.mailtrap.io:2525'", "smtp_smarthost: 'sandbox.smtp.mailtrap.io:2525'"

# Ajouter l'authentification si elle n'existe pas
if ($content -notmatch "smtp_auth_username") {
    $content = $content -replace "(smtp_from: '[^']*')", "`$1`n  smtp_auth_username: '$MailtrapUsername'`n  smtp_auth_password: '$MailtrapPassword'"
} else {
    $content = $content -replace "smtp_auth_username: '[^']*'", "smtp_auth_username: '$MailtrapUsername'"
    $content = $content -replace "smtp_auth_password: '[^']*'", "smtp_auth_password: '$MailtrapPassword'"
}

# Sauvegarder le fichier modifié
$content | Set-Content $alertmanagerFile -Encoding UTF8

Write-Host "✅ Configuration AlertManager mise à jour" -ForegroundColor Green

# Créer ou mettre à jour le fichier .env
if (Test-Path $envFile) {
    $envContent = Get-Content $envFile -Raw
    $envContent = $envContent -replace "SMTP_SMARTHOST=.*", "SMTP_SMARTHOST=sandbox.smtp.mailtrap.io:2525"
    $envContent = $envContent -replace "SMTP_AUTH_USERNAME=.*", "SMTP_AUTH_USERNAME=$MailtrapUsername"
    $envContent = $envContent -replace "SMTP_AUTH_PASSWORD=.*", "SMTP_AUTH_PASSWORD=$MailtrapPassword"
    $envContent | Set-Content $envFile -Encoding UTF8
} else {
    # Copier depuis .env.example si .env n'existe pas
    if (Test-Path ".env.example") {
        Copy-Item ".env.example" $envFile
        $envContent = Get-Content $envFile -Raw
        $envContent = $envContent -replace "YOUR_MAILTRAP_USERNAME", $MailtrapUsername
        $envContent = $envContent -replace "YOUR_MAILTRAP_PASSWORD", $MailtrapPassword
        $envContent | Set-Content $envFile -Encoding UTF8
    }
}

Write-Host "✅ Fichier .env mis à jour" -ForegroundColor Green

# Afficher la configuration
Write-Host "`n📋 Configuration Mailtrap:" -ForegroundColor Cyan
Write-Host "- Serveur SMTP: sandbox.smtp.mailtrap.io:2525" -ForegroundColor White
Write-Host "- Nom d'utilisateur: $MailtrapUsername" -ForegroundColor White
Write-Host "- Email de test: $TestEmail" -ForegroundColor White

Write-Host "`n🔄 Redémarrage d'AlertManager nécessaire..." -ForegroundColor Yellow
Write-Host "Exécutez: docker-compose restart alertmanager" -ForegroundColor White

Write-Host "`n🧪 Pour tester la configuration:" -ForegroundColor Yellow
Write-Host ".\scripts\test-mailtrap.ps1" -ForegroundColor White

Write-Host "`n✅ Configuration Mailtrap terminée!" -ForegroundColor Green
Write-Host "Vos emails d'alerte seront maintenant capturés dans votre inbox Mailtrap." -ForegroundColor White
