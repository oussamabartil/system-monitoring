# 📊 Supervision des Systèmes avec Prometheus & Grafana

## 🎯 Description

Cette solution complète de monitoring utilise **Prometheus** et **Grafana** pour surveiller vos systèmes Windows avec Docker. Elle fournit une surveillance en temps réel des performances système, des conteneurs Docker, et permet la création d'alertes personnalisées.

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│    Grafana      │    │   Prometheus    │    │  AlertManager   │
│   (Port 3000)   │◄───┤   (Port 9090)   │◄───┤   (Port 9093)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                ┌───────────────┼───────────────┐
                │               │               │
        ┌───────▼──────┐ ┌──────▼──────┐ ┌─────▼──────┐
        │ Node Exporter│ │   cAdvisor  │ │Windows Exp.│
        │ (Port 9100)  │ │ (Port 8080) │ │(Port 9182) │
        └──────────────┘ └─────────────┘ └────────────┘
```

## 🚀 Démarrage Rapide

### Prérequis
- Windows 10/11 ou Windows Server
- Docker Desktop installé et démarré
- PowerShell 5.0 ou supérieur

### Installation

1. **Cloner ou télécharger ce projet**
```powershell
git clone <repository-url>
cd monitoring
```

2. **Démarrer la stack de monitoring**
```powershell
.\scripts\start-monitoring.ps1
```

3. **Accéder aux interfaces**
- **Grafana**: http://localhost:3000 (admin/admin123)
- **Prometheus**: http://localhost:9090
- **AlertManager**: http://localhost:9093

## 📋 Services Inclus

| Service | Port | Description |
|---------|------|-------------|
| **Grafana** | 3000 | Interface de visualisation et dashboards |
| **Prometheus** | 9090 | Collecte et stockage des métriques |
| **AlertManager** | 9093 | Gestion des alertes et notifications |
| **Node Exporter** | 9100 | Métriques système Linux/Unix |
| **cAdvisor** | 8080 | Métriques des conteneurs Docker |
| **Windows Exporter** | 9182 | Métriques spécifiques Windows |

## 📊 Dashboards Pré-configurés

### 🖥️ System Overview
- Utilisation CPU en temps réel
- Consommation mémoire
- Espace disque disponible
- Charge système

### 🐳 Docker Overview  
- Utilisation CPU des conteneurs
- Consommation mémoire des conteneurs
- Statistiques réseau
- État des conteneurs

## 🔔 Alertes Configurées

### Alertes Système
- **CPU élevé**: > 80% pendant 5 minutes
- **Mémoire élevée**: > 85% pendant 5 minutes  
- **Espace disque faible**: > 90% d'utilisation
- **Service indisponible**: Service down pendant 1 minute

### Alertes Docker
- **Conteneur arrêté**: Conteneur down pendant 1 minute
- **CPU conteneur élevé**: > 80% pendant 5 minutes
- **Mémoire conteneur élevée**: > 90% de la limite

## 🛠️ Scripts de Gestion

### Démarrage
```powershell
.\scripts\start-monitoring.ps1
```

### Arrêt
```powershell
.\scripts\stop-monitoring.ps1
```

### Sauvegarde
```powershell
.\scripts\backup-monitoring.ps1
```

## ⚙️ Configuration

### Modifier les seuils d'alertes
Éditez le fichier `prometheus/rules/alerts.yml` pour ajuster les seuils selon vos besoins.

### Ajouter des sources de données
Modifiez `prometheus/prometheus.yml` pour ajouter de nouvelles cibles de monitoring.

### Personnaliser les dashboards
- Accédez à Grafana (http://localhost:3000)
- Créez ou modifiez les dashboards existants
- Exportez vos dashboards personnalisés

### Configuration des notifications
Éditez `alertmanager/alertmanager.yml` pour configurer:
- Notifications email
- Intégrations Slack/Teams
- Webhooks personnalisés

## 📁 Structure du Projet

```
monitoring/
├── docker-compose.yml              # Orchestration des services
├── prometheus/
│   ├── prometheus.yml              # Configuration Prometheus
│   └── rules/
│       └── alerts.yml              # Règles d'alertes
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/            # Sources de données
│   │   └── dashboards/             # Configuration dashboards
│   └── dashboards/
│       ├── system/                 # Dashboards système
│       └── docker/                 # Dashboards Docker
├── alertmanager/
│   └── alertmanager.yml            # Configuration alertes
└── scripts/
    ├── start-monitoring.ps1        # Script de démarrage
    ├── stop-monitoring.ps1         # Script d'arrêt
    └── backup-monitoring.ps1       # Script de sauvegarde
```

## 🔧 Maintenance

### Mise à jour des images
```powershell
docker-compose pull
docker-compose up -d
```

### Nettoyage des données anciennes
```powershell
# Prometheus conserve 200h de données par défaut
# Modifiez --storage.tsdb.retention.time dans docker-compose.yml
```

### Surveillance des logs
```powershell
docker-compose logs -f [service-name]
```

## 🚨 Dépannage

### Les services ne démarrent pas
1. Vérifiez que Docker Desktop est démarré
2. Vérifiez les ports disponibles
3. Consultez les logs: `docker-compose logs`

### Grafana ne se connecte pas à Prometheus
1. Vérifiez que Prometheus est accessible: http://localhost:9090
2. Vérifiez la configuration dans Grafana > Configuration > Data Sources

### Pas de métriques Windows
1. Vérifiez que Windows Exporter fonctionne: http://localhost:9182
2. Redémarrez le conteneur: `docker-compose restart windows-exporter`

## 📈 Métriques Surveillées

### Système
- CPU (utilisation, charge)
- Mémoire (utilisée, disponible, cache)
- Disque (espace, I/O, latence)
- Réseau (trafic, erreurs, connexions)

### Docker
- Conteneurs (état, ressources)
- Images (taille, âge)
- Volumes (utilisation)
- Réseaux (trafic, connectivité)

## 🔐 Sécurité

### Recommandations
1. **Changez les mots de passe par défaut**
2. **Configurez HTTPS** pour la production
3. **Limitez l'accès réseau** aux ports de monitoring
4. **Activez l'authentification** sur tous les services
5. **Chiffrez les communications** entre services

### Configuration HTTPS (Production)
```yaml
# Ajoutez dans docker-compose.yml pour Grafana
environment:
  - GF_SERVER_PROTOCOL=https
  - GF_SERVER_CERT_FILE=/etc/ssl/certs/grafana.crt
  - GF_SERVER_CERT_KEY=/etc/ssl/private/grafana.key
```

## 📞 Support

Pour toute question ou problème:
1. Consultez les logs des conteneurs
2. Vérifiez la documentation officielle
3. Créez une issue sur le repository

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier LICENSE pour plus de détails.
