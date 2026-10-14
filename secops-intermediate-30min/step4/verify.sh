#!/bin/bash
. /usr/local/lib/secops-lab/lib.sh
step_begin 4
c1() { [ -z "$(awk -F: '$3==0 && $1!="root"' /etc/passwd)" ]; }
c2() { [ -z "$(find /usr/local /opt /tmp /var/tmp /home /srv -xdev -perm -4000 -type f 2>/dev/null)" ]; }
c3() { grep -q 'admin@bastion.lab' /root/.ssh/authorized_keys && ! grep -q '203.0.113.50' /root/.ssh/authorized_keys; }
c4() { ! grep -rEqs '^[[:space:]]*www-data' /etc/sudoers /etc/sudoers.d && visudo -c; }
chk "pas de second compte UID 0" c1
chk "pas de binaire SUID suspect" c2
chk "clé SSH illégitime retirée, légitime conservée" c3
chk "sudo www-data retiré, sudoers valide" c4
step_end
