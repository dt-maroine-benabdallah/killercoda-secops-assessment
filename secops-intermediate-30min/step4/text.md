# IaC : revue d'un plan Terraform

Avant chaque déploiement en production, la CI génère un plan Terraform et attend la validation d'un relecteur. Le plan de ce soir est enregistré dans `/root/iac/plan.txt` :

```
less /root/iac/plan.txt
```{{exec}}

Vous êtes le relecteur sécurité. Un des changements prévus ne doit pas être appliqué en l'état.

**Objectif :** écrire dans `/root/reponse.txt` (quelques lignes suffisent) l'adresse de la ressource concernée, le risque, et la correction à demander à l'auteur de la modification.

Aucune action sur l'infrastructure n'est demandée.

Cliquez sur **CHECK** quand vous avez terminé.
