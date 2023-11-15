# LAST RUN:

```
reset && time vagrant up --provider virtualbox ;
```

Version & brief details of last run near to the time of last commit.

```
real	3m2.490s  # 5m16.617s  # 4m26.931s

2023-11-15 @ 12:11 ;
Linux 6.1.0-11-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.1.38-4 (2023-08-08) GNU/Linux Description:	Debian GNU/Linux 12 (bookworm) ;
CPU: 8-core AMD Ryzen 7 7735HS with Radeon Graphics (-MT MCP-) speed/min/max: 1991/1600/4828 MHz;
VirtualBox: 7.0.10r158379 ;
Vagrant 2.3.7 ;

Linux 6.1.0-10-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.1.38-1 (2023-07-14) GNU/Linux Description:	Debian GNU/Linux 12 (bookworm) ;
Vault v1.15.2+ent.hsm (8b6cdc3100961bfd91cf03cfb5eaa0a2448199b5), built 2023-11-07T13:52:33Z (cgo);
```


## Host Machine - To Run:

```bash
VD=$(date "+%F @ %H:%M")
# // brew install inxi # OR apt-get install inxi
VOS=$(uname -orsv) ; if [[ ${VOS} == *"Darwin"* ]] ; then VOS+=" macOS $(sw_vers | grep 'ProductVersion')" ; elif [[ ${VOS} == *"Linux"* ]] ; then VOS+=" $(lsb_release -a | grep Description)" ; fi ;
VVBOX="VirtualBox: $(vboxmanage --version)" ;
VVAGR="$(vagrant --version)" ;
VCPU=$(inxi -c 2>/dev/null | grep CPU) ;
printf "\n$VD ;\n${VOS} ;\n${VCPU};\n${VVBOX} ;\n${VVAGR} ;\n\n" ;
```


## VM Node - To Run:

```bash
vagrant ssh dr1primary-vault1 -c 'VOS=$(uname -orsv) ; VOS+=" $(lsb_release -a 2>/dev/null | grep Description)" ; VVAULT="$(vault --version)" ; printf "\n${VOS} ;\n${VVAULT};\n\n" ;'
```
