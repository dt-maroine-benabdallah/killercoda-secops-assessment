#!/bin/bash
. /usr/local/lib/secops-lab/lib.sh
step_begin 3
IP=$(ip -4 route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1);exit}}')
c1() { curl -fsS -m 3 "http://$IP:8081" >/dev/null; }
c2() { ! curl -sS -m 3 "http://$IP:9200" >/dev/null 2>&1; }
chk "inventory joignable" c1
chk "base interne toujours protégée" c2
step_end
