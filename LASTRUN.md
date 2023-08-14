# LAST RUN:

```
reset && time vagrant up --provider virtualbox ;
```

Version & brief details of last run near to the time of last commit.

```
real	4m26.931s
user	0m6.755s
sys	0m7.892s

2023-08-14 @ 16:12 ;
Linux 6.1.0-11-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.1.38-4 (2023-08-08) GNU/Linux Description:	Debian GNU/Linux 12 (bookworm) ;
CPU: 8-core AMD Ryzen 7 7735HS with Radeon Graphics (-MT MCP-) speed/min/max: 1903/1600/4828 MHz;
VirtualBox: 7.0.10r158379 ;
Vagrant 2.3.7 ;

Linux 5.10.0-22-amd64 #1 SMP Debian 5.10.178-3 (2023-04-22) GNU/Linux Description:	Debian GNU/Linux 11 (bullseye) ;
Vault v1.14.1+ent.hsm (1b45cddc7a6e5a6b2c7b9f3fe988819d0c4b2dc5), built 2023-07-21T23:04:42Z (cgo);
```

## Host Machine - To Run:
```

VD=$(date "+%F @ %H:%M")
# // brew install inxi # OR apt-get install inxi
VOS=$(uname -orsv) ; if [[ ${VOS} == *"Darwin"* ]] ; then VOS+=" macOS $(sw_vers | grep 'ProductVersion')" ; elif [[ ${VOS} == *"Linux"* ]] ; then VOS+=" $(lsb_release -a | grep Description)" ; fi ;
VVBOX="VirtualBox: $(vboxmanage --version)" ;
VVAGR="$(vagrant --version)" ;
VCPU=$(inxi -c 2>/dev/null | grep CPU) ;
printf "\n$VD ;\n${VOS} ;\n${VCPU};\n${VVBOX} ;\n${VVAGR} ;\n\n" ;
```

## VM Node - To Run:
```
vagrant ssh dr1primary-vault1 -c 'VOS=$(uname -orsv) ; VOS+=" $(lsb_release -a 2>/dev/null | grep Description)" ; VVAULT="$(vault --version)" ; printf "\n${VOS} ;\n${VVAULT};\n\n" ;'
```
