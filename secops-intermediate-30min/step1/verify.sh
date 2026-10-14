#!/bin/bash
. /usr/local/lib/secops-lab/lib.sh
step_begin 1
c1() { [ "$(systemctl is-active reporting)" = "active" ]; }
c2() { [ "$(curl -s -m 3 localhost:8080/health)" = "ok" ]; }
c3() { [ "$(systemctl is-enabled reporting)" = "enabled" ]; }
c4() { pid=$(systemctl show -p MainPID --value reporting); [ "$pid" -gt 0 ] && [ "$(ps -o user= -p "$pid" | tr -d ' ')" != "root" ]; }
chk "service actif" c1
chk "health ok" c2
chk "activé au boot" c3
chk "ne tourne pas en root" c4
step_end
