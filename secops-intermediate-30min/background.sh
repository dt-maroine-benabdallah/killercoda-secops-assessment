#!/bin/bash
# Préparation de l'environnement (exécuté en arrière-plan à l'ouverture du scénario)
export DEBIAN_FRONTEND=noninteractive
LAB=/usr/local/lib/secops-lab
RES=/var/lib/secops-lab
mkdir -p "$LAB" "$RES"
date +%s > "$RES/start"

# --- Paquets nécessaires -----------------------------------------------------
need=()
command -v sshd >/dev/null     || need+=(openssh-server)
command -v iptables >/dev/null || need+=(iptables)
command -v curl >/dev/null     || need+=(curl)
command -v openssl >/dev/null  || need+=(openssl)
command -v sudo >/dev/null     || need+=(sudo)
command -v python3 >/dev/null  || need+=(python3)
if [ ${#need[@]} -gt 0 ]; then
  apt-get update -qq && apt-get install -y -qq "${need[@]}"
fi

# --- Bibliothèque de vérification --------------------------------------------
cat > "$LAB/lib.sh" <<'EOF'
RES=/var/lib/secops-lab
PASS=0; TOTAL=0
step_begin() { STEP=$1; : > "$RES/step$STEP.log"; }
chk() {
  local desc="$1" fn="$2"; TOTAL=$((TOTAL+1))
  if "$fn" >/dev/null 2>&1; then PASS=$((PASS+1)); echo "OK $desc" >> "$RES/step$STEP.log"
  else echo "KO $desc" >> "$RES/step$STEP.log"; fi
}
step_end() {
  echo "$PASS/$TOTAL" > "$RES/step$STEP"
  echo "Étape $STEP enregistrée. Vous pouvez continuer ('score' affiche votre avancement)."
  exit 0
}
EOF

cat > /usr/local/bin/score <<'EOF'
#!/bin/bash
R=/var/lib/secops-lab
labels=("Sécurité : SFTP attaqué" "Sécurité : compte admin" "Réseau   : service injoignable" "Bonus    : CSR et certificat")
max=(2 2 2 5)
start=$(cat $R/start 2>/dev/null || date +%s)
echo "Temps écoulé : $(( ($(date +%s) - start) / 60 )) min"
echo
core=0; bonus=0
for i in 1 2 3 4; do
  r=$(cat $R/step$i 2>/dev/null || echo "-")
  p=${r%%/*}; [ "$r" = "-" ] && p=0
  if [ "$i" -le 3 ]; then core=$((core+p)); else bonus=$p; fi
  printf "Étape %s  %-32s %s/%s\n" "$i" "${labels[$((i-1))]}" "$p" "${max[$((i-1))]}"
done
echo
echo "Score socle : $core/6"
echo "Bonus       : $bonus/5"
EOF
chmod +x /usr/local/bin/score

# --- Étape 1 : SFTP attaqué ------------------------------------------------------
# Adresses de test sur lo : attaquant, partenaire légitime, bruit légitime
ip addr replace 192.0.2.66/32 dev lo
ip addr replace 192.0.2.10/32 dev lo
ip addr replace 192.0.2.77/32 dev lo
id partner1 >/dev/null 2>&1 || useradd -m -s /usr/sbin/nologin partner1
ssh-keygen -A >/dev/null 2>&1
cat > /etc/ssh/sftp_gateway_config <<'EOF'
Port 2222
ListenAddress 0.0.0.0
HostKey /etc/ssh/ssh_host_ed25519_key
PidFile /run/sftp-gateway.pid
PermitRootLogin no
PasswordAuthentication yes
KbdInteractiveAuthentication no
UsePAM yes
AllowUsers partner1
AllowTcpForwarding no
X11Forwarding no
Subsystem sftp internal-sftp
ForceCommand internal-sftp
EOF
cat > /etc/systemd/system/sftp-gateway.service <<'EOF'
[Unit]
Description=SFTP gateway partenaires
After=network.target

[Service]
ExecStartPre=/usr/bin/mkdir -p /run/sshd
ExecStart=/usr/sbin/sshd -D -f /etc/ssh/sftp_gateway_config
Restart=always

[Install]
WantedBy=multi-user.target
EOF
mkdir -p /var/log/sftp-gateway
LOG=/var/log/sftp-gateway/auth.log
host=$(hostname)
now=$(date +%s)
users=(admin root test oracle ubuntu ftp git user postgres support)
: > "$LOG"
for i in $(seq 1 180); do
  t=$((now - 2400 + i * 13))
  ts=$(date -d "@$t" '+%b %e %H:%M:%S')
  port=$((20000 + RANDOM % 40000))
  pid=$((3000 + RANDOM % 900))
  u=${users[$((RANDOM % 10))]}
  pre="$ts $host sshd[$pid]:"
  if   [ $((i % 45)) -eq 0 ]; then echo "$pre Accepted password for partner1 from 192.0.2.10 port $port ssh2"
  elif [ $((i % 70)) -eq 0 ]; then echo "$pre Failed password for partner1 from 192.0.2.10 port $port ssh2"
  elif [ $((i % 90)) -eq 0 ]; then echo "$pre Failed password for invalid user test from 192.0.2.77 port $port ssh2"
  elif [ "$u" = root ];        then echo "$pre Failed password for root from 192.0.2.66 port $port ssh2"
  else                              echo "$pre Failed password for invalid user $u from 192.0.2.66 port $port ssh2"
  fi
done >> "$LOG"

# --- Étape 2 : compte admin illégitime ------------------------------------------
id sysadmin >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo -c "Administrateur" sysadmin
id deploy >/dev/null 2>&1 || useradd -m -s /bin/bash -c "Compte de déploiement" deploy
id tmp-support >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo -c "Support temporaire" tmp-support

# --- Étape 3 : pare-feu ------------------------------------------------------------
mkdir -p /srv/inventory /srv/internal-db
echo "inventory ok" > /srv/inventory/index.html
echo "base interne" > /srv/internal-db/index.html
for svc in "inventory:8081" "internal-db:9200"; do
  name=${svc%%:*}; port=${svc##*:}
  cat > /etc/systemd/system/$name.service <<EOF
[Unit]
Description=$name
After=network.target

[Service]
User=nobody
ExecStart=/usr/bin/python3 -m http.server $port --bind 0.0.0.0 --directory /srv/$name
Restart=always

[Install]
WantedBy=multi-user.target
EOF
done
iptables -A INPUT -p tcp --dport 8081 -j DROP
iptables -A INPUT -p tcp --dport 9200 -m comment --comment "acces a la base interne interdit" -j DROP

# --- Étape 4 : CA interne + portail HTTPS --------------------------------------
mkdir -p /opt/ca /etc/portal-tls
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout /opt/ca/ca.key -out /opt/ca/ca.crt \
  -subj "/CN=DiliLab Internal CA/O=Lab" >/dev/null 2>&1
chmod 600 /opt/ca/ca.key
openssl req -x509 -newkey rsa:2048 -nodes -days 30 \
  -keyout /etc/portal-tls/key.pem -out /etc/portal-tls/cert.pem \
  -subj "/CN=portal.lab.internal" >/dev/null 2>&1
chmod 644 /etc/portal-tls/key.pem
cat > /etc/portal-tls/server.py <<'EOF'
import http.server, ssl
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = b"portail ok\n"
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a):
        pass
class S(http.server.ThreadingHTTPServer):
    def get_request(self):
        sock, addr = self.socket.accept()
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain("/etc/portal-tls/cert.pem", "/etc/portal-tls/key.pem")
        return ctx.wrap_socket(sock, server_side=True), addr
S(("0.0.0.0", 8443), H).serve_forever()
EOF
cat > /etc/systemd/system/portal-tls.service <<'EOF'
[Unit]
Description=Portail interne HTTPS
After=network.target

[Service]
ExecStart=/usr/bin/python3 /etc/portal-tls/server.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# --- Démarrage des services -----------------------------------------------------
systemctl daemon-reload
systemctl enable --now sftp-gateway.service inventory.service internal-db.service portal-tls.service >/dev/null 2>&1
touch /tmp/.secops-setup-done
