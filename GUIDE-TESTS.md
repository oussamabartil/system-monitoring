# Guide de Tests Complet - Système de Monitoring

## 🎯 Vue d'ensemble

Ce guide vous accompagne étape par étape pour tester toutes les fonctionnalités de votre système de monitoring Prometheus + Grafana + AlertManager.

## 📋 Prérequis

- [ ] Docker Desktop installé et en cours d'exécution
- [ ] PowerShell 5.1 ou plus récent
- [ ] Privilèges administrateur pour certains tests
- [ ] Système de monitoring démarré (`.\start.bat`)

## 🚀 Tests Rapides (5 minutes)

### Étape 1 : Test de base
```powershell
# Vérifier que tous les services sont en cours d'exécution
.\scripts\test-complete-monitoring.ps1
```

**Résultats attendus :**
- ✅ Tous les conteneurs Docker en cours d'exécution
- ✅ Ports accessibles (9090, 3000, 9093, 8082)
- ✅ APIs fonctionnelles

### Étape 2 : Test Grafana
```powershell
# Tester l'interface Grafana
.\scripts\test-grafana.ps1
```

**Actions manuelles :**
1. Ouvrir http://localhost:3000
2. Se connecter avec `admin` / `admin123`
3. Vérifier que les dashboards sont visibles
4. Vérifier que les graphiques affichent des données

## 🔧 Tests Complets (15-30 minutes)

### Étape 3 : Installation Windows Exporter (si pas déjà fait)
```powershell
# Exécuter en tant qu'administrateur
.\scripts\install-windows-exporter.ps1
```

### Étape 4 : Test du système d'alertes
```powershell
# Test des alertes sans simulation CPU
.\scripts\test-alerts.ps1

# OU avec simulation CPU (attention : charge intensive!)
.\scripts\test-alerts.ps1 -SimulateCpuAlert
```

### Étape 5 : Tests de performance
```powershell
# Test de performance standard (5 minutes)
.\scripts\test-performance.ps1

# Test de performance avec stress test
.\scripts\test-performance.ps1 -StressTest
```

## 🎪 Suite de Tests Complète (30-60 minutes)

### Option 1 : Mode Interactif (Recommandé)
```powershell
# Lance tous les tests avec confirmations
.\scripts\run-all-tests.ps1
```

### Option 2 : Mode Automatique
```powershell
# Lance tous les tests sans interruption
.\scripts\run-all-tests.ps1 -Interactive:$false
```

### Option 3 : Tests Personnalisés
```powershell
# Ignorer Windows Exporter
.\scripts\run-all-tests.ps1 -SkipWindowsExporter

# Inclure simulation CPU
.\scripts\run-all-tests.ps1 -SimulateCpuAlert

# Tests complets avec stress test
.\scripts\run-all-tests.ps1 -SkipStressTest:$false
```

## 📊 Vérifications Manuelles

### 1. Prometheus (http://localhost:9090)
- [ ] Interface accessible
- [ ] Onglet "Status" → "Targets" : tous les targets en "UP"
- [ ] Onglet "Status" → "Rules" : règles d'alerte chargées
- [ ] Requête test : `up` retourne des résultats

### 2. Grafana (http://localhost:3000)
- [ ] Connexion avec admin/admin123
- [ ] Dashboards visibles dans le menu
- [ ] Graphiques affichent des données
- [ ] Pas d'erreurs de source de données

### 3. AlertManager (http://localhost:9093)
- [ ] Interface accessible
- [ ] Configuration visible
- [ ] Aucune alerte active (sauf si test en cours)

### 4. cAdvisor (http://localhost:8082)
- [ ] Interface accessible
- [ ] Métriques des conteneurs visibles
- [ ] Graphiques de performance affichés

### 5. Windows Exporter (http://localhost:9182/metrics)
- [ ] Page de métriques accessible
- [ ] Métriques Windows présentes (cpu, memory, disk)

## 🚨 Test des Alertes Email

### Configuration Email
1. Vérifier `alertmanager/alertmanager.yml`
2. Confirmer que votre email est configuré
3. Tester avec une alerte manuelle :

```powershell
$headers = @{'Content-Type' = 'application/json'}
$body = @'
[{
  "labels": {
    "alertname": "TestAlert",
    "severity": "warning"
  },
  "annotations": {
    "summary": "Test alert",
    "description": "This is a test"
  }
}]
'@

Invoke-RestMethod -Uri 'http://localhost:9093/api/v1/alerts' -Method POST -Headers $headers -Body $body
```

### Test CPU Alert
```powershell
# Simulation de charge CPU élevée
.\scripts\test-alerts.ps1 -SimulateCpuAlert
```

**Attendu :**
- Charge CPU > 85% pendant 1-2 minutes
- Alerte générée dans Prometheus
- Notification envoyée par AlertManager
- Email reçu à oussamabartil.04@gmail.com

## 📈 Tests de Performance

### Métriques à surveiller
- **Temps de réponse** : < 1000ms pour les interfaces
- **Utilisation CPU** : < 80% en fonctionnement normal
- **Utilisation RAM** : < 70% en fonctionnement normal
- **Taux d'erreur** : < 5% lors des tests de charge

### Commandes de monitoring
```powershell
# Surveiller les ressources système
Get-Counter "\Processor(_Total)\% Processor Time" -Continuous

# Surveiller les conteneurs Docker
docker stats

# Vérifier les logs
docker-compose logs -f prometheus
docker-compose logs -f grafana
```

## 🔍 Dépannage

### Problèmes Courants

#### Services non accessibles
```powershell
# Vérifier l'état des conteneurs
docker-compose ps

# Redémarrer si nécessaire
docker-compose restart
```

#### Windows Exporter ne fonctionne pas
```powershell
# Vérifier le service
Get-Service windows_exporter

# Redémarrer le service
Restart-Service windows_exporter

# Vérifier les logs Windows
Get-EventLog -LogName Application -Source windows_exporter -Newest 10
```

#### Alertes non reçues
1. Vérifier la configuration SMTP dans `alertmanager/alertmanager.yml`
2. Tester la connectivité réseau
3. Vérifier les logs AlertManager : `docker-compose logs alertmanager`

#### Dashboards vides
1. Vérifier la source de données Prometheus dans Grafana
2. Confirmer que Prometheus collecte des données
3. Vérifier la configuration des targets

## 📝 Rapport de Tests

Après chaque session de tests, un rapport HTML est généré automatiquement :
- **Fichier** : `test-results.html`
- **Contenu** : Résultats détaillés, métriques, recommandations

## 🔄 Tests Réguliers

### Quotidien
```powershell
.\scripts\health-check.ps1
```

### Hebdomadaire
```powershell
.\scripts\test-complete-monitoring.ps1
.\scripts\test-grafana.ps1
```

### Mensuel
```powershell
.\scripts\run-all-tests.ps1 -SkipStressTest:$false
```

## 📞 Support

En cas de problème :
1. Consulter les logs : `docker-compose logs`
2. Vérifier la documentation : `README.md`
3. Exécuter les scripts de diagnostic
4. Redémarrer les services si nécessaire

---

**🎉 Félicitations !** Votre système de monitoring est maintenant entièrement testé et opérationnel.
