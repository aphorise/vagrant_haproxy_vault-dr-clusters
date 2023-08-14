#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive ;
set -eu ; # abort this script when a command fails or an unset variable is used.
#set -x ; # echo all the executed commands.
UNAME="$(uname -ar)" ;
# should have already installed: build-essential libssh-dev; but will re-request
PKGS="build-essential libssh-dev opensc" ;  # // minimal set for building or using SoftHSM
PKGS_HSM="${PKGS}" ;
# libltdl7 libsofthsm2 softhsm2 opensc" ;  # // to use older stable release < softhsm 2.4 with Vault 1.2 maybe?
printf "OS INSTALLING: ${PKGS_HSM} ...\n" ;
sudo apt-get update > /dev/null && apt-get install -yq ${PKGS_HSM} > /dev/null ;

# // package source mirrors to allow for obtaining os & version specific software:
# // default main or stable apps
sudo cp /etc/apt/sources.list /etc/apt/sources.list.d/unstable.list ;
if [[ ${UNAME} == *"Debian"* ]] ; then
:;
	#printf 'APT::Default-Release "stable";\n' > /etc/apt/apt.conf.d/99defaultrelease ;
	#PKG_TRG='unstable' ;
	#PKG_SRC="$(grep -E '#|deb-src|security|^$' -v /etc/apt/sources.list.d/unstable.list)" ;
	#PKG_SRC=${PKG_SRC/debian[[:space:]]*/'debian unstable main'} ;
elif [[ ${UNAME} == *"Ubuntu"* ]] ; then
	PKG_TRG='groovy' ;
	set +e ;  # // disbale errors
	PKG_SRC="$(grep -E '#|deb-src|security|^$' -v /etc/apt/sources.list.d/unstable.list | grep 'bionic universe')" ;
	set -e ;  # // re-enable errors
	if ! [[ ${PKG_SRC} == "" ]] ; then
		PKG_SRC=${PKG_SRC/'ubuntu bionic'/'ubuntu groovy main '} ;
	else
		PKG_SRC="$(grep -E '#|deb-src|security|^$' -v /etc/apt/sources.list.d/unstable.list | grep -E 'ubuntu\ \w+\ universe')" ;
		PKG_SRC=${PKG_SRC/'ubuntu focal'/'ubuntu groovy main '} ;
	fi ;
else
	printf "\e[31mERROR: Linux OS / Distribution not recognited - only Debian or Ubuntu are currently supported.\e[0m" ; exit 1 ;
fi ;
#printf "# // UNSTABLE sources (for softhsm2 2.6+):\n${PKG_SRC}\n" > /etc/apt/sources.list.d/unstable.list ;
apt-get update > /dev/null 2>&1 ;
printf "OS INSTALLING: softhsm2 ...\n" ;
apt-get -yq install softhsm2 > /dev/null ;

# // DOWNLOAD, BUILD & INSTALL SoftHSM from source
#HSM_SOFT_VERSION='2.6.1' ;
#HSM_URL='https://dist.opendnssec.org/source/' ;
#HSM_PATH="softhsm-${HSM_SOFT_VERSION}" ;
#HSM_FILE="${HSM_PATH}.tar.gz" ;
#HSM_URL_FULL="${HSM_URL}${HSM_FILE}" ;
#printf "DOWNLOADING: ${HSM_URL_FULL}\n" ;
#wget -q "${HSM_URL_FULL}" ;
#tar -xzf ${HSM_FILE} ;
#cd ${HSM_PATH} ;
#printf "BUILDING: SoftHSM ${HSM_SOFT_VERSION} ...\n" ;
#./configure > /dev/null 2>&1 ;
#make > /dev/null 2>&1 && sudo make install > /dev/null 2>&1 ;
#if (($? == 0)) ; then printf "INSTALLED: SoftHSM ${HSM_SOFT_VERSION}\n" ; fi ;
## // cli testing hsm module
## // pkcs11-tool --module /usr/local/lib/softhsm/libsofthsm2.so -l -t ;
