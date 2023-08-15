# HashiCorp `vagrant` demo of HAProxy with **`vault`** DR-Primary & DR-Secondary clusters

**See: [LASTRUN.md for details of most recent tests](LASTRUN.md).**

This repo is a mock example of two Vault clusters which are serviced by their respective HAProxy Load-Balancer using `X-Forward-For`.

It's possible to use [Vault HSM Enterprise](https://www.vaultproject.io/docs/enterprise/hsm) with [SoftHSM](https://www.opendnssec.org/softhsm/) as an [auto-unseal type is possible](https://www.vaultproject.io/docs/configuration/seal/pkcs11) as detailed below.

:memo: Past tests on **X86 / AMD64** hosts with Windows (10 & 11) & Linux (Debian 11 & macOS 12.4) using VirtualBox 6.1.34 r150636 + Vagrant 2.2.19 & earlier. :memo:
 

## Makeup & Concept

Two sets of Vault clusters are deployed which are labelled as `dr1primary` & `dr2secondary` each with a HAProxy (Layer7) reverse proxy managing request from end-users or another Vault clusters. The address of the LB in each cluster is the configured as HCL High Availability parameters `` & `` for all the nodes in each cluster

Once successfully launched visit IPs including:
 - dr1primary HAProxy [http://192.168.178.254:60100](http://192.168.178.254:60100)
 - dr2secondary HAProxy [http://192.168.178.253:60100](http://192.168.178.253:60100)

```
                        VAULT SYS 💻 / USER 😎 REQUESTS
              ▒.................................................▒ 
______________|____________________ 🌍 WAN  ____________________|______________
 API (80,443)╲  ╲ TCP RPC (8200)  |   /    |    TCP RPC (8200)╱  ╱API (80,443)
              ╲  ╲                |  NET   |                 ╱  ╱              
 dr1primary   254.╦═════════════╦ |        | ╓══════════════╦.253  dr2secondary           
                ║ load-balancer ║ |        | ║ load-balancer ║                 
     backend    ║   (haproxy)   ║ |        | ║   (haproxy)   ║    backend      
 ,============. ╚╩═════════════╩╝ |        | ╚╩═════════════╩╝ ,============.  
 |  servers   |          ║        |        |         ║         |  servers   |  
 |.----------.|         ▲▼        |        |         ▲▼        |.----------.|  
 || v1 v2 v3 ||◄► ══ ◄► ═╝        |        |         ╚═◄► ══ ◄►|| v1 v2 v3 ||  
 |'----------'|                   |        |                   |'----------'|  
 | |||||||||| |.183, .182, .181...|        |...173, .172, .171 | |||||||||| |  
 |============|-  RPC & API       |        |        RPC & API -|============|  
__________________________________|        |___________________________________
v1 = vault1, etc...
```


## Prerequisites
The hardware & software requirements needed to use this repo is listed below.
 
#### HARDWARE & SOFTWARE
 - **RAM** **8**+ Gb Free minimum - more if with Consul.
 - **CPU** **8**+ Cores Free minimum - more if with Consul.
 - **Network** interface allowing IP assignment and interconnection in VirtualBox bridged mode for all instances.
 - - adjust `sNET='en0: Wi-Fi (Wireless)'` in **`Vagrantfile`** to match your system.
 - [**Virtualbox**](https://www.virtualbox.org/) with [Virtualbox Guest Additions (VBox GA)](https://download.virtualbox.org/virtualbox/) correctly installed.
 - [**Vagrant**](https://www.vagrantup.com/)
 - **OPTIONAL**: :lock: An [enterprise license](https://www.hashicorp.com/products/vault/pricing/) is needed for [HSM Support](https://www.vaultproject.io/docs/enterprise/hsm) :lock:


## Usage & Workflow
Refer to the contents of **`Vagrantfile`** & ensure network IP ranges specific to your setting then `vagrant up`.

To use Vault Enterprise HSM ensure that a license `vault_license.txt` is set in directory for each cluster **`vault_files_dr-primary/`** as well as **`vault_files_dr-secondary/`** and that the template is adjusted with version specifics as documented in the `Vagrantfile` - eg: `VV1='VAULT_VERSION='+'1.10.4+ent.hsm'` ***prior to performing*** `vagrant up`.

```bash
vagrant up --provider virtualbox ;
# // ... output of provisioning steps.

vagrant global-status ; # should show running nodes
  # id       name        provider   state   directory
  # -------------------------------------------------------------------------------------
  # 6127f10  dr1primary-haproxy   virtualbox running /home/auser/hashicorp.vagrant_haproxy_vault-dr-clusters
  # c389198  dr1primary-vault1    virtualbox running /home/auser/hashicorp.vagrant_haproxy_vault-dr-clusters
  # 7d3bb3a  dr1primary-vault2    virtualbox running /home/auser/hashicorp.vagrant_haproxy_vault-dr-clusters
  # 893d929  dr1primary-vault3    virtualbox running /home/auser/hashicorp.vagrant_haproxy_vault-dr-clusters
  # 82f6a8b  dr2secondary-haproxy virtualbox running /home/auser/hashicorp.vagrant_haproxy_vault-dr-clusters
  # 200a2a4  dr2secondary-vault1  virtualbox running /home/auser/hashicorp.vagrant_haproxy_vault-dr-clusters
  # 8259c6d  dr2secondary-vault2  virtualbox running /home/auser/hashicorp.vagrant_haproxy_vault-dr-clusters
  # 28261c9  dr2secondary-vault3  virtualbox running /home/auser/hashicorp.vagrant_haproxy_vault-dr-clusters

vagrant ssh dr1primary-vault1
  # ...
#vagrant@dr1primary-vault1:~$ \
vault status
vault read sys/replication/status -format=json ;
vault read sys/replication/dr/status -format=json ;


# // On a separate Terminal session check status of 2nd Vault cluster.
vagrant ssh dr2secondary-vault1
  # ...
#vagrant@dr2secondary-vault1:~$ \
vault status
VAULT_TOKEN_DR_BATCH=$(cat vault_token_dr_batch.json | jq -r '.auth.client_token') ;
vault operator raft list-peers -dr-token=$VAULT_TOKEN_DR_BATCH ;  # curl -k -X PUT -H "X-Vault-Token: ${VAULT_TOKEN}" -d '{"dr_operation_token":"'$VAULT_TOKEN_DR_BATCH'"}' ${VAULT_ADDR}/v1/sys/storage/raft/configuration ;
# // PROMOTE dr2 cluster as
VAULT_TOKEN_DR_BATCH=$(cat vault_token_dr_batch.json | jq -r '.auth.client_token') ;
vault write /sys/replication/dr/secondary/promote dr_operation_token=${VAULT_TOKEN_DR_BATCH} ;


exit ;
# // ---------------------------------------------------------------------------
# when completely done:
vagrant destroy -f ;
vagrant box remove -f debian/bullseye64 --provider virtualbox ; # ... delete box images
```

## Notes
This is intended as a mere practise / training exercise.

### Reference material:

 - [github.com/aphorise/hashicorp.vagrant_vault-dr](https://github.com/aphorise/hashicorp.vagrant_vault-dr)
 - [github.com/aphorise/hashicorp.vagrant_vault-hsm](https://github.com/aphorise/hashicorp.vagrant_vault-hsm)

------
