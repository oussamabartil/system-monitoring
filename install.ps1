# Script d'installation automatique pour la stack de monitoring
# Supervision des Systemes avec Prometheus & Grafana

param(
    [switch]$SkipDockerCheck,
    [switch]$AutoStart,
    [string]$GrafanaPassword = "admin123"
)

Write-Host "Installation de la stack de monitoring Prometheus & Grafana" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor Cyan

# Fonction pour verifier les prerequis
function Test-Prerequisites {
    Write-Host "Verification des prerequis..." -ForegroundColor Yellow
    
    # Verification de PowerShell
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -lt 5) {
        Write-Host "PowerShell 5.0 ou superieur requis (version actuelle: $psVersion)" -ForegroundColor Red
        return $false
    }
    Write-Host "PowerShell $psVersion detecte" -ForegroundColor Green
    
    # Verification de Docker (si pas ignoree)
    if (-not $SkipDockerCheck) {
        try {
            $dockerVersion = docker --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Docker detecte: $dockerVersion" -ForegroundColor Green
            } else {
                throw "Docker non trouve"
            }
            
            $composeVersion = docker-compose --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Docker Compose detecte: $composeVersion" -ForegroundColor Green
            } else {
                throw "Docker Compose non trouve"
            }
        } catch {
            Write-Host "Docker ou Docker Compose non installe" -ForegroundColor Red
            Write-Host "Veuillez installer Docker Desktop depuis: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
            return $false
        }
    }
    
    return $true
}

# Fonction pour creer la structure de repertoires
function New-DirectoryStructure {
    Write-Host "Creation de la structure de repertoires..." -ForegroundColor Yellow
    
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
            Write-Host "Cree: $dir" -ForegroundColor Green
        } else {
            Write-Host "Existe deja: $dir" -ForegroundColor Blue
        }
    }
}

# Fonction pour configurer les permissions
function Set-Permissions {
    Write-Host "Configuration des permissions..." -ForegroundColor Yellow
    
    # Permissions pour les repertoires de donnees
    $dataDirs = @("data/prometheus", "data/grafana", "data/alertmanager")
    
    foreach ($dir in $dataDirs) {
        if (Test-Path $dir) {
            try {
                # Donner les permissions completes au repertoire
                $acl = Get-Acl $dir
                $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                    "Everyone", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
                )
                $acl.SetAccessRule($accessRule)
                Set-Acl -Path $dir -AclObject $acl
                Write-Host "Permissions configurees pour: $dir" -ForegroundColor Green
            } catch {
                Write-Host "Impossible de configurer les permissions pour: $dir" -ForegroundColor Yellow
            }
        }
    }
}

# Fonction pour creer le fichier .env
function New-EnvironmentFile {
    Write-Host "Configuration de l'environnement..." -ForegroundColor Yellow
    
    if (!(Test-Path ".env")) {
        if (Test-Path ".env.example") {
            Copy-Item ".env.example" ".env"
            
            # Personnalisation du mot de passe Grafana
            if ($GrafanaPassword -ne "admin123") {
                (Get-Content ".env") -replace "GRAFANA_ADMIN_PASSWORD=admin123", "GRAFANA_ADMIN_PASSWORD=$GrafanaPassword" | Set-Content ".env"
            }
            
            Write-Host "Fichier .env cree a partir de .env.example" -ForegroundColor Green
            Write-Host "Vous pouvez modifier .env pour personnaliser la configuration" -ForegroundColor Blue
        } else {
            Write-Host "Fichier .env.example non trouve" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Fichier .env existe deja" -ForegroundColor Blue
    }
}

# Fonction pour telecharger les images Docker
function Get-DockerImages {
    Write-Host "Telechargement des images Docker..." -ForegroundColor Yellow
    
    $images = @(
        "prom/prometheus:latest",
        "grafana/grafana:latest", 
        "prom/node-exporter:latest",
        "gcr.io/cadvisor/cadvisor:latest",
        "ghcr.io/prometheus-community/windows-exporter:latest",
        "prom/alertmanager:latest"
    )
    
    foreach ($image in $images) {
        Write-Host "Telechargement de $image..." -ForegroundColor Blue
        docker pull $image
        if ($LASTEXITCODE -eq 0) {
            Write-Host "$image telecharge" -ForegroundColor Green
        } else {
            Write-Host "Erreur lors du telechargement de $image" -ForegroundColor Yellow
        }
    }
}

# Fonction pour valider la configuration
function Test-Configuration {
    Write-Host "Validation de la configuration..." -ForegroundColor Yellow
    
    $configFiles = @(
        "docker-compose.yml",
        "prometheus/prometheus.yml",
        "prometheus/rules/alerts.yml",
        "alertmanager/alertmanager.yml"
    )
    
    $allValid = $true
    
    foreach ($file in $configFiles) {
        if (Test-Path $file) {
            Write-Host "$file trouve" -ForegroundColor Green
        } else {
            Write-Host "$file manquant" -ForegroundColor Red
            $allValid = $false
        }
    }
    
    return $allValid
}

# Execution de l'installation
Write-Host "Demarrage de l'installation..." -ForegroundColor White

# Etape 1: Verification des prerequis
if (!(Test-Prerequisites)) {
    Write-Host "Installation interrompue - Prerequis non satisfaits" -ForegroundColor Red
    exit 1
}

# Etape 2: Creation de la structure
New-DirectoryStructure

# Etape 3: Configuration des permissions
Set-Permissions

# Etape 4: Configuration de l'environnement
New-EnvironmentFile

# Etape 5: Validation de la configuration
if (!(Test-Configuration)) {
    Write-Host "Installation interrompue - Configuration invalide" -ForegroundColor Red
    exit 1
}

# Etape 6: Telechargement des images Docker
if (-not $SkipDockerCheck) {
    Get-DockerImages
}

# Etape 7: Demarrage automatique (si demande)
if ($AutoStart) {
    Write-Host "Demarrage automatique de la stack..." -ForegroundColor Yellow
    if (Test-Path "scripts/start-monitoring.ps1") {
        & "scripts/start-monitoring.ps1"
    } else {
        docker-compose up -d
    }
}

# Resume de l'installation
Write-Host "`nInstallation terminee avec succes!" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host "Prochaines etapes:" -ForegroundColor White
Write-Host "   1. Demarrer la stack: .\scripts\start-monitoring.ps1" -ForegroundColor Cyan
Write-Host "   2. Acceder a Grafana: http://localhost:3000" -ForegroundColor Cyan
Write-Host "   3. Se connecter avec: admin / $GrafanaPassword" -ForegroundColor Cyan
Write-Host "   4. Verifier la sante: .\scripts\health-check.ps1" -ForegroundColor Cyan

Write-Host "`nConseils:" -ForegroundColor White
Write-Host "   • Lisez le README.md pour plus d'informations" -ForegroundColor Yellow
Write-Host "   • Personnalisez le fichier .env selon vos besoins" -ForegroundColor Yellow
Write-Host "   • Configurez les alertes dans alertmanager/alertmanager.yml" -ForegroundColor Yellow

if (-not $AutoStart) {
    Write-Host "`nPour demarrer maintenant:" -ForegroundColor White
    Write-Host "   .\scripts\start-monitoring.ps1" -ForegroundColor Green
}
