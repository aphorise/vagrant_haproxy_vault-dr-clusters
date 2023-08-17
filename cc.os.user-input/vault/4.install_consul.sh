#!/usr/bin/env bash
set -eu ; # abort this script when a command fails or an unset variable is used.
#set -x ; # echo all the executed commands.

if [[ ${1-} ]] && [[ (($# == 1)) || $1 == "-h" || $1 == "--help" || $1 == "help" ]] ; then
printf """Usage: VARIABLE='...' ${0##*/} [OPTIONS]
Installs HashiCorp Consul & can help setup agents (client & server).

By default this script only downloads & copies binaries where no inline SETUP
value is provided ('server' or 'client').

Some of the inline variables and values that can be set are show below.

For upto date & complete documentation of Consul see: https://www.consul.io/

VARIABLES:
		SETUP='server | client' # // default ''
		CONSUL_VERSION='' # // default LATEST - '1.5.1+ent' for enterprise or '1.5.1' for oss.
		LICENSE='' # // MUST be adjusted with +ent CONSUL_VERSION
		IP_WAN_INTERFACE='eth1' # // default
		IP_LAN_INTERFACE='eth1' # // default
		PATH_BINARY='/usr/local/bin/consul' # // default
		IPS='"10.0.100.1", "10.0.100.2", "10.0.100.3"' # // default ''

EXAMPLES:
		SETUP='server' IPS='"10.0.100.1", "10.0.100.2", "10.0.100.3"' ${0##*/} ;
			# install cluster with above IP list for Consul config join setting.

		SETUP='server' IP_WAN_INTERFACE='eth1' IP_LAN_INTERFACE='eth0' \\
		IPS='"10.0.100.1", "10.0.100.2", "10.0.100.3"' ${0##*/} ;
		# use IPs for Consul config join settings & adaptor IP details.

		SETUP='server' LICENSE='...' IPS='"10.0.100.1", "10.0.100.2", "10.0.100.3"' ${0##*/} ;
		# use IPs for Consul config join settings & adaptor IP details.

${0##*/} 0.0.3					August 2023
""" ;
fi ;

# // logger
function pOUT() { printf "$1\n" ; } ;

# // Colourised logger for errors (red)
function pERR()
{	# sMSG=${1/@('ERROR:')/"\e[31mERROR:\e[0m"} ; sMSG=${1/('ERROR:')/"\e[31mERROR:\e[0m"}
	if [[ $1 == "--"* ]] ; then pOUT "\e[31m$1\n\e[0m\n" ;
	else pOUT "\n\e[31m$1\n\e[0m\n" ; fi ;
}

if ! which curl 2>&1>/dev/null ; then pOUT 'ERROR: curl utility missing & required. Install & retry again.' ; exit 1 ; fi ;
if ! which unzip 2>&1>/dev/null ; then pOUT 'ERROR: unzip utility missing & required. Install & retry again.' ; exit 1 ; fi ;

if [[ ! ${SETUP+x} ]]; then SETUP='server' ; fi ; # // default 'server' setup or change to 'client'
if [[ ! ${USER_MAIN+x} ]] ; then USER_MAIN=$(logname) ; fi ; # // root user executing this script as sudo for example.
if [[ ! ${USER_CONSUL+x} ]]; then USER_CONSUL='consul' ; fi ; # // default consul user
if [[ ! ${PATH_CONSUL+x} ]]; then PATH_CONSUL="/etc/consul.d" ; fi ; # // default Consul Daemon Path where configuration & files are to reside.

if [[ ! ${SYSD_FILE_CLIENT+x} ]] ; then SYSD_FILE_CLIENT='/etc/systemd/system/consul-client.service' ; fi ; # // SystemD unit
if [[ ! ${SYSD_FILE_SERVER+x} ]] ; then SYSD_FILE_SERVER='/etc/systemd/system/consul-server.service' ; fi ; # // SystemD unit

if [[ ! ${LICENSE+x} ]]; then LICENSE='' ; fi ; # // for enterprise version

# macOS: ipconfig getifaddr
if [[ ! ${PATH_BINARY+x} ]]; then PATH_BINARY='/usr/local/bin/consul' ; fi ;
if [[ ! ${PATH_CONSUL_CONFIG+x} ]]; then PATH_CONSUL_CONFIG="${PATH_CONSUL}/consul.hcl" ; fi ; # // AGENT CLIENT CONF
if [[ ! ${PATH_CONSUL_CONFIG_SERVER+x} ]]; then PATH_CONSUL_CONFIG_SERVER="${PATH_CONSUL}/server.hcl" ; fi ; # // AGENT SERVER CONF
if [[ ! ${PATH_CONSUL_DATA+x} ]]; then PATH_CONSUL_DATA="/opt/consul" ; fi ;

if [[ ! ${URL_CONSUL+x} ]]; then URL_CONSUL='https://releases.hashicorp.com/consul/' ; fi ;
if [[ ! ${CONSUL_VERSION+x} ]]; then CONSUL_VERSION='' ; fi ; # // VERSIONS: "1.7.0' for regular release version - '1.6.3+ent' for Enterprise

if [[ ! ${OS_CPU+x} ]]; then OS_CPU='' ; fi ; # // ARCH CPU's: 'amd64', '386', 'arm64' or 'arm'
if [[ ! ${OS_VERSION+x} ]]; then OS_VERSION=$(uname -ar) ; fi ; # // OS's: 'Darwin', 'Linux', 'Solaris', 'FreeBSD', 'NetBSD', 'OpenBSD'
if [[ ! ${PATH_INSTALL+x} ]]; then PATH_INSTALL="$(pwd)/consul_installs" ; fi ; # // where consul install files will be

if [[ ! ${IPS+x} ]]; then IPS='"__IPS-SET__"' ; fi ;
if [[ ! ${IP_WAN_INTERFACE+x} ]]; then IP_WAN_INTERFACE="$(ip a | awk '/: / { print $2 }' | sed -n 3p | cut -d ':' -f1)" ; fi ; # // 2nd interface 'eth1'
if [[ ! ${IP_LAN_INTERFACE+x} ]]; then IP_LAN_INTERFACE="$(ip a | awk '/: / { print $2 }' | sed -n 3p | cut -d ':' -f1)" ; fi ; # // 2nd interface 'eth1'
if [[ ! ${NODE_NAME+x} ]]; then NODE_NAME="$(hostname)" ; fi ;

if [[ ! ${FILE+x} ]]; then FILE="consul_${CONSUL_VERSION}_" ; fi ; # // part of URL file to obtain
if [[ ! ${URL+x} ]]; then URL="${URL_CONSUL}${CONSUL_VERSION}/" ; fi ; # // later part of URL file to obtain
if [[ ! ${URL2+x} ]]; then URL2="${URL_CONSUL}${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS" ; fi ; # // SHA256 sums

if [[ ! ${IP_WAN+x} ]]; then
	IP_WAN="$(ip a show ${IP_WAN_INTERFACE} | grep -oE '\b((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b' | head -n 1)" ;
	if (( $? != 0 )) ; then pERR "ERROR: Unable to determine WAN IP of ${IP_WAN_INTERFACE}" ; fi ;
fi ;

if [[ ! ${IP_LAN+x} ]]; then
	IP_LAN="$(ip a show ${IP_LAN_INTERFACE} | grep -oE '\b((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b' | head -n 1)" ;
	if (( $? != 0 )) ; then pERR "ERROR: Unable to determine LAN IP of ${IP_LAN_INTERFACE}" ; fi ;
fi ;

if ! mkdir -p ${PATH_INSTALL} 2>/dev/null ; then pERR "ERROR: Could not create directory at: ${PATH_INSTALL}"; exit 1; fi ;

sERR="REFER TO: ${URL_CONSUL}\n\nERROR: Operating System Not Supported." ;
sERR_DL="REFER TO: ${URL_CONSUL}\n\nERROR: Could not determined download state." ;

# // PGP Public Key on Security Page which can be piped to file.
#PGP_KEY_PUB=$(curl -s https://www.hashicorp.com/security.html | grep -Pzo '\-\-\-\-\-BEGIN PGP PUBLIC KEY BLOCK\-\-\-\-\-\n.*\n(\n.*){27}?') ;
#curl -s ${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS.sig ;
#getconf LONG_BIT ; # // can be handy for 32bit vs 64bit determination

# // DETERMINE LATEST VERSION - where none are provided.
if [[ ${CONSUL_VERSION} == '' ]] ; then
	CONSUL_VERSION=$(curl -s ${URL_CONSUL} | grep '<a href="/consul/' | grep -v -E 'alpha|beta|rc|ent' | head -n 1 | grep -E -o '([0-9]{1,3}[\.]){2}[0-9]{1,3}' | head -n 1) ;
	if [[ ${CONSUL_VERSION} == '' ]] ; then
		pERR 'ERROR: Could not determine valid / current consul version to download.' ;
		exit 1 ;
		else
		# // re-assign all version related refernces
		FILE="consul_${CONSUL_VERSION}_" ;
		URL="${URL_CONSUL}${CONSUL_VERSION}/" ;
		URL2="${URL_CONSUL}${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS" ;
	fi ;
fi ;

set +e ; CHECK=$(consul --version 2>&1) ; set -e ; # // maybe required consul version is already installed.
if [[ ${CHECK} == *"v${CONSUL_VERSION}"* ]] && [[ (($# == 0)) || $1 != "-f" ]] ; then pOUT "Consule v${CONSUL_VERSION} already installed; Use '-f' to force this script to run anyway.\nNo action taken." && exit 0 ; fi ;

sAOK="\nRemember to copy ('cp'), link ('ln') or path the consul executable as required." ;
sAOK+="\nTry: '${PATH_BINARY} --version' ; # to test.\n\nSuccessfully installed Consul ${CONSUL_VERSION} in: ${PATH_INSTALL}" ;

function donwloadUnpack()
{
	pOUT "Downloading from: ${URL}\n" ;
	cd ${PATH_INSTALL} && \
	if wget -qc ${URL} && wget -qc ${URL2} ; then
		if [[ $(shasum -a 256 -c consul_${CONSUL_VERSION}_SHA256SUMS 2>/dev/null | grep OK) == *" OK"* ]] ; then
			if unzip -qo ${FILE} ; then
				chown -R ${USER_MAIN} ${PATH_INSTALL} ;
				pOUT "${sAOK}" ;
			else
				pERR 'ERROR: Could not unzip.' ;
			fi ;
		else
			pERR 'ERROR: During shasum - Downloaded .zip corrupted?' ;
			exit 1 ;
		fi ;
	else
		pERR "${sERR_DL}" ; exit 1 ;
	fi ;
}

if [[ ${OS_CPU} == '' ]] ; then
	if [[ ${OS_VERSION} == *'x86_64'* ]] ; then
		OS_CPU='amd64' ;
	else
		if [[ ${OS_VERSION} == *' i386'* || ${OS_VERSION} == *' i686'* ]] ; then OS_CPU='386' ; fi ;
		if [[ ${OS_VERSION} == *' armv6'* || ${OS_VERSION} == *' armv7'* ]] ; then OS_CPU='arm' ; fi ;
		if [[ ${OS_VERSION} == *' armv8'* || ${OS_VERSION} == *' aarch64'* ]] ; then OS_CPU='arm64' ; fi ;
		if [[ ${OS_VERSION} == *'solaris'* ]] ; then OS_CPU='amd64' ; fi ;
	fi ;
	if [[ ${OS_CPU} == '' ]] ; then pERR "${sERR}" ; exit 1 ; fi ;
fi ;

case "$(uname -ar)" in
	Darwin*) #pOUT 'macOS (aka OSX)\n' ;
		if which brew > /dev/null ; then
			pOUT 'Consider: "brew install consul" since you have HomeBrew availble.' ;
		else :; fi ;
		FILE="${FILE}darwin_${OS_CPU}.zip" ;
	;;
	Linux*) #pOUT 'Linux\n' ;
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
		pOUT "Conisder downloading (exe) from: ${URL}.\nUse consul.exe from CMD / Windows Prompt(s)." ;
		exit 0 ;
	;;

	*)	pERR "${sERR}" ;
		exit 1 ;
	;;
esac ;

function sudoSetup()
{
	if [[ ${FILE} == *"darwin"* ]] ; then pOUT '\nWARNING: On MacOS - all other setup setps will need to be appropriatly completed by the user.\n' ; exit 0 ; fi ;
	if ! (( $(id -u) == 0 )) ; then pERR 'ERROR: Root privileges lacking to peform all setup tasks. Consider "sudo ..." re-execution.' ; exit 1 ; fi ;

	# // Move consul to default paths
	cd ${PATH_INSTALL} && \
	chown root:root consul && \
	mv consul ${PATH_BINARY} ;

	# Create a unique, non-privileged system user to run Consul.
	if ! id -u ${USER_CONSUL} &>/dev/null ; then
		useradd --system --home ${PATH_CONSUL} --shell /bin/false ${USER_CONSUL} ;
	else
		pOUT "USER: ${USER_CONSUL} - already present." ;
	fi ;

	# // Enable auto complete
	set +e
	consul -autocomplete-install 2>/dev/null && complete -C ${PATH_BINARY} consul 2>/dev/null ;
	su -l ${USER_MAIN} -c "consul -autocomplete-install 2>/dev/null && complete -C ${PATH_BINARY} consul 2>/dev/null;" 2>&1>/dev/null
	set -e

	# // SystemD for service / startup
	if ! which systemctl 2>&1>/dev/null ; then pERR 'ERROR: No systemctl / SystemD installed on system.' ; exit 1 ; fi ;
	if [[ ${FILE} == *"darwin"* ]] ; then pERR 'ERROR: Only SystemD can be provisioned - build MacOS launchd plist yourself.' ; exit 1 ; fi ;

	if ! [[ -d ${PATH_CONSUL_DATA} ]] ; then mkdir -p ${PATH_CONSUL_DATA} && chown -R ${USER_CONSUL}:${USER_CONSUL} ${PATH_CONSUL_DATA} ; fi ;

	mkdir -p ${PATH_CONSUL} ;

	if [[ ${SETUP,,} == *'client'* ]] && ! [[ -s ${PATH_CONSUL_CONFIG} ]] ; then
		if printf 'server = false
node_name = "'${NODE_NAME}'"
data_dir = "'"${PATH_CONSUL_DATA}"'"
bind_addr = "'${IP_WAN}'"
client_addr = "127.0.0.1"
retry_join = ['"${IPS}"']
enable_syslog = true
' > ${PATH_CONSUL_CONFIG} && chmod 640 ${PATH_CONSUL_CONFIG} ; then :;
		else
			pERR "ERROR: Unable to create config: ${PATH_CONSUL_CONFIG}." ; exit 1 ;
		fi ;
	else
		if [[ ${SETUP,,} == *'client'* ]] ; then pOUT "CONSUL Conifg: ${PATH_CONSUL_CONFIG} - already present." ; fi ;
	fi ;

	if [[ ${SETUP,,} == *'server'* ]] && ! [[ -s ${PATH_CONSUL_CONFIG_SERVER} ]] ; then
		if touch ${PATH_CONSUL_CONFIG_SERVER} && chown -R ${USER_CONSUL}:${USER_CONSUL} ${PATH_CONSUL} && chmod 640 ${PATH_CONSUL_CONFIG_SERVER} && \
			printf 'server = true
data_dir = "'${PATH_CONSUL_DATA}'"
bootstrap_expect = 3
ui = true
node_name = "'${NODE_NAME}'"
bind_addr = "'${IP_WAN}'"
advertise_addr = "'${IP_WAN}'"
advertise_addr_wan = "'${IP_WAN}'"
start_join = ['"${IPS}"']
retry_join = ['"${IPS}"']
' > ${PATH_CONSUL_CONFIG_SERVER} ; then :;
		else
			pERR "ERROR: Unable to create ${PATH_CONSUL_CONFIG_SERVER}." ; exit 1 ;
		fi ;

	else
		if [[ ${SETUP,,} == *'server'* ]] ; then pOUT "CONSUL Server conifg: ${PATH_CONSUL_CONFIG_SERVER} - already present." ; fi ;
	fi ;

	chown -R ${USER_CONSUL}:${USER_CONSUL} ${PATH_CONSUL} ;

	if ! [[ -s ${SYSD_FILE_SERVER} ]] && [[ ${SETUP,,} == *'server'* ]] ; then
		UNIT_FILE=${PATH_CONSUL_CONFIG_SERVER} ;
		UNIT_SYSTEMD='[Unit]\nDescription="HashiCorp Consul - A service mesh solution"\nDocumentation=https://www.consul.io/\nRequires=network-online.target\nAfter=network-online.target\nConditionFileNotEmpty='${UNIT_FILE}'\n\n[Service]\nType=notify\nUser=consul\nGroup=consul\nExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/\nExecReload=/usr/local/bin/consul reload\nKillMode=process\nRestart=on-failure\nLimitNOFILE=65536\n\n[Install]\nWantedBy=multi-user.target\n' ;
		printf "${UNIT_SYSTEMD}" > ${SYSD_FILE_SERVER} && chmod 664 ${SYSD_FILE_SERVER}
		# // Determine name of service from provided path
		IFS='/' read -a aPATHS <<< "${SYSD_FILE_SERVER}" ;
		SYSD_FILE_SERVER=${aPATHS[${#aPATHS[@]}-1]} ;
		systemctl daemon-reload ;
		set +e ;
		systemctl start ${SYSD_FILE_SERVER} ;
		set -e ;
		systemctl enable ${SYSD_FILE_SERVER} ;
	fi ;

	if ! [[ -s ${SYSD_FILE_CLIENT} ]] && [[ ${SETUP,,} == *'client'* ]] ; then
		UNIT_FILE=${PATH_CONSUL_CONFIG} ;
		UNIT_SYSTEMD='[Unit]\nDescription="HashiCorp Consul - A service mesh solution"\nDocumentation=https://www.consul.io/\nRequires=network-online.target\nAfter=network-online.target\nConditionFileNotEmpty='${UNIT_FILE}'\n\n[Service]\nType=notify\nUser=consul\nGroup=consul\nExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/\nExecReload=/usr/local/bin/consul reload\nKillMode=process\nRestart=on-failure\nLimitNOFILE=65536\n\n[Install]\nWantedBy=multi-user.target\n' ;
		printf "${UNIT_SYSTEMD}" > ${SYSD_FILE_CLIENT} && chmod 664 ${SYSD_FILE_CLIENT}
		# // Determine name of service from provided path
		IFS='/' read -a aPATHS <<< "${SYSD_FILE_CLIENT}" ;
		SYSD_FILE_CLIENT=${aPATHS[${#aPATHS[@]}-1]} ;
		systemctl daemon-reload ;
		set +e ;
		systemctl start ${SYSD_FILE_CLIENT} ;
		set -e ;
		systemctl enable ${SYSD_FILE_CLIENT} ;
	fi ;

	# // apply license if not already there.
	if ! [[ ${LICENSE} == "" ]] && [[ ${SETUP,,} == *'server'* ]] ; then
		LICENSE_ATM=$(consul license get | grep -i 'License ID') ;
		LICENSE_EXP=$(consul license get | grep -i 'Expires') ;
		if [[ ${LICENSE_ATM} == *": temporary"* ]] ; then
			consul license put "${LICENSE}" ;
		else
			pOUT "CONSUL LICNESE: Already present & ${LICENSE_EXP}" ;
		fi ;
	fi ;

        if [[ -s /home/${USER_MAIN}/.config/neofetch/config.conf ]] && ! [[ -s ${PATH_CONSUL}/logo.txt ]] ; then
                printf '''
${c1}    █████████◤
${c1}  ██          ${c5}HashiCorp
${c1}██    ,gPPRg,    ◉
${c1}██   8)     (8  ◉ ◉
${c1}██   Yb     dP ◉
${c1}██    "8ggg8"   ◉ ◉
${c1} ███             ◉
${c1}   ███████████◤ ${c6}Consul''' > ${PATH_CONSUL}/logo.txt ;
                printf "neofetch --source ${PATH_CONSUL}/logo.txt --ascii_colors 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15" > /etc/profile.d/neofetch.sh ;
		sed -i 's/info title/#info title/g' /home/${USER_MAIN}/.config/neofetch/config.conf
		sed -i 's/info underline/#info underline/g' /home/${USER_MAIN}/.config/neofetch/config.conf
		sed -i 's/info "Packages"/#info "Packages"/g' /home/${USER_MAIN}/.config/neofetch/config.conf
		sed -i 's/info "Resolution"/#info "Resolution/g' /home/${USER_MAIN}/.config/neofetch/config.conf
		sed -i 's/info "GPU"/#info "GPU"/g' /home/${USER_MAIN}/.config/neofetch/config.conf
		sed -i 's/info "Terminal" term/#info "Terminal" term/g' /home/${USER_MAIN}/.config/neofetch/config.conf
		sed -i 's/info title/#info title/g' /home/${USER_MAIN}/.config/neofetch/config.conf
		sed -i 's/# info "Disk"/info "Disk"/g' /home/${USER_MAIN}/.config/neofetch/config.conf
		sed -i 's/# info "Local IP"/info "Local IP"/g' /home/${USER_MAIN}/.config/neofetch/config.conf
		sed -i 's/gap=3/gap=0/g' /home/${USER_MAIN}/.config/neofetch/config.conf
		sed -i 's/memory_percent="off"/memory_percent="on"/g' /home/${USER_MAIN}/.config/neofetch/config.conf
		sed -i 's/info cols/#info cols\n    prin "\\n ${c0}▉${c2}▉${c3}▉${c4}▉${c5}▉${c6}▉${c1}▉${reset}${c15}▉${c2}▉${c3}▉${c4}▉${c5}▉${c6}▉${c1}▉${reset}${c15}▉"/g' /home/${USER_MAIN}/.config/neofetch/config.conf
        fi ;
}
URL="${URL}${FILE}" ;
donwloadUnpack && if [[ ${SETUP,,} == *'client'* || ${SETUP,,} == *'server'* ]]; then sudoSetup ; fi ;
