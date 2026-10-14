# Réseau : résolution de noms et TLS

L'application appelle `https://intranet.lab:8443`, mais le nom ne pointe pas vers le bon serveur.

**Objectifs :**

1. Faire résoudre `intranet.lab` vers cette machine (`127.0.0.1`), de façon cohérente pour tous les programmes.
2. Inspecter le certificat servi sur le port 8443 et écrire dans `/root/answers.txt`, une valeur par ligne :

```
expiry=AAAA-MM-JJ
key_bits=NNNN
```

`expiry` est la date d'expiration du certificat (UTC), `key_bits` la taille de sa clé publique.

Cliquez sur **CHECK** quand vous avez terminé.
