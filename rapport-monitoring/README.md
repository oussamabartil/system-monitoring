# 📄 Rapport Technique - Système de Monitoring

Ce dossier contient un rapport technique complet du système de monitoring Prometheus, Grafana et AlertManager.

## 📁 Structure du Dossier

```
rapport-monitoring/
├── rapport-monitoring.tex      # Document LaTeX principal
├── generate_graphs.py          # Script Python pour générer les graphiques
├── compile_report.ps1          # Script PowerShell de compilation
├── README.md                   # Ce fichier
├── images/                     # Dossier des graphiques générés
│   ├── cpu_usage_24h.png
│   ├── memory_usage.png
│   ├── disk_usage.png
│   ├── network_traffic.png
│   ├── container_metrics.png
│   ├── alerts_timeline.png
│   └── system_overview.png
└── rapport-monitoring.pdf     # Rapport final (généré)
```

## 🚀 Génération du Rapport

### Méthode Automatique (Recommandée)

```powershell
# Compilation complète avec génération des graphiques
.\compile_report.ps1

# Compilation sans regénérer les graphiques
.\compile_report.ps1 -GenerateGraphs:$false

# Compilation sans ouvrir le PDF automatiquement
.\compile_report.ps1 -OpenPDF:$false
```

### Méthode Manuelle

1. **Générer les graphiques** :
   ```bash
   python generate_graphs.py
   ```

2. **Compiler le LaTeX** :
   ```bash
   pdflatex rapport-monitoring.tex
   pdflatex rapport-monitoring.tex  # Deuxième passe pour les références
   pdflatex rapport-monitoring.tex  # Troisième passe pour la table des matières
   ```

## 📋 Prérequis

### Logiciels Requis

1. **Python 3.x** avec les packages suivants :
   ```bash
   pip install matplotlib seaborn pandas numpy
   ```

2. **LaTeX Distribution** :
   - **Windows** : [MiKTeX](https://miktex.org/) ou [TeX Live](https://tug.org/texlive/)
   - **Linux** : `sudo apt-get install texlive-full` (Ubuntu/Debian)
   - **macOS** : [MacTeX](https://tug.org/mactex/)

### Packages LaTeX Utilisés

Le document utilise les packages LaTeX suivants (installés automatiquement avec MiKTeX) :
- `babel` (français)
- `graphicx` (images)
- `tikz` et `pgfplots` (diagrammes)
- `listings` (code source)
- `hyperref` (liens)
- `booktabs` (tableaux)
- `geometry` (mise en page)

## 📊 Contenu du Rapport

### Chapitres Inclus

1. **Introduction**
   - Objectif du rapport
   - Contexte du projet
   - Technologies utilisées

2. **Architecture du Système**
   - Vue d'ensemble
   - Flux de données
   - Diagrammes d'architecture

3. **Configuration Détaillée**
   - Configuration Prometheus
   - Configuration AlertManager
   - Configuration Grafana

4. **Métriques et Alertes**
   - Métriques système (CPU, mémoire, disque, réseau)
   - Règles d'alertes
   - Seuils et notifications

5. **Dashboards Grafana**
   - Configuration des sources de données
   - Dashboards disponibles
   - Visualisations

6. **Tests et Validation**
   - Tests automatisés
   - Procédures de test
   - Scripts de validation

7. **Maintenance et Sauvegarde**
   - Procédures de sauvegarde
   - Maintenance préventive
   - Planification des tâches

8. **Dépannage**
   - Problèmes courants
   - Solutions
   - Logs et diagnostics

9. **Conclusion**
   - Résumé du système
   - Performances
   - Évolutions futures

### Graphiques Générés

Le rapport inclut plusieurs graphiques automatiquement générés :

- **Utilisation CPU sur 24h** : Courbe temporelle avec seuils d'alerte
- **Utilisation Mémoire** : Graphiques en valeurs absolues et pourcentages
- **Utilisation Disque** : Barres et camembert par partition
- **Trafic Réseau** : Débit en temps réel et volume cumulé
- **Métriques Conteneurs** : CPU et mémoire par conteneur Docker
- **Timeline des Alertes** : Historique des alertes sur 7 jours
- **Dashboard Overview** : Vue d'ensemble du système avec gauges

## 🎨 Personnalisation

### Modifier les Graphiques

Éditez le fichier `generate_graphs.py` pour :
- Changer les données simulées
- Modifier les couleurs et styles
- Ajouter de nouveaux types de graphiques
- Ajuster les seuils d'alerte

### Modifier le Contenu

Éditez le fichier `rapport-monitoring.tex` pour :
- Ajouter du contenu
- Modifier la mise en page
- Changer les couleurs du thème
- Ajouter des sections

### Thème et Couleurs

Le rapport utilise un thème personnalisé avec :
- **Couleur primaire** : Bleu (#0066CC)
- **Couleur secondaire** : Bleu clair (#3399FF)
- **Couleur de fond** : Gris clair (#F5F5F5)

## 🔧 Dépannage

### Erreurs Courantes

#### "pdflatex command not found"
```bash
# Windows : Installer MiKTeX
# Linux : sudo apt-get install texlive-latex-base texlive-latex-extra
# macOS : Installer MacTeX
```

#### "Python module not found"
```bash
pip install matplotlib seaborn pandas numpy
```

#### "Package tikz not found"
```bash
# MiKTeX : Les packages sont installés automatiquement
# TeX Live : sudo apt-get install texlive-pictures
```

#### Erreurs de compilation LaTeX
- Vérifiez que tous les fichiers images existent dans le dossier `images/`
- Assurez-vous que les caractères spéciaux sont correctement encodés
- Compilez plusieurs fois pour résoudre les références croisées

### Logs de Débogage

Les logs de compilation LaTeX sont disponibles dans :
- `rapport-monitoring.log` : Log détaillé de la compilation
- Console PowerShell : Messages d'erreur du script

## 📈 Métriques du Rapport

Le rapport final contient approximativement :
- **40-50 pages** de contenu technique
- **15+ graphiques** et diagrammes
- **10+ tableaux** de configuration
- **Code source** avec coloration syntaxique
- **Table des matières** automatique
- **Index des figures** et tableaux

## 🔄 Mise à Jour

Pour mettre à jour le rapport avec de nouvelles données :

1. Modifiez les scripts de génération de graphiques
2. Mettez à jour le contenu LaTeX si nécessaire
3. Recompilez avec `.\compile_report.ps1`

## 📞 Support

En cas de problème :
1. Vérifiez les prérequis et dépendances
2. Consultez les logs d'erreur
3. Vérifiez la documentation LaTeX pour les packages utilisés
4. Testez la compilation manuelle étape par étape

## 📄 Licence

Ce rapport et ses scripts sont fournis à des fins de documentation technique du système de monitoring.

---

**Auteur** : Oussama Bartil  
**Date** : Janvier 2025  
**Version** : 1.0
