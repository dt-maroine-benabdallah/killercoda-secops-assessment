#!/bin/bash
. /usr/local/lib/secops-lab/lib.sh
step_begin 1
probe() {
  python3 - "$1" <<'PY'
import socket, sys
s = socket.socket()
s.settimeout(3)
try:
    s.bind((sys.argv[1], 0))
    s.connect(("127.0.0.1", 2222))
    sys.exit(0 if s.recv(64).startswith(b"SSH-") else 1)
except Exception:
    sys.exit(1)
PY
}
ruleset_blocks() { { iptables-save; nft list ruleset; ufw status; } 2>/dev/null | grep -F '192.0.2.66' | grep -Eiq 'drop|reject|deny'; }
c1() { ! probe 192.0.2.66 || ruleset_blocks; }
c2() { c1 && probe 192.0.2.10; }
chk "attaquant bloqué" c1
chk "partenaire légitime toujours autorisé" c2
step_end
