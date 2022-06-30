#!/usr/bin/env bash
set -eu ; # abort this script when a command fails or an unset variable is used.
#set -x ; # echo all the executed commands

# // OpenSSL Configuration & paths
OPENSSL_PATH=$(openssl version -a | grep OPENSSLDIR | grep -oP '"\K[^"\047]+(?=["\047])') ; # // get directory path
OPENSSL_CONF="${OPENSSL_PATH}/openssl.cnf" ;

# // logger
function pOUT() { printf "$1\n" ; } ;

# // Colourised logger for errors (red)
function pERR()
{	# sMSG=${1/@('ERROR:')/"\e[31mERROR:\e[0m"} ; sMSG=${1/('ERROR:')/"\e[31mERROR:\e[0m"}
	if [[ $1 == "--"* ]] ; then pOUT "\e[31m$1\n\e[0m\n" ;
	else pOUT "\n\e[31m$1\n\e[0m\n" ; fi ;
}

if [[ ! ${IP_WAN_INTERFACE+x} ]]; then IP_WAN_INTERFACE="$(ip a | awk '/: / { print $2 }' | sed -n 3p | cut -d ':' -f1)" ; fi ; # 2nd interface 'eth1'
if [[ ! ${IP_WAN+x} ]]; then
	IP_WAN="$(ip a show ${IP_WAN_INTERFACE} | grep -oE '\b((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b' | head -n 1)" ;
	if (( $? != 0 )) ; then pERR "--ERROR: Unable to determine WAN IP of ${IP_WAN_INTERFACE}" ; fi ;
fi ;

IP_WAN2='' ;
if [[ ! ${IP_LB_INTERFACE+x} ]]; then IP_LB_INTERFACE="$(ip a | awk '/: / { print $2 }' | sed -n 4p | cut -d ':' -f1)" ; fi ; # // 2nd interface 'eth2'
if [[ ! ${IP_LB+x} && ${IP_LB_INTERFACE} != "" ]]; then
	IP_WAN2="$(ip a show ${IP_LB_INTERFACE} | grep -oE '\b((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b' | head -n 1)" ;
	if (( $? != 0 )) ; then
		pERR "ERROR: Unable to determine LB IP of ${IP_LB_INTERFACE}" ;
	else
		IP_WAN2="IP.3=${IP_WAN2}"
	fi ;
fi ;


if [[ ! ${VAULT_NODENAME+x} ]]; then VAULT_NODENAME=$(hostname) ; fi ; # // will be based on hostname *1 == main, others standby.

# // if current host is HAProxy then we'll set CA configs and generate certificates.
if [[ ${VAULT_NODENAME,,} == *"haproxy"* ]] ; then
	if [[ ! ${VAULT_FILE_KEY+x} ]]; then VAULT_FILE_KEY='haproxy_private.key' ; fi ;
	if [[ ! ${VAULT_FILE_CSR+x} ]]; then VAULT_FILE_CSR='haproxy_tbc.csr' ; fi ;
	if [[ ! ${VAULT_FILE_CRT+x} ]]; then VAULT_FILE_CRT='haproxy_certificate.crt' ; fi ;
fi ;

if [[ ! ${CA_FILENAME+x} ]]; then CA_FILENAME='cacert.crt' ; fi ;
if [[ ! ${CA2_FILENAME+x} ]]; then CA2_FILENAME='cacert2.crt' ; fi ;

if [[ ! ${IP_VAULT1+x} ]]; then pERR "--ERROR: IP address of first vault required. IP_VAULT1 variable not passed." ; fi ;
if [[ ! ${FQDN_VAULT1+x} ]]; then pERR "--ERROR: FQDN address of first vault required. FQDN_VAULT1 variable not passed." ; fi ;

CA_CSN='3141' ; # // CA - Certificate Serial Number (starting issue number)
SECRET_CA='' ; # // CA - Certificate password
SECRET_VLT='' ; # // VAULT - Certificate password

CA_FILE_KEY="${OPENSSL_PATH}/private/cakey.pem" ;
CA_FILE_CSR='cacert.csr' ;
CA_FILE_CRT="${OPENSSL_PATH}/${CA_FILENAME}" ;

INT_FILE_KEY="${OPENSSL_PATH}/private/intermediate.pem" ;
INT_FILE_CSR='intermediate.csr' ;
INT_FILE_CRT="${OPENSSL_PATH}/intermediate_certificate.pem" ;

I_TLS_COUNTRY='GB' ; # // Intermediate COUNTRY 2-letters - MUST PROVIDE
I_TLS_STATE='.' ; # // Intermediate STATE OR PROVINCE
I_TLS_CITY='.' ; # // Intermediate CITY
I_TLS_ORG='.' ; # // Intermediate ORGANISATION
I_TLS_ORGU='HAP Vault CA' ; # // Intermediate ORGANISATIONAL UNIT
I_TLS_CN='hap-vault.tld.com.local' ; # // Intermediate COMMON NAME
I_TLS_EMAIL='user@hap-vault.tld.com.local' ; # // Intermediate EMAIL ADDRESS
I_CSR_SUB="/C=${I_TLS_COUNTRY}/ST=${I_TLS_STATE}/L=${I_TLS_CITY}/O=${I_TLS_ORG}/OU=${I_TLS_ORGU}/CN=${I_TLS_CN}/emailAddress=${I_TLS_EMAIL}" ;

TLS_TTL=3652 ; # // 10 years approximately

C_TLS_COUNTRY='GB' ; # // CA COUNTRY 2-letters - MUST PROVIDE
C_TLS_STATE='.' ; # // CA STATE OR PROVINCE
C_TLS_CITY='.' ; # // CA CITY
C_TLS_ORG='.' ; # // CA ORGANISATION
C_TLS_ORGU='.' ; # // CA ORGANISATIONAL UNIT
C_TLS_CN='www.hap-vault-tld.com.local' ; # // CA COMMON NAME
C_TLS_EMAIL='user@hap-vault-tld.com.local' ; # // CA EMAIL ADDRESS
CA_CSR_SUB="/C=${C_TLS_COUNTRY}/ST=${C_TLS_STATE}/L=${C_TLS_CITY}/O=${C_TLS_ORG}/OU=${C_TLS_ORGU}/CN=${C_TLS_CN}/emailAddress=${C_TLS_EMAIL}" ;

VAULT_TLS_COUNTRY='GB' ; # // HAProxy COUNTRY 2-letters - MUST PROVIDE
VAULT_TLS_STATE='.' ; # // HAProxy STATE OR PROVINCE
VAULT_TLS_CITY='.' ; # // HAProxy CITY
VAULT_TLS_ORG='.' ; # // HAProxy ORGANISATION
VAULT_TLS_ORGU='.' ; # // HAProxy ORGANISATIONAL UNIT
VAULT_TLS_CN='hap-vault.tld.com.local' ; # // HAProxy COMMON NAME
VAULT_TLS_EMAIL='user2@hap-vault.tld.local' ; # // HAProxy EMAIL ADDRESS
VAULT_CSR_SUB="/C=${VAULT_TLS_COUNTRY}/ST=${VAULT_TLS_STATE}/L=${VAULT_TLS_CITY}/O=${VAULT_TLS_ORG}/OU=${VAULT_TLS_ORGU}/CN=${VAULT_TLS_CN}/emailAddress=${VAULT_TLS_EMAIL}" ;

LOCAL_FQDN=$(hostname -f)

VAULT_SAN="""[SAN]
subjectAltName=@alt_names
basicConstraints=CA:FALSE
[alt_names]
DNS.1=localhost
DNS.2=${LOCAL_FQDN}
IP.1=127.0.0.1
IP.2=${IP_WAN}
${IP_WAN2}
""" ;

LOGNAME=$(logname) ;

mkdir -p "${OPENSSL_PATH}/newcerts" "${OPENSSL_PATH}/certs" "${OPENSSL_PATH}/crl" "${OPENSSL_PATH}/private" "${OPENSSL_PATH}/requests" ;
touch "${OPENSSL_PATH}/index.txt" ;

if ! [[ -s "${OPENSSL_PATH}/serial" ]] ; then
	printf "${CA_CSN}\n" > "${OPENSSL_PATH}/serial" ; # starting certificate serial
fi ;

if grep -E '\[\s?CA_default\s?]|\[\s?ca\s?\]' ${OPENSSL_CONF} 2>&1>/dev/null ; then
	pOUT '[ CA_default ] - exists in OpenSSL configuration.'
	# // CHANGE DEFAULT DIR PATH - '/' forward slashes need escaping.
	sed -i 's/^dir.*\.\/demoCA/dir\t\t= '${OPENSSL_PATH////\\/}'/g' ${OPENSSL_CONF} ;
	sed -i 's/cacert\.pem/'${CA_FILE_CRT##*/}'/g' ${OPENSSL_CONF} ;
else
	pOUT "ERROR: Malformed / bad or empty configuration file (${OPENSSL_CONF})." ; exit 1 ;
fi ;

function makeRootCA()
{
	# // ---------------------------------------------------------------------------
	# // ROOT CA PRIVATE KEY
	if ! [[ -s ${CA_FILE_KEY} ]] ; then
		# // CA Private Key
		if [[ ${SECRET_CA} == '' ]] ; then
			# // openssl genrsa -aes256 -out ${CA_FILE_KEY} 4096 ;
			openssl genrsa -out ${CA_FILE_KEY} 4096 2>/dev/null ;
		else
			openssl genrsa -aes256 -passout pass:${SECRET_CA} -out ${CA_FILE_KEY} 4096 2>/dev/null ;
		fi ;
		pOUT "MADE TLS - CA - Key: ${CA_FILE_KEY}." ;
	else
		pOUT "ALREADY have TLS - CA - Key: ${CA_FILE_KEY}" ;
	fi ;
	# // ---------------------------------------------------------------------------
	# // CA certificate signing request CSR
	if ! [[ -s ${CA_FILE_CSR} ]] ; then
		if [[ ${SECRET_CA} == '' ]] ; then
			openssl req -new -key ${CA_FILE_KEY} -out ${CA_FILE_CSR} -subj "${CA_CSR_SUB}" 2>/dev/null ;
		else
			openssl req -passin pass:${SECRET_CA} -new -key ${CA_FILE_KEY} -out ${CA_FILE_CSR} -subj "${CA_CSR_SUB}" 2>/dev/null ; # -sha256
		fi ;
		# pOUT "MADE TLS - CA - Csr: ${CA_FILE_CSR}." ;
	else
		pOUT "ALREADY have TLS - CA - Csr: ${CA_FILE_CSR}" ;
	fi ;
	# // ---------------------------------------------------------------------------
	# // CA CSR to self-sign / approve
	# openssl req -passin pass:${SECRET_CA} -x509 -sha256 -days ${TLS_TTL} -key ${CA_FILE_KEY} -in ${CA_FILE_CSR} -out ${CA_FILE_CRT}
	if ! [[ -s ${CA_FILE_CRT} ]] ; then
		if [[ ${SECRET_CA} == '' ]] ; then
	#		openssl ca -batch -days ${TLS_TTL} -in ${CA_FILE_CSR} -out ${CA_FILE_CRT} ;
			openssl req -extensions v3_ca -x509 -days ${TLS_TTL} -key ${CA_FILE_KEY} -in ${CA_FILE_CSR} -out ${CA_FILE_CRT} 2>/dev/null ;
		else
	#		openssl ca -batch -passin pass:${SECRET_CA} -days ${TLS_TTL} -in ${CA_FILE_CSR} -out ${CA_FILE_CRT} ;
			openssl req -extensions v3_ca -passin pass:${SECRET_CA} -x509 -sha256 -days ${TLS_TTL} -key ${CA_FILE_KEY} -in ${CA_FILE_CSR} -out ${CA_FILE_CRT} 2>/dev/null ;
		fi ;
		# // ^^ To be distributed consumers of certificates and other certificates signed by us.
		pOUT "MADE TLS - CA - Crt: ${CA_FILE_CRT}." ;
		cp ${CA_FILE_CRT} . ;
	else
		pOUT "ALREADY have TLS - CA - Crt: ${CA_FILE_CRT}" ;
	fi ;
	# // ---------------------------------------------------------------------------
	# // ---------------------------------------------------------------------------
}

function makeInermediateCA()
{
	# // ---------------------------------------------------------------------------
	# // INTERMEDIATE PRIVATE KEY
	if ! [[ -s ${INT_FILE_KEY} ]] ; then
		# // CA Private Key
		if [[ ${SECRET_CA} == '' ]] ; then
			# // openssl genrsa -aes256 -out ${CA_FILE_KEY} 4096 ;
			openssl genrsa -out ${INT_FILE_KEY} 4096 2>/dev/null ;
		else
			openssl genrsa -aes256 -passout pass:${SECRET_CA} -out ${INT_FILE_KEY} 4096 2>/dev/null ;
		fi ;
		pOUT "MADE TLS - CA - Key Intermediate: ${INT_FILE_KEY}." ;
	else
		pOUT "ALREADY have: ${INT_FILE_KEY}" ;
	fi ;
	# // ---------------------------------------------------------------------------
	# // INTERMEDIATE certificate signing request CSR
	if ! [[ -s ${INT_FILE_CSR} ]] ; then
		if [[ ${SECRET_CA} == '' ]] ; then
			openssl req -new -key ${INT_FILE_KEY} -out ${INT_FILE_CSR} -subj "${I_CSR_SUB}" 2>/dev/null ;
		else
			openssl req -passin pass:${SECRET_CA} -new -key ${INT_FILE_KEY} -out ${INT_FILE_CSR} -subj "${I_CSR_SUB}" 2>/dev/null ; # -sha256
		fi ;
		#pOUT "GENERATED: CSR - Intermediate - ${INT_FILE_CSR}." ;
	else
		pOUT "ALREADY have: ${INT_FILE_CSR}" ;
	fi ;
	# // ---------------------------------------------------------------------------
	# // INTERMEDIATE CSR to self-sign / approve
	if ! [[ -s ${INT_FILE_CRT} ]] ; then
		if [[ ${SECRET_CA} == '' ]] ; then
			openssl ca -extensions v3_ca -batch -days ${TLS_TTL} -in ${INT_FILE_CSR} -out ${INT_FILE_CRT} 2>/dev/null ;
		else
			openssl ca -extensions v3_ca -batch -passin pass:${SECRET_CA} -days ${TLS_TTL} -in ${INT_FILE_CSR} -out ${INT_FILE_CRT} 2>/dev/null ;
		fi ;
		pOUT "GENERATED: Certifiate - Intermediate - ${INT_FILE_CRT}." ;
		# // ^^ To be distributed to issuing CA (Vault).
		cp ${INT_FILE_CRT} . ;
		CERT_INTER_BUNDLE='ca_intermediate.pem' ;
		cat ${INT_FILE_CRT} ${INT_FILE_KEY} ${CA_FILE_CRT} > ${CERT_INTER_BUNDLE} ;
	else
		pOUT "ALREADY have: ${INT_FILE_CRT}" ;
	fi ;
	# // ---------------------------------------------------------------------------
	# // ---------------------------------------------------------------------------
}
sMSG_TLS_GENERATED_KEYS=('MADE TLS Client Key(s):') ;
sMSG_TLS_GENERATED_CSRS=('MADE TLS Client Csr(s):') ;
sMSG_TLS_GENERATED_CRTS=('MADE TLS Client Crt(s):') ;

sMSG_TLS_EXISTS_KEYS=('ALREADY have TLS Client Key(s):') ;
sMSG_TLS_EXISTS_CSRS=('ALREADY have TLS Client Csr(s):') ;
sMSG_TLS_EXISTS_CRTS=('ALREADY have TLS Client Crt(s):') ;

function makeCertificate()
{
	# // ---------------------------------------------------------------------------
	# // VAULT Private Key
	if ! [[ -s ${VAULT_FILE_KEY} ]] ; then
		if [[ ${SECRET_VLT} == '' ]] ; then
			openssl genrsa -out ${VAULT_FILE_KEY} 4096 2>/dev/null ;
		else
			openssl genrsa -aes256 -passout pass:${SECRET_VLT} -out ${VAULT_FILE_KEY} 4096 2>/dev/null ;
		fi ;
		sMSG_TLS_GENERATED_KEYS+=("${VAULT_FILE_KEY}") ;
	else
		sMSG_TLS_EXISTS_CRTS+=("${VAULT_FILE_KEY}") ;
	fi ;

	# // VAULT CSR Sign / Approve
	# openssl req -passin pass:${SECRET_CA} -x509 -sha256 -days ${TLS_TTL} -key ${CA_FILE_KEY} -in ${VAULT_FILE_CSR} -out ${VAULT_FILE_CRT} ;
	if ! [[ -s ${VAULT_FILE_CRT} ]] ; then
		# // VAULT CSR Generate
		if ! [[ -s ${VAULT_FILE_CSR} ]] ; then
			if [[ ${SECRET_VLT} == '' ]] ; then
				openssl req -new -key ${VAULT_FILE_KEY} -out ${VAULT_FILE_CSR} -subj "${VAULT_CSR_SUB}" 2>/dev/null ; # -sha256
			else
				openssl req -passin pass:${SECRET_VLT} -new -key ${VAULT_FILE_KEY} -out ${VAULT_FILE_CSR} -subj "${VAULT_CSR_SUB}" 2>/dev/null ; # -sha256
			fi ;
			sMSG_TLS_GENERATED_CSRS+=("${VAULT_FILE_CSR}") ;
		else
			sMSG_TLS_EXISTS_CSRS+=("${VAULT_FILE_CSR}") ;
		fi ;

		if [[ ${SECRET_CA} == '' ]] ; then
			# openssl ca -batch -days ${TLS_TTL} -in ${VAULT_FILE_CSR} -out ${VAULT_FILE_CRT} 2>/dev/null ;
			openssl ca -batch -days ${TLS_TTL} -in ${VAULT_FILE_CSR} -out ${VAULT_FILE_CRT} -extensions SAN -extfile <(printf "${VAULT_SAN}") 2>/dev/null ;
		else
			# openssl ca -batch -passin pass:${SECRET_CA} -days ${TLS_TTL} -in ${VAULT_FILE_CSR} -out ${VAULT_FILE_CRT} 2>/dev/null ;
			openssl ca -batch --passin pass:${SECRET_CA} days ${TLS_TTL} -in ${VAULT_FILE_CSR} -out ${VAULT_FILE_CRT} -extensions SAN -extfile <(printf "${VAULT_SAN}") 2>/dev/null ;
		fi ;
		sMSG_TLS_GENERATED_CRTS+=("${VAULT_FILE_CRT}") ;
	else
		sMSG_TLS_EXISTS_CRTS+=("${VAULT_FILE_CRT}") ;
	fi ;
}

function makeCertificates_Vault()
{
	VAULT_FILE_KEY='vault_private.key' ;
	VAULT_FILE_CSR='vault_tbc.csr' ;
	VAULT_FILE_CRT='vault_certificate.crt' ;

	for ((iX=1; iX <= $1; ++iX)) ; do
		# // grab original values:
		O_VAULT_FILE_KEY=${VAULT_FILE_KEY} ;
		O_VAULT_FILE_CSR=${VAULT_FILE_CSR} ;
		O_VAULT_FILE_CRT=${VAULT_FILE_CRT} ;
		O_VAULT_TLS_CN=${VAULT_TLS_CN} ;
		O_VAULT_TLS_EMAIL=${VAULT_TLS_EMAIL} ;

		# // increment numbers used in all filenames.
		VAULT_FILE_KEY=${VAULT_FILE_KEY/vault/vault${iX}} ;
		VAULT_FILE_CSR=${VAULT_FILE_CSR/vault/vault${iX}} ;
		VAULT_FILE_CRT=${VAULT_FILE_CRT/vault/vault${iX}} ;
		VAULT_TLS_CN=${VAULT_TLS_CN/\./${iX}.} ;
		VAULT_TLS_EMAIL=${VAULT_TLS_CN/\./${iX}.} ;
		VAULT_CSR_SUB="/C=${VAULT_TLS_COUNTRY}/ST=${VAULT_TLS_STATE}/L=${VAULT_TLS_CITY}/O=${VAULT_TLS_ORG}/OU=${VAULT_TLS_ORGU}/CN=${VAULT_TLS_CN}/emailAddress=${VAULT_TLS_EMAIL}" ;
		FQDN_VAULT1=${FQDN_VAULT1/vault1/vault${iX}} ;
		VAULT_SAN=${VAULT_SAN/DNS\.2\=${LOCAL_FQDN}/DNS\.2=${FQDN_VAULT1}} ;
		LOCAL_FQDN=${FQDN_VAULT1}
		sIP2=$(printf ${IP_VAULT1} | cut -d. -f4) ;
		sIP2=${IP_VAULT1/%\.${sIP2}/\.$((sIP2-(iX-1)))} ; # // decremt IP based on D class - HAProxy & Vault nodes 23-IP's apart
		VAULT_SAN=${VAULT_SAN/IP\.2\=*/IP\.2=${sIP2}} ;
		# // should implement later if Vault certificates are expected to have dual IP
		if ! [[ IP_WAN2 == "" ]] ; then   # "IP.3=${IP_WAN2}"
			VAULT_SAN=${VAULT_SAN/IP\.3\=*/#IP\.3=...} ;
		fi ;
		makeCertificate ;

		# // re-assigns original values.
		VAULT_FILE_KEY=${O_VAULT_FILE_KEY} ;
		VAULT_FILE_CSR=${O_VAULT_FILE_CSR} ;
		VAULT_FILE_CRT=${O_VAULT_FILE_CRT} ;
		VAULT_TLS_CN=${O_VAULT_TLS_CN} ;
		VAULT_TLS_EMAIL=${O_VAULT_TLS_EMAIL} ;
	done ;

	if ((${#sMSG_TLS_GENERATED_KEYS[*]} > 1)) ; then printf '%s\n' "${sMSG_TLS_GENERATED_KEYS[*]}" ; fi ;
	#if ((${#sMSG_TLS_GENERATED_CSRS[*]} > 1)) ; then printf '%s\n' "${sMSG_TLS_GENERATED_CSRS[*]}" ; fi ;
	if ((${#sMSG_TLS_GENERATED_CRTS[*]} > 1)) ; then printf '%s\n' "${sMSG_TLS_GENERATED_CRTS[*]}" ; fi ;
	if ((${#sMSG_TLS_EXISTS_KEYS[*]} > 1)) ; then printf '%s\n' "${sMSG_TLS_EXISTS_KEYS[*]}" ; fi ;
	#if ((${#sMSG_TLS_EXISTS_CSRS[*]} > 1)) ; then printf '%s\n' "${sMSG_TLS_EXISTS_CSRS[*]}" ; fi ;
	if ((${#sMSG_TLS_EXISTS_CRTS[*]} > 1)) ; then printf '%s\n' "${sMSG_TLS_EXISTS_CRTS[*]}" ; fi ;
}

# // if current host is HAProxy then we'll set CA configs and generate certificates.
if [[ ${VAULT_NODENAME,,} == *"haproxy"* ]] ; then
	makeRootCA ;
	# makeInermediateCA ;
	makeCertificate ;  # // for HAPROXY itself.
	if [[ ${1-} ]] ; then makeCertificates_Vault $1 ; fi ;
	cat haproxy_private.key haproxy_certificate.crt > /usr/lib/ssl/haproxy_cert.pem ;
fi ;

# // if current host is vault1 then we'll set CA configs and generate certificates.
if [[ ${VAULT_NODENAME,,} == *"vault1" ]] ; then
	if ! [[ -s ${CA_FILENAME} ]] ; then makeRootCA ; fi ;
	# makeInermediateCA ;
	VNUM=1 ; if [[ ${1-} ]] ; then VNUM=$1 ; fi ;	
	makeCertificates_Vault $VNUM ;
fi ;

if [[ -s /etc/ca-certificates.conf ]] ; then
	if [[ -s ${CA_FILENAME} ]] ; then
		if [[ -s ${CA2_FILENAME} ]] ; then cp ${CA2_FILENAME} /usr/local/share/ca-certificates/. ; fi ;
		# // expected cacert.crt file in current script path (ommitting any prefix paths)
		if cp ${CA_FILENAME} /usr/local/share/ca-certificates/. ; then
			# // root CA must be added OS.
			CRT_UPDATE=$(update-ca-certificates 2>&1 | head -n2 | tail -n1 | cut -d' ' -f 1) ;
			if ((CRT_UPDATE != 0)) ; then
				pOUT "OS CA Certificates - ADDED: ${CRT_UPDATE} to trust store." ;
			else
				pERR "ERROR: CA Certificates\e[0m Nothing Added to trust store - ${CRT_UPDATE}!" ;
			fi ;
		else
			pERR "ERROR: CA Certificate could not be copied to path." ;
		fi ;
	else
		pERR "ERROR NO CERTIFICATE File: ${CA_FILENAME}." ;
	fi ;
else
	pOUT '\e[33mWARNING\e[0m: unable to determine OS ca-certificates path - did not add Root CA certificates.' ;
fi ;

chown -R ${LOGNAME} . ;

# // DELETE CSR
rm -rf *.csr ;

# // COPY KEY & CRT to OpenSSL Paths. (should not be needed)
# cp ${VAULT_FILE_KEY} ${OPENSSL_PATH}/private/. && cp ${VAULT_FILE_CRT} ${OPENSSL_PATH}/certs/.
# cat ${VAULT_FILE_KEY} ${VAULT_FILE_CRT} > combined_cert.pem ;

# // generation of p12
# sudo openssl pkcs12 -export -clcerts -in vault_certificate.pem -inkey vault_privatekey.pem -out client.p12

# // p12 with issuing (intermediate) ca cert (generated by vault)
#openssl pkcs12 -export -clcerts -in testing1.tld.com.local_certificate.pem -inkey testing1.tld.com.local_key.pem -chain -CAfile vault_ca.pem -out testing1.tld.com.local2.p12

# // REGENERATE SERVICE READY KEY with no pass prompts
# openssl rsa -in ${VAULT_FILE_KEY} -out unsecured.${VAULT_FILE_KEY}
