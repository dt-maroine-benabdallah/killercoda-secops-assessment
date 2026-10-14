#!/bin/bash
. /usr/local/lib/secops-lab/lib.sh
step_begin 4
F=/root/reponse.txt
c1() { [ -s "$F" ] && grep -Eqi 'rds_ingress' "$F" && grep -Eqi '0\.0\.0\.0/0|5432|postgres|rds|base de donn' "$F"; }
c2() {
  c1 || return 1
  grep -Eqi '0\.0\.0\.0/0|internet|public|publique|ouvert|monde|exposé|expose|any' "$F" || return 1
  grep -Eqi '10\.20|restreindre|restreint|limiter|limit|bastion|vpn|source_security_group|security group|groupe de s|priv|réseau applicatif|reseau applicatif|cidr|revert|annuler|refuser|rejeter|bloquer|supprimer' "$F"
}
chk "ressource et exposition identifiées" c1
chk "risque et correction décrits" c2
step_end
