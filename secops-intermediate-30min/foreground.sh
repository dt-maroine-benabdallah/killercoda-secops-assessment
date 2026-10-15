#!/bin/bash
echo "Préparation de l'environnement, merci de patienter..."
while [ ! -f /tmp/.secops-setup-done ]; do sleep 1; done
clear
echo "Environnement prêt."
echo
read -r -t 300 -p "Code candidat communiqué par l'évaluateur, puis Entrée : " code
code=$(printf '%s' "$code" | tr -cd 'A-Za-z0-9_-' | cut -c1-20)
[ -n "$code" ] || code="non-renseigne"
echo "$code" > /var/lib/secops-lab/candidate
date +%s > /var/lib/secops-lab/start
. /usr/local/lib/secops-lab/lib.sh
notify "SecOps test : session demarree ($code)" "Candidat : $code. Session ouverte le $(date -u '+%F %T') UTC."
clear
echo "Merci. Le chronomètre démarre maintenant. Bon courage !"
