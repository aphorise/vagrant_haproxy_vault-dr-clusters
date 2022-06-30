#!/usr/bin/env bash
# // DONT EXECUTE if NOT Enterprise Vault.
VVERSION=$(vault --version) ; if ! [[ ${VVERSION} == *"ent"* ]] ; then exit 0 ; fi ;

# // logger
function pOUT() { printf "$1\n" ; } ;

# // Colourised logger for errors (red)
function pERR()
{
	# sMSG=${1/@('ERROR:')/"\e[31mERROR:\e[0m"} ; sMSG=${1/('ERROR:')/"\e[31mERROR:\e[0m"}
	if [[ $1 == "--"* ]] ; then pOUT "\e[31m$1\n\e[0m\n" ;
	else pOUT "\n\e[31m$1\n\e[0m\n" ; fi ;
}

VVERSION=$(vault --version) ;
if ! [[ ${VVERSION} == *"ent"* ]] ; then
	pERR "VAULT ENTERPRISE REQUIRED! - but found: ${VVERSION}\n" ; exit 1 ;
fi ;

# // VAULT_TOKEN ought to exist by now from either init or copy from vault1:
if [[ ${VAULT_TOKEN} == "" ]] ; then VAULT_TOKEN=$(grep -F VAULT_TOKEN ${HOME_PATH}/.bashrc | cut -d'=' -f2) ; fi ;
if [[ ${VAULT_TOKEN} == "" ]] ; then pERR 'VAULT ERROR: No Token Found.' ; exit 1 ; fi ;

DR_TOKEN="$(cat vault_token_dr.json | jq -r '.wrap_info.token')" ;
if [[ ${DR_TOKEN} == "" ]] ; then pERR 'VAULT ERROR: DR Token NOT Found.' ; exit 1 ; fi ;

vault write /sys/replication/dr/secondary/enable token=${DR_TOKEN} 2> /dev/null ;
if (($? == 0)) ; then pOUT 'VAULT: SECONDARY-DR Replication Token Accepted.' ;
else pERR 'VAULT ERROR: Applying SECONDARY-DR token.' ; fi ;

# // invoke manually
#VAULT_TOKEN_DR_BATCH="$(cat vault_token_dr_batch.json | jq -r '.auth.client_token')" ;
#vault write /sys/replication/dr/secondary/promote dr_operation_token=${VAULT_TOKEN_DR_BATCH} ;
