# Sécurité : un SFTP exposé qui se fait attaquer

Le service SFTP utilisé pour échanger des fichiers avec nos partenaires (port 2222) est exposé sur Internet. Le pare-feu externe signale un volume anormal de tentatives de connexion.

Le journal d'authentification du service : `/var/log/sftp-gateway/auth.log`

**Objectif :** identifier la source de l'attaque et la bloquer, sans couper l'accès des partenaires légitimes.

Une seule action corrective est attendue.

Cliquez sur **CHECK** quand vous avez terminé.
