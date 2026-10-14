# Bonus : CSR et certificat signé par la CA interne

Le portail interne `portal.lab.internal` est servi en HTTPS sur le port 8443 avec un certificat auto-signé provisoire. Vous devez le remplacer par un certificat émis par la CA interne (`/opt/ca/ca.crt` et `/opt/ca/ca.key`).

**Objectifs :**

1. Générer une nouvelle clé privée et une demande de certificat (CSR) enregistrée dans `/root/portal.csr`, avec le nom `portal.lab.internal` et les noms alternatifs (SAN) `portal.lab.internal` et `www.portal.lab.internal`.
2. Signer cette CSR avec la CA interne pour obtenir un certificat valable **90 jours**, qui conserve les SAN.
3. Déployer la clé et le certificat dans `/etc/portal-tls/key.pem` et `/etc/portal-tls/cert.pem`. La clé privée ne doit pas être lisible par les autres utilisateurs.

Le serveur recharge ces fichiers à chaque connexion, aucun redémarrage n'est nécessaire. Test possible :

```
curl --cacert /opt/ca/ca.crt --resolve portal.lab.internal:8443:127.0.0.1 https://portal.lab.internal:8443
```{{exec}}

Cliquez sur **CHECK** quand vous avez terminé.
