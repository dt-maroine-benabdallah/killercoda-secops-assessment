#!/bin/bash
. /usr/local/lib/secops-lab/lib.sh
step_begin 2
c1() {
  touch /tmp/.bk-marker; sleep 1
  runuser -u backup -- /usr/local/bin/backup-app.sh || return 1
  [ -n "$(find /var/backups/app -name 'reporting-*.tar.gz' -newer /tmp/.bk-marker)" ]
}
c2() {
  f=/etc/cron.d/backup-app
  [ "$(stat -c '%U %a' $f)" = "root 644" ] || return 1
  grep -Eq '^([0-9*/,-]+[[:space:]]+){5}backup[[:space:]]+/usr/local/bin/backup-app\.sh|^@[a-z]+[[:space:]]+backup[[:space:]]+/usr/local/bin/backup-app\.sh' $f
}
c3() { m=$(stat -c '%a' /var/backups/app); [ $((8#$m & 2)) -eq 0 ] && [ $((8#$m & 4)) -eq 0 ]; }
chk "script exécuté par backup" c1
chk "entrée cron valide" c2
chk "dépôt non accessible en écriture/lecture globale" c3
step_end
