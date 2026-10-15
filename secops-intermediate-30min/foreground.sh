#!/bin/bash
echo "Préparation de l'environnement, merci de patienter..."
while [ ! -f /tmp/.secops-setup-done ]; do sleep 1; done
clear
echo "Environnement prêt."
echo
echo "Avant de commencer le test et d'appuyer sur START, merci d'exécuter ce script pour identifier votre session :"
echo "exemple : start_test.sh \"Benoit Dupont\""
echo
