# Sécurité : durcissement SSH

Le serveur SSH va être exposé sur Internet. Durcissez sa configuration :

- interdire la connexion directe de `root`
- n'autoriser que l'authentification par clé
- limiter à 4 tentatives d'authentification par connexion

La configuration doit rester valide (`sshd -t`) et le service ne doit pas être coupé. Seule la configuration **effective** compte.

Cliquez sur **CHECK** quand vous avez terminé.
