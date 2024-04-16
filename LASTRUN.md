# LAST RUN:

```
reset && time vagrant up --provider virtualbox ;
```

Version & brief details of last run near to the time of last commit.

```
real	1m25.957s  # 3m2.490s  # 5m16.617s  # 4m26.931s


2024-04-16 @ 13:29 ;
Linux 6.1.0-17-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.1.69-1 (2023-12-30) GNU/Linux Description:	Debian GNU/Linux 12 (bookworm) ;
CPU: 8-core AMD Ryzen 7 7735HS with Radeon Graphics (-MT MCP-) speed/min/max: 2542/1600/4828 MHz;
VirtualBox: 7.0.14r161095 ;
Vagrant 2.4.0 ;

Linux 6.1.0-20-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.1.85-1 (2024-04-11) GNU/Linux Description:	Debian GNU/Linux 12 (bookworm) ;
Vault v1.16.1+ent.hsm (701619211bec617b605d42551425168c88316ecf), built 2023-09-11T23:05:20Z (cgo);
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
