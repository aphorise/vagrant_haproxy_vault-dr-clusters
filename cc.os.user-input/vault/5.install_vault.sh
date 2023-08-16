#!/usr/bin/env bash
set -eu ; # abort this script when a command fails or an unset variable is used.
#set -x ; # echo all the executed commands.
if [[ ${1-} ]] && [[ (($# == 1)) || $1 == "-h" || $1 == "--help" || $1 == "help" ]] ; then
printf """Usage: VARIABLE='...' ${0##*/} [OPTIONS]
Installs HashiCorp Vault & can help setup services.

By default this script only downloads & copies binaries where no inline SETUP
value is provided ('server').

Some of the inline variables and values that can be set are show below.

For upto date & complete documentation of Vault see: https://www.vaultproject.io/

VARIABLES:
		SETUP='' # // default just download binary otherwise 'server'
		VAULT_VERSION='' # // default LATEST - '1.10.4+ent' for enterprise or oss by default.
		IP_WAN_INTERFACE='eth1' # // default for cluster_address uses where not set eth1.

EXAMPLES:
		SETUP='server' ${0##*/} ;
		# install latest vault version setting up systemd services too.

		SETUP='server' IP_WAN_INTERFACE='eth0' ${0##*/} ;
		# Use a differnt interface ip for vault cluster_address binding.

${0##*/} 0.0.8haproxy_dr-v1.10.4					28 June 2022
""" ;
fi ;

# // logger
function pOUT() { printf "$1\n" ; } ;

# // Colourised logger for errors (red)
function pERR()
{
	# sMSG=${1/@('ERROR:')/"\e[31mERROR:\e[0m"} ; sMSG=${1/('ERROR:')/"\e[31mERROR:\e[0m"}
	if [[ $1 == "--"* ]] ; then pOUT "\e[31m$1\n\e[0m\n" ;
	else pOUT "\n\e[31m$1\n\e[0m\n" ; fi ;
}

if ! which curl 2>&1>/dev/null ; then pERR 'ERROR: curl utility missing & required. Install & retry again.' ; exit 1 ; fi ;
if ! which unzip 2>&1>/dev/null ; then pERR 'ERROR: unzip utility missing & required. Install & retry again.' ; exit 1 ; fi ;

if [[ ! ${SETUP+x} ]]; then SETUP='server' ; fi ; # // default 'server' setup or change to 'client'
if [[ ! ${USER_MAIN+x} ]] ; then USER_MAIN=$(logname) ; fi ; # // root user executing this script as sudo for example.
if [[ ! ${USER_VAULT+x} ]] ; then USER_VAULT='vault' ; fi ; # // default vault (daemon) user.
if [[ ! ${HOME_PATH+x} ]] ; then HOME_PATH=$(getent passwd "$USER" | cut -d: -f6 ) ; fi ;
if [[ ! ${VAULT_INIT_FILE+x} ]] ; then VAULT_INIT_FILE="${HOME_PATH}/vault_init.json" ; fi ;
if [[ ! ${VAULT_TOKEN_INIT+x} ]]; then VAULT_TOKEN_INIT="${HOME_PATH}/vault_token.txt" ; fi ; # // where initial root token will be temporarily saved (output from Vault)
if [[ ! ${VAULT_PRIMARY_INIT_PR+x} ]]; then VAULT_PRIMARY_INIT_PR="${HOME_PATH}/vault_init.json" ; fi ;  # // DR-Primary init tokens.

if [[ ! ${VAULT_CLUSTER_NAME+x} ]] ; then VAULT_CLUSTER_NAME='cluster_name = "primary"' ; else VAULT_CLUSTER_NAME="cluster_name = \"${VAULT_CLUSTER_NAME}\"" ; fi ;

if [[ ! ${VAULT_NODENAME+x} ]]; then VAULT_NODENAME=$(hostname) ; fi ; # // will be based on hostname *1 == main, others standby.

if [[ ! ${URL_VAULT+x} ]]; then URL_VAULT='https://releases.hashicorp.com/vault/' ; fi ;
if [[ ! ${VAULT_VERSION+x} ]]; then VAULT_VERSION='' ; fi ; # // VERSIONS: "1.3.2' for OSS, '1.3.2+ent' for Enterprise, '1.3.2+ent.hsm' for Enterprise with HSM.
if [[ ! ${OS_CPU+x} ]]; then OS_CPU='' ; fi ; # // ARCH CPU's: 'amd64', '386', 'arm64' or 'arm'.
if [[ ! ${OS_VERSION+x} ]]; then OS_VERSION=$(uname -ar) ; fi ; # // OS's: 'Darwin', 'Linux', 'Solaris', 'FreeBSD', 'NetBSD', 'OpenBSD'.
if [[ ! ${PATH_INSTALL+x} ]]; then PATH_INSTALL="$(pwd)/vault_installs" ; fi ; # // where vault install files will be.

if [[ ! ${SYSD_FILE+x} ]]; then SYSD_FILE='/etc/systemd/system/vault.service' ; fi ; # name of SystemD service for vault.
if [[ ! ${PATH_VAULT+x} ]]; then PATH_VAULT="/etc/vault.d" ; fi ; # // Vault Daemon Path where configuration & files are to reside.
if [[ ! ${PATH_BINARY+x} ]]; then PATH_BINARY='/usr/local/bin/vault' ; fi ; # // Target binary location for vault executable.
if [[ ! ${PATH_VAULT_CONFIG+x} ]]; then PATH_VAULT_CONFIG="${PATH_VAULT}/vault.hcl" ; fi ; # // Main vault config.
if [[ ! ${PATH_VAULT_DATA+x} ]]; then PATH_VAULT_DATA="/vault/data" ; fi ; # // Where local storage is used local data path.

if [[ ! ${VAULT_RAFT_JOIN+x} ]]; then VAULT_RAFT_JOIN="" ; fi ;

if [[ ! ${VAULT_PORT_API+x} ]]; then VAULT_PORT_API="8200" ; fi ;
if [[ ! ${VAULT_PORT_CLUSTER+x} ]]; then VAULT_PORT_CLUSTER="8201" ; fi ;

if [[ ! ${IP_LB_INTERFACE+x} ]]; then IP_LB_INTERFACE="$(ip a | awk '/: / { print $2 }' | sed -n 4p | cut -d ':' -f1)" ; fi ; # // 2nd interface 'eth2'
if [[ ! ${IP_WAN_INTERFACE+x} ]]; then IP_WAN_INTERFACE="$(ip a | awk '/: / { print $2 }' | sed -n 3p | cut -d ':' -f1)" ; fi ; # // 2nd interface 'eth1'
if [[ ! ${IP_LAN_INTERFACE+x} ]]; then IP_LAN_INTERFACE="$(ip a | awk '/: / { print $2 }' | sed -n 3p | cut -d ':' -f1)" ; fi ; # // 2nd interface 'eth1'

if [[ ! ${IP_LB+x} && ${IP_LB_INTERFACE} != "" ]]; then
	IP_LB="$(ip a show ${IP_LB_INTERFACE} | grep -oE '\b((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b' | head -n 1)" ;
	if (( $? != 0 )) ; then
		pERR "ERROR: Unable to determine LB IP of ${IP_LB_INTERFACE}" ;
	else
		if [[ ${VAULT_API_ADDR+x} ]] ; then sudo ip route add "$(printf ${VAULT_API_ADDR} | cut -d'/' -f3 | cut -d':' -f1)" via ${IP_LB} dev ${IP_LB_INTERFACE} ; fi ;
	fi ;
	

fi ;

if [[ ! ${IP_WAN+x} ]]; then
	IP_WAN="$(ip a show ${IP_WAN_INTERFACE} | grep -oE '\b((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b' | head -n 1)" ;
	if (( $? != 0 )) ; then pERR "ERROR: Unable to determine WAN IP of ${IP_WAN_INTERFACE}" ; fi ;
fi ;

if [[ ! ${IP_LAN+x} ]]; then
	IP_LAN="$(ip a show ${IP_LAN_INTERFACE} | grep -oE '\b((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b' | head -n 1)" ;
	if (( $? != 0 )) ; then pERR "ERROR: Unable to determine LAN IP of ${IP_LAN_INTERFACE}" ; fi ;
fi ;

# // DETERMINE LATEST VERSION - where none are provided.
if [[ ${VAULT_VERSION} == '' ]] ; then
	VAULT_VERSION=$(curl -s ${URL_VAULT} | grep '<a href="/vault/' | grep -v -E 'beta|rc|ent' | head -n 1 | grep -E -o '([0-9]{1,3}[\.]){2}[0-9]{1,3}' | head -n 1) ;
	if [[ ${VAULT_VERSION} == '' ]] ; then
		pERR 'ERROR: Could not determine valid / current vault version to download.' ;
		exit 1 ;
	fi ;
fi ;

if [[ ! ${FILE+x} ]] ; then FILE="vault_${VAULT_VERSION}_" ; fi ; # // to be appended later if not passed.
if [[ ! ${URL+x} ]] ; then URL="${URL_VAULT}${VAULT_VERSION}/" ; fi ; # // to be appended later if not passed.
if [[ ! ${URL2+x} ]] ; then URL2="${URL_VAULT}${VAULT_VERSION}/vault_${VAULT_VERSION}_SHA256SUMS" ; fi ;

set +e ; CHECK=$(vault --version 2>&1) ; set -e ; # // maybe required vault version is already installed.
if [[ ${CHECK} == *"v${VAULT_VERSION}"* ]] && [[ (($# == 0)) || $1 != "-f" || $2 != "-f" ]] ; then pOUT "Vault v${VAULTL_VERSION} already installed; Use '-f' to force this script to run anyway.\nNo action taken." && exit 0 ; fi ;

if ! mkdir -p ${PATH_INSTALL} 2>/dev/null ; then pERR "ERROR: Could not create directory at: ${PATH_INSTALL}"; exit 1; fi ;

if [[ ! ${VAULT_CONF_CLUSTER_NAME+x} ]]; then VAULT_CONF_CLUSTER_NAME='cluster_name = "primary"' ; fi ; # // vault.hcl config. Passed in-line or determined later.
if [[ ! ${VAULT_CONF_TLS_DISABLED+x} ]]; then VAULT_CONF_TLS_DISABLED="	tls_disable      = true" ; fi ; # // vault.hcl config. Passed in-line or determined later.
if [[ ! ${VAULT_CONF_TLS_CERT_FILE+x} ]]; then VAULT_CONF_TLS_CERT_FILE='' ; fi ; # // vault.hcl config. Passed in-line or determined later.
if [[ ! ${VAULT_CONF_TLS_KEY_FILE+x} ]]; then VAULT_CONF_TLS_KEY_FILE='' ; fi ; # // vault.hcl config. Passed in-line or determined later.
if [[ ${VAULT_CONF_CLUSTER_NAME} != 'cluster_name = "'* ]]; then VAULT_CONF_CLUSTER_NAME="cluster_name = \"${VAULT_CONF_CLUSTER_NAME}\"" ; fi ; # // if lacking proper hcl add
if [[ ${VAULT_CONF_TLS_CERT_FILE} != "" && ${VAULT_CONF_TLS_CERT_FILE} != 'tls_cert_file = "'* ]]; then VAULT_CONF_TLS_CERT_FILE="	tls_cert_file = \"${VAULT_CONF_TLS_CERT_FILE}\"" ; fi ; # // if lacking proper hcl add
if [[ ${VAULT_CONF_TLS_KEY_FILE} != "" && ${VAULT_CONF_TLS_KEY_FILE} != 'tls_cert_file = "'* ]]; then VAULT_CONF_TLS_KEY_FILE="	tls_key_file = \"${VAULT_CONF_TLS_KEY_FILE}\"" ; fi ; # // if lacking proper hcl add
if [[ ! ${TLS_CRT_KEY_FILES+x} ]]; then TLS_CRT_KEY_FILES='vault*' ; fi ; # // pattern of files used to determine .key & .crt file

if [[ ! ${LICENSE_FILE+x} ]]; then LICENSE_FILE='vault_license.txt' ; fi ; # // if contents of file are not empty or blank then uses value to apply vault licnese.

# // A post setup script that will run at the end of the process.
if [[ ! ${VAULT_POST_SETUP_FILE+x} ]]; then
	VAULT_POST_SETUP_FILE='post_setup_vault.sh' ;
	if ! [[ -s ${VAULT_POST_SETUP_FILE} ]] ; then VAULT_POST_SETUP_FILE='' ; fi ;
fi ;

if [[ ! ${VAULT_CONFIG_FILE_SEAL+x} ]]; then VAULT_CONFIG_FILE_SEAL='vault_seal.hcl' ; fi ; # // file representing seal portion of vault.hcl config.
if [[ ! ${VAULT_CONF_SEAL+x} ]]; then
	VAULT_CONF_SEAL=( "# seal ..." ) ; # // default no seal - will be over-written if defined.
	if [[ -s ${VAULT_CONFIG_FILE_SEAL} ]] ; then
		IFS=$'\n' VAULT_CONF_SEAL=($(< ${VAULT_CONFIG_FILE_SEAL})) ;
		if [[ ${VAULT_CONF_SEAL[0]} != "" ]] ; then VAULT_CONF_SEAL=("" "${VAULT_CONF_SEAL[@]}") ; fi ;
#		VAULT_CONF_SEAL=$(printf "%s\n" "${VAULT_CONF_SEAL[*]}") ;
	fi ;
fi ; # // string seal portion of vault.hcl config.

if [[ ! ${VAULT_CONFIG_FILE_STORE+x} ]]; then VAULT_CONFIG_FILE_STORE='vault_store.hcl' ; fi ; # // file representing seal portion of vault.hcl config.
if [[ ! ${VAULT_CONF_STORE+x} ]]; then
	VAULT_CONF_STORE="" ;
	if [[ -s ${VAULT_CONFIG_FILE_STORE} ]] ; then
		VAULT_CONF_STORE=($(< ${VAULT_CONFIG_FILE_STORE})) ;
		if [[ ${VAULT_CONF_STORE[0]} != "" ]] ; then VAULT_CONF_STORE=("" "${VAULT_CONF_STORE[@]}") ; fi ;
		#VAULT_CONF_STORE=$(printf "%s\n" "${VAULT_CONF_STORE[*]}") ;
	else
		# // default storage - if consul is installed then just use that otherwise assume Integrated / Raft Storage.
		CONSUL_PEERS='' ;
		# // Where consul members list match our IP:
		set +e ; IFS=$'\n' CONSUL_PEERS+=($(consul members 2>/dev/null)) ; set -e ;
		for sN in ${CONSUL_PEERS[*]} ; do
			if [[ ${sN} == *"${IP_WAN}"* || ${sN} == *"${IP_LAN}"* ]] ; then
				VAULT_CONF_STORE='''
storage "consul" {
	address	= "127.0.0.1:8500"
	path	= "vault/"
}''' ;
				break ;
			fi ;
		done ;

		# // No Consul then we'll assume raft - first node inmem reset disk location based.
#		if [[ ${VAULT_CONF_STORE} == '' && ${VAULT_NODENAME} == *"1" ]] ; then
#			VAULT_CONF_STORE='''
## // PRIMARY NODE Storage inmem:
#storage "inmem" {}''' ;
#		fi ;
#
		# // No Consul then raft for secondary nodes (not inmem)
		if [[ ${VAULT_CONF_STORE} == '' ]] ; then
			VAULT_CONF_STORE='''
storage "raft" {
	path		= "'${PATH_VAULT_DATA}'"
	node_id		= "'${VAULT_NODENAME}'"
}''' ;
		fi ;

	fi ;
fi ; # // string store portion of vault.hcl config.

sERR="REFER TO: ${URL_VAULT}\n\nERROR: Operating System Not Supported." ;
sERR_DL="REFER TO: ${URL_VAULT}\n\nERROR: Could not determined download state." ;

if [[ ${OS_CPU} == '' ]] ; then
	if [[ ${OS_VERSION} == *'x86_64'* ]] ; then
		OS_CPU='amd64' ;
	else
		if [[ ${OS_VERSION} == *' i386'* || ${OS_VERSION} == *' i686'* ]] ; then OS_CPU='386' ; fi ;
		if [[ ${OS_VERSION} == *' armv6'* || ${OS_VERSION} == *' armv7'* ]] ; then OS_CPU='arm' ; fi ;
		if [[ ${OS_VERSION} == *' armv8'* || ${OS_VERSION} == *' aarch64'* ]] ; then OS_CPU='arm64' ; fi ;
		if [[ ${OS_VERSION} == *'solaris'* ]] ; then OS_CPU='amd64' ; fi ;
	fi ;
	if [[ ${OS_CPU} == '' ]] ; then pOUT "${sERR}" ; exit 1 ; fi ;
fi ;

case "$(uname -ar)" in
	Darwin*) #pOUT 'macOS (aka OSX)' ;
		if which brew > /dev/null ; then
			pOUT 'Consider: "brew install vault" since you have HomeBrew availble.' ;
		else :; fi ;
		FILE="${FILE}darwin_${OS_CPU}.zip" ;
	;;
	Linux*) #pOUT 'Linux' ;
		FILE="${FILE}linux_${OS_CPU}.zip" ;
	;;
	*Solaris) #pOUT 'SunOS / Solaris' ;
		FILE="${FILE}solaris_${OS_CPU}.zip" ;
	;;
	*FreeBSD*) #pOUT 'FreeBSD' ;
		FILE="${FILE}freebsd_${OS_CPU}.zip" ;
	;;
	*NetBSD*) #pOUT 'NetBSD' ;
		FILE="${FILE}netbsd_${OS_CPU}.zip" ;
	;;
	*OpenBSD*) #pOUT 'OpenBSD' ;
		FILE="${FILE}netbsd_${OS_CPU}.zip" ;
	;;
	*Cygwin) #pOUT 'Cygwin - POSIX on MS Windows'
		FILE="${FILE}windows_${OS_CPU}.zip" ;
		URL="${URL}${FILE}" ;
		pOUT "Conisder downloading (exe) from: ${URL}.\nUse vault.exe from CMD / Windows Prompt(s)." ;
		exit 0 ;
	;;
	*) pOUT "${sERR}" ; exit 1 ;
	;;
esac ;


function donwloadUnpack()
{
	# // PGP Public Key on Security Page which can be piped to file.
	#PGP_KEY_PUB=$(curl -s https://www.hashicorp.com/security.html | grep -Pzo '\-\-\-\-\-BEGIN PGP PUBLIC KEY BLOCK\-\-\-\-\-\n.*\n(\n.*){27}?') ;
	#curl -s ${VAULT_VERSION}/vault_${VAULT_VERSION}_SHA256SUMS.sig ;

	sAOK="Remember to copy ('cp'), link ('ln') or path the vault executable as required." ;
	sAOK+="	Try: '${PATH_BINARY} --version' ; # to test.\nSUCCESS INSTALLED VAULT ${VAULT_VERSION} in: ${PATH_INSTALL}" ;

	pOUT "Downloading from: ${URL}" ;
	cd ${PATH_INSTALL} && \
	if wget -qc ${URL} && wget -qc ${URL2} ; then
		if [[ $(shasum -a 256 -c vault_${VAULT_VERSION}_SHA256SUMS 2>&1>/dev/null | grep OK) == "" ]] ; then
			if unzip -qo ${FILE} ; then pOUT "${sAOK}" ; else pERR "ERROR: Could not unzip." ; fi ;
		else
			pERR 'ERROR: During shasum - Downloaded .zip corrupted?' ;
			exit 1 ;
		fi ;
	else
		pOUT "${sERR_DL}" ;
	fi ;
}


function hsmSetup()
{
	pOUT 'SoftHSM: Checking status ...' ;
	iSLOT=0 ;
	iLIB=0 ;
	HSM_SLOT="" ;
	HSM_LABEL="" ;
	HSM_PIN="" ;
	iX=1 ;
	for sString in ${VAULT_CONF_SEAL[@]} ; do
		# // remove quotes and get inner equal value only (with sTMP subs)
		if [[ ${sString} == *"slot"*"="* ]] ; then sTMP=${sString//\"/} ; HSM_SLOT=${sTMP/*slot*=\ /} ; iSLOT=$iX ; fi ;
		if [[ ${sString} == *"key_label"*"="* && ${sString} != *"hmac_key_label"* ]] ; then sTMP=${sString//\"/} ; HSM_LABEL=${sTMP/*key_label*=\ /} ; fi ;
		if [[ ${sString} == *"pin"*"="* ]] ; then sTMP=${sString//\"/} ; HSM_PIN=${sTMP/*pin*=\ /} ; fi ;
		if [[ ${sString} == *"lib"*"="* ]] ; then sTMP=${sString//\"/} ; HSM_LIB=${sTMP/*lib*=\ /} ; iLIB=$iX ; fi ;

		if [[ ${sString} == *"lib"*"="* ]] ; then
			sTMP=${sString//\"/} ; HSM_LIB=${sTMP/*lib*=\ /} ;
			# // check if .so module path exists or we have to determine
		fi ;
		((++iX)) ;
	done

	# // check if (.so) softhsm modules path exist otherwise try to determine it.
	if (($iLIB != 0)) && ! [[ -s ${HSM_LIB} ]] ; then
		PATH_SOFTHSM=$(which softhsm2-util) ;
		if [[ ${PATH_SOFTHSM} == *"/usr/local/"* ]] ; then
			PATH_SOFTHSM='/usr/local/lib/softhsm/libsofthsm2.so' ;
		else
			PATH_SOFTHSM='/usr/lib/softhsm/libsofthsm2.so' ;
		fi ;
		if ! [[ -s ${PATH_SOFTHSM} ]] ; then pERR "ERROR: SoftHSM unable to determine module path (${PATH_SOFTHSM})." ; exit 1 ; fi ;
		VAULT_CONF_SEAL[$iLIB]=${VAULT_CONF_SEAL[$iLIB]/=*/= \"${PATH_SOFTHSM}\"} ;
	fi ;

	# // check if lot exists if not create it.
	if (($iSLOT != 0)) ; then
		HSM_SLOT_CREATE=1;
		HSM_SLOTS=($(sudo softhsm2-util --show-slots | grep -E 'Slot\ [[:digit:]]')) ;
		for sString in ${HSM_SLOTS[@]} ; do
			# // DONT Create HSM Slot as its there.
			if [[ ${sString} == "Slot ${HSM_SLOT}"* ]] ; then HSM_SLOT_CREATE=0 ; fi ;
		done ;

		if (($HSM_SLOT_CREATE == 1)) ; then
			HSM_SLOT=$(sudo softhsm2-util --init-token --free --label "${HSM_LABEL}" --pin ${HSM_PIN} --so-pin ${HSM_PIN}) ;
			HSM_SLOT=${HSM_SLOT/*slot\ /} ;

			VAULT_CONF_SEAL[$iSLOT]=${VAULT_CONF_SEAL[$iSLOT]/=*/= \"${HSM_SLOT}\"} ;
			pOUT "SoftHSM: SLOT ${HSM_SLOT} created." ;
		fi ;
	fi ;
}


function sudoSetup()
{
	if [[ ${FILE} == *"darwin"* ]] ; then pOUT '\nWARNING: On MacOS - all other setup setps will need to be appropriatly completed by the user.' ; exit 0 ; fi ;
	if ! (( $(id -u) == 0 )) ; then pERR 'ERROR: Root privileges lacking to peform all setup tasks. Consider "sudo ..." re-execution.' ; exit 1 ; fi ;

	# // Move vault to default paths
	cd ${PATH_INSTALL} && \
	chown root:root vault && \
	mv vault ${PATH_BINARY} ;

	# Give ability to mlock syscall without running the process as root & preventing memory from being swapped to disk.
	setcap cap_ipc_lock=+ep ${PATH_BINARY} ; # // /usr/local/bin/vault

	# Create a unique, non-privileged system user to run Vault.
	if ! id -u ${USER_VAULT} &>/dev/null ; then
		useradd --system --home ${PATH_VAULT} --shell /bin/false -ou 0 ${USER_VAULT} ;
	else
		pOUT "USER: ${USER_VAULT} - already present." ;
	fi ;

	# // Enable auto complete
	set +e ;
	vault -autocomplete-install 2>/dev/null && complete -C ${PATH_BINARY} vault 2>/dev/null ;
	su -l ${USER_MAIN} -c "vault -autocomplete-install 2>/dev/null && complete -C ${PATH_BINARY} vault 2>/dev/null;"
	set -e ;

	# // SystemD for service / startup
	if ! which systemctl 2>&1>/dev/null ; then pERR 'ERROR: No systemctl / SystemD installed on system.' ; exit 1 ; fi ;
	if [[ ${FILE} == *"darwin"* ]] ; then pERR 'ERROR: Only SystemD can be provisioned - build MacOS launchd plist yourself.\n' ; exit 1 ; fi ;

	# // HSM pre-setup preparation if applicable
	if [[ ${VAULT_CONF_SEAL[*]} == *"seal \"pkcs11\""* ]] ; then hsmSetup ; fi ;

	if ! [[ -d ${PATH_VAULT_DATA} ]] ; then mkdir -p ${PATH_VAULT_DATA} && chown -R ${USER_VAULT} ${PATH_VAULT_DATA} ; fi ;

	if mkdir -p ${PATH_VAULT} && touch ${PATH_VAULT_CONFIG} && chown -R ${USER_VAULT} ${PATH_VAULT} && chmod 640 ${PATH_VAULT_CONFIG} ; then
		if ! [[ -s ${PATH_VAULT_CONFIG} ]] ; then
			if [[ ${VAULT_CONF_TLS_CERT_FILE} == "" && ${VAULT_CONF_TLS_KEY_FILE} == "" ]] ; then
				cd ${PATH_INSTALL} ; cd .. ;

				# // determine key & crt file based on current path & first returned file.
				for sFILE in $(pwd)/${TLS_CRT_KEY_FILES} ; do
					if [[ ${sFILE} == *".crt" ]] ; then VAULT_CONF_TLS_CERT_FILE="	tls_cert_file = \"${sFILE}\"" ; fi ;
					if [[ ${sFILE} == *".key" ]] ; then VAULT_CONF_TLS_KEY_FILE="	tls_key_file = \"${sFILE}\"" ; chown ${USER_VAULT} ${sFILE} ; fi ;
					if [[ ${VAULT_CONF_TLS_CERT_FILE} != "" && ${VAULT_CONF_TLS_KEY_FILE} != "" ]] ; then
						VAULT_CONF_TLS_DISABLED='''	# tls_disable      = true
	tls_prefer_server_cipher_suites = "true"
	tls_cipher_suites = "TLS_CHACHA20_POLY1305_SHA256,TLS_RSA_WITH_AES_256_GCM_SHA384,TLS_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_RSA_WITH_AES_128_GCM_SHA256,TLS_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"''' ;
						break ;
					fi ;
				done ;

				# // if still blank then comment related TLS properties in conf file.
				if [[ ${VAULT_CONF_TLS_CERT_FILE} == "" && ${VAULT_CONF_TLS_KEY_FILE} == "" ]] ; then
					VAULT_CONF_TLS_CERT_FILE='	# tls_cert_file = "'${HOME_PATH}'/vault_certificate.pem"' ;
					VAULT_CONF_TLS_KEY_FILE='	# tls_key_file  = "'${HOME_PATH}'/vault_privatekey.pem"' ;
				fi ;
			elif [[ ${VAULT_CONF_TLS_CERT_FILE} != "" && ${VAULT_CONF_TLS_KEY_FILE} != "" ]] ; then
					VAULT_CONF_TLS_DISABLED='''	# tls_disable      = true
	tls_prefer_server_cipher_suites = "true"
	tls_cipher_suites = "TLS_CHACHA20_POLY1305_SHA256,TLS_RSA_WITH_AES_256_GCM_SHA384,TLS_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_RSA_WITH_AES_128_GCM_SHA256,TLS_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"''' ;
			fi ;

			PROTO='http' ;
			if [[ ${VAULT_CONF_TLS_DISABLED} == *'# tls_disable'* ]] ; then PROTO='https' ; fi ;

			# // IMPORTANT: Set value address for CLI calls and config
			if [[ ! ${VAULT_API_ADDR+x} ]] ; then VAULT_API_ADDR="${PROTO}://${IP_WAN}:${VAULT_PORT_API}" ; fi ;
			if [[ ! ${VAULT_CLU_ADDR+x} ]] ; then VAULT_CLU_ADDR="${PROTO}://${IP_WAN}:${VAULT_PORT_CLUSTER}" ; fi

			# // LICNESE for 1.8.x or higher needs file and different to earlier
			VAULT_CONF_LICENSE='' ;
			VVERSION=$(vault --version) ;
			VVERSION2=$(echo ${VVERSION} | cut -d'v' -f2 | cut -d' ' -f1) ;
			# // 1.10 semantic versions wont work with all x < y comparisons
			# // for all versions that are 4 length 1.1x or 1.2x then just apply
			VVERSION2=${VVERSION2:0:4} ;  # // take only major portion of version
			if [[ "${VVERSION2:3:1}" == "." ]] ; then
				VVERSION2=$(echo ${VVERSION} | cut -d'v' -f2 | cut -d' ' -f1) ;
				VVERSION2=${VVERSION2:0:3} ;  # // take only major portion of version
			fi ;
			if [[ ${VVERSION} == *"ent" || ${VVERSION} == *"ent.hsm"* ]] && [[ -s ${LICENSE_FILE} ]] && \
				[[ (( ${#VVERSION2} == 4 )) && "1" == $(bc <<<"1.10 <= $VVERSION2") ]] || \
				[[ "1" == $(bc <<<"a = 1.8 <= ${VVERSION2}") ]] ; then
				cp ${LICENSE_FILE} ${PATH_VAULT}/. ;
				VLPWD="${PATH_VAULT}/${LICENSE_FILE}" ;
				VAULT_CONF_LICENSE="license_path=\"${VLPWD}\""  ;
			fi ;

			export sLISTENER_IP_LB='' ;
			if [[ ${IP_LB+x} ]] ; then
				sLISTENER_IP_LB='''listener "tcp" {
	address	        = "'${IP_LB}':'${VAULT_PORT_API}'"
	cluster_address	= "'${IP_LB}':'${VAULT_PORT_CLUSTER}'"
	tls_disable     = true
	# // Load-Balancers / Proxy - Forwarded-For headers.
	x_forwarded_for_authorized_addrs = "'${IP_WAN}'/32"
	#x_forwarded_for_reject_not_authorized = "true"  # default
	#x_forwarded_for_reject_not_present = "true"  # default	
}''' ;		fi ; 

			sLISTENER_IP='''listener "tcp" {
	address         = "'${IP_WAN}':'${VAULT_PORT_API}'"
	cluster_address	= "'${IP_WAN}':'${VAULT_PORT_CLUSTER}'"
'${VAULT_CONF_TLS_CERT_FILE}'
'${VAULT_CONF_TLS_KEY_FILE}'
'"${VAULT_CONF_TLS_DISABLED}"'
}''' ;

			printf "%s" ''''${VAULT_CLUSTER_NAME}'
api_addr = "'${VAULT_API_ADDR}'"
cluster_addr = "'${VAULT_CLU_ADDR}'"

listener "tcp" {
	address     = "127.0.0.1:8200"
	tls_disable = true
}
'"${sLISTENER_IP_LB}"'
'"${sLISTENER_IP}"'
'"${VAULT_CONF_STORE}"'
'"$(iX=0 ; while (( ${#VAULT_CONF_SEAL[@]} > iX )); do printf "${VAULT_CONF_SEAL[iX++]}\n" ; done )"'

disable_mlock = true
log_level = "trace"
ui = true
raw_storage_endpoint = true
# plugin_directory = "/etc/vault.d/plugins"  # // path needs to exist to get enable plugins
'${VAULT_CONF_LICENSE}'
''' > ${PATH_VAULT_CONFIG} ;
		else
			pOUT "VAULT Conifg: ${PATH_VAULT_CONFIG} - already present." ;
		fi ;
	else
		pERR "ERROR: Unable to create ${PATH_VAULT}." ; exit 1 ;
	fi ;

	# // place address of vault API in .bashrc for ease of use initially.
	if ! grep VAULT_ADDR ${HOME_PATH}/.bashrc ; then
		if [[ "${PROTO}://${IP_WAN}:${VAULT_PORT_API}" == ${VAULT_API_ADDR} ]] ; then
			printf "\nexport VAULT_ADDR=${VAULT_API_ADDR}\n" >> ${HOME_PATH}/.bashrc ;
		else
			printf "\nexport VAULT_ADDR=${PROTO}://${IP_WAN}:${VAULT_PORT_API}\n" >> ${HOME_PATH}/.bashrc ;
		fi ;
		pOUT "Set VAULT_ADDR in ${HOME_PATH}/.bashrc" ;
		# // disable TLS skip verify if needed:
		# if ! grep VAULT_SKIP_VERIFY ${HOME_PATH}/.bashrc ; then printf "\nexport VAULT_SKIP_VERIFY=true\n" >> ${HOME_PATH}/.bashrc ; fi ;
	fi ;

	if ! [[ -s ${SYSD_FILE} ]] && [[ ${SETUP,,} == *'server'* ]]; then
		# // common Vault version systemd unit file
		UNIT_SYSTEMD='[Unit]\nDescription="HashiCorp Vault - A tool for managing secrets"\nDocumentation=https://www.vaultproject.io/docs/\nRequires=network-online.target\nAfter=network-online.target\nConditionFileNotEmpty=/etc/vault.d/vault.hcl\nStartLimitIntervalSec=60\nStartLimitBurst=3\n\n[Service]\nUser=vault\nGroup=vault\nProtectSystem=full\nProtectHome=read-only\nPrivateTmp=yes\nPrivateDevices=yes\nSecureBits=keep-caps\nAmbientCapabilities=CAP_IPC_LOCK\nCapabilities=CAP_IPC_LOCK+ep\nCapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK\nNoNewPrivileges=yes\nExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl\nExecReload=/bin/kill --signal HUP $MAINPID\nKillMode=process\nKillSignal=SIGINT\nRestart=on-failure\nRestartSec=5\nTimeoutStopSec=30\nStartLimitInterval=60\nStartLimitIntervalSec=60\nStartLimitBurst=3\nLimitNOFILE=65536\nLimitMEMLOCK=infinity\n\n[Install]\nWantedBy=multi-user.target\n' ;

		# // Vault hsm / pkcs11 verison:
		VVERSION=$(vault --version) ;
		if [[ ${VVERSION} == *"ent.hsm"* ]] ; then
			UNIT_SYSTEMD='[Unit]\nDescription="HashiCorp Vault - A tool for managing secrets"\nDocumentation=https://www.vaultproject.io/docs/\nRequires=network-online.target\nAfter=network-online.target\nConditionFileNotEmpty=/etc/vault.d/vault.hcl\nStartLimitIntervalSec=60\nStartLimitBurst=3\n\n[Service]\nUser=vault\nGroup=vault\nProtectSystem=full\nProtectHome=read-only\nPrivateTmp=yes\nPrivateDevices=yes\nSecureBits=keep-caps\nAmbientCapabilities=CAP_IPC_LOCK\n#Capabilities=CAP_IPC_LOCK+ep\nCapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK\nNoNewPrivileges=yes\nExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl\nExecReload=/bin/kill --signal HUP $MAINPID\nKillMode=process\nKillSignal=SIGINT\nRestart=on-failure\nRestartSec=5\nTimeoutStopSec=30\n#StartLimitInterval=60\n#StartLimitIntervalSec=60\nStartLimitBurst=3\nLimitNOFILE=65536\nLimitMEMLOCK=infinity\n\n[Install]\nWantedBy=multi-user.target\n' ;
		fi ;

		printf "${UNIT_SYSTEMD}" > ${SYSD_FILE} && chmod 664 ${SYSD_FILE}
		systemctl daemon-reload > /dev/null 2>&1 ;
		systemctl enable vault.service > /dev/null 2>&1 ;
		systemctl start vault.service > /dev/null 2>&1 ;

		SLEEP_TIME=8 ; # // time to sleep after a restart
		pOUT "WAITING ${SLEEP_TIME} seconds for Vault service to be ready after a start." ;
		sleep ${SLEEP_TIME} ;
	fi ;
}


function vaultInitSetup()
{
	# // CAUTION: version is not always listed prior to vault init.
	export VAULT_ADDR=${VAULT_API_ADDR} ;

	# // Vault status likely to return a non-0 response when seal / at start.
	set +e ;
	VSEAL_TATUS=($(vault status -format=json 2>/dev/null | jq -r '.initialized,.sealed,.t,.progress,.type,.storage_type')) ;
	set -e ;

	if [[ ${VSEAL_TATUS[*]} == "" ]] ; then pERR 'ERROR: VAULT unable to get status.' ; fi ;

	# // do initial init based on seal type.
	if [[ ${VSEAL_TATUS[0]} == "false" && ${VSEAL_TATUS[1]} == "true" && ${VSEAL_TATUS[2]} == "0" && ${VSEAL_TATUS[3]} == "0" ]] ; then
		# // shamir init - DEFAULT - when no seal have been defined in configuration:
		if [[ "" == "$(grep -v '#' ${PATH_VAULT_CONFIG} | grep 'seal')" ]] ; then
			if [[ ${VAULT_NODENAME} == *"1" ]] ; then
				vault operator init -key-shares=1 -key-threshold=1 -format=json > ${VAULT_INIT_FILE} && \
				jq -r '.root_token' ${VAULT_INIT_FILE} > ${VAULT_TOKEN_INIT} ; # && \
				if (($? == 0)) ; then
					chown ${USER_MAIN} ${VAULT_INIT_FILE} && chown ${USER_MAIN} ${VAULT_TOKEN_INIT} ;
					pOUT 'VAULT INIT: with SHAMIR (DEFAULT).' ;
					pOUT 'WAITING 6 seconds for Vault service to be ready after DEFAULT SHAMIR init set (will vault unseal after).' ;
					sleep 6 ; # // need a sleep 10 seconds for status to update.
					VAULT_TOKEN=$(jq -r '.root_token' ${VAULT_INIT_FILE}) ;
					VAULT_TOKEN=${VAULT_TOKEN} vault operator unseal $(jq -r '.unseal_keys_b64[0]' ${VAULT_INIT_FILE}) > /dev/null ;
					pOUT 'WAITING 5 seconds after Vault unseal for leadership election.' ;
					sleep 5 ; # // need a sleep 10 seconds for status to update & leader node to be selected.
				else
					pERR 'ERROR: unable to set initial VAULT Recovery or Root tokens.' ;
				fi ;
			else
				if [[ -s ${VAULT_INIT_FILE} && ${VSEAL_TATUS[5]} == "raft" ]] ; then
					# // may need raft join if storage is configured as such for all nodes after 1.
					if [[ ${VAULT_RAFT_JOIN} != "" ]] ; then
						VAULT_TOKEN=$(jq -r '.root_token' ${VAULT_INIT_FILE}) ;
						if [[ ${VAULT_TOKEN} != "" ]] ; then
							pOUT 'RAFT: Attempting to join.' ;
							sleep 1 ;
							set +e ;
							vault operator raft join ${VAULT_RAFT_JOIN} > /dev/null 2>&1 ;
							if (($? == 0)) ; then
								pOUT "RAFT: SUCCESS JOINED ${VAULT_NODENAME} to ${VAULT_RAFT_JOIN}." ;
							else
								pERR "--ERROR: Vault RAFT unable to join ${VAULT_NODENAME} to ${VAULT_RAFT_JOIN}." ;
							fi ;
							set -e ;
							pOUT 'WAITING 4 seconds for Vault to sync before manually UNSEALING.' ;
							sleep 4 ; # // need a sleep 8 seconds for status to update & primary node to be selected.
							pOUT 'VAULT UNSEAL: Attempting Unseal using UNSEAL KEYS from Leader Node (vault_init.json).' ;
							vault operator unseal $(jq -r '.unseal_keys_b64[0]' ${VAULT_INIT_FILE}) > /dev/null 2>&1 ;
							if (($? == 0)) ; then
								pOUT "SHAMIR: UNSEAL MANUALLY USING LOACAL KEYS." ;
							else
								pERR "--ERROR: UNSEAL ISSUE." ;
							fi ;
						else
							pERR '--ERROR: Vault RAFT - No Token or Vault not ready to join.' ;
						fi ;
					fi ;
				#else printf 'VAULT: NO UNSEAL ACTIONS TAKEN.\n' ;
				fi ;
			fi ;
		# // kms based init:
		elif [[ ${VAULT_NODENAME} == *"vault1" && ${VSEAL_TATUS[4]} == *"kms"* ]] ; then
			vault operator init -recovery-shares=1 -recovery-threshold=1 -format=json > ${VAULT_INIT_FILE} && \
			jq -r '.root_token' ${VAULT_INIT_FILE} > ${VAULT_TOKEN_INIT} ; # && \
			if (($? == 0)) ; then
				chown ${USER_MAIN} ${VAULT_INIT_FILE} && chown ${USER_MAIN} ${VAULT_TOKEN_INIT} ;
				pOUT 'VAULT INIT: with KMS of awskms.' ;
				pOUT 'WAITING 5 seconds for Vault service to be ready after KMS init.' ;
				sleep 5 ; # // need a sleep 8 seconds for status to update & primary node to be selected.
			else
				pERR 'ERROR: unable to set initial VAULT Recovery or Root tokens.' ;
			fi ;
		# // hsm based init:
		elif [[ ${VAULT_NODENAME} == *"vault1" && ${VSEAL_TATUS[4]} == *"pkcs11"* ]] ; then
			vault operator init -recovery-shares=1 -recovery-threshold=1 -format=json > ${VAULT_INIT_FILE} && \
			jq -r '.root_token' ${VAULT_INIT_FILE} > ${VAULT_TOKEN_INIT} ; # && \
			if (($? == 0)) ; then
				chown ${USER_MAIN} ${VAULT_INIT_FILE} && chown ${USER_MAIN} ${VAULT_TOKEN_INIT} ;
				pOUT 'VAULT INIT: with HSM pkcs11 (SoftHSM).' ;
				pOUT 'WAITING 6 seconds for Vault service to be ready after HSM init.' ;
				sleep 6 ; # // need a sleep 8 seconds for status to update & primary node to be selected.
			else
				pERR 'ERROR: unable to set initial VAULT Recovery or Root tokens.' ;
			fi ;
		else
			pOUT 'VAULT WARNING: Undetermined init setup status (not: shamir, kms or pkcs11 / hsm).' ;
		fi ;
	fi ;
	# // .....

	# // where token file exists then set it in .bashrc and maybe delete after.
	if [[ -s ${VAULT_TOKEN_INIT} ]] ; then
		VAULT_TOKEN=$(< ${VAULT_TOKEN_INIT}) ;
		if ! grep VAULT_TOKEN ${HOME_PATH}/.bashrc > /dev/null 2>&1 ; then
			# printf "${VAULT_TOKEN}" > ${HOME_PATH}/vault_token.txt ;
			printf "\nexport VAULT_TOKEN=${VAULT_TOKEN}\n" >> ${HOME_PATH}/.bashrc ;
			pOUT "Set VAULT_TOKEN in ${HOME_PATH}/.bashrc" ;
		# else pOUT 'VAULT_TOKEN already present in .bashrc profile.' ;
		fi ;
		# rm -rf ${VAULT_TOKEN_INIT} ;
	fi ;

	if [[ ! ${VAULT_TOKEN+x} && -s ${VAULT_INIT_FILE} ]] ; then
		VAULT_TOKEN=$(jq -r '.root_token' ${VAULT_INIT_FILE}) ;
	fi ;

	if [[ ${VAULT_TOKEN} == "" ]] ; then
		# // VAULT_TOKEN ought to exist by now from either init or copy from vault1:
		VAULT_TOKEN=$(grep -F VAULT_TOKEN ${HOME_PATH}/.bashrc | cut -d'=' -f2) ;
	fi ;

	# // apply license if enterprise & file exists and is not empty or commented.
	# // LICNESE for 1.8.x or higher needs file and different to earlier
	VVERSION=$(vault --version) ;
	VVERSION2=$(echo ${VVERSION} | cut -d'v' -f2 | cut -d' ' -f1) ;
	# // 1.10 semantic versions wont work with all x < y comparisons
	# // for all versions that are 4 length 1.1x or 1.2x then just apply
	VVERSION2=${VVERSION2:0:4} ;  # // take only major portion of version
	if [[ "${VVERSION2:3:1}" == "." ]] ; then
		VVERSION2=$(echo ${VVERSION} | cut -d'v' -f2 | cut -d' ' -f1) ;
		VVERSION2=${VVERSION2:0:3} ;  # // take only major portion of version
	fi ;
	if [[ ${VAULT_NODENAME} == *"1" ]] && [[ ${VVERSION} == *"ent" || ${VVERSION} == *"ent.hsm"* ]] && [[ -s ${LICENSE_FILE} ]] && \
		[[ (( ${#VVERSION2} == 4 )) && "0" == $(bc <<<"1.10 <= $VVERSION2") ]] || \
		[[ (( ${#VVERSION2} == 3 )) && "0" == $(bc <<<"a = 1.8 <= ${VVERSION2}") ]] ; then
		set +e ;
		# // read the key
		VAULT_LICENSE=$(grep -v '#' ${LICENSE_FILE}) ;
		set -e ;
		if [[ ${VAULT_LICENSE} != "" ]] ; then
			if [[ ${VAULT_TOKEN} != "" ]] ; then
				set +e ;
				sleep 2 ;
				if ! VAULT_TOKEN=${VAULT_TOKEN} vault write /sys/license "text=${VAULT_LICENSE}" > /dev/null 2>&1 ; then
					pERR '--ERROR: Vault Applying License.' ;
				else
					pOUT 'VAULT: Enterprise License Applied.' ;
				fi ;
				set -e ;
			else
				pERR '--ERROR: Vault Applying License - No Token or Vault not ready.' ;
			fi ;
		fi ;
	fi ;

	if [[ -s ${VAULT_POST_SETUP_FILE} ]] ; then
		export VAULT_TOKEN=${VAULT_TOKEN} ;
		bash "${VAULT_POST_SETUP_FILE}" ;
	fi ;

	# // SET DR Primary vault_init_primary.json details
	if [[ -s ${VAULT_PRIMARY_INIT_PR} && ${VAULT_INIT_FILE} != ${VAULT_PRIMARY_INIT_PR} ]] ; then
		if [[ -s ${VAULT_INIT_FILE} ]] ; then
			mv ${VAULT_INIT_FILE} old.${VAULT_INIT_FILE}.before-replication ;
			mv ${VAULT_PRIMARY_INIT_PR} ${VAULT_INIT_FILE} ;
		fi ;
		VT=$(jq -r '.root_token' ${VAULT_PRIMARY_INIT_PR}) ;
		sed -i 's/^export VAULT_TOKEN/#xport VAULT_TOKEN/g' ~/.bashrc
		printf "export VAULT_TOKEN=${VT}\n" >> ~/.bashrc ;
		printf "RE-SET VAULT_TOKEN using Primary init file (${VAULT_PRIMARY_INIT_PR}).\n" ;
	fi ;
	# // do anything further...
}


URL="${URL}${FILE}" ;
donwloadUnpack && if [[ ${SETUP,,} == *"server"* ]]; then sudoSetup && vaultInitSetup ; fi ;
