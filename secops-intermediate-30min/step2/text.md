# Système : sauvegarde nocturne en échec

La sauvegarde de l'application `reporting` devrait s'exécuter chaque nuit à 2h sous le compte système `backup`, mais aucune archive n'apparaît dans `/var/backups/app`.

Les fichiers concernés : `/usr/local/bin/backup-app.sh` et `/etc/cron.d/backup-app`.

**Objectif :** corriger tous les problèmes pour que la sauvegarde fonctionne réellement, sans affaiblir la sécurité du dépôt de sauvegarde. Vous pouvez lancer la sauvegarde à la main pour tester, avec le compte prévu.

Cliquez sur **CHECK** quand vous avez terminé.
