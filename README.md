# HashiCorp `vagrant` demo of **`vault`** DR-Primary & DR-Secondary.

It is not clear currently (1.9.0) how to raft list-peers on a DR-Secondary after it's setup.

**NOTE:**: Place license in `vault_license.txt` for each respective cluster.


## Usage & Workflow

```bash
vagrant up --provider virtualbox ;
# // ... output of provisioning steps.

# // On a separate Terminal session check status of vault2 & cluster.
vagrant ssh dr2secondary-vault1
  # ...

VAULT_TOKEN_DR_BATCH=$(cat vault_token_dr_batch.json | jq -r '.auth.client_token') ;

VAULT_TOKEN=$VAULT_TOKEN_DR_BATCH vault operator raft list-peers ;
  # Error reading the raft cluster configuration: Error making API request.
  # 
  # URL: GET https://192.168.178.243:8200/v1/sys/storage/raft/configuration
  # Code: 400. Errors:
  # 
  # * path disabled in replication DR secondary mode

curl -k -L -H "X-Vault-Token: $VAULT_TOKEN_DR_BATCH" ${VAULT_ADDR}/v1/sys/storage/raft/configuration ;
  # {"errors":["path disabled in replication DR secondary mode"]}
```

## Reference material:

 - [aphorise/hashicorp.vagrant_vault-hsm](https://github.com/aphorise/hashicorp.vagrant_vault-hsm)

------
