# HashiCorp `vagrant` demo of HAProxy with **`vault`** DR-Primary & DR-Secondary clusters

**See: [LASTRUN.md for details of most recent tests](LASTRUN.md).**

The same as the [MAIN branch](main/README.md) - built on :apple: Apple Silicon (ARM64) and MacOS with VMWare fusion (as opposed to VirtualBox).


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
 - [:apple: **macOS** (aka OSX) Fusion 13](https://www.vmware.com/products/fusion.html) for Apple Silicon (M1, M2 / M3).
 - [**Vagrant**](https://www.vagrantup.com/)
 - **OPTIONAL**: :lock: An [enterprise license](https://www.hashicorp.com/products/vault/pricing/) is needed [for DR / replication Support](https://www.vaultproject.io/docs/enterprise) :lock:


## Usage & Workflow
Refer to the contents of **`Vagrantfile`** & ensure network IP ranges specific to your setting then `vagrant up`.

To use Vault Enterprise ensure that a license `vault_license.txt` is set in directory for each cluster **`vault_files_dr-primary/`** as well as **`vault_files_dr-secondary/`** and that the template is adjusted with version specifics as documented in the `Vagrantfile` - eg: `VV1='VAULT_VERSION='+'1.10.4+ent'` ***prior to performing*** `vagrant up`.

```bash
vagrant up --provider vmware_desktop ;
# // ... output of provisioning steps.

vagrant global-status ; # should show running nodes

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
vagrant box remove -f aphorise/debian12-arm64 --provider vmware_desktop ; # ... delete box images
```

## Notes
This is intended as a mere practise / training exercise.

### Reference material:

 - [github.com/aphorise/hashicorp.vagrant_vault-dr](https://github.com/aphorise/hashicorp.vagrant_vault-dr)
 - [github.com/aphorise/hashicorp.vagrant_vault-hsm](https://github.com/aphorise/hashicorp.vagrant_vault-hsm)

------
