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
NTFY_TOPIC="dt-secops-6ff488da993f3d67dd37da31"
NOTIFY_MAIL="secops-test@dilitrust.com"
# Notification anonyme a l'evaluateur (aucune donnee personnelle). Silencieuse en cas d'echec.
notify() {
  command -v curl >/dev/null 2>&1 || return 0
  setsid -f curl -fsS -m 10 -H "Title: $1" -H "Email: $NOTIFY_MAIL" -H "Tags: shield" -d "$2" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1 || true
}
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
. /usr/local/lib/secops-lab/lib.sh
labels=("Sécurité : SFTP attaqué" "Sécurité : compte trop puissant" "Réseau   : service injoignable" "IaC      : revue Terraform" "Bonus    : CSR et certificat")
max=(2 2 2 2 5)
start=$(cat $R/start 2>/dev/null || date +%s)
mins=$(( ($(date +%s) - start) / 60 ))
cand=$(cat $R/candidate 2>/dev/null || echo non-renseigne)
core=0; bonus=0; lines=""; done_n=0
for i in 1 2 3 4 5; do
  r=$(cat $R/step$i 2>/dev/null || echo "-")
  p=${r%%/*}; [ "$r" = "-" ] && p=0 || done_n=$((done_n+1))
  if [ "$i" -le 4 ]; then core=$((core+p)); else bonus=$p; fi
  lines+=$(printf "Étape %s  %-32s %s/%s" "$i" "${labels[$((i-1))]}" "$p" "${max[$((i-1))]}")$'\n'
done
echo "Temps écoulé : $mins min"
echo
printf '%s' "$lines"
echo
echo "Score socle : $core/8"
echo "Bonus       : $bonus/5"
# Notification a l'evaluateur : 3 envois maximum, uniquement si le resultat a change
sig=$(printf '%s' "$core/$bonus/$done_n" | md5sum | cut -c1-8)
n=$(cat $R/notified 2>/dev/null || echo 0)
if [ "$done_n" -ge 1 ] && [ "$n" -lt 3 ] && [ "$sig" != "$(cat $R/lastsig 2>/dev/null)" ]; then
  echo "$sig" > $R/lastsig; echo $((n+1)) > $R/notified
  notify "SecOps test [$cand] : score $core/8, bonus $bonus/5 ($mins min)" "Candidat : $cand. Étapes enregistrées : $done_n/5. Durée : $mins min.
$lines
Socle : $core/8 - Bonus : $bonus/5"
fi
EOF
cat > /usr/local/bin/candidat <<'EOF'
#!/bin/bash
code=$(printf '%s' "$1" | tr -cd 'A-Za-z0-9_-' | cut -c1-20)
[ -n "$code" ] || { echo "Usage : candidat CODE"; exit 1; }
echo "$code" > /var/lib/secops-lab/candidate
. /usr/local/lib/secops-lab/lib.sh
notify "SecOps test : code candidat $code" "Candidat : $code (code saisi apres le demarrage)."
echo "Code enregistré : $code"
EOF
chmod +x /usr/local/bin/score /usr/local/bin/candidat

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

# --- Étape 2 : compte deploy trop puissant ---------------------------------------
id sysadmin >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo -c "Administrateur" sysadmin
id deploy >/dev/null 2>&1 || useradd -m -s /bin/bash -c "Compte de déploiement" deploy
cat > /usr/local/bin/restart-inventory.sh <<'RSEOF'
#!/bin/bash
systemctl restart inventory
RSEOF
chown deploy:deploy /usr/local/bin/restart-inventory.sh
chmod 755 /usr/local/bin/restart-inventory.sh
cat > /etc/sudoers.d/40-deploy <<'SUDOEOF'
# Compte de deploiement
deploy ALL=(root) NOPASSWD: /usr/local/bin/restart-inventory.sh
SUDOEOF
chmod 440 /etc/sudoers.d/40-deploy
visudo -cf /etc/sudoers.d/40-deploy >/dev/null

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

# --- Étape 4 : plan Terraform à relire ---------------------------------------------
mkdir -p /root/iac
cat > /root/iac/plan.txt <<'PLANEOF'
Terraform used the selected providers to generate the following execution plan.
Resource actions are indicated with the following symbols:
  + create
  ~ update in-place

Terraform will perform the following actions:

  # aws_lb.app will be updated in-place
  ~ resource "aws_lb" "app" {
        id                         = "arn:aws:elasticloadbalancing:eu-west-3:123456789012:loadbalancer/app/prod-app/50dc6c495c0c9188"
      ~ idle_timeout               = 60 -> 120
        name                       = "prod-app"
        # (14 unchanged attributes hidden)
    }

  # aws_security_group_rule.alb_https will be created
  + resource "aws_security_group_rule" "alb_https" {
      + cidr_blocks              = [
          + "0.0.0.0/0",
        ]
      + description              = "HTTPS public vers le load balancer"
      + from_port                = 443
      + protocol                 = "tcp"
      + security_group_id        = "sg-0a1b2c3d4e5f60718"
      + to_port                  = 443
      + type                     = "ingress"
    }

  # aws_security_group_rule.rds_ingress will be updated in-place
  ~ resource "aws_security_group_rule" "rds_ingress" {
      ~ cidr_blocks              = [
          - "10.20.0.0/16",
          + "0.0.0.0/0",
        ]
        description              = "PostgreSQL depuis le reseau applicatif"
        from_port                = 5432
        id                       = "sgrule-2873144915"
        protocol                 = "tcp"
        security_group_id        = "sg-0f9e8d7c6b5a43210"
        to_port                  = 5432
        type                     = "ingress"
    }

  # aws_instance.worker will be updated in-place
  ~ resource "aws_instance" "worker" {
        id                           = "i-0123456789abcdef0"
      ~ instance_type                = "t3.small" -> "t3.medium"
      ~ tags                         = {
          ~ "CostCenter" = "ops" -> "platform"
            # (2 unchanged elements hidden)
        }
        # (28 unchanged attributes hidden)
    }

  # aws_s3_bucket.exports will be created
  + resource "aws_s3_bucket" "exports" {
      + acl                         = "private"
      + bucket                      = "dilitrust-prod-exports"
      + force_destroy               = false
      + id                          = (known after apply)
    }

  # aws_s3_bucket_public_access_block.exports will be created
  + resource "aws_s3_bucket_public_access_block" "exports" {
      + block_public_acls           = true
      + block_public_policy         = true
      + bucket                      = (known after apply)
      + ignore_public_acls          = true
      + restrict_public_buckets     = true
    }

  # aws_s3_bucket_server_side_encryption_configuration.exports will be created
  + resource "aws_s3_bucket_server_side_encryption_configuration" "exports" {
      + bucket = (known after apply)
      + rule {
          + apply_server_side_encryption_by_default {
              + sse_algorithm = "aws:kms"
            }
        }
    }

Plan: 3 to add, 3 to change, 0 to destroy.
PLANEOF

# --- Étape 5 : CA interne + portail HTTPS --------------------------------------
mkdir -p /opt/ca /etc/portal-tls
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout /opt/ca/ca.key -out /opt/ca/ca.crt \
  -subj "/CN=DiliLab Internal CA/O=Lab" >/dev/null 2>&1
chmod 600 /opt/ca/ca.key
openssl req -x509 -newkey rsa:2048 -nodes -days 30 \
  -keyout /etc/portal-tls/key.pem -out /etc/portal-tls/cert.pem \
  -subj "/CN=portal.lab.internal" >/dev/null 2>&1
chmod 600 /etc/portal-tls/key.pem
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
