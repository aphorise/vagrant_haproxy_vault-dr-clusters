#!/usr/bin/env bash
set -eu ; # abort this script when a command fails or an unset variable is used.

# // defaults:
if [[ ! ${HOME_PATH+x} ]] ; then HOME_PATH=$(getent passwd "$USER" | cut -d: -f6 ) ; fi ;
if [[ ! ${VAULT_ADDR+x} ]] ; then export VAULT_ADDR=$(grep -F VAULT_ADDR ${HOME_PATH}/.bashrc | cut -d'=' -f2) ; fi ;
if [[ ! ${VAULT_TOKEN+x} ]] ; then export VAULT_TOKEN=$(grep -F VAULT_TOKEN ${HOME_PATH}/.bashrc | cut -d'=' -f2) ; fi ;
if [[ ! ${VAULT_NODENAME+x} ]]; then VAULT_NODENAME=$(hostname) ; fi ;

SIZE_KB='32M' ;  # // use default 32Mb for nodes 2, 3, etc.
if [[ ${VAULT_NODENAME} == *"1" ]] ; then SIZE_KB='17k' ; fi ;

sudo mkdir /mnt/ramfs ;
sudo mount -t tmpfs -o size=${SIZE_KB} vaudit /mnt/ramfs ;

if [[ ${VAULT_NODENAME} == *"1" ]] ; then vault audit enable file file_path=/mnt/ramfs/vaudit.json ; fi ;
if (($? == 0)) ; then
    printf 'ENABLED File Audits on RamFS.\n' ;
else
    printf 'ERROR Enabling File Audits on RamFS.\n' ;
fi ;
