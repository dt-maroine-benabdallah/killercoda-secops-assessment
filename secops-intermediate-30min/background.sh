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
command -v tar >/dev/null      || need+=(tar)
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
labels=("Système  : service en échec" "Système  : sauvegarde" "Sécurité : durcissement SSH" "Sécurité : audit" "Réseau   : service injoignable" "Réseau   : DNS et TLS")
max=(4 3 4 4 2 3)
start=$(cat $R/start 2>/dev/null || date +%s)
echo "Temps écoulé : $(( ($(date +%s) - start) / 60 )) min"
echo
tp=0; tt=0
for i in 1 2 3 4 5 6; do
  r=$(cat $R/step$i 2>/dev/null || echo "-")
  p=${r%%/*}; [ "$r" = "-" ] && p=0
  tp=$((tp+p)); tt=$((tt+${max[$((i-1))]}))
  printf "Étape %s  %-32s %s/%s\n" "$i" "${labels[$((i-1))]}" "$p" "${max[$((i-1))]}"
done
echo
echo "Score total : $tp/$tt"
EOF
chmod +x /usr/local/bin/score

# --- Étape 1 : service reporting cassé ---------------------------------------
mkdir -p /opt/reporting
cat > /opt/reporting/app.py <<'EOF'
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        body = b"ok\n" if self.path == "/health" else b"reporting api\n"
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a):
        pass
HTTPServer(("0.0.0.0", 8080), H).serve_forever()
EOF
cat > /etc/systemd/system/reporting.service <<'EOF'
[Unit]
Description=Reporting API (interne)
After=network.target

[Service]
User=reportsvc
WorkingDirectory=/opt/reporting
ExecStart=/usr/bin/python3 /opt/reporting/server.py

[Install]
WantedBy=multi-user.target
EOF

# --- Étape 2 : sauvegarde cassée ---------------------------------------------
cat > /usr/local/bin/backup-app.sh <<'EOF'
#!/bin/bash
set -euo pipefail
tar czf "/var/backups/app/reporting-$(date +%Y%m%d-%H%M%S).tar.gz" /opt/reporting
EOF
chmod 644 /usr/local/bin/backup-app.sh
mkdir -p /var/backups/app /etc/cron.d
chown root:root /var/backups/app; chmod 700 /var/backups/app
cat > /etc/cron.d/backup-app <<'EOF'
# Sauvegarde nocturne de l'application reporting
0 2 * * * /usr/local/bin/backup-app.sh
EOF
chmod 644 /etc/cron.d/backup-app

# --- Étape 3 : SSH faible via drop-ins ---------------------------------------
mkdir -p /run/sshd /etc/ssh/sshd_config.d
ssh-keygen -A >/dev/null 2>&1
grep -q '^Include /etc/ssh/sshd_config.d' /etc/ssh/sshd_config || sed -i '1i Include /etc/ssh/sshd_config.d/*.conf' /etc/ssh/sshd_config
printf 'PermitRootLogin yes\nMaxAuthTries 10\n' > /etc/ssh/sshd_config.d/10-lab.conf
printf 'PasswordAuthentication yes\n' > /etc/ssh/sshd_config.d/50-cloud-init.conf

# --- Étape 4 : compromission simulée -----------------------------------------
useradd -o -u 0 -g 0 -M -s /bin/bash svc-monitor 2>/dev/null
cp /bin/bash /usr/local/bin/.sysupdate; chmod 4755 /usr/local/bin/.sysupdate
mkdir -p /root/.ssh; chmod 700 /root/.ssh
K=$(mktemp -d)
ssh-keygen -q -t ed25519 -N '' -C 'admin@bastion.lab' -f "$K/k1"
ssh-keygen -q -t ed25519 -N '' -C 'svc@203.0.113.50' -f "$K/k2"
cat "$K/k1.pub" "$K/k2.pub" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys; rm -rf "$K"
mkdir -p /etc/sudoers.d
printf 'www-data ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/90-maintenance
chmod 440 /etc/sudoers.d/90-maintenance

# --- Étape 5 : pare-feu --------------------------------------------------------
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

# --- Étape 6 : DNS + TLS -------------------------------------------------------
mkdir -p /etc/intranet-tls
BITS=$(shuf -e 2048 3072 4096 -n1)
DAYS=$((RANDOM % 30 + 30))
openssl req -x509 -newkey rsa:$BITS -nodes -days $DAYS \
  -keyout /etc/intranet-tls/key.pem -out /etc/intranet-tls/cert.pem \
  -subj "/CN=intranet.lab/O=Lab" \
  -addext "subjectAltName=DNS:intranet.lab,DNS:intranet-legacy.lab" >/dev/null 2>&1
cat > /etc/intranet-tls/server.py <<'EOF'
import http.server, ssl
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = b"intranet ok\n"
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a):
        pass
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain("/etc/intranet-tls/cert.pem", "/etc/intranet-tls/key.pem")
srv = http.server.HTTPServer(("0.0.0.0", 8443), H)
srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
srv.serve_forever()
EOF
cat > /etc/systemd/system/intranet-tls.service <<'EOF'
[Unit]
Description=Intranet TLS
After=network.target

[Service]
ExecStart=/usr/bin/python3 /etc/intranet-tls/server.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF
sed -i '1i 10.255.255.1 intranet.lab # ancien serveur (migré)' /etc/hosts
echo '127.0.0.1 intranet.lab' >> /etc/hosts

# --- Démarrage des services -----------------------------------------------------
systemctl daemon-reload
systemctl enable --now inventory.service internal-db.service intranet-tls.service >/dev/null 2>&1
systemctl start reporting.service >/dev/null 2>&1 || true   # échoue volontairement
touch /tmp/.secops-setup-done
