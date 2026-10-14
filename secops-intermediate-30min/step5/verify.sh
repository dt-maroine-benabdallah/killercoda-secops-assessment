#!/bin/bash
. /usr/local/lib/secops-lab/lib.sh
step_begin 5
CA=/opt/ca/ca.crt
SC=$(openssl s_client -connect 127.0.0.1:8443 -servername portal.lab.internal -CAfile "$CA" -verify_hostname portal.lab.internal </dev/null 2>&1)
LEAF=$(openssl s_client -connect 127.0.0.1:8443 -servername portal.lab.internal </dev/null 2>/dev/null | openssl x509 2>/dev/null)
c1() { [ -s /root/portal.csr ] && openssl req -in /root/portal.csr -noout -verify 2>&1 | grep -qi 'verify ok' && T=$(openssl req -in /root/portal.csr -noout -text) && echo "$T" | grep -q 'DNS:portal.lab.internal' && echo "$T" | grep -q 'DNS:www.portal.lab.internal'; }
c2() { echo "$SC" | grep -q 'Verify return code: 0 (ok)'; }
c3() { S=$(echo "$LEAF" | openssl x509 -noout -ext subjectAltName) && echo "$S" | grep -q 'DNS:portal.lab.internal' && echo "$S" | grep -q 'DNS:www.portal.lab.internal'; }
c4() { s=$(date -d "$(echo "$LEAF" | openssl x509 -noout -startdate | cut -d= -f2)" +%s); e=$(date -d "$(echo "$LEAF" | openssl x509 -noout -enddate | cut -d= -f2)" +%s); d=$(( (e - s) / 86400 )); [ "$d" -ge 88 ] && [ "$d" -le 92 ]; }
c5() { m=$(stat -c '%a' /etc/portal-tls/key.pem); [ "$m" = 600 ] || [ "$m" = 400 ]; }
chk "CSR valide avec CN et SAN" c1
chk "certificat servi signé par la CA interne" c2
chk "SAN du certificat servi" c3
chk "validité de 90 jours" c4
chk "clé privée protégée" c5
step_end
