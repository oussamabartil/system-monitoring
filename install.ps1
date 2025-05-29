# Script d'installation automatique pour la stack de monitoring
# Supervision des Systèmes avec Prometheus & Grafana

param(
    [switch]$SkipDockerCheck,
    [switch]$AutoStart,
    [string]$GrafanaPassword = "admin123"
)

Write-Host "🚀 Installation de la stack de monitoring Prometheus & Grafana" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor Cyan

# Fonction pour vérifier les prérequis
function Test-Prerequisites {
    Write-Host "🔍 Vérification des prérequis..." -ForegroundColor Yellow
    
    # Vérification de PowerShell
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -lt 5) {
        Write-Host "❌ PowerShell 5.0 ou supérieur requis (version actuelle: $psVersion)" -ForegroundColor Red
        return $false
    }
    Write-Host "✅ PowerShell $psVersion détecté" -ForegroundColor Green
    
    # Vérification de Docker (si pas ignorée)
    if (-not $SkipDockerCheck) {
        try {
            $dockerVersion = docker --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Docker détecté: $dockerVersion" -ForegroundColor Green
            } else {
                throw "Docker non trouvé"
            }
            
            $composeVersion = docker-compose --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Docker Compose détecté: $composeVersion" -ForegroundColor Green
            } else {
                throw "Docker Compose non trouvé"
            }
        } catch {
            Write-Host "❌ Docker ou Docker Compose non installé" -ForegroundColor Red
            Write-Host "   Veuillez installer Docker Desktop depuis: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
            return $false
        }
    }
    
    return $true
}

# Fonction pour créer la structure de répertoires
function New-DirectoryStructure {
    Write-Host "📁 Création de la structure de répertoires..." -ForegroundColor Yellow
    
    $directories = @(
        "prometheus/rules",
        "grafana/provisioning/datasources",
        "grafana/provisioning/dashboards",
        "grafana/dashboards/system",
        "grafana/dashboards/docker", 
        "grafana/dashboards/applications",
        "alertmanager",
        "scripts",
        "data/prometheus",
        "data/grafana",
        "data/alertmanager",
        "backups"
    )
    
    foreach ($dir in $directories) {
        if (!(Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Host "✅ Créé: $dir" -ForegroundColor Green
        } else {
            Write-Host "ℹ️  Existe déjà: $dir" -ForegroundColor Blue
        }
    }
}

# Fonction pour configurer les permissions
function Set-Permissions {
    Write-Host "🔐 Configuration des permissions..." -ForegroundColor Yellow
    
    # Permissions pour les répertoires de données
    $dataDirs = @("data/prometheus", "data/grafana", "data/alertmanager")
    
    foreach ($dir in $dataDirs) {
        if (Test-Path $dir) {
            try {
                # Donner les permissions complètes au répertoire
                $acl = Get-Acl $dir
                $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                    "Everyone", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
                )
                $acl.SetAccessRule($accessRule)
                Set-Acl -Path $dir -AclObject $acl
                Write-Host "✅ Permissions configurées pour: $dir" -ForegroundColor Green
            } catch {
                Write-Host "⚠️  Impossible de configurer les permissions pour: $dir" -ForegroundColor Yellow
            }
        }
    }
}

# Fonction pour créer le fichier .env
function New-EnvironmentFile {
    Write-Host "⚙️  Configuration de l'environnement..." -ForegroundColor Yellow
    
    if (!(Test-Path ".env")) {
        if (Test-Path ".env.example") {
            Copy-Item ".env.example" ".env"
            
            # Personnalisation du mot de passe Grafana
            if ($GrafanaPassword -ne "admin123") {
                (Get-Content ".env") -replace "GRAFANA_ADMIN_PASSWORD=admin123", "GRAFANA_ADMIN_PASSWORD=$GrafanaPassword" | Set-Content ".env"
            }
            
            Write-Host "✅ Fichier .env créé à partir de .env.example" -ForegroundColor Green
            Write-Host "💡 Vous pouvez modifier .env pour personnaliser la configuration" -ForegroundColor Blue
        } else {
            Write-Host "⚠️  Fichier .env.example non trouvé" -ForegroundColor Yellow
        }
    } else {
        Write-Host "ℹ️  Fichier .env existe déjà" -ForegroundColor Blue
    }
}

# Fonction pour télécharger les images Docker
function Get-DockerImages {
    Write-Host "📦 Téléchargement des images Docker..." -ForegroundColor Yellow
    
    $images = @(
        "prom/prometheus:latest",
        "grafana/grafana:latest", 
        "prom/node-exporter:latest",
        "gcr.io/cadvisor/cadvisor:latest",
        "ghcr.io/prometheus-community/windows-exporter:latest",
        "prom/alertmanager:latest"
    )
    
    foreach ($image in $images) {
        Write-Host "⬇️  Téléchargement de $image..." -ForegroundColor Blue
        docker pull $image
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ $image téléchargé" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Erreur lors du téléchargement de $image" -ForegroundColor Yellow
        }
    }
}

# Fonction pour valider la configuration
function Test-Configuration {
    Write-Host "🔍 Validation de la configuration..." -ForegroundColor Yellow
    
    $configFiles = @(
        "docker-compose.yml",
        "prometheus/prometheus.yml",
        "prometheus/rules/alerts.yml",
        "alertmanager/alertmanager.yml"
    )
    
    $allValid = $true
    
    foreach ($file in $configFiles) {
        if (Test-Path $file) {
            Write-Host "✅ $file trouvé" -ForegroundColor Green
        } else {
            Write-Host "❌ $file manquant" -ForegroundColor Red
            $allValid = $false
        }
    }
    
    return $allValid
}

# Exécution de l'installation
Write-Host "Démarrage de l'installation..." -ForegroundColor White

# Étape 1: Vérification des prérequis
if (!(Test-Prerequisites)) {
    Write-Host "❌ Installation interrompue - Prérequis non satisfaits" -ForegroundColor Red
    exit 1
}

# Étape 2: Création de la structure
New-DirectoryStructure

# Étape 3: Configuration des permissions
Set-Permissions

# Étape 4: Configuration de l'environnement
New-EnvironmentFile

# Étape 5: Validation de la configuration
if (!(Test-Configuration)) {
    Write-Host "❌ Installation interrompue - Configuration invalide" -ForegroundColor Red
    exit 1
}

# Étape 6: Téléchargement des images Docker
if (-not $SkipDockerCheck) {
    Get-DockerImages
}

# Étape 7: Démarrage automatique (si demandé)
if ($AutoStart) {
    Write-Host "🚀 Démarrage automatique de la stack..." -ForegroundColor Yellow
    if (Test-Path "scripts/start-monitoring.ps1") {
        & "scripts/start-monitoring.ps1"
    } else {
        docker-compose up -d
    }
}

# Résumé de l'installation
Write-Host "`n🎉 Installation terminée avec succès!" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host "📋 Prochaines étapes:" -ForegroundColor White
Write-Host "   1. Démarrer la stack: .\scripts\start-monitoring.ps1" -ForegroundColor Cyan
Write-Host "   2. Accéder à Grafana: http://localhost:3000" -ForegroundColor Cyan
Write-Host "   3. Se connecter avec: admin / $GrafanaPassword" -ForegroundColor Cyan
Write-Host "   4. Vérifier la santé: .\scripts\health-check.ps1" -ForegroundColor Cyan

Write-Host "`n💡 Conseils:" -ForegroundColor White
Write-Host "   • Lisez le README.md pour plus d'informations" -ForegroundColor Yellow
Write-Host "   • Personnalisez le fichier .env selon vos besoins" -ForegroundColor Yellow
Write-Host "   • Configurez les alertes dans alertmanager/alertmanager.yml" -ForegroundColor Yellow

if (-not $AutoStart) {
    Write-Host "`n🚀 Pour démarrer maintenant:" -ForegroundColor White
    Write-Host "   .\scripts\start-monitoring.ps1" -ForegroundColor Green
}
