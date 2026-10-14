#!/bin/bash
echo "Préparation de l'environnement, merci de patienter..."
while [ ! -f /tmp/.secops-setup-done ]; do sleep 1; done
clear
echo "Environnement prêt. Bon courage !"
