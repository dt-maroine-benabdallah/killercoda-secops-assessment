#!/bin/bash
. /usr/local/lib/secops-lab/lib.sh
step_begin 6
CERT=$(openssl s_client -connect 127.0.0.1:8443 -servername intranet.lab </dev/null 2>/dev/null | openssl x509 2>/dev/null)
c1() { [ "$(getent hosts intranet.lab | awk '{print $1; exit}')" = "127.0.0.1" ]; }
c2() { e=$(echo "$CERT" | openssl x509 -noout -enddate | cut -d= -f2); d=$(date -u -d "$e" +%F); grep -Eq "^expiry=$d[[:space:]]*$" /root/answers.txt; }
c3() { b=$(echo "$CERT" | openssl x509 -noout -text | sed -n 's/.*Public-Key: (\([0-9]*\) bit).*/\1/p'); [ -n "$b" ] && grep -Eq "^key_bits=$b[[:space:]]*$" /root/answers.txt; }
chk "intranet.lab résolu vers 127.0.0.1" c1
chk "date d'expiration correcte" c2
chk "taille de clé correcte" c3
step_end
