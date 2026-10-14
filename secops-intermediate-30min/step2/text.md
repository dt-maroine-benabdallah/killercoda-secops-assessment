# Sécurité : un compte de déploiement trop puissant

Le compte `deploy` sert uniquement à redémarrer le service `inventory` lors des mises en production. Un audit interne affirme pourtant qu'il peut en pratique obtenir un accès root complet sur cette machine.

**Objectif :** comprendre d'où vient ce risque et le supprimer, sans empêcher `deploy` de redémarrer `inventory`. Ne touchez pas aux autres comptes.

Une seule action corrective est attendue.

Cliquez sur **CHECK** quand vous avez terminé.
