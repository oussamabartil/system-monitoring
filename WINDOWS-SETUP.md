# Configuration Monitoring pour Windows

Ce guide explique comment configurer le stack de monitoring Prometheus + Grafana sur Windows avec Docker Desktop.

## Problèmes résolus

Les erreurs que vous avez rencontrées étaient dues à des incompatibilités de plateforme :
- Les images Docker tentaient de s'exécuter en mode Linux/AMD64
- Node Exporter ne fonctionne que sur Linux
- Windows Exporter nécessite une installation native sur l'hôte Windows

## Modifications apportées

### 1. Docker Compose (`docker-compose.yml`)
- ✅ Suppression de la directive `version` obsolète
- ✅ Ajout de `platform: linux/amd64` pour forcer l'architecture
- ✅ Désactivation de `node-exporter` (Linux uniquement)
- ✅ Désactivation de `windows-exporter` en conteneur
- ✅ Mise à jour de cAdvisor avec version spécifique

### 2. Configuration Prometheus (`prometheus/prometheus.yml`)
- ✅ Désactivation du scraping de `node-exporter`
- ✅ Configuration préparée pour `windows-exporter` sur l'hôte
- ✅ Maintien de cAdvisor pour les métriques Docker

## Services disponibles après correction

| Service | Port | Status | Description |
|---------|------|--------|-------------|
| Prometheus | 9090 | ✅ Actif | Collecte et stockage des métriques |
| Grafana | 3000 | ✅ Actif | Visualisation des données |
| cAdvisor | 8081 | ✅ Actif | Métriques des conteneurs Docker |
| AlertManager | 9093 | ✅ Actif | Gestion des alertes |

## Installation de Windows Exporter (Optionnel)

Pour collecter les métriques système Windows :

### Option 1: Script automatique (Recommandé)
```powershell
# Exécuter en tant qu'administrateur
.\scripts\install-windows-exporter.ps1
```

### Option 2: Installation manuelle
1. Télécharger depuis [GitHub Releases](https://github.com/prometheus-community/windows_exporter/releases)
2. Installer comme service Windows
3. Décommenter la section dans `prometheus/prometheus.yml`

## Démarrage du monitoring

```bash
# Démarrer tous les services
docker-compose up -d

# Vérifier le statut
docker-compose ps

# Voir les logs
docker-compose logs -f
```

## Accès aux interfaces

- **Grafana**: http://localhost:3000 (admin/admin123)
- **Prometheus**: http://localhost:9090
- **cAdvisor**: http://localhost:8081
- **AlertManager**: http://localhost:9093

## Vérification du fonctionnement

1. **Prometheus**: Vérifiez que les targets sont UP dans Status > Targets
2. **Grafana**: Importez les dashboards depuis `grafana/dashboards/`
3. **cAdvisor**: Vérifiez les métriques Docker sur http://localhost:8081

## Dépannage

### Si les conteneurs ne démarrent pas
```bash
# Nettoyer et redémarrer
docker-compose down
docker-compose pull
docker-compose up -d
```

### Si Windows Exporter ne fonctionne pas
```powershell
# Vérifier le service
Get-Service -Name windows_exporter

# Tester la connectivité
Invoke-WebRequest -Uri "http://localhost:9182/metrics"
```

### Logs détaillés
```bash
# Voir les logs d'un service spécifique
docker-compose logs prometheus
docker-compose logs grafana
```

## Configuration du pare-feu Windows

Si Windows Exporter est installé, assurez-vous que le port 9182 est autorisé :

```powershell
# Autoriser le port dans le pare-feu
New-NetFirewallRule -DisplayName "Windows Exporter" -Direction Inbound -Port 9182 -Protocol TCP -Action Allow
```

## Prochaines étapes

1. ✅ Démarrer le monitoring avec `docker-compose up -d`
2. 🔄 Optionnel: Installer Windows Exporter pour les métriques système
3. 📊 Configurer les dashboards Grafana
4. 🚨 Personnaliser les alertes dans AlertManager

## Support

En cas de problème, vérifiez :
1. Docker Desktop est en mode Linux containers
2. Les ports ne sont pas utilisés par d'autres applications
3. Les volumes Docker ont les bonnes permissions
