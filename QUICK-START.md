# 🚀 Guide de Démarrage Rapide

## ⚡ Démarrage en 3 étapes

### 1. Vérifiez Docker
Assurez-vous que Docker Desktop est installé et démarré :
```cmd
docker --version
docker-compose --version
```

### 2. Démarrez la stack
Ouvrez une invite de commande (cmd) dans le répertoire du projet et exécutez :
```cmd
docker-compose up -d
```

### 3. Accédez aux interfaces
- **Grafana** : http://localhost:3000 (admin/admin123)
- **Prometheus** : http://localhost:9090
- **AlertManager** : http://localhost:9093

## 🔧 Commandes Utiles

### Démarrer les services
```cmd
docker-compose up -d
```

### Arrêter les services
```cmd
docker-compose down
```

### Voir les logs
```cmd
docker-compose logs -f
```

### Vérifier l'état
```cmd
docker-compose ps
```

### Redémarrer un service
```cmd
docker-compose restart grafana
```

## 📊 Premiers Pas dans Grafana

1. **Connexion** : http://localhost:3000 avec admin/admin123
2. **Changez le mot de passe** lors de la première connexion
3. **Explorez les dashboards** : Menu → Dashboards → Browse
4. **Vérifiez les données** : Menu → Explore → Sélectionnez Prometheus

## 🔍 Vérification de Santé

### Vérifiez que tous les services répondent :
```cmd
curl http://localhost:3000/api/health
curl http://localhost:9090/-/healthy
curl http://localhost:9093/-/healthy
curl http://localhost:9100/metrics
curl http://localhost:8080/healthz
curl http://localhost:9182/metrics
```

## 🚨 Dépannage Rapide

### Les conteneurs ne démarrent pas
```cmd
# Vérifiez les logs
docker-compose logs

# Vérifiez les ports
netstat -an | findstr "3000\|9090\|9093"

# Redémarrez Docker Desktop
```

### Grafana ne charge pas
```cmd
# Redémarrez Grafana
docker-compose restart grafana

# Vérifiez les logs
docker-compose logs grafana
```

### Pas de métriques dans Prometheus
```cmd
# Vérifiez les targets
# Allez sur http://localhost:9090/targets

# Redémarrez les exporters
docker-compose restart node-exporter windows-exporter cadvisor
```

## 📈 Métriques de Base à Surveiller

### Dans Prometheus (http://localhost:9090)
Testez ces requêtes :
```promql
# CPU Usage
100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory Usage
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100

# Disk Usage
(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100
```

## 🎯 Configuration Initiale Recommandée

### 1. Changez les mots de passe
- Grafana : admin/admin123 → votre mot de passe
- Modifiez `.env` pour personnaliser

### 2. Configurez les alertes
- Éditez `alertmanager/alertmanager.yml`
- Ajoutez vos emails/Slack webhooks

### 3. Personnalisez les dashboards
- Importez des dashboards depuis grafana.com
- Créez vos propres visualisations

## 📞 Besoin d'Aide ?

1. **Consultez les logs** : `docker-compose logs [service]`
2. **Lisez le README.md** pour plus de détails
3. **Consultez TECHNICAL-GUIDE.md** pour la configuration avancée

## 🛑 Arrêt et Nettoyage

### Arrêt simple
```cmd
docker-compose down
```

### Arrêt avec suppression des données
```cmd
docker-compose down -v
```

### Nettoyage complet
```cmd
docker-compose down -v --rmi all
docker system prune -f
```
