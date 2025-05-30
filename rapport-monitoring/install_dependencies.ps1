# Script d'installation des dépendances pour la génération du rapport
# Installe automatiquement Python, LaTeX et les packages nécessaires

param(
    [switch]$SkipPython = $false,
    [switch]$SkipLatex = $false,
    [switch]$Force = $false
)

Write-Host "🔧 INSTALLATION DES DÉPENDANCES" -ForegroundColor Green
Write-Host "===============================" -ForegroundColor Cyan
Write-Host ""

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

# Fonction pour télécharger un fichier
function Download-File {
    param(
        [string]$Url,
        [string]$OutputPath
    )
    try {
        Write-Host "📥 Téléchargement depuis $Url..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
        return $true
    } catch {
        Write-Host "❌ Erreur de téléchargement : $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Vérification des privilèges administrateur
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host "⚠️  Ce script nécessite des privilèges administrateur pour certaines installations" -ForegroundColor Yellow
    Write-Host "Relancez PowerShell en tant qu'administrateur pour une installation complète" -ForegroundColor White
    Write-Host ""
}

# 1. Installation de Python
if (-not $SkipPython) {
    Write-Host "🐍 VÉRIFICATION DE PYTHON" -ForegroundColor Blue
    Write-Host "=========================" -ForegroundColor Cyan
    
    if (Test-Command "python") {
        $pythonVersion = python --version 2>&1
        Write-Host "✅ Python déjà installé : $pythonVersion" -ForegroundColor Green
        
        # Vérifier les packages Python
        Write-Host "📦 Vérification des packages Python..." -ForegroundColor Yellow
        
        $requiredPackages = @("matplotlib", "seaborn", "pandas", "numpy")
        $missingPackages = @()
        
        foreach ($package in $requiredPackages) {
            $checkResult = python -c "import $package; print('OK')" 2>$null
            if ($checkResult -eq "OK") {
                Write-Host "✅ $package : Installé" -ForegroundColor Green
            } else {
                Write-Host "❌ $package : Manquant" -ForegroundColor Red
                $missingPackages += $package
            }
        }
        
        if ($missingPackages.Count -gt 0) {
            Write-Host ""
            Write-Host "📦 Installation des packages Python manquants..." -ForegroundColor Yellow
            
            # Mettre à jour pip
            Write-Host "   Mise à jour de pip..." -ForegroundColor Gray
            python -m pip install --upgrade pip | Out-Null
            
            # Installer les packages manquants
            foreach ($package in $missingPackages) {
                Write-Host "   Installation de $package..." -ForegroundColor Gray
                python -m pip install $package
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✅ $package installé avec succès" -ForegroundColor Green
                } else {
                    Write-Host "❌ Erreur lors de l'installation de $package" -ForegroundColor Red
                }
            }
        }
        
    } else {
        Write-Host "❌ Python n'est pas installé" -ForegroundColor Red
        
        if ($Force -or (Read-Host "Voulez-vous installer Python automatiquement? (y/N)") -eq 'y') {
            Write-Host "📥 Téléchargement de Python..." -ForegroundColor Yellow
            
            # Détecter l'architecture
            $arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "win32" }
            $pythonUrl = "https://www.python.org/ftp/python/3.11.7/python-3.11.7-$arch.exe"
            $pythonInstaller = "$env:TEMP\python-installer.exe"
            
            if (Download-File -Url $pythonUrl -OutputPath $pythonInstaller) {
                Write-Host "🔧 Installation de Python..." -ForegroundColor Yellow
                Write-Host "   (Cette opération peut prendre quelques minutes)" -ForegroundColor Gray
                
                # Installation silencieuse avec ajout au PATH
                $installArgs = "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0"
                Start-Process -FilePath $pythonInstaller -ArgumentList $installArgs -Wait
                
                # Nettoyer le fichier temporaire
                Remove-Item $pythonInstaller -Force -ErrorAction SilentlyContinue
                
                # Recharger les variables d'environnement
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
                
                # Vérifier l'installation
                if (Test-Command "python") {
                    Write-Host "✅ Python installé avec succès" -ForegroundColor Green
                    
                    # Installer les packages requis
                    Write-Host "📦 Installation des packages Python..." -ForegroundColor Yellow
                    python -m pip install --upgrade pip
                    python -m pip install matplotlib seaborn pandas numpy
                    
                } else {
                    Write-Host "❌ Erreur lors de l'installation de Python" -ForegroundColor Red
                    Write-Host "Installez Python manuellement depuis https://python.org" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "⏭️  Installation de Python ignorée" -ForegroundColor Yellow
            Write-Host "Téléchargez Python depuis : https://python.org" -ForegroundColor White
        }
    }
    
    Write-Host ""
}

# 2. Installation de LaTeX
if (-not $SkipLatex) {
    Write-Host "📝 VÉRIFICATION DE LATEX" -ForegroundColor Blue
    Write-Host "========================" -ForegroundColor Cyan
    
    if (Test-Command "pdflatex") {
        $latexVersion = pdflatex --version 2>&1 | Select-Object -First 1
        Write-Host "✅ LaTeX déjà installé : $latexVersion" -ForegroundColor Green
        
        # Vérifier les packages LaTeX essentiels
        Write-Host "📦 Vérification des packages LaTeX..." -ForegroundColor Yellow
        
        # Créer un fichier de test minimal
        $testLatex = @"
\documentclass{article}
\usepackage[utf8]{inputenc}
\usepackage[french]{babel}
\usepackage{graphicx}
\usepackage{tikz}
\usepackage{booktabs}
\usepackage{hyperref}
\begin{document}
Test
\end{document}
"@
        
        $testFile = "$env:TEMP\latex-test.tex"
        $testLatex | Out-File -FilePath $testFile -Encoding UTF8
        
        # Tester la compilation
        Push-Location $env:TEMP
        $testResult = pdflatex -interaction=nonstopmode latex-test.tex 2>&1
        Pop-Location
        
        if (Test-Path "$env:TEMP\latex-test.pdf") {
            Write-Host "✅ Packages LaTeX essentiels : Disponibles" -ForegroundColor Green
            Remove-Item "$env:TEMP\latex-test.*" -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "⚠️  Certains packages LaTeX peuvent être manquants" -ForegroundColor Yellow
            Write-Host "MiKTeX installera automatiquement les packages manquants lors de la première utilisation" -ForegroundColor White
        }
        
    } else {
        Write-Host "❌ LaTeX n'est pas installé" -ForegroundColor Red
        
        if ($Force -or (Read-Host "Voulez-vous installer MiKTeX automatiquement? (y/N)") -eq 'y') {
            Write-Host "📥 Téléchargement de MiKTeX..." -ForegroundColor Yellow
            
            # URL de MiKTeX (version basique)
            $miktexUrl = "https://miktex.org/download/ctan/systems/win32/miktex/setup/windows-x64/basic-miktex-23.10-x64.exe"
            $miktexInstaller = "$env:TEMP\miktex-installer.exe"
            
            if (Download-File -Url $miktexUrl -OutputPath $miktexInstaller) {
                Write-Host "🔧 Installation de MiKTeX..." -ForegroundColor Yellow
                Write-Host "   (Cette opération peut prendre 10-15 minutes)" -ForegroundColor Gray
                Write-Host "   Une interface d'installation peut s'ouvrir" -ForegroundColor Gray
                
                # Lancer l'installateur (installation interactive)
                Start-Process -FilePath $miktexInstaller -Wait
                
                # Nettoyer le fichier temporaire
                Remove-Item $miktexInstaller -Force -ErrorAction SilentlyContinue
                
                # Recharger les variables d'environnement
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
                
                # Vérifier l'installation
                if (Test-Command "pdflatex") {
                    Write-Host "✅ MiKTeX installé avec succès" -ForegroundColor Green
                    
                    # Configurer MiKTeX pour installer automatiquement les packages manquants
                    Write-Host "⚙️  Configuration de MiKTeX..." -ForegroundColor Yellow
                    try {
                        initexmf --set-config-value=[MPM]AutoInstall=1 2>$null
                        Write-Host "✅ Installation automatique des packages activée" -ForegroundColor Green
                    } catch {
                        Write-Host "⚠️  Configuration automatique échouée, mais MiKTeX est installé" -ForegroundColor Yellow
                    }
                    
                } else {
                    Write-Host "❌ Erreur lors de l'installation de MiKTeX" -ForegroundColor Red
                    Write-Host "Installez MiKTeX manuellement depuis https://miktex.org" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "⏭️  Installation de LaTeX ignorée" -ForegroundColor Yellow
            Write-Host "Téléchargez MiKTeX depuis : https://miktex.org" -ForegroundColor White
            Write-Host "Ou TeX Live depuis : https://tug.org/texlive/" -ForegroundColor White
        }
    }
    
    Write-Host ""
}

# 3. Résumé final
Write-Host "📊 RÉSUMÉ DE L'INSTALLATION" -ForegroundColor Green
Write-Host "===========================" -ForegroundColor Cyan

$pythonOK = Test-Command "python"
$latexOK = Test-Command "pdflatex"

Write-Host "🐍 Python : $(if ($pythonOK) { '✅ Disponible' } else { '❌ Non disponible' })" -ForegroundColor $(if ($pythonOK) { 'Green' } else { 'Red' })
Write-Host "📝 LaTeX  : $(if ($latexOK) { '✅ Disponible' } else { '❌ Non disponible' })" -ForegroundColor $(if ($latexOK) { 'Green' } else { 'Red' })

if ($pythonOK -and $latexOK) {
    Write-Host ""
    Write-Host "🎉 Toutes les dépendances sont installées!" -ForegroundColor Green
    Write-Host "Vous pouvez maintenant générer le rapport avec :" -ForegroundColor White
    Write-Host ".\compile_report.ps1" -ForegroundColor Yellow
} elseif ($pythonOK -or $latexOK) {
    Write-Host ""
    Write-Host "⚠️  Installation partielle" -ForegroundColor Yellow
    if (-not $pythonOK) {
        Write-Host "• Installez Python depuis : https://python.org" -ForegroundColor White
        Write-Host "• Puis exécutez : pip install matplotlib seaborn pandas numpy" -ForegroundColor White
    }
    if (-not $latexOK) {
        Write-Host "• Installez MiKTeX depuis : https://miktex.org" -ForegroundColor White
    }
} else {
    Write-Host ""
    Write-Host "❌ Aucune dépendance installée" -ForegroundColor Red
    Write-Host "Installez manuellement :" -ForegroundColor White
    Write-Host "• Python : https://python.org" -ForegroundColor White
    Write-Host "• MiKTeX : https://miktex.org" -ForegroundColor White
}

Write-Host ""
Write-Host "📋 PROCHAINES ÉTAPES" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan
Write-Host "1. Vérifiez que toutes les dépendances sont installées" -ForegroundColor White
Write-Host "2. Redémarrez PowerShell pour recharger les variables d'environnement" -ForegroundColor White
Write-Host "3. Exécutez .\compile_report.ps1 pour générer le rapport" -ForegroundColor White
Write-Host "4. Le rapport PDF sera généré automatiquement" -ForegroundColor White
