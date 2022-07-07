# -*- mode: ruby -*-
# vi: set ft=ruby :
# // To list interfaces on CLI typically:
# //	macOS: networksetup -listallhardwareports ;
# //	Linux: lshw -class network ;
sNET='en6: USB 10/100/1000 LAN'  # // network adaptor to use for bridged mode

iCLUSTERA_N = 1  # // Vault A INSTANCES UP TO 9 <= iN > 0
iCLUSTERB_N = 1  # // Vault B INSTANCES UP TO 9 <= iN > 0
iCLUSTERA_C = 0  # // Consul B INSTANCES UP TO 9 <= iN > 2
iCLUSTERB_C = 0  # // Consul B INSTANCES UP TO 9 <= iN > 2
bCLUSTERA_CONSUL = false  # // Consul A use Consul as store for vault?
bCLUSTERB_CONSUL = false  # // Consul B use Consul as store for vault?
bCLUSTERA_LB = false  # true  # // Cluster A with HAPROXY?
bCLUSTERB_LB = false  # // Cluster B with HAPROXY?

sCLUSTERA_IP_CLASS_D='192.168.178'  # // Consul A NETWORK CIDR forconfigs.
sCLUSTERB_IP_CLASS_D='192.168.178'  # // Consul B NETWORK CIDR for configs.
iCLUSTERA_IP_CONSUL_CLASS_D=110  # // Consul A IP starting D class (increment or de)
iCLUSTERB_IP_CONSUL_CLASS_D=120  # // Consul B IP starting D class (increment or de)
iCLUSTERA_IP_VAULT_CLASS_D=234  # // Vault A Leader IP starting D class (increment or de)
iCLUSTERB_IP_VAULT_CLASS_D=224  # // Vault B Leader IP starting D class (increment or de)
iCLUSTERA_IP_VAULT_CLASS_D2=184  # // Vault A Load-Balancer IP minus -1 on eth2 adaptor typically
iCLUSTERB_IP_VAULT_CLASS_D2=174  # // Vault A Load-Balancer IP minus -1 on eth2 adaptor typically

sCLUSTERA_IP_CA_NODE="#{sCLUSTERA_IP_CLASS_D}.#{iCLUSTERA_IP_VAULT_CLASS_D-1}"  # // Cluster A - static IP of CA
sCLUSTERB_IP_CA_NODE="#{sCLUSTERB_IP_CLASS_D}.#{iCLUSTERB_IP_VAULT_CLASS_D-1}"  # // Cluster B - static IP of CA
sCLUSTERA_sIP_VAULT_LEADER="#{sCLUSTERA_IP_CLASS_D}.#{iCLUSTERA_IP_VAULT_CLASS_D-1}"  # // Vault A static IP of CA
sCLUSTERB_sIP_VAULT_LEADER="#{sCLUSTERB_IP_CLASS_D}.#{iCLUSTERB_IP_VAULT_CLASS_D-1}"  # // Vault B static IP of CA
sCLUSTERA_IPS=''  # // Consul A - IPs constructed based on IP D class + instance number
sCLUSTERB_IPS=''  # // Consul B - IPs constructed based on IP D class + instance number
sCLUSTERA_sIP="#{sCLUSTERA_IP_CLASS_D}.254"  # // HAProxy Load-Balancer IP
sCLUSTERB_sIP="#{sCLUSTERB_IP_CLASS_D}.253"  # // HAProxy Load-Balancer IP

VV1='VAULT_VERSION='+'1.10.4+ent.hsm'  # VV1='' to Install Latest OSS
VR1="VAULT_RAFT_JOIN=https://#{sCLUSTERA_sIP_VAULT_LEADER}:8200"  # raft join script determines applicability
VV2='VAULT_VERSION='+'1.10.4+ent.hsm'  # VV1='' to Install Latest OSS
VR2="VAULT_RAFT_JOIN=https://#{sCLUSTERB_sIP_VAULT_LEADER}:8200"  # raft join script determines applicability

CLUSTERA_VAULT_NAME = 'DR-Primary'  # // Vault A Cluster Name
CLUSTERB_VAULT_NAME = 'DR-Secondary'  # // Vault B Cluster Name
CLUSTERA_HOSTNAME_PREFIX = 'dr1primary-'  # // Vault A Cluster Name
CLUSTERB_HOSTNAME_PREFIX = 'dr2secondary-'  # // Vault B Cluster Name
sCLUSTERA_HAP_NAME="#{CLUSTERA_HOSTNAME_PREFIX}haproxy"
sCLUSTERB_HAP_NAME="#{CLUSTERB_HOSTNAME_PREFIX}haproxy"

aCLUSTERA_FILES =  # // Cluster A files to copy to instances
[
	"vault_files_dr-primary/."  # "vault_files/vault_seal.hcl", "vault_files/vault_license.txt"  ## // for individual files
];
aCLUSTERB_FILES =  # // Cluster B files to copy to instances
[
	"vault_files_dr-secondary/."
];

sVUSER='vagrant'  # // vagrant user
sHOME="/home/#{sVUSER}"  # // home path for vagrant user
sPTH='cc.os.user-input'  # // path where scripts are expected
sCA_CERT='cacert.crt'  # // Root CA certificate.
sCLUSTERA_sCERT_BUNDLE='ca_intermediate.pem'
sCLUSTERB_sCERT_BUNDLE='ca_intermediate.pem'

sERROR_MSG_CONSUL="CONSUL Node count can NOT be zero (0). Set to: 3, 5, 7 , 11, etc."

Vagrant.configure("2") do |config|
	config.vm.post_up_message = ""
	config.vm.box = "debian/bullseye64"
	config.vm.box_check_update = false  # // disabled to reduce verbosity - better enabled
	#config.vm.box_version = "11.20220328.1"  # // Debian tested version.

	config.vm.provider "virtualbox" do |v|
		v.memory = 1024  # // RAM / Memory
		v.cpus = 1  # // CPU Cores / Threads
		v.check_guest_additions = false  # // disable virtualbox guest additions (no default warning message)
	end

	# // ESSENTIALS PACKAGES INSTALL & SETUP
	config.vm.provision "shell" do |s|
		 s.path = "#{sPTH}/1.install_commons.sh"
	end

	# // -----------------------------------------------------------------------
	# // A A A A A A A ------ CLUSTER A ------ CLUSTER A ------ A A A A A A A A
	if bCLUSTERA_LB then  # // HAProxy Host
		config.vm.define vm_name2="#{sCLUSTERA_HAP_NAME}" do |haproxy_dr1|
			haproxy_dr1.vm.hostname = vm_name2
			haproxy_dr1.vm.network "public_network", bridge: "#{sNET}", ip: "#{sCLUSTERA_sIP}"
			# haproxy_dr1.vm.network "forwarded_port", guest: 80, host: "48080", id: "#{vm_name2}"
	
			# // ORDERED: setup certs then call HAProxy setup.
			haproxy_dr1.vm.provision "file", source: "#{sPTH}/2.install_tls_ca_certs.sh", destination: "#{sHOME}/install_tls_ca_certs.sh"
			haproxy_dr1.vm.provision "file", source: "#{sPTH}/haproxy/3.install_haproxy.sh", destination: "#{sHOME}/install_haproxy.sh"
			haproxy_dr1.vm.provision "shell", inline: <<-SCRIPT
IP_VAULT1=#{sCLUSTERA_IP_CLASS_D}.#{iCLUSTERA_IP_VAULT_CLASS_D-1} FQDN_VAULT1=#{CLUSTERA_HOSTNAME_PREFIX}vault1 #{sHOME}/install_tls_ca_certs.sh #{iCLUSTERA_N} ;
VHOSTNAME=#{CLUSTERA_HOSTNAME_PREFIX}vault VIP_C=#{sCLUSTERA_IP_CLASS_D}. VIP_D=#{iCLUSTERA_IP_VAULT_CLASS_D2-1} #{sHOME}/install_haproxy.sh ;
# // allow for SSHD on all interfaces
sed -i "s/#ListenAddress/ListenAddress/g" /etc/ssh/sshd_config ;
SCRIPT
		end
	end

	# // Consul Server Nodes
	if bCLUSTERA_CONSUL then
		if iCLUSTERA_C == 0 then STDERR.puts "\e[31m#{sERROR_MSG_CONSUL}\e[0m" ; exit(3) ; end ;
		(1..iCLUSTERA_C-1).each do |iY|  # // CONSUL Server Nodes IP's for join (concatenation)
			sCLUSTERA_IPS+="\"#{sCLUSTERA_IP_CLASS_D}.#{iCLUSTERA_IP_CONSUL_CLASS_D+iY}\"" + (iY < iCLUSTERA_C ? ", " : "")
		end
		# // CONSUL AGENT SCRIPTS to setup
		config.vm.provision "file", source: "#{sPTH}/vault/4.install_consul.sh", destination: "#{sHOME}/install_consul.sh"
		# // CONSUL Server Nodes
		(1..iCLUSTERA_C).each do |iY|
			config.vm.define vm_name="#{CLUSTERA_HOSTNAME_PREFIX}consul#{iY}" do |consul_node|
				consul_node.vm.hostname = vm_name
				consul_node.vm.network "public_network", bridge: "#{sNET}", ip: "#{sCLUSTERA_IP_CLASS_D}.#{iCLUSTERA_IP_CONSUL_CLASS_D+iY}"
				# consul_node.vm.network "forwarded_port", guest: 80, host: "5818#{iY}", id: "#{vm_name}"
				$script = <<-SCRIPT
sed -i 's/\"__IPS-SET__\"/#{sCLUSTERA_IPS}/g' #{sHOME}/install_consul.sh
/bin/bash -c #{sHOME}/install_consul.sh
SCRIPT
				consul_node.vm.provision "shell", inline: $script
			end
		end
	end

	# // VAULT Server Nodes & Consul Clients.
	(1..iCLUSTERA_N).each do |iX|
		config.vm.define vm_name="#{CLUSTERA_HOSTNAME_PREFIX}vault#{iX}" do |vault_node|
			vault_node.vm.hostname = vm_name
			vault_node.vm.network "public_network", bridge: "#{sNET}", ip: "#{sCLUSTERA_IP_CLASS_D}.#{iCLUSTERA_IP_VAULT_CLASS_D-iX}"
			vault_node.vm.network "public_network", bridge: "#{sNET}", ip: "#{sCLUSTERA_IP_CLASS_D}.#{iCLUSTERA_IP_VAULT_CLASS_D2-iX}", :adapter => 3, :name => 'eth2'
			# vault_node.vm.network "forwarded_port", guest: 80, host: "5828#{iX}", id: "#{vm_name}"

			if bCLUSTERA_CONSUL then
				$script = <<-SCRIPT
sed -i 's/\"__IPS-SET__\"/#{sCLUSTERA_IPS}/g' #{sHOME}/install_consul.sh
/bin/bash -c 'SETUP=client #{sHOME}/install_consul.sh'
SCRIPT
				vault_node.vm.provision "shell", inline: $script
			end

			vault_node.vm.provision "file", source: "#{sPTH}/vault/3.install_hsm.sh", destination: "#{sHOME}/install_hsm.sh"
			$script = <<-SCRIPT
chmod +x #{sHOME}/install_hsm.sh
/bin/bash -c '#{sHOME}/install_hsm.sh'
SCRIPT
			vault_node.vm.provision "shell", inline: $script


			if ! bCLUSTERA_LB then
				# // ORDERED: Copy certs & ssh private keys before setup from vault1 / CA source generating.
				if iX > 1 then
					vault_node.vm.provision "file", source: ".vagrant/machines/#{CLUSTERA_HOSTNAME_PREFIX}vault1/virtualbox/private_key", destination: "#{sHOME}/.ssh/id_rsa2"
					$script = <<-SCRIPT
ssh-keyscan #{sCLUSTERA_IP_CA_NODE} 2>/dev/null >> #{sHOME}/.ssh/known_hosts ; chown #{sVUSER}:#{sVUSER} -R #{sHOME}/.ssh ;
su -l #{sVUSER} -c \"rsync -qva --rsh='ssh -i #{sHOME}/.ssh/id_rsa2' #{sVUSER}@#{sCLUSTERA_IP_CA_NODE}:~/vault#{iX}* :~/#{sCA_CERT} :~/vault_init.json #{sHOME}/.\"
SCRIPT
					vault_node.vm.provision "shell", inline: $script
				end
			else
				vault_node.vm.provision "file", source: ".vagrant/machines/#{sCLUSTERA_HAP_NAME}/virtualbox/private_key", destination: "#{sHOME}/.ssh/id_rsa2"
				$script = <<-SCRIPT
ssh-keyscan #{sCLUSTERA_sIP} 2>/dev/null >> #{sHOME}/.ssh/known_hosts ; chown #{sVUSER}:#{sVUSER} -R #{sHOME}/.ssh ;
su -l #{sVUSER} -c \"rsync -qva --rsh='ssh -i #{sHOME}/.ssh/id_rsa2' #{sVUSER}@#{sCLUSTERA_sIP}:~/vault#{iX}* :~/#{sCA_CERT} #{sHOME}/.\"
SCRIPT
				vault_node.vm.provision "shell", inline: $script

				if iX > 1 then
					vault_node.vm.provision "file", source: ".vagrant/machines/#{CLUSTERA_HOSTNAME_PREFIX}vault1/virtualbox/private_key", destination: "#{sHOME}/.ssh/id_rsa1"
					$script = <<-SCRIPT
ssh-keyscan #{sCLUSTERA_sIP_VAULT_LEADER} 2>/dev/null >> #{sHOME}/.ssh/known_hosts ; chown #{sVUSER}:#{sVUSER} -R #{sHOME}/.ssh ;
su -l #{sVUSER} -c \"rsync -qva --rsh='ssh -i #{sHOME}/.ssh/id_rsa1' #{sVUSER}@#{sCLUSTERA_sIP_VAULT_LEADER}:~/vault_init.json #{sHOME}/.\"
SCRIPT
				vault_node.vm.provision "shell", inline: $script
				end
			end

			# // ORDERED: setup certs.
			vault_node.vm.provision "file", source: "#{sPTH}/2.install_tls_ca_certs.sh", destination: "#{sHOME}/install_tls_ca_certs.sh"			
			$script = <<-SCRIPT
chmod +x #{sHOME}/install_tls_ca_certs.sh
/bin/bash -c 'IP_VAULT1=#{sCLUSTERA_IP_CLASS_D}.#{iCLUSTERA_IP_VAULT_CLASS_D-iX} FQDN_VAULT1=#{CLUSTERA_HOSTNAME_PREFIX}vault1 #{sHOME}/install_tls_ca_certs.sh #{ bCLUSTERA_LB == false && iX == 1 ? iCLUSTERA_N : '' }'
SCRIPT
			vault_node.vm.provision "shell", inline: $script

			# // where additional Vault related files exist copy them across (eg License & seal configuration)
			for sFILE in aCLUSTERA_FILES
				if(File.file?("#{sFILE}") || File.directory?("#{sFILE}"))
					vault_node.vm.provision "file", source: "#{sFILE}", destination: "#{sHOME}"
				end
			end

			# // ORDERED: setup vault
			# // DR specific script invoked by Vault Setup script.
			if bCLUSTERA_LB then
				vault_node.vm.provision "file", source: "#{sPTH}/vault/5.install_vault.sh", destination: "#{sHOME}/install_vault.sh"
				if iX == 1 then
					vault_node.vm.provision "file", source: "#{sPTH}/vault/6.post_setup_vault_leader_dr_enable.sh", destination: "#{sHOME}/post_setup_vault.sh"
					$script = <<-SCRIPT
chmod +x #{sHOME}/install_vault.sh
/bin/bash -c '#{VV1} VAULT_API_ADDR='https://#{sCLUSTERA_sIP}' VAULT_CLU_ADDR='https://#{sCLUSTERA_sIP}:8201' VAULT_CLUSTER_NAME='#{CLUSTERA_VAULT_NAME}' USER='#{sVUSER}' #{sHOME}/install_vault.sh'
SCRIPT
					vault_node.vm.provision "shell", inline: $script
				else
					$script = <<-SCRIPT
chmod +x #{sHOME}/install_vault.sh
/bin/bash -c '#{VV1} #{VR1} VAULT_API_ADDR='https://#{sCLUSTERA_sIP}' VAULT_CLUSTER_NAME='#{CLUSTERA_VAULT_NAME}' USER='#{sVUSER}' #{sHOME}/install_vault.sh'
SCRIPT
					vault_node.vm.provision "shell", inline: $script
				end
			else
				vault_node.vm.provision "file", source: "#{sPTH}/vault/5.install_vault.sh", destination: "#{sHOME}/install_vault.sh"
				if iX == 1 then
					vault_node.vm.provision "file", source: "#{sPTH}/vault/6.post_setup_vault_leader_dr_enable.sh", destination: "#{sHOME}/post_setup_vault.sh"
					$script = <<-SCRIPT
chmod +x #{sHOME}/install_vault.sh
/bin/bash -c '#{VV1} VAULT_CLUSTER_NAME='#{CLUSTERA_VAULT_NAME}' USER='#{sVUSER}' #{sHOME}/install_vault.sh'
SCRIPT
					vault_node.vm.provision "shell", inline: $script
				else
					$script = <<-SCRIPT
chmod +x #{sHOME}/install_vault.sh
/bin/bash -c '#{VV1} #{VR1} VAULT_CLUSTER_NAME='#{CLUSTERA_VAULT_NAME}' USER='#{sVUSER}' #{sHOME}/install_vault.sh'
SCRIPT
					vault_node.vm.provision "shell", inline: $script
				end
			end

			# // DESTROY ACTION - need to perform raft peer remove if its not the last node:
			vault_node.trigger.before :destroy do |trigger|
				if iCLUSTERA_C == 0 && iCLUSTERA_N > 1 then
					trigger.run_remote = {inline: "printf 'RAFT CHECKING: if Removal from Qourum peers-list is required.\n' && bash -c 'set +eu ; export VAULT_ADDR=\"$(grep -F VAULT_ADDR #{sHOME}/.bashrc | cut -d= -f2)\" ; export VAULT_TOKEN=\"$(grep -F VAULT_TOKEN #{sHOME}/.bashrc | cut -d= -f2)\" ; if (($(vault operator raft list-peers -format=json 2>/dev/null | jq -r \".data.config.servers|length\") == 1)) ; then echo \"RAFT: Last Node - NOT REMOVING.\" && exit 0 ; fi ; VS=$(vault status | grep -iE \"Raft\") ; if [[ \${VS} == *\"Raft\"* ]] ; then vault operator raft remove-peer \$(hostname) 2>&1>/dev/null && printf \"Peer removed successfully!\n\" ; fi ;'"}
				end
			end
		end
	end

	# // -----------------------------------------------------------------------
	# // B B B B B B B ------ CLUSTER B ------ CLUSTER B ------ B B B B B B B B
	if iCLUSTERB_N > 0 && bCLUSTERA_LB then  # // HAProxy Host
		config.vm.define vm_name3="#{sCLUSTERB_HAP_NAME}" do |haproxy_dr2|
			haproxy_dr2.vm.hostname = vm_name3
			haproxy_dr2.vm.network "public_network", bridge: "#{sNET}", ip: "#{sCLUSTERB_sIP}"
			# haproxy_dr2.vm.network "forwarded_port", guest: 80, host: "48080", id: "#{vm_name2}"
	
			# // ORDERED: setup certs then call HAProxy setup.
			haproxy_dr2.vm.provision "file", source: "#{sPTH}/2.install_tls_ca_certs.sh", destination: "#{sHOME}/install_tls_ca_certs.sh"
			haproxy_dr2.vm.provision "file", source: "#{sPTH}/haproxy/3.install_haproxy.sh", destination: "#{sHOME}/install_haproxy.sh"
			haproxy_dr2.vm.provision "shell", inline: <<-SCRIPT
IP_VAULT1=#{sCLUSTERB_IP_CLASS_D}.#{iCLUSTERB_IP_VAULT_CLASS_D-1} FQDN_VAULT1=#{CLUSTERB_HOSTNAME_PREFIX}vault1 #{sHOME}/install_tls_ca_certs.sh #{iCLUSTERB_N} ;
VHOSTNAME=#{CLUSTERB_HOSTNAME_PREFIX}vault VIP_C=#{sCLUSTERB_IP_CLASS_D}. VIP_D=#{iCLUSTERB_IP_VAULT_CLASS_D2-1} #{sHOME}/install_haproxy.sh ;
# // allow for SSHD on all interfaces
sed -i "s/#ListenAddress/ListenAddress/g" /etc/ssh/sshd_config ;
SCRIPT
		end
	end

	# // Consul Server Nodes
	if bCLUSTERB_CONSUL then
		if iCLUSTERB_C == 0 then STDERR.puts "\e[31m#{sERROR_MSG_CONSUL}\e[0m" ; exit(3) ; end ;
		(1..iCLUSTERB_C).each do |iY|  # // CONSUL Server Nodes IP's for join (concatenation)
			sCLUSTERB_IPS+="\"#{sCLUSTERB_IP_CLASS_D}.#{iCLUSTERB_IP_CONSUL_CLASS_D+iY}\"" + (iY < iCLUSTERB_C ? ", " : "")
		end
		# // CONSUL AGENT SCRIPTS to setup
		config.vm.provision "file", source: "#{sPTH}/vault/4.install_consul.sh", destination: "#{sHOME}/install_consul.sh"
		# // CONSUL Server Nodes
		(1..iCLUSTERB_C).each do |iY|
			config.vm.define vm_name="#{CLUSTERB_HOSTNAME_PREFIX}consul#{iY}" do |consul_node|
				consul_node.vm.hostname = vm_name
				consul_node.vm.network "public_network", bridge: "#{sNET}", ip: "#{sCLUSTERB_IP_CLASS_D}.#{iCLUSTERB_IP_CONSUL_CLASS_D+iY}"
				# consul_node.vm.network "forwarded_port", guest: 80, host: "5918#{iY}", id: "#{vm_name}"
				$script = <<-SCRIPT
sed -i 's/\"__IPS-SET__\"/#{sCLUSTERB_IPS}/g' #{sHOME}/install_consul.sh
/bin/bash -c #{sHOME}/install_consul.sh
SCRIPT
				consul_node.vm.provision "shell", inline: $script
			end
		end
	end
	# // VAULT Server Nodes & Consul Clients.
	(1..iCLUSTERB_N).each do |iX|
		config.vm.define vm_name="#{CLUSTERB_HOSTNAME_PREFIX}vault#{iX}" do |vault_node|
			vault_node.vm.hostname = vm_name
			vault_node.vm.network "public_network", bridge: "#{sNET}", ip: "#{sCLUSTERB_IP_CLASS_D}.#{iCLUSTERB_IP_VAULT_CLASS_D-iX}"
			vault_node.vm.network "public_network", bridge: "#{sNET}", ip: "#{sCLUSTERB_IP_CLASS_D}.#{iCLUSTERB_IP_VAULT_CLASS_D2-iX}", :adapter => 3, :name => 'eth2'
			# vault_node.vm.network "forwarded_port", guest: 80, host: "5928#{iX}", id: "#{vm_name}"

			if bCLUSTERB_CONSUL then
				$script = <<-SCRIPT
sed -i 's/\"__IPS-SET__\"/#{sCLUSTERB_IPS}/g' #{sHOME}/install_consul.sh
/bin/bash -c 'SETUP=client #{sHOME}/install_consul.sh'
SCRIPT
				vault_node.vm.provision "shell", inline: $script
			end

			vault_node.vm.provision "file", source: "#{sPTH}/vault/3.install_hsm.sh", destination: "#{sHOME}/install_hsm.sh"
			$script = <<-SCRIPT
chmod +x #{sHOME}/install_hsm.sh
/bin/bash -c '#{sHOME}/install_hsm.sh'
SCRIPT
			vault_node.vm.provision "shell", inline: $script

			if ! bCLUSTERB_LB then
				# // ORDERED: Copy certs & ssh private keys before setup from vault1 / CA source generating.
				if iX > 1 then
					vault_node.vm.provision "file", source: ".vagrant/machines/#{CLUSTERA_HOSTNAME_PREFIX}vault1/virtualbox/private_key", destination: "#{sHOME}/.ssh/id_rsa2"
					vault_node.vm.provision "file", source: ".vagrant/machines/#{CLUSTERB_HOSTNAME_PREFIX}vault1/virtualbox/private_key", destination: "#{sHOME}/.ssh/id_rsa1"
					$script = <<-SCRIPT
ssh-keyscan #{sCLUSTERB_IP_CA_NODE} 2>/dev/null >> #{sHOME}/.ssh/known_hosts ;
ssh-keyscan #{sCLUSTERA_IP_CA_NODE} 2>/dev/null >> #{sHOME}/.ssh/known_hosts ;
chown #{sVUSER}:#{sVUSER} -R #{sHOME}/.ssh ;
su -l #{sVUSER} -c \"rsync -qva --rsh='ssh -i #{sHOME}/.ssh/id_rsa1' #{sVUSER}@#{sCLUSTERB_IP_CA_NODE}:~/vault#{iX}* :~/#{sCA_CERT} :~/cacert2.crt #{sHOME}/.\"
su -l #{sVUSER} -c \"rsync -qva --rsh='ssh -i #{sHOME}/.ssh/id_rsa2' #{sVUSER}@#{sCLUSTERA_IP_CA_NODE}:~/vault_init.json #{sHOME}/.\"
SCRIPT
					vault_node.vm.provision "shell", inline: $script
				else
					vault_node.vm.provision "file", source: ".vagrant/machines/#{CLUSTERA_HOSTNAME_PREFIX}vault1/virtualbox/private_key", destination: "#{sHOME}/.ssh/id_rsa1"
					$script = <<-SCRIPT
ssh-keyscan #{sCLUSTERB_IP_CA_NODE} 2>/dev/null >> #{sHOME}/.ssh/known_hosts ;
ssh-keyscan #{sCLUSTERA_IP_CA_NODE} 2>/dev/null >> #{sHOME}/.ssh/known_hosts ;
chown #{sVUSER}:#{sVUSER} -R #{sHOME}/.ssh ;
su -l #{sVUSER} -c \"rsync -qva --rsh='ssh -i #{sHOME}/.ssh/id_rsa1' #{sVUSER}@#{sCLUSTERA_IP_CA_NODE}:~/*token_dr*.json #{sHOME}/.\"
su -l #{sVUSER} -c \"rsync -qva --rsh='ssh -i #{sHOME}/.ssh/id_rsa1' #{sVUSER}@#{sCLUSTERA_IP_CA_NODE}:~/#{sCA_CERT} #{sHOME}/cacert2.crt\"
su -l #{sVUSER} -c \"rsync -qva --rsh='ssh -i #{sHOME}/.ssh/id_rsa1' #{sVUSER}@#{sCLUSTERA_IP_CA_NODE}:~/vault_init.json #{sHOME}/.\"
SCRIPT
					vault_node.vm.provision "shell", inline: $script
				end
			else
				# // EXTRA's - SSH keys from Cluster-A & CA Certificate.
				vault_node.vm.provision "file", source: ".vagrant/machines/#{sCLUSTERA_HAP_NAME}/virtualbox/private_key", destination: "#{sHOME}/.ssh/id_rsa1"
				vault_node.vm.provision "file", source: ".vagrant/machines/#{sCLUSTERB_HAP_NAME}/virtualbox/private_key", destination: "#{sHOME}/.ssh/id_rsa2"
				vault_node.vm.provision "file", source: ".vagrant/machines/#{CLUSTERA_HOSTNAME_PREFIX}vault1/virtualbox/private_key", destination: "#{sHOME}/.ssh/id_rsa3"

				# // Copy DR related tokens from primary / leader cluster.
				$script = <<-SCRIPT
ssh-keyscan #{sCLUSTERA_sIP} 2>/dev/null >> #{sHOME}/.ssh/known_hosts ;
ssh-keyscan #{sCLUSTERB_sIP} 2>/dev/null >> #{sHOME}/.ssh/known_hosts ;
ssh-keyscan #{sCLUSTERA_sIP_VAULT_LEADER} 2>/dev/null >> #{sHOME}/.ssh/known_hosts ;
chown #{sVUSER}:#{sVUSER} -R #{sHOME}/.ssh ;
su -l #{sVUSER} -c \"rsync -qva --rsh='ssh -i #{sHOME}/.ssh/id_rsa1' #{sVUSER}@#{sCLUSTERA_sIP}:~/#{sCA_CERT} #{sHOME}/cacert2.crt\"
su -l #{sVUSER} -c \"rsync -qva --rsh='ssh -i #{sHOME}/.ssh/id_rsa2' #{sVUSER}@#{sCLUSTERB_sIP}:~/vault#{iX}* :~/#{sCA_CERT} #{sHOME}/.\"
su -l #{sVUSER} -c \"rsync -qva --rsh='ssh -i #{sHOME}/.ssh/id_rsa3' #{sVUSER}@#{sCLUSTERA_sIP_VAULT_LEADER}:~/*token_dr*.json #{sHOME}/.\"
SCRIPT
				vault_node.vm.provision "shell", inline: $script

				if iX == 1 then
					$script = <<-SCRIPT
su -l #{sVUSER} -c \"rsync -qva --rsh='ssh -i #{sHOME}/.ssh/id_rsa3' #{sVUSER}@#{sCLUSTERA_sIP_VAULT_LEADER}:~/vault_init.json #{sHOME}/vault_init_primary.json\"
SCRIPT
				else
					$script = <<-SCRIPT
su -l #{sVUSER} -c \"rsync -qva --rsh='ssh -i #{sHOME}/.ssh/id_rsa3' #{sVUSER}@#{sCLUSTERA_sIP_VAULT_LEADER}:~/vault_init.json #{sHOME}/.\"
SCRIPT
				end
				vault_node.vm.provision "shell", inline: $script
			end

			# // ORDERED: setup certs.
			vault_node.vm.provision "file", source: "#{sPTH}/2.install_tls_ca_certs.sh", destination: "#{sHOME}/install_tls_ca_certs.sh"			
			$script = <<-SCRIPT
chmod +x #{sHOME}/install_tls_ca_certs.sh
/bin/bash -c 'IP_VAULT1=#{sCLUSTERB_IP_CLASS_D}.#{iCLUSTERB_IP_VAULT_CLASS_D-iX} FQDN_VAULT1=#{CLUSTERB_HOSTNAME_PREFIX}vault1 #{sHOME}/install_tls_ca_certs.sh #{ bCLUSTERB_LB == false && iX == 1 ? iCLUSTERB_N : '' }'
SCRIPT
			vault_node.vm.provision "shell", inline: $script

			# // where additional Vault related files exist copy them across (eg License & seal configuration)
			for sFILE2 in aCLUSTERB_FILES
				if(File.file?("#{sFILE2}") || File.directory?("#{sFILE2}"))
					vault_node.vm.provision "file", source: "#{sFILE2}", destination: "#{sHOME}"
				end
			end

			# // ORDERED: setup vault
			# // DR specific script invoked by Vault Setup script.
			if bCLUSTERB_LB then
				vault_node.vm.provision "file", source: "#{sPTH}/vault/5.install_vault.sh", destination: "#{sHOME}/install_vault.sh"
				if iX == 1 then
					vault_node.vm.provision "file", source: "#{sPTH}/vault/7.post_setup_vault_dr_become_leader.sh", destination: "#{sHOME}/post_setup_vault.sh"
					$script = <<-SCRIPT
chmod +x #{sHOME}/install_vault.sh
/bin/bash -c '#{VV2} VAULT_API_ADDR='https://#{sCLUSTERB_sIP}' VAULT_CLU_ADDR='https://#{sCLUSTERB_sIP}:8201' VAULT_CLUSTER_NAME='#{CLUSTERB_VAULT_NAME}' USER='#{sVUSER}' #{sHOME}/install_vault.sh'
SCRIPT
					vault_node.vm.provision "shell", inline: $script
				else
					$script = <<-SCRIPT
chmod +x #{sHOME}/install_vault.sh
/bin/bash -c '#{VV2} #{VR2} VAULT_API_ADDR='https://#{sCLUSTERB_sIP}' VAULT_CLUSTER_NAME='#{CLUSTERB_VAULT_NAME}' USER='#{sVUSER}' #{sHOME}/install_vault.sh'
SCRIPT
					vault_node.vm.provision "shell", inline: $script

				end
			else
				vault_node.vm.provision "file", source: "#{sPTH}/vault/5.install_vault.sh", destination: "#{sHOME}/install_vault.sh"
				if iX == 1 then
					vault_node.vm.provision "file", source: "#{sPTH}/vault/7.post_setup_vault_dr_become_leader.sh", destination: "#{sHOME}/post_setup_vault.sh"
					$script = <<-SCRIPT
chmod +x #{sHOME}/install_vault.sh
/bin/bash -c '#{VV2} VAULT_CLUSTER_NAME='#{CLUSTERB_VAULT_NAME}' USER='#{sVUSER}' #{sHOME}/install_vault.sh'
SCRIPT
					vault_node.vm.provision "shell", inline: $script
				else
					$script = <<-SCRIPT
chmod +x #{sHOME}/install_vault.sh
/bin/bash -c '#{VV2} #{VR2} VAULT_CLUSTER_NAME='#{CLUSTERB_VAULT_NAME}' USER='#{sVUSER}' #{sHOME}/install_vault.sh'
SCRIPT
					vault_node.vm.provision "shell", inline: $script
				end
			end

			# // DESTROY ACTION - need to perform raft peer remove if its not the last node:
#			vault_node.trigger.before :destroy do |trigger|
#				if iCLUSTERB_C == 0 && iCLUSTERB_N > 1 then
#					trigger.run_remote = {inline: "printf 'RAFT CHECKING: if Removal from Qourum peers-list is required.\n' && bash -c 'set +eu ; export VAULT_TOKEN=\"$(grep -F VAULT_TOKEN #{sHOME}/.bashrc | cut -d= -f2)\" ; if (($(vault operator raft list-peers -format=json 2>/dev/null | jq -r \".data.config.servers|length\") == 1)) ; then echo \"RAFT: Last Node - NOT REMOVING.\" && exit 0 ; fi ; VS=$(vault status | grep -iE \"Raft\") ; if [[ \${VS} == *\"Raft\"* ]] ; then vault operator raft remove-peer \$(hostname) 2>&1>/dev/null && printf \"Peer removed successfully!\n\" ; fi ;'"}
#				end
#			end
		end
	end
	# // -----------------------------------------------------------------------
end
