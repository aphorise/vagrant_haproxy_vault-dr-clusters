# HashiCorp `vagrant` demo of **`vault`** DR-Primary & DR-Secondary.

Undo Logs were introduced in Vault 1.12 and helps prevent the breaking of replication on the Secondary (PR / DR) clusters that typically resulted in a permanent `merkle-sync` where currently (in 1.12 or lower) without Undo Logs the only resolution is to re-attempt the impacted Secondary clusters anew (de novo).

To enabled or use Undo Logs set or Launch Vault with the Environment Variable:

```
# // in-line
VAULT_REPLICATION_USE_UNDO_LOGS=true vault server ...

#// or exported already
export VAULT_REPLICATION_USE_UNDO_LOGS=true ;
vault server ...
```

Vault 1.13 is expected to have Undo Logs enabled by default.

Where **Consul** is used as a backend store for Vault - then it must be on Consul 1.14 or higher; related improvements are anticipated in Vault 1.13 where recent Consul 1.14.3 & higher 
is used then may be more suitable to consider evaulating those later versions instead.

**NOTE:**: Place license in `vault_license.txt` for each respective cluster.


## Usage & Workflow

```bash
vagrant up --provider virtualbox ;
# // ... output of provisioning steps.

# // On a separate Terminal session ssh to `dr2secondary-vault1`
vagrant ssh dr2secondary-vault1
  # ...

# // check details of undo logs in Vault log:
sudo journalctl -u vault --no-pager | ack -i --passthru --color-match="bold white on_red" undo

# // check speeds of blockmount device with limited IOPS that's to be used:
cat storage_perf.txt
  # /dev/mapper/dm-slow:
  #  Timing cached reads:     2 MB in  5.14 seconds = 398.11 kB/sec
  #  Timing buffered disk reads:   2 MB in  4.94 seconds = 414.90 kB/sec

sudo service vault stop
  # ...
cp -r /vault /mnt/blockdev/.
  # ...

# // change /etc/vault.d/vault.hcl to use block device
nano /etc/vault.d/vault.hcl

sudo service vault restart
jv  # // follow journalctl logs for vault

# // on another terminal of same host `dr2secondary-vault1`
watch "vault read -format=json sys/replication/dr/status | jq"
# // ^^ can repeat above concurrently on `dr1primary-vault1` too
```

------
