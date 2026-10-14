#!/bin/bash
. /usr/local/lib/secops-lab/lib.sh
step_begin 3
T=$(sshd -T 2>/dev/null)
c1() { echo "$T" | grep -qx 'permitrootlogin no'; }
c2() { echo "$T" | grep -qx 'passwordauthentication no'; }
c3() { n=$(echo "$T" | awk '$1=="maxauthtries"{print $2}'); [ -n "$n" ] && [ "$n" -le 4 ]; }
c4() { sshd -t; }
chk "root login interdit" c1
chk "mot de passe interdit" c2
chk "MaxAuthTries <= 4" c3
chk "configuration valide" c4
step_end
