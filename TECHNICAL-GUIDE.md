# 🔧 Guide Technique - Monitoring Stack

## 📊 Architecture Détaillée

### Flux de Données
```
[Système Windows] → [Exporters] → [Prometheus] → [Grafana]
                                      ↓
                                [AlertManager] → [Notifications]
```

### Composants et Responsabilités

| Composant | Rôle | Port | Données Collectées |
|-----------|------|------|-------------------|
| **Prometheus** | Collecte, stockage, requêtes | 9090 | Métriques time-series |
| **Grafana** | Visualisation, dashboards | 3000 | Interface utilisateur |
| **AlertManager** | Gestion alertes, notifications | 9093 | Règles d'alertes |
| **Node Exporter** | Métriques système Unix/Linux | 9100 | CPU, RAM, Disque, Réseau |
| **Windows Exporter** | Métriques système Windows | 9182 | Performances Windows |
| **cAdvisor** | Métriques conteneurs | 8080 | Docker, ressources |

## 🔍 Métriques Clés

### Métriques Système (Node/Windows Exporter)
```promql
# CPU
node_cpu_seconds_total
windows_cpu_time_total

# Mémoire  
node_memory_MemTotal_bytes
windows_memory_available_bytes

# Disque
node_filesystem_size_bytes
windows_logical_disk_size_bytes

# Réseau
node_network_receive_bytes_total
windows_net_bytes_received_total
```

### Métriques Docker (cAdvisor)
```promql
# CPU conteneurs
container_cpu_usage_seconds_total

# Mémoire conteneurs
container_memory_usage_bytes
container_memory_limit_bytes

# Réseau conteneurs
container_network_receive_bytes_total
container_network_transmit_bytes_total

# État conteneurs
container_last_seen
```

## 📈 Requêtes PromQL Utiles

### Performance Système
```promql
# CPU Usage (%)
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory Usage (%)
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100

# Disk Usage (%)
(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100

# Network Traffic (bytes/sec)
rate(node_network_receive_bytes_total[5m]) + rate(node_network_transmit_bytes_total[5m])
```

### Performance Docker
```promql
# CPU par conteneur (%)
rate(container_cpu_usage_seconds_total[5m]) * 100

# Mémoire par conteneur (%)
container_memory_usage_bytes / container_spec_memory_limit_bytes * 100

# Conteneurs actifs
count(container_last_seen)

# Top 5 conteneurs CPU
topk(5, rate(container_cpu_usage_seconds_total[5m]))
```

## 🚨 Configuration Avancée des Alertes

### Règles d'Alertes Personnalisées
```yaml
# Exemple: Alerte disque spécifique
- alert: DatabaseDiskFull
  expr: (node_filesystem_size_bytes{mountpoint="/var/lib/mysql"} - node_filesystem_free_bytes{mountpoint="/var/lib/mysql"}) / node_filesystem_size_bytes{mountpoint="/var/lib/mysql"} * 100 > 85
  for: 2m
  labels:
    severity: critical
    service: database
  annotations:
    summary: "Base de données - Espace disque critique"
    description: "Le disque de la base de données est plein à {{ $value }}%"
```

### Groupement d'Alertes
```yaml
# AlertManager - Groupement par service
route:
  group_by: ['service', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 12h
  routes:
    - match:
        service: database
      receiver: 'database-team'
    - match:
        service: web
      receiver: 'web-team'
```

## 🔧 Optimisation des Performances

### Prometheus
```yaml
# Configuration optimisée
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  
# Rétention optimisée
command:
  - '--storage.tsdb.retention.time=30d'
  - '--storage.tsdb.retention.size=10GB'
  - '--storage.tsdb.wal-compression'
```

### Grafana
```yaml
# Variables d'environnement optimisées
environment:
  - GF_DATABASE_WAL=true
  - GF_DATABASE_CACHE_MODE=shared
  - GF_RENDERING_SERVER_URL=http://renderer:8081/render
  - GF_RENDERING_CALLBACK_URL=http://grafana:3000/
```

## 🔐 Sécurisation

### HTTPS avec Certificats
```yaml
# docker-compose.yml - Grafana HTTPS
grafana:
  environment:
    - GF_SERVER_PROTOCOL=https
    - GF_SERVER_CERT_FILE=/etc/ssl/certs/grafana.crt
    - GF_SERVER_CERT_KEY=/etc/ssl/private/grafana.key
  volumes:
    - ./ssl:/etc/ssl:ro
```

### Authentification LDAP
```ini
# grafana.ini
[auth.ldap]
enabled = true
config_file = /etc/grafana/ldap.toml
allow_sign_up = false

[auth]
disable_login_form = false
disable_signout_menu = false
```

### Reverse Proxy (Nginx)
```nginx
server {
    listen 443 ssl;
    server_name monitoring.company.com;
    
    ssl_certificate /etc/ssl/certs/monitoring.crt;
    ssl_certificate_key /etc/ssl/private/monitoring.key;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /prometheus/ {
        proxy_pass http://localhost:9090/;
        auth_basic "Prometheus";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }
}
```

## 📊 Dashboards Avancés

### Variables de Template
```json
{
  "templating": {
    "list": [
      {
        "name": "instance",
        "type": "query",
        "query": "label_values(up, instance)",
        "refresh": 1
      },
      {
        "name": "container",
        "type": "query", 
        "query": "label_values(container_last_seen, name)",
        "refresh": 2
      }
    ]
  }
}
```

### Panels Conditionnels
```json
{
  "targets": [
    {
      "expr": "up{instance=~\"$instance\"}",
      "legendFormat": "{{instance}}"
    }
  ],
  "thresholds": [
    {
      "value": 0.8,
      "colorMode": "critical",
      "op": "gt"
    }
  ]
}
```

## 🔄 Sauvegarde et Restauration

### Script de Sauvegarde Automatisée
```powershell
# Tâche planifiée Windows
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\monitoring\scripts\backup-monitoring.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At "02:00"
Register-ScheduledTask -TaskName "MonitoringBackup" -Action $action -Trigger $trigger
```

### Restauration depuis Sauvegarde
```powershell
# Restauration des données
docker-compose down
tar -xzf prometheus-data.tar.gz -C ./data/prometheus/
tar -xzf grafana-data.tar.gz -C ./data/grafana/
docker-compose up -d
```

## 🐛 Dépannage Avancé

### Logs et Diagnostics
```powershell
# Logs détaillés par service
docker-compose logs -f prometheus
docker-compose logs -f grafana
docker-compose logs -f alertmanager

# Métriques internes Prometheus
curl http://localhost:9090/metrics | grep prometheus_

# État des targets
curl http://localhost:9090/api/v1/targets
```

### Problèmes Courants

#### Prometheus ne collecte pas les métriques
```bash
# Vérifier la configuration
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml

# Vérifier les targets
curl http://localhost:9090/api/v1/targets
```

#### Grafana ne se connecte pas à Prometheus
```bash
# Test de connectivité
docker exec grafana curl http://prometheus:9090/api/v1/label/__name__/values
```

#### Alertes non envoyées
```bash
# Vérifier AlertManager
curl http://localhost:9093/api/v1/status
curl http://localhost:9093/api/v1/alerts
```

## 📈 Monitoring de la Stack elle-même

### Métriques de Santé
```promql
# Prometheus
prometheus_tsdb_head_samples_appended_total
prometheus_config_last_reload_successful

# Grafana
grafana_stat_totals_dashboard
grafana_stat_total_users

# AlertManager
alertmanager_alerts_received_total
alertmanager_notifications_total
```

### Auto-Monitoring
```yaml
# Alerte si Prometheus down
- alert: PrometheusDown
  expr: up{job="prometheus"} == 0
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "Prometheus est indisponible"
```
