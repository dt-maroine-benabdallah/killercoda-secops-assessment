# Réseau : service injoignable

Le service `inventory` écoute sur le port 8081 mais reste injoignable depuis l'adresse IP de la machine :

```
curl -m 3 http://$(hostname -I | awk '{print $1}'):8081
```{{exec}}

**Objectif :** diagnostiquer et rétablir l'accès, sans dégrader la sécurité des autres services de la machine.

Cliquez sur **CHECK** quand vous avez terminé.
