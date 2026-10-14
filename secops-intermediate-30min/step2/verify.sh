#!/bin/bash
. /usr/local/lib/secops-lab/lib.sh
step_begin 2
c1() { if ! id tmp-support >/dev/null 2>&1; then return 0; fi; sudo -l -U tmp-support 2>&1 | grep -q 'not allowed'; }
c2() { c1 && id -nG sysadmin | tr ' ' '\n' | grep -qx sudo && id deploy >/dev/null 2>&1; }
chk "compte illégitime sans droits admin" c1
chk "comptes légitimes intacts" c2
step_end
