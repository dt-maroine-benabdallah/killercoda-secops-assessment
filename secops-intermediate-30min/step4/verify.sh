#!/bin/bash
. /usr/local/lib/secops-lab/lib.sh
step_begin 4
# Un compte UID 0 autre que root doit etre supprime, ou neutralise (verrouille + shell nologin/false)
c1() {
  while IFS=: read -r u _ id _ _ _ sh; do
    [ "$id" = 0 ] && [ "$u" != root ] || continue
    pw=$(awk -F: -v u="$u" '$1==u{print $2}' /etc/shadow)
    case "$pw" in '!'*|'*'*) ;; *) return 1 ;; esac
    case "$sh" in */nologin|*/false) ;; *) return 1 ;; esac
  done < /etc/passwd
  return 0
}
c2() { [ -z "$(find /usr/local /opt /tmp /var/tmp /home /srv -xdev -perm -4000 -type f 2>/dev/null)" ]; }
c3() { grep -q 'admin@bastion.lab' /root/.ssh/authorized_keys && ! grep -q '203.0.113.50' /root/.ssh/authorized_keys; }
c4() { ! grep -rEqs '^[[:space:]]*www-data' /etc/sudoers /etc/sudoers.d && visudo -c; }
chk "pas de second compte UID 0 actif" c1
chk "pas de binaire SUID suspect" c2
chk "clé SSH illégitime retirée, légitime conservée" c3
chk "sudo www-data retiré, sudoers valide" c4
step_end
