# Script final pour générer le rapport de monitoring
# Génère automatiquement un rapport PDF complet du système de monitoring

param(
    [switch]$OpenPDF = $true,
    [switch]$Verbose = $false
)

Write-Host "📄 GÉNÉRATION DU RAPPORT DE MONITORING" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Fonction pour afficher les messages en mode verbose
function Write-Verbose-Custom {
    param([string]$Message)
    if ($Verbose) {
        Write-Host "   $Message" -ForegroundColor Gray
    }
}

# Vérifier que nous sommes dans le bon répertoire
if (-not (Test-Path "rapport-monitoring-simple.tex")) {
    Write-Host "❌ Fichier rapport-monitoring-simple.tex non trouvé!" -ForegroundColor Red
    Write-Host "Assurez-vous d'être dans le dossier rapport-monitoring" -ForegroundColor Yellow
    exit 1
}

# Fonction pour vérifier si une commande existe
function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Étape 1: Vérification des dépendances
Write-Host "🔍 Vérification des dépendances..." -ForegroundColor Yellow

$latexAvailable = Test-Command "pdflatex"
if ($latexAvailable) {
    Write-Host "✅ LaTeX : Disponible" -ForegroundColor Green
    Write-Verbose-Custom "pdflatex trouvé dans le PATH"
} else {
    Write-Host "❌ LaTeX : Non disponible" -ForegroundColor Red
    Write-Host ""
    Write-Host "⚠️  LaTeX est requis pour générer le rapport PDF" -ForegroundColor Yellow
    Write-Host "Installez MiKTeX depuis : https://miktex.org" -ForegroundColor White
    Write-Host "Ou TeX Live depuis : https://tug.org/texlive/" -ForegroundColor White
    Write-Host ""
    
    $continue = Read-Host "Voulez-vous continuer sans générer le PDF? (y/N)"
    if ($continue -ne 'y' -and $continue -ne 'Y') {
        exit 1
    }
}

Write-Host ""

# Étape 2: Génération des placeholders d'images
Write-Host "🎨 Préparation des ressources..." -ForegroundColor Yellow

if (-not (Test-Path "images")) {
    Write-Verbose-Custom "Création du dossier images"
    New-Item -ItemType Directory -Path "images" -Force | Out-Null
}

# Vérifier si les placeholders existent
$placeholders = @(
    "cpu_usage_24h_placeholder.txt",
    "memory_usage_placeholder.txt",
    "disk_usage_placeholder.txt",
    "network_traffic_placeholder.txt",
    "container_metrics_placeholder.txt",
    "alerts_timeline_placeholder.txt",
    "system_overview_placeholder.txt"
)

$missingPlaceholders = 0
foreach ($placeholder in $placeholders) {
    if (-not (Test-Path "images\$placeholder")) {
        $missingPlaceholders++
    }
}

if ($missingPlaceholders -gt 0) {
    Write-Verbose-Custom "Génération des placeholders d'images manquants"
    try {
        python generate_graphs.py | Out-Null
        Write-Host "✅ Ressources préparées" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Impossible de générer les placeholders, mais ce n'est pas critique" -ForegroundColor Yellow
    }
} else {
    Write-Host "✅ Ressources déjà disponibles" -ForegroundColor Green
}

Write-Host ""

# Étape 3: Compilation du rapport LaTeX
if ($latexAvailable) {
    Write-Host "📝 Compilation du rapport PDF..." -ForegroundColor Yellow
    
    try {
        # Première compilation
        Write-Verbose-Custom "Première passe de compilation..."
        $output1 = pdflatex -interaction=nonstopmode rapport-monitoring-simple.tex 2>&1
        
        # Deuxième compilation pour les références croisées
        Write-Verbose-Custom "Deuxième passe (références croisées)..."
        $output2 = pdflatex -interaction=nonstopmode rapport-monitoring-simple.tex 2>&1
        
        # Troisième compilation pour la table des matières
        Write-Verbose-Custom "Troisième passe (table des matières)..."
        $output3 = pdflatex -interaction=nonstopmode rapport-monitoring-simple.tex 2>&1
        
        if (Test-Path "rapport-monitoring-simple.pdf") {
            Write-Host "✅ PDF généré avec succès!" -ForegroundColor Green
            
            # Obtenir les informations du fichier
            $pdfFile = Get-Item "rapport-monitoring-simple.pdf"
            $fileSize = [math]::Round($pdfFile.Length / 1MB, 2)
            $creationTime = $pdfFile.LastWriteTime.ToString("dd/MM/yyyy HH:mm:ss")
            
            Write-Host "📄 Fichier : rapport-monitoring-simple.pdf" -ForegroundColor White
            Write-Host "📊 Taille : $fileSize MB" -ForegroundColor White
            Write-Host "🕒 Généré le : $creationTime" -ForegroundColor White
            
        } else {
            Write-Host "❌ Erreur : Le fichier PDF n'a pas été créé" -ForegroundColor Red
            Write-Host "Vérifiez le fichier rapport-monitoring-simple.log pour plus de détails" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "❌ Erreur lors de la compilation LaTeX" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
} else {
    Write-Host "⏭️  Compilation LaTeX ignorée (LaTeX non disponible)" -ForegroundColor Yellow
}

Write-Host ""

# Étape 4: Nettoyage des fichiers temporaires
Write-Host "🧹 Nettoyage..." -ForegroundColor Yellow

$tempFiles = @("*.aux", "*.log", "*.toc", "*.out", "*.fls", "*.fdb_latexmk", "*.synctex.gz")
$cleanedFiles = 0

foreach ($pattern in $tempFiles) {
    $files = Get-ChildItem -Path . -Name $pattern -ErrorAction SilentlyContinue
    if ($files) {
        Remove-Item $pattern -Force -ErrorAction SilentlyContinue
        $cleanedFiles += $files.Count
        Write-Verbose-Custom "Supprimé : $pattern"
    }
}

if ($cleanedFiles -gt 0) {
    Write-Host "✅ $cleanedFiles fichier(s) temporaire(s) supprimé(s)" -ForegroundColor Green
} else {
    Write-Host "✅ Aucun fichier temporaire à nettoyer" -ForegroundColor Green
}

Write-Host ""

# Étape 5: Résumé final
Write-Host "📊 RÉSUMÉ DE LA GÉNÉRATION" -ForegroundColor Green
Write-Host "==========================" -ForegroundColor Cyan

$success = Test-Path "rapport-monitoring-simple.pdf"

if ($success) {
    Write-Host "📄 Rapport PDF : ✅ Généré avec succès" -ForegroundColor Green
    Write-Host "📁 Emplacement : $(Get-Location)\rapport-monitoring-simple.pdf" -ForegroundColor White
    
    # Statistiques du rapport
    $pdfFile = Get-Item "rapport-monitoring-simple.pdf"
    $estimatedPages = [math]::Round($pdfFile.Length / 50KB)  # Estimation basée sur la taille
    
    Write-Host ""
    Write-Host "📈 STATISTIQUES DU RAPPORT" -ForegroundColor Green
    Write-Host "==========================" -ForegroundColor Cyan
    Write-Host "📄 Pages estimées : ~$estimatedPages pages" -ForegroundColor White
    Write-Host "💾 Taille du fichier : $([math]::Round($pdfFile.Length / 1MB, 2)) MB" -ForegroundColor White
    Write-Host "📅 Date de génération : $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" -ForegroundColor White
    
    # Ouvrir le PDF si demandé
    if ($OpenPDF) {
        Write-Host ""
        Write-Host "📖 Ouverture du rapport..." -ForegroundColor Yellow
        try {
            Start-Process "rapport-monitoring-simple.pdf"
            Write-Host "✅ Rapport ouvert dans le lecteur PDF par défaut" -ForegroundColor Green
        } catch {
            Write-Host "⚠️  Impossible d'ouvrir automatiquement le PDF" -ForegroundColor Yellow
            Write-Host "Ouvrez manuellement : rapport-monitoring-simple.pdf" -ForegroundColor White
        }
    }
    
} else {
    Write-Host "📄 Rapport PDF : ❌ Échec de la génération" -ForegroundColor Red
    if (Test-Path "rapport-monitoring-simple.log") {
        Write-Host "📋 Consultez le fichier de log pour plus de détails : rapport-monitoring-simple.log" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "🎉 Génération terminée!" -ForegroundColor Green

# Instructions finales
Write-Host ""
Write-Host "📋 PROCHAINES ÉTAPES" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan

if ($success) {
    Write-Host "• Le rapport est prêt à être consulté ou partagé" -ForegroundColor White
    Write-Host "• Pour regénérer : .\generer_rapport_final.ps1" -ForegroundColor White
    Write-Host "• Pour ouvrir : start rapport-monitoring-simple.pdf" -ForegroundColor White
} else {
    Write-Host "• Vérifiez l'installation de LaTeX" -ForegroundColor White
    Write-Host "• Consultez les logs d'erreur" -ForegroundColor White
    Write-Host "• Réessayez après avoir corrigé les problèmes" -ForegroundColor White
}

Write-Host "• Documentation complète disponible dans README.md" -ForegroundColor White
Write-Host ""

# Afficher le contenu du rapport
if ($success) {
    Write-Host "📚 CONTENU DU RAPPORT" -ForegroundColor Green
    Write-Host "=====================" -ForegroundColor Cyan
    Write-Host "1. Introduction et contexte du projet" -ForegroundColor White
    Write-Host "2. Architecture détaillée du système" -ForegroundColor White
    Write-Host "3. Configuration Prometheus, Grafana, AlertManager" -ForegroundColor White
    Write-Host "4. Métriques et règles d'alertes" -ForegroundColor White
    Write-Host "5. Dashboards et visualisations" -ForegroundColor White
    Write-Host "6. Procédures de test et validation" -ForegroundColor White
    Write-Host "7. Maintenance et sauvegarde" -ForegroundColor White
    Write-Host "8. Conclusion et recommandations" -ForegroundColor White
    Write-Host ""
    Write-Host "Le rapport contient des diagrammes d'architecture, des tableaux" -ForegroundColor Gray
    Write-Host "de configuration, et une documentation technique complète." -ForegroundColor Gray
}
