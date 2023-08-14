#!/bin/bash
export DEBIAN_FRONTEND=noninteractive ;
set -eu ; # abort this script when a command fails or an unset variable is used.
#set -x ; # echo all the executed commands.

# Repair "==> default: stdin: is not a tty" message
sudo ex +"%s@DPkg@//DPkg" -cwq /etc/apt/apt.conf.d/70debconf ;
sudo dpkg-reconfigure debconf -f noninteractive -p critical ;

echo "LC_ALL=en_US.UTF-8" >> /etc/environment
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "LC_ALL=en_US.UTF-8" >> /etc/environment
export LANGUAGE=en_US.UTF-8 ;
export LANG=en_US.UTF-8 ;
locale-gen en_US.UTF-8 > /dev/null 2>&1 && dpkg-reconfigure locales > /dev/null 2>&1 ;
printf "OS LOCALS / LANG: '${LANGUAGE}' set.\n" ;
#export LC_ALL=en_US.UTF-8 ;

# // persist journal entries between reboots:
mkdir -p /var/log/journal && chown root:adm /var/log/journal ;
#sed -i 's/^#Storage=auto/Storage=auto/g' /etc/systemd/journald.conf ;

UNAME="$(uname -ar)" ;
# // OS Version specific apps missing:
# PKG_UBUNTU='realpath' ; # if [[ ${UNAME} == *"Ubuntu"* ]] ; then sudo apt-get update > /dev/null && sudo apt-get install -yq ${PKG_UBUNTU} > /dev/null ; fi ;
# // common utils & build tools: make, cpp, etc.
PKGS="locales rsync hdparm policykit-1 unzip curl htop screen tmux jq build-essential libssh-dev bc glances fio sysstat linux-perf net-tools ack" ;
PKGS="${PKGS}" ;  # ${PKG_UBUNTU} any-other-packages" ;
printf "OS INSTALLING: ${PKGS:0:62} ...\n" ;
sudo apt-get update > /dev/null && apt-get install -yq ${PKGS} > /dev/null ;

# // .bashrc profile alias and history settings.
sBASH_DEFAULT='''
SHELL_SESSION_HISTORY=0
export HISTSIZE=1000000
export HISTFILESIZE=100000000
export HISTCONTROL=ignoreboth:erasedups
PROMPT_COMMAND="history -a;$PROMPT_COMMAND"
alias ack="ack -i --color-match=\"bold white on_red\""
alias nano="nano -c"
alias grep="grep --color=auto"
alias ls="ls --color=auto"
alias dir="dir --color=auto"
alias reset="reset; stty sane; tput rs1; clear; echo -e \\"\033c\\""
alias jv="sudo journalctl -u vault.service --no-pager -f --output cat"
alias jreset="sudo journalctl --rotate && sudo journalctl --vacuum-time=1s"
''' ;
printf "${sBASH_DEFAULT}" >> ~/.bashrc ;
if [[ $(logname) != $(whoami) ]] ; then printf "${sBASH_DEFAULT}" >> /home/$(logname)/.bashrc ; fi ;
printf 'BASH: defaults in (.bashrc) profile set.\n' ;

## // package source mirrors to allow for obtaining os & version specific software:
## // default main or stable apps
#sudo cp /etc/apt/sources.list /etc/apt/sources.list.d/unstable.list
#if [[ ${UNAME} == *"Debian"* ]] ; then
#	printf 'APT::Default-Release "stable";\n' > /etc/apt/apt.conf.d/99defaultrelease ;
#	PKG_TRG='unstable' ;
#	PKG_SRC="$(grep -E '#|deb-src|security|^$' -v /etc/apt/sources.list.d/unstable.list)" ;
#	PKG_SRC=${PKG_SRC/debian[[:space:]]*/'debian unstable main'} ;
#elif [[ ${UNAME} == *"Ubuntu"* ]] ; then
#	PKG_TRG='groovy' ;
#	set +e ;  # // disbale errors
#	PKG_SRC="$(grep -E '#|deb-src|security|^$' -v /etc/apt/sources.list.d/unstable.list | grep 'bionic universe')" ;
#	set -e ;  # // re-enable errors
#	if ! [[ ${PKG_SRC} == "" ]] ; then
#		PKG_SRC=${PKG_SRC/'ubuntu bionic'/'ubuntu groovy main '} ;
#	else
#		PKG_SRC="$(grep -E '#|deb-src|security|^$' -v /etc/apt/sources.list.d/unstable.list | grep -E 'ubuntu\ \w+\ universe')" ;
#		PKG_SRC=${PKG_SRC/'ubuntu focal'/'ubuntu groovy main '} ;
#	fi ;
#else
#	printf "\e[31mERROR: Linux OS / Distribution not recognited - only Debian or Ubuntu are currently supported.\e[0m" ; exit 1 ;
#fi ;
#printf "# // UNSTABLE sources (for latest apps 2.6+):\n${PKG_SRC}\n" > /etc/apt/sources.list.d/unstable.list ;
#apt-get update > /dev/null 2>&1 ;
