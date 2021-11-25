# -*- mode: ruby -*-
# vi: set ft=ruby :
# // To list interfaces on CLI typically:
# //	macOS: networksetup -listallhardwareports ;
# //	Linux: lshw -class network ;
#sNET='en0: Wi-Fi (Wireless)'  # // network adaptor to use for bridged mode
sNET='en7: USB 10/100/1000 LAN'  # // network adaptor to use for bridged mode

sVUSER='vagrant'  # // vagrant user
sHOME="/home/#{sVUSER}"  # // home path for vagrant user
sPTH='cc.os.user-input'  # // path where scripts are expected
sCA_CERT='cacert.crt'  # // Root CA certificate.

iCLUSTERA_N = 1  # // Vault A INSTANCES UP TO 9 <= iN > 0
iCLUSTERB_N = 3  # // Vault B INSTANCES UP TO 9 <= iN > 0
iCLUSTERA_C = 0  # // Consul B INSTANCES UP TO 9 <= iN > 2
iCLUSTERB_C = 0  # // Consul B INSTANCES UP TO 9 <= iN > 2
bCLUSTERA_CONSUL = false  # // Consul A use Consul as store for vault?
bCLUSTERB_CONSUL = false  # // Consul B use Consul as store for vault?
CLUSTERA_VAULT_NAME = 'DR-Primary'  # // Vault A Cluster Name
CLUSTERB_VAULT_NAME = 'DR-Secondary'  # // Vault B Cluster Name
CLUSTERA_HOSTNAME_PREFIX = 'dr1primary-'  # // Vault A Cluster Name
CLUSTERB_HOSTNAME_PREFIX = 'dr2secondary-'  # // Vault B Cluster Name
sCLUSTERA_IP_CLASS_D='192.168.178'  # // Consul A NETWORK CIDR forconfigs.
sCLUSTERB_IP_CLASS_D='192.168.178'  # // Consul B NETWORK CIDR for configs.
iCLUSTERA_IP_CONSUL_CLASS_D=110  # // Consul A IP starting D class (increment or de)
iCLUSTERB_IP_CONSUL_CLASS_D=120  # // Consul B IP starting D class (increment or de)
iCLUSTERA_IP_VAULT_CLASS_D=254  # // Vault A Leader IP starting D class (increment or de)
iCLUSTERB_IP_VAULT_CLASS_D=244  # // Vault B Leader IP starting D class (increment or de)
sCLUSTERA_IP_CA_NODE="#{sCLUSTERA_IP_CLASS_D}.#{iCLUSTERA_IP_VAULT_CLASS_D-1}"  # // Cluster A - static IP of CA
sCLUSTERB_IP_CA_NODE="#{sCLUSTERB_IP_CLASS_D}.#{iCLUSTERB_IP_VAULT_CLASS_D-1}"  # // Cluster B - static IP of CA
sCLUSTERA_sIP_VAULT_LEADER="#{sCLUSTERA_IP_CLASS_D}.#{iCLUSTERA_IP_VAULT_CLASS_D-1}"  # // Vault A static IP of CA
sCLUSTERB_sIP_VAULT_LEADER="#{sCLUSTERB_IP_CLASS_D}.#{iCLUSTERB_IP_VAULT_CLASS_D-1}"  # // Vault B static IP of CA
sCLUSTERA_IPS=''  # // Consul A - IPs constructed based on IP D class + instance number
sCLUSTERB_IPS=''  # // Consul B - IPs constructed based on IP D class + instance number
aCLUSTERA_FILES =  # // Cluster A files to copy to instances
[
	"vault_files_dr-primary/."  # "vault_files/vault_seal.hcl", "vault_files/vault_license.txt"  ## // for individual files
];

aCLUSTERB_FILES =  # // Cluster B files to copy to instances
[
	"vault_files_dr-secondary/."
];

VV1='VAULT_VERSION='+'1.9.0+ent.hsm'  # VV1='' to Install Latest OSS
VR1="VAULT_RAFT_JOIN=https://#{sCLUSTERA_sIP_VAULT_LEADER}:8200"  # raft join script determines applicability
VV2='VAULT_VERSION='+'1.9.0+ent.hsm'  # VV1='' to Install Latest OSS
VR2="VAULT_RAFT_JOIN=https://#{sCLUSTERB_sIP_VAULT_LEADER}:8200"  # raft join script determines applicability

sERROR_MSG_CONSUL="CONSUL Node count can NOT be zero (0). Set to: 3, 5, 7 , 11, etc."

Vagrant.configure("2") do |config|
	config.vm.box = "debian/buster64"
	config.vm.box_check_update = false  # // disabled to reduce verbosity - better enabled
	#config.vm.box_version = "10.4.0"  # // Debian tested version.
	# // OS may be "ubuntu/bionic64" or "ubuntu/focal64" as well.

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
	# // A A A A A A A A A A A A A A A A A A A A A A A A A A A A A A A A A A A A
	# // ------ CLUSTER A ------ CLUSTER A ------
	# // Consul Server Nodes
	if bCLUSTERA_CONSUL then
		if iCLUSTERA_C == 0 then STDERR.puts "\e[31m#{sERROR_MSG_CONSUL}\e[0m" ; exit(3) ; end ;
		(1..iCLUSTERA_C-1).each do |iY|  # // CONSUL Server Nodes IP's for join (concatenation)
			sCLUSTERA_IPS+="\"#{sCLUSTERA_IP_CLASS_D}.#{iCLUSTERA_IP_CONSUL_CLASS_D+iY}\"" + (iY < iCLUSTERA_C ? ", " : "")
		end
		# // CONSUL AGENT SCRIPTS to setup
		config.vm.provision "file", source: "#{sPTH}/3.install_consul.sh", destination: "#{sHOME}/install_consul.sh"
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
	# // VAULT Server Nodes as Consul Clients as well.
	(1..iCLUSTERA_N).each do |iX|
		config.vm.define vm_name="#{CLUSTERA_HOSTNAME_PREFIX}vault#{iX}" do |vault_node|
			vault_node.vm.hostname = vm_name
			vault_node.vm.network "public_network", bridge: "#{sNET}", ip: "#{sCLUSTERA_IP_CLASS_D}.#{iCLUSTERA_IP_VAULT_CLASS_D-iX}"
			# vault_node.vm.network "forwarded_port", guest: 80, host: "5828#{iX}", id: "#{vm_name}"

			if bCLUSTERA_CONSUL then
				$script = <<-SCRIPT
sed -i 's/\"__IPS-SET__\"/#{sCLUSTERA_IPS}/g' #{sHOME}/install_consul.sh
/bin/bash -c 'SETUP=client #{sHOME}/install_consul.sh'
SCRIPT
				vault_node.vm.provision "shell", inline: $script
			end

			vault_node.vm.provision "file", source: "#{sPTH}/2.install_hsm.sh", destination: "#{sHOME}/install_hsm.sh"
			vault_node.vm.provision "shell", inline: "/bin/bash -c '#{sHOME}/install_hsm.sh #{iCLUSTERA_N}'"

			# // ORDERED: Copy certs & ssh private keys before setup from vault1 / CA source generating.
			if iX > 1 then
				vault_node.vm.provision "file", source: ".vagrant/machines/#{CLUSTERA_HOSTNAME_PREFIX}vault1/virtualbox/private_key", destination: "#{sHOME}/.ssh/id_rsa2"
				$script = <<-SCRIPT
ssh-keyscan #{sCLUSTERA_IP_CA_NODE} 2>/dev/null >> #{sHOME}/.ssh/known_hosts ; chown #{sVUSER}:#{sVUSER} -R #{sHOME}/.ssh ;
su -l #{sVUSER} -c \"rsync -qva --rsh='ssh -i #{sHOME}/.ssh/id_rsa2' #{sVUSER}@#{sCLUSTERA_IP_CA_NODE}:~/vault#{iX}* :~/#{sCA_CERT} :~/vault_init.json #{sHOME}/.\"
SCRIPT
				vault_node.vm.provision "shell", inline: $script
			end

			# // ORDERED: setup certs.
			vault_node.vm.provision "file", source: "#{sPTH}/4.install_tls_ca_certs.sh", destination: "#{sHOME}/install_tls_ca_certs.sh"
			vault_node.vm.provision "shell", inline: "/bin/bash -c '#{sHOME}/install_tls_ca_certs.sh #{iX == 1 ? iCLUSTERA_N : '' }'"

			# // where additional Vault related files exist copy them across (eg License & seal configuration)
			for sFILE in aCLUSTERA_FILES
				if(File.file?("#{sFILE}") || File.directory?("#{sFILE}"))
					vault_node.vm.provision "file", source: "#{sFILE}", destination: "#{sHOME}"
				end
			end

			# // ORDERED: copy VAULT TOKEN to .bashrc for convenience from main node after setup.
			if iX > 1 then
				vault_node.vm.provision "shell", inline: "su -l #{sVUSER} -c 'VT=$(ssh -i #{sHOME}/.ssh/id_rsa2 #{sVUSER}@#{sCLUSTERA_sIP_VAULT_LEADER} \"[[ -f /home/vagrant/vault_token.txt ]] && cat /home/vagrant/vault_token.txt || printf \'\'\"); if ! [[ ${VT} == \"\" ]] && ! grep VAULT_TOKEN ~/.bashrc ; then printf \"export VAULT_TOKEN=${VT}\n\" >> ~/.bashrc ; fi ;'"
			end

			# // ORDERED: setup vault
			vault_node.vm.provision "file", source: "#{sPTH}/5.install_vault.sh", destination: "#{sHOME}/install_vault.sh"
			if iX == 1 then
				# // DR specific script invoked by Vault Setup script.
				vault_node.vm.provision "file", source: "#{sPTH}/6.post_setup_vault_leader_dr_enable.sh", destination: "#{sHOME}/post_setup_vault.sh"
				vault_node.vm.provision "shell", inline: "/bin/bash -c '#{VV1} VAULT_CLUSTER_NAME='#{CLUSTERA_VAULT_NAME}' USER='#{sVUSER}' #{sHOME}/install_vault.sh'"
			else
				vault_node.vm.provision "shell", inline: "/bin/bash -c '#{VV1} #{VR1} VAULT_CLUSTER_NAME='#{CLUSTERA_VAULT_NAME}' USER='#{sVUSER}' #{sHOME}/install_vault.sh'"
			end

			# // Cluster A ONLY - ENABLE DR & Related Settings will occure as part of vault setup from vault_post_setup.sh script.

			# // DESTROY ACTION - need to perform raft peer remove if its not the last node:
			vault_node.trigger.before :destroy do |trigger|
				if iCLUSTERA_C == 0 && iCLUSTERA_N > 1 then
					trigger.run_remote = {inline: "printf 'RAFT CHECKING: if Removal from Qourum peers-list is required.\n' && bash -c 'set +eu ; export VAULT_TOKEN=\"$(grep -F VAULT_TOKEN #{sHOME}/.bashrc | cut -d= -f2)\" ; if (($(vault operator raft list-peers -format=json 2>/dev/null | jq -r \".data.config.servers|length\") == 1)) ; then echo \"RAFT: Last Node - NOT REMOVING.\" && exit 0 ; fi ; VS=$(vault status | grep -iE \"Raft\") ; if [[ \${VS} == *\"Raft\"* ]] ; then vault operator raft remove-peer \$(hostname) 2>&1>/dev/null && printf \"Peer removed successfully!\n\" ; fi ;'"}
				end
			end
		end
	end

	# // -----------------------------------------------------------------------
	# // B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B
	# // ------ CLUSTER B ------ CLUSTER B ------
	# // Consul Server Nodes
	if bCLUSTERB_CONSUL then
		if iCLUSTERB_C == 0 then STDERR.puts "\e[31m#{sERROR_MSG_CONSUL}\e[0m" ; exit(3) ; end ;
		(1..iCLUSTERB_C).each do |iY|  # // CONSUL Server Nodes IP's for join (concatenation)
			sCLUSTERB_IPS+="\"#{sCLUSTERB_IP_CLASS_D}.#{iCLUSTERB_IP_CONSUL_CLASS_D+iY}\"" + (iY < iCLUSTERB_C ? ", " : "")
		end
		# // CONSUL AGENT SCRIPTS to setup
		config.vm.provision "file", source: "#{sPTH}/3.install_consul.sh", destination: "#{sHOME}/install_consul.sh"
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
	# // VAULT Server Nodes as Consul Clients as well.
	(1..iCLUSTERB_N).each do |iX|
		config.vm.define vm_name="#{CLUSTERB_HOSTNAME_PREFIX}vault#{iX}" do |vault_node|
			vault_node.vm.hostname = vm_name
			vault_node.vm.network "public_network", bridge: "#{sNET}", ip: "#{sCLUSTERB_IP_CLASS_D}.#{iCLUSTERB_IP_VAULT_CLASS_D-iX}"
			# vault_node.vm.network "forwarded_port", guest: 80, host: "5928#{iX}", id: "#{vm_name}"

			if bCLUSTERB_CONSUL then
				$script = <<-SCRIPT
sed -i 's/\"__IPS-SET__\"/#{sCLUSTERB_IPS}/g' #{sHOME}/install_consul.sh
/bin/bash -c 'SETUP=client #{sHOME}/install_consul.sh'
SCRIPT
				vault_node.vm.provision "shell", inline: $script
			end

			vault_node.vm.provision "file", source: "#{sPTH}/2.install_hsm.sh", destination: "#{sHOME}/install_hsm.sh"
			vault_node.vm.provision "shell", inline: "/bin/bash -c '#{sHOME}/install_hsm.sh #{iCLUSTERB_N}'"

			# // ORDERED: Copy certs & ssh private keys before setup from vault1 / CA source generating.
			if iX > 1 then
				vault_node.vm.provision "file", source: ".vagrant/machines/#{CLUSTERB_HOSTNAME_PREFIX}vault1/virtualbox/private_key", destination: "#{sHOME}/.ssh/id_rsa2"
				vault_node.vm.provision "file", source: ".vagrant/machines/#{CLUSTERA_HOSTNAME_PREFIX}vault1/virtualbox/private_key", destination: "#{sHOME}/.ssh/id_rsa3"
				$script = <<-SCRIPT
ssh-keyscan #{sCLUSTERB_IP_CA_NODE} 2>/dev/null >> #{sHOME}/.ssh/known_hosts ; 
ssh-keyscan #{sCLUSTERA_IP_CA_NODE} 2>/dev/null >> #{sHOME}/.ssh/known_hosts ;
chown #{sVUSER}:#{sVUSER} -R #{sHOME}/.ssh ;
su -l #{sVUSER} -c \"rsync -qva --rsh='ssh -i #{sHOME}/.ssh/id_rsa2' #{sVUSER}@#{sCLUSTERB_IP_CA_NODE}:~/vault#{iX}* :~/#{sCA_CERT} #{sHOME}/.\"
su -l #{sVUSER} -c \"rsync -qva --rsh='ssh -i #{sHOME}/.ssh/id_rsa3' #{sVUSER}@#{sCLUSTERA_IP_CA_NODE}:~/vault_init.json #{sHOME}/.\"
SCRIPT
				vault_node.vm.provision "shell", inline: $script
			end

			if iX == 1 then
				# // EXTRA's - SSH keys from Cluster-A & CA Certificate.
				vault_node.vm.provision "file", source: ".vagrant/machines/#{CLUSTERA_HOSTNAME_PREFIX}vault1/virtualbox/private_key", destination: "#{sHOME}/.ssh/id_rsa1"

				# // Copy DR related tokens from primary / leader cluster.
				$script = <<-SCRIPT
ssh-keyscan #{sCLUSTERA_sIP_VAULT_LEADER} 2>/dev/null >> #{sHOME}/.ssh/known_hosts ; chown #{sVUSER}:#{sVUSER} -R #{sHOME}/.ssh ;
su -l #{sVUSER} -c \"rsync -qva --rsh='ssh -i #{sHOME}/.ssh/id_rsa1' #{sVUSER}@#{sCLUSTERA_sIP_VAULT_LEADER}:~/*token_dr*.json #{sHOME}/.\"
su -l #{sVUSER} -c \"rsync -qva --rsh='ssh -i #{sHOME}/.ssh/id_rsa1' #{sVUSER}@#{sCLUSTERA_sIP_VAULT_LEADER}:~/#{sCA_CERT} #{sHOME}/cacert_leader.crt\"
SCRIPT
				vault_node.vm.provision "shell", inline: $script
			end

			# // ORDERED: setup certs.
			vault_node.vm.provision "file", source: "#{sPTH}/4.install_tls_ca_certs.sh", destination: "#{sHOME}/install_tls_ca_certs.sh"
			vault_node.vm.provision "shell", inline: "/bin/bash -c '#{sHOME}/install_tls_ca_certs.sh #{iX == 1 ? iCLUSTERB_N : '' }'"

			# // where additional Vault related files exist copy them across (eg License & seal configuration)
			for sFILE2 in aCLUSTERB_FILES
				if(File.file?("#{sFILE2}") || File.directory?("#{sFILE2}"))
					vault_node.vm.provision "file", source: "#{sFILE2}", destination: "#{sHOME}"
				end
			end

			# // ORDERED: copy VAULT TOKEN to .bashrc for convenience from main node after setup.
			if iX > 1 then
				vault_node.vm.provision "shell", inline: "su -l #{sVUSER} -c 'VT=$(ssh -i #{sHOME}/.ssh/id_rsa2 #{sVUSER}@#{sCLUSTERB_sIP_VAULT_LEADER} \"[[ -f /home/vagrant/vault_token.txt ]] && cat /home/vagrant/vault_token.txt || printf \'\'\"); if ! [[ ${VT} == \"\" ]] && ! grep VAULT_TOKEN ~/.bashrc ; then printf \"export VAULT_TOKEN=${VT}\n\" >> ~/.bashrc ; fi ;'"
			end

			# // ORDERED: setup vault
			vault_node.vm.provision "file", source: "#{sPTH}/5.install_vault.sh", destination: "#{sHOME}/install_vault.sh"
			if iX == 1 then
				# // DR specific script invoked by Vault Setup script.
				vault_node.vm.provision "file", source: "#{sPTH}/7.post_setup_vault_dr_become_leader.sh", destination: "#{sHOME}/post_setup_vault.sh"
				vault_node.vm.provision "shell", inline: "/bin/bash -c '#{VV2} VAULT_CLUSTER_NAME='#{CLUSTERB_VAULT_NAME}' USER='#{sVUSER}' #{sHOME}/install_vault.sh'"
				# // OVER-WRITE: VAULT TOKEN to .bashrc from Cluster-A
				vault_node.vm.provision "shell", inline: "su -l #{sVUSER} -c 'VT=$(ssh -i #{sHOME}/.ssh/id_rsa1 #{sVUSER}@#{sCLUSTERA_sIP_VAULT_LEADER} \"[[ -f /home/vagrant/vault_token.txt ]] && cat /home/vagrant/vault_token.txt || printf \'\'\"); if ! [[ ${VT} == \"\" ]] && ! grep VAULT_TOKEN ~/.bashrc ; then printf \"export VAULT_TOKEN=${VT}\n\" >> ~/.bashrc ; fi ;'"
			else
				vault_node.vm.provision "shell", inline: "/bin/bash -c '#{VV2} #{VR2} VAULT_CLUSTER_NAME='#{CLUSTERB_VAULT_NAME}' USER='#{sVUSER}' #{sHOME}/install_vault.sh'"
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
