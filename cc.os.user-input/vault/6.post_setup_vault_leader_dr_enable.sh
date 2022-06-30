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

if [[ ${VAULT_TOKEN} == "" ]] ; then
	# // VAULT_TOKEN ought to exist by now from either init or copy from vault1:
	VAULT_TOKEN=$(grep -F VAULT_TOKEN ${HOME_PATH}/.bashrc | cut -d'=' -f2) ;
fi ;

if [[ ${VAULT_TOKEN} == "" ]] ; then pERR 'VAULT ERROR: No Token Found.\n' ; exit 1 ; fi ;

vault write -f sys/replication/dr/primary/enable > /dev/null 2>&1 ;
if (($? == 0)) ; then pOUT 'VAULT: DR Successfully set "sys/replication/dr/primary/enable"' ;
else pERR 'VAULT ERROR: Setting "sys/replication/dr/primary/enable"' ; fi ;

vault write sys/replication/dr/primary/secondary-token -format=json id=hsm2 2>/dev/null > vault_token_dr.json
if (($? == 0)) ; then pOUT 'VAULT: DR Replication "secondory-Token" generated.' ;
else pERR 'VAULT ERROR: Generating DR Replication "secondory-Token"' ; fi ;

vault policy write dr2promotion >/dev/null - <<EOF
path "*" {
	capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
#path "sys/replication/dr/secondary/promote" {
#	capabilities = [ "update" ]
#}
EOF
if (($? == 0)) ; then pOUT 'VAULT: DR Successfully writen "promote" policy write.' ;
else pERR 'VAULT ERROR: Unable to write policy "promote"' ; fi ;

vault write auth/token/roles/failsafe allowed_policies=dr2promotion orphan=true renewable=false token_type=batch >/dev/null ;
if (($? == 0)) ; then pOUT 'VAULT: DR "auth/token/roles/failsafe" writen.' ;
else pERR 'VAULT ERROR: Unable to write  "auth/token/roles/failsafe"' ; fi ;

vault token create -format=json -role=failsafe > vault_token_dr_batch.json ;
if (($? == 0)) ; then pOUT 'VAULT: DR Successfully created dr-token.' ;
else pOUT 'VAULT ERROR: Unable to create dr-token"' ; fi ;
