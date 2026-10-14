# Système : un service qui ne démarre pas

L'API interne `reporting` (HTTP, port 8080) est en panne : `systemctl start reporting` échoue.

**Objectif :** la remettre en service de façon durable, en respectant les bonnes pratiques de sécurité.

Test fonctionnel : `curl localhost:8080/health` doit répondre `ok`.

Cliquez sur **CHECK** quand vous avez terminé.
