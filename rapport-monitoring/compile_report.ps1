# Script PowerShell pour compiler le rapport LaTeX
# Génère automatiquement les graphiques et compile le PDF

param(
    [switch]$GenerateGraphs = $true,
    [switch]$OpenPDF = $true
)

Write-Host "📄 COMPILATION DU RAPPORT DE MONITORING" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# Vérifier que nous sommes dans le bon répertoire
if (-not (Test-Path "rapport-monitoring.tex")) {
    Write-Host "❌ Fichier rapport-monitoring.tex non trouvé!" -ForegroundColor Red
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

# Vérifier les dépendances
Write-Host "🔍 Vérification des dépendances..." -ForegroundColor Yellow

$dependencies = @{
    "python" = "Python (pour générer les graphiques)"
    "pdflatex" = "LaTeX (pour compiler le PDF)"
}

$missingDeps = @()
foreach ($dep in $dependencies.Keys) {
    if (Test-Command $dep) {
        Write-Host "✅ $($dependencies[$dep]) : Disponible" -ForegroundColor Green
    } else {
        Write-Host "❌ $($dependencies[$dep]) : Non trouvé" -ForegroundColor Red
        $missingDeps += $dep
    }
}

if ($missingDeps.Count -gt 0) {
    Write-Host ""
    Write-Host "⚠️  Dépendances manquantes détectées!" -ForegroundColor Yellow
    Write-Host "Pour installer les dépendances manquantes :" -ForegroundColor White
    
    if ($missingDeps -contains "python") {
        Write-Host "- Python : Téléchargez depuis https://python.org" -ForegroundColor White
        Write-Host "  Puis installez les packages : pip install matplotlib seaborn pandas numpy" -ForegroundColor White
    }
    
    if ($missingDeps -contains "pdflatex") {
        Write-Host "- LaTeX : Installez MiKTeX depuis https://miktex.org" -ForegroundColor White
        Write-Host "  Ou TeX Live depuis https://tug.org/texlive/" -ForegroundColor White
    }
    
    $continue = Read-Host "`nVoulez-vous continuer malgré les dépendances manquantes? (y/N)"
    if ($continue -ne 'y' -and $continue -ne 'Y') {
        exit 1
    }
}

Write-Host ""

# Étape 1: Générer les graphiques
if ($GenerateGraphs) {
    Write-Host "🎨 Génération des graphiques..." -ForegroundColor Yellow
    
    if (Test-Command "python") {
        try {
            # Vérifier si les packages Python sont installés
            $pythonCheck = python -c "import matplotlib, seaborn, pandas, numpy; print('OK')" 2>$null
            if ($pythonCheck -eq "OK") {
                python generate_graphs.py
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✅ Graphiques générés avec succès" -ForegroundColor Green
                } else {
                    Write-Host "❌ Erreur lors de la génération des graphiques" -ForegroundColor Red
                }
            } else {
                Write-Host "❌ Packages Python manquants. Installez avec :" -ForegroundColor Red
                Write-Host "pip install matplotlib seaborn pandas numpy" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "❌ Erreur lors de l'exécution du script Python" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    } else {
        Write-Host "⚠️  Python non disponible, génération des graphiques ignorée" -ForegroundColor Yellow
    }
} else {
    Write-Host "⏭️  Génération des graphiques ignorée (paramètre -GenerateGraphs:$false)" -ForegroundColor Yellow
}

Write-Host ""

# Étape 2: Compiler le LaTeX
Write-Host "📝 Compilation du document LaTeX..." -ForegroundColor Yellow

if (Test-Command "pdflatex") {
    try {
        # Première compilation
        Write-Host "   Première passe..." -ForegroundColor Gray
        pdflatex -interaction=nonstopmode rapport-monitoring.tex | Out-Null
        
        # Deuxième compilation pour les références croisées
        Write-Host "   Deuxième passe (références croisées)..." -ForegroundColor Gray
        pdflatex -interaction=nonstopmode rapport-monitoring.tex | Out-Null
        
        # Troisième compilation pour la table des matières
        Write-Host "   Troisième passe (table des matières)..." -ForegroundColor Gray
        pdflatex -interaction=nonstopmode rapport-monitoring.tex | Out-Null
        
        if (Test-Path "rapport-monitoring.pdf") {
            Write-Host "✅ PDF généré avec succès : rapport-monitoring.pdf" -ForegroundColor Green
            
            # Obtenir la taille du fichier
            $fileSize = (Get-Item "rapport-monitoring.pdf").Length
            $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
            Write-Host "📄 Taille du fichier : $fileSizeMB MB" -ForegroundColor White
            
        } else {
            Write-Host "❌ Erreur : Le fichier PDF n'a pas été créé" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "❌ Erreur lors de la compilation LaTeX" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
} else {
    Write-Host "❌ pdflatex non disponible, compilation impossible" -ForegroundColor Red
    Write-Host "Installez MiKTeX ou TeX Live pour compiler le document" -ForegroundColor Yellow
}

Write-Host ""

# Étape 3: Nettoyage des fichiers temporaires
Write-Host "🧹 Nettoyage des fichiers temporaires..." -ForegroundColor Yellow

$tempFiles = @("*.aux", "*.log", "*.toc", "*.lof", "*.lot", "*.out", "*.fls", "*.fdb_latexmk", "*.synctex.gz")
foreach ($pattern in $tempFiles) {
    $files = Get-ChildItem -Path . -Name $pattern -ErrorAction SilentlyContinue
    if ($files) {
        Remove-Item $pattern -Force
        Write-Host "   Supprimé : $pattern" -ForegroundColor Gray
    }
}

Write-Host "✅ Nettoyage terminé" -ForegroundColor Green
Write-Host ""

# Étape 4: Résumé et ouverture
Write-Host "📊 RÉSUMÉ DE LA COMPILATION" -ForegroundColor Green
Write-Host "===========================" -ForegroundColor Cyan

if (Test-Path "images") {
    $imageCount = (Get-ChildItem -Path "images" -Filter "*.png").Count
    Write-Host "🎨 Graphiques générés : $imageCount fichiers" -ForegroundColor White
}

if (Test-Path "rapport-monitoring.pdf") {
    Write-Host "📄 Rapport PDF : ✅ Généré avec succès" -ForegroundColor Green
    
    # Ouvrir le PDF
    if ($OpenPDF) {
        Write-Host ""
        Write-Host "📖 Ouverture du rapport..." -ForegroundColor Yellow
        try {
            Start-Process "rapport-monitoring.pdf"
            Write-Host "✅ Rapport ouvert dans le lecteur PDF par défaut" -ForegroundColor Green
        } catch {
            Write-Host "⚠️  Impossible d'ouvrir automatiquement le PDF" -ForegroundColor Yellow
            Write-Host "Ouvrez manuellement le fichier : rapport-monitoring.pdf" -ForegroundColor White
        }
    }
} else {
    Write-Host "📄 Rapport PDF : ❌ Échec de la génération" -ForegroundColor Red
}

Write-Host ""
Write-Host "🎉 Compilation terminée!" -ForegroundColor Green

# Afficher les instructions finales
Write-Host ""
Write-Host "📋 INSTRUCTIONS FINALES" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan
Write-Host "• Le rapport est disponible dans : rapport-monitoring.pdf" -ForegroundColor White
Write-Host "• Les graphiques sont dans le dossier : images/" -ForegroundColor White
Write-Host "• Pour recompiler : .\compile_report.ps1" -ForegroundColor White
Write-Host "• Pour regénérer seulement les graphiques : .\compile_report.ps1 -GenerateGraphs -OpenPDF:$false" -ForegroundColor White
Write-Host ""

# Statistiques finales
if (Test-Path "rapport-monitoring.pdf") {
    Write-Host "📈 STATISTIQUES DU RAPPORT" -ForegroundColor Green
    Write-Host "==========================" -ForegroundColor Cyan
    
    # Compter les pages (approximation basée sur la taille du fichier)
    $fileSize = (Get-Item "rapport-monitoring.pdf").Length
    $estimatedPages = [math]::Round($fileSize / 50KB)  # Approximation
    Write-Host "📄 Pages estimées : ~$estimatedPages pages" -ForegroundColor White
    Write-Host "💾 Taille du fichier : $([math]::Round($fileSize / 1MB, 2)) MB" -ForegroundColor White
    Write-Host "📅 Date de génération : $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" -ForegroundColor White
}
