
#----Primary Consul Cluster
resource "aws_instance" "consul_primarycluster" {
  count = 3
  ami                    = var.aws_ami
  key_name               = var.aws_keypair
  subnet_id              = element(var.privatesubnet_id, count.index)
  instance_type          = var.consulcluster_instancetype
  iam_instance_profile   = var.instance_profile
  vpc_security_group_ids = [var.consulcluster_securitygroups,
                            var.bastionhost_securitygroups,]

	connection {
			type = "ssh"
      bastion_host = var.bastion_host
      bastion_host_key = "${file(var.public_key)}"
      bastion_port = 22
      bastion_user = "ec2-user"
			host = self.private_ip
			user = "ec2-user"
			bastion_private_key = "${file(var.private_key)}"
      private_key = "${file(var.private_key)}"
		}
    
  provisioner "file" {
    content = <<EOF
    datacenter         = "DC1"
    server             = true
    bootstrap_expect   = 3
    leave_on_terminate = true
    advertise_addr     = "${self.private_ip}"
    data_dir           = "/var/lib/consul/data"
    client_addr        = "0.0.0.0"
    log_level          = "INFO"
    ui                 = true
    node_name          = "${format("consulserver-p%02d", count.index +1)}"
    encrypt            = "${var.encrypt_key}"
    
    #AWS cloud join
    retry_join         = ["provider=aws region=us-east-1 tag_key=EnvironmentName tag_value=DevConsulPrimary"]
   
    disable_remote_exec = false

    connect {
     enabled = true
    }

    primary_datacenter = "DC1"
    acl {
      enabled = true
      default_policy = "deny"
      down_policy = "extend-cache"

       #tokens {
        #Agent = "consulacltoken" 
        #}
    } 
    EOF

    destination = "/tmp/consul.hcl"
  }

  
  provisioner "file" {
    content = <<EOF
    [Unit]
    Description="HashiCorp Consul - A service mesh solution"
    Documentation=https://www.consul.io/
    Requires=network-online.target
    After=network-online.target
    ConditionFileNotEmpty=/etc/consul.d/consul.hcl

    [Service]
    User=consul
    Group=consul
    ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/ -server -bootstrap-expect 3
    ExecReload=/usr/local/bin/consul reload
    KillMode=process
    Restart=on-failure
    LimitNOFILE=65536

    [Install]
    WantedBy=multi-user.target
    
    EOF

    destination = "/tmp/consul.service"
  }

  provisioner "remote-exec" {
		inline = [
      "cd /usr/local/bin && sudo curl -o consul.zip https://releases.hashicorp.com/consul/1.6.2/consul_1.6.2_linux_amd64.zip && sudo unzip consul.zip && sudo rm -f consul.zip",
      "sudo hostnamectl set-hostname --static ${format("consulserver-p%02d", count.index +1)}",
			"sudo sh -c 'echo \"preserve_hostname: true\" >> /etc/cloud/cloud.cfg'",
      "sudo mkdir -p /etc/consul.d /var/lib/consul/data",
      "sudo groupadd --system consul",
      "sudo useradd -s /sbin/nologin --system -g consul consul",
      "sudo mv /tmp/consul.hcl /etc/consul.d/consul.hcl",
      "sudo mv /tmp/consul.service /etc/systemd/system/consul.service",
      "sudo chown -R consul:consul /var/lib/consul/data /etc/consul.d",
      "sudo chmod -R 775 /var/lib/consul/data /etc/consul.d",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable consul",
      "sudo systemctl start consul"
      
		]
    }

  tags = {
      Name = format("consulserver-p%02d", count.index +1)
      EnvironmentName = "DevConsulPrimary"
  }
}


##########################################################################################################################
resource "null_resource" "consul_configuretokens" {
  depends_on = [aws_instance.consul_primarycluster]

	connection {
			type = "ssh"
      bastion_host = var.bastion_host
      bastion_host_key = "${file(var.public_key)}"
      bastion_port = 22
      bastion_user = "ec2-user"
			host = "${aws_instance.consul_primarycluster[0].private_ip}"
			user = "ec2-user"
			bastion_private_key = "${file(var.private_key)}"
      private_key = "${file(var.private_key)}"
		}


provisioner "file" {
    source      = "Modules/Policies"
    destination = "/tmp"
  }

provisioner "file" {
    source      = "ssh/id_rsa"
    destination = "/tmp/id_rsa"
  }
  
provisioner "remote-exec" {
		inline = [
      "sleep 1m",
      "consul acl bootstrap > /tmp/masterbootstraptoken",
      "export CONSUL_HTTP_TOKEN=$(cat /tmp/masterbootstraptoken | grep SecretID | awk '{print $2}')",    
      "sed -i \"s|CONSULMASTERTOKEN|$CONSUL_HTTP_TOKEN|g\" /tmp/Policies/consulacltoken.sh",
      "sudo chmod +x /tmp/Policies/consulacltoken.sh",
      "/tmp/Policies/consulacltoken.sh > /tmp/catoken.txt",
      "sed -i 's/{\"ID\":\"//g' /tmp/catoken.txt",
      "sed -i 's/\"}//g' /tmp/catoken.txt",
      "sudo chmod 600 /tmp/id_rsa",
      "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /tmp/id_rsa /tmp/catoken.txt ec2-user@${aws_instance.consul_primarycluster[1].private_ip}:/tmp/",
      "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /tmp/id_rsa /tmp/catoken.txt ec2-user@${aws_instance.consul_primarycluster[2].private_ip}:/tmp/",
		  "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /tmp/id_rsa /tmp/catoken.txt ec2-user@${aws_instance.vault_primarycluster[0].private_ip}:/tmp/",
      "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /tmp/id_rsa /tmp/catoken.txt ec2-user@${aws_instance.vault_primarycluster[1].private_ip}:/tmp/",
      "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /tmp/id_rsa /tmp/catoken.txt ec2-user@${aws_instance.vault_primarycluster[2].private_ip}:/tmp/",
      "sed -i \"s|CONSULMASTERTOKEN|$CONSUL_HTTP_TOKEN|g\" /tmp/Policies/vaultagenttoken.sh",
      "sudo chmod +x /tmp/Policies/vaultagenttoken.sh",
      "/tmp/Policies/vaultagenttoken.sh > /tmp/vatoken.txt",
      "sed -i 's/{\"ID\":\"//g' /tmp/vatoken.txt",
      "sed -i 's/\"}//g' /tmp/vatoken.txt",
      "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /tmp/id_rsa /tmp/vatoken.txt ec2-user@${aws_instance.vault_primarycluster[0].private_ip}:/tmp/",
      "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /tmp/id_rsa /tmp/vatoken.txt ec2-user@${aws_instance.vault_primarycluster[1].private_ip}:/tmp/",
      "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /tmp/id_rsa /tmp/vatoken.txt ec2-user@${aws_instance.vault_primarycluster[2].private_ip}:/tmp/",
      
      ]
    }

}
########################################################################################################################

resource "null_resource" "consul_configureacls" {
  depends_on = [aws_instance.consul_primarycluster, null_resource.consul_configuretokens]
  count = 3
	connection {
			type = "ssh"
      bastion_host = var.bastion_host
      bastion_host_key = "${file(var.public_key)}"
      bastion_port = 22
      bastion_user = "ec2-user"
			host = "${aws_instance.consul_primarycluster[count.index].private_ip}"
			user = "ec2-user"
			bastion_private_key = "${file(var.private_key)}"
      private_key = "${file(var.private_key)}"
		}


provisioner "remote-exec" {
		inline = [
      "export CONSULACLTOKEN=$(cat /tmp/catoken.txt | awk '{print $1}')", 
      "sudo sed -i 's/#tokens {/tokens {/g' /etc/consul.d/consul.hcl",
      "sudo sed -i 's/#Agent/Agent/g' /etc/consul.d/consul.hcl",
      "sudo sed -i \"s|consulacltoken|\"$CONSULACLTOKEN\"|g\" /etc/consul.d/consul.hcl",
      "sudo sed -i 's/#}/}/g' /etc/consul.d/consul.hcl",
      "sudo systemctl restart consul"
		]
    }
}

######################################################################################################################################################################
/*
resource "null_resource" "move_rootcerts" {
  provisioner "local-exec" {
		command = "sleep 45; mv ./*dev-root* Modules/Certs/Root/"
    }  
}
*/

#---- Primary Vault Cluster
resource "aws_instance" "vault_primarycluster" {
  #depends_on = [null_resource.move_rootcerts]
  count = 3
  ami                    = var.aws_ami
  key_name               = var.aws_keypair
  subnet_id              = element(var.privatesubnet_id, count.index)
  instance_type          = var.consulcluster_instancetype
  iam_instance_profile   = var.instance_profile
  vpc_security_group_ids = [var.consulcluster_securitygroups,
                            var.bastionhost_securitygroups,]

	connection {
			type = "ssh"
      bastion_host = var.bastion_host
      bastion_host_key = "${file(var.public_key)}"
      bastion_port = 22
      bastion_user = "ec2-user"
			host = self.private_ip
			user = "ec2-user"
			bastion_private_key = "${file(var.private_key)}"
      private_key = "${file(var.private_key)}"
		}
    
  provisioner "file" {
    source      = "Modules/Certs/Root"
    destination = "/tmp"
  }

  provisioner "file" {
    content = <<EOF
    storage "consul" {
      address = "127.0.0.1:8500"
      path    = "vault/"
      #token  = "vaulttoken"
    }

    listener "tcp" {
      address     = "0.0.0.0:8200"
      cluster_address  = "127.0.0.1:8201"
      tls_disable      = "true"
      #tls_cert_file = "/tmp/Root/ss-dev-root.crt.pem"
      #tls_key_file = "/tmp/Root/ss-dev-root.key.pem"
    }

    seal "awskms" {
     region = "${var.aws_region}"
     kms_key_id = "${var.vaultprimary_kmskey}"
    }
    
    
    cluster_addr = "http://${self.private_ip}:8201"
    api_addr = "http://primaryelbname:8200"

    ui=true
        
    EOF

    destination = "/tmp/vault.hcl"
  }

  
  provisioner "file" {
    content = <<EOF
    [Unit]
    Description="HashiCorp Vault - A tool for managing secrets"
    Documentation=https://www.vaultproject.io/docs/
    Requires=network-online.target
    After=network-online.target
    ConditionFileNotEmpty=/etc/vault.d/vault.hcl

    [Service]
    User=vault
    Group=vault
    ProtectSystem=full
    ProtectHome=read-only
    PrivateTmp=yes
    PrivateDevices=yes
    SecureBits=keep-caps
    AmbientCapabilities=CAP_IPC_LOCK
    Capabilities=CAP_IPC_LOCK+ep
    CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
    NoNewPrivileges=yes
    ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
    ExecReload=/bin/kill --signal HUP $MAINPID
    KillMode=process
    KillSignal=SIGINT
    Restart=on-failure
    RestartSec=5
    TimeoutStopSec=30
    StartLimitIntervalSec=60
    StartLimitBurst=3
    LimitNOFILE=65536

    [Install]
    WantedBy=multi-user.target
    
    EOF

    destination = "/tmp/vault.service"
  }



provisioner "file" {
    content = <<EOF
    datacenter         = "DC1"
    server             = false
    bind_addr          = "${self.private_ip}"
    data_dir           = "/var/lib/consul/data"
    client_addr        = "127.0.0.1"
    log_level          = "DEBUG"
    enable_syslog      = true
    node_name          = "${format("consulclient-p%02d", count.index +1)}"
    encrypt            = "${var.encrypt_key}"

    #AWS cloud join
    retry_join         = ["provider=aws region=us-east-1 tag_key=EnvironmentName tag_value=DevConsulPrimary"]

    primary_datacenter = "DC1"
    acl {
      enabled = true
      default_policy = "deny"
      down_policy = "extend-cache"

    #tokens {
      #Agent = "consulacltoken" 
    #}
    }   

    EOF

    destination = "/tmp/consul.hcl"
  }

  
  provisioner "file" {
    content = <<EOF
    [Unit]
    Description="HashiCorp Consul Client - A service mesh solution"
    Documentation=https://www.consul.io/
    Requires=network-online.target
    After=network-online.target
    ConditionFileNotEmpty=/etc/consul.d/consul.hcl

    [Service]
    User=consul
    Group=consul
    ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
    ExecReload=/usr/local/bin/consul reload
    KillMode=process
    Restart=on-failure
    LimitNOFILE=65536

    [Install]
    WantedBy=multi-user.target
    
    EOF

    destination = "/tmp/consul.service"
  }


  provisioner "remote-exec" {
		inline = [
      "mv /tmp/Root/*ca.crt.pem /tmp/Root/ss-dev-root.ca.crt.pem",
      "mv /tmp/Root/*leaf.crt.pem /tmp/Root/ss-dev-root.crt.pem",
      "mv /tmp/Root/*leaf.key.pem /tmp/Root/ss-dev-root.key.pem",
      "sudo hostnamectl set-hostname --static ${format("vaultconsul-p%02d", count.index +1)}",
			"sudo sh -c 'echo \"preserve_hostname: true\" >> /etc/cloud/cloud.cfg'", 
      "cd /usr/local/bin && sudo curl -o vault.zip https://releases.hashicorp.com/vault/1.3.0/vault_1.3.0_linux_amd64.zip && sudo unzip vault.zip && sudo rm -f vault.zip",
      "sudo setcap cap_ipc_lock=+ep /usr/local/bin/vault",
      "sudo mkdir -p /etc/vault.d",
      "sudo mv /tmp/vault.hcl /etc/vault.d/vault.hcl",
      "sudo mv /tmp/vault.service /etc/systemd/system/vault.service",
      "sudo groupadd --system vault",
      "sudo useradd -s /sbin/nologin --system -g vault vault",
      "sudo chown -R vault:vault /etc/vault.d",
      "sudo chmod 640 /etc/vault.d/vault.hcl",
      "cd /usr/local/bin && sudo curl -o consul.zip https://releases.hashicorp.com/consul/1.6.2/consul_1.6.2_linux_amd64.zip && sudo unzip consul.zip && sudo rm -f consul.zip",
      "sudo mkdir -p /etc/consul.d /var/lib/consul/data",
      "sudo groupadd --system consul",
      "sudo useradd -s /sbin/nologin --system -g consul consul",
      "sudo mv /tmp/consul.hcl /etc/consul.d/consul.hcl",
      "sudo mv /tmp/consul.service /etc/systemd/system/consul.service",
      "sudo chown -R consul:consul /var/lib/consul/data /etc/consul.d",
      "sudo chmod -R 775 /var/lib/consul/data /etc/consul.d",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable consul",
      "sudo systemctl enable vault"
      
		]
    }
    
  tags = {
      Name = format("vaultconsul-p%02d", count.index +1)
      EnvName = "DevVaultPrimary"
      EnvironmentName = "DevConsulPrimary"
  }
}


#####################################################################################################

resource "null_resource" "vault_configureacls" {
  depends_on = [aws_instance.consul_primarycluster, null_resource.consul_configuretokens]
  count = 3
	connection {
			type = "ssh"
      bastion_host = var.bastion_host
      bastion_host_key = "${file(var.public_key)}"
      bastion_port = 22
      bastion_user = "ec2-user"
			host = "${aws_instance.vault_primarycluster[count.index].private_ip}"
			user = "ec2-user"
			bastion_private_key = "${file(var.private_key)}"
      private_key = "${file(var.private_key)}"
		}



provisioner "remote-exec" {
		inline = [
      "export CONSULACLTOKEN=$(cat /tmp/catoken.txt | awk '{print $1}')",
      "export VAULTTOKEN=$(cat /tmp/vatoken.txt | awk '{print $1}')",  
      "sudo sed -i 's/#tokens {/tokens {/g' /etc/consul.d/consul.hcl",
      "sudo sed -i 's/#Agent/Agent/g' /etc/consul.d/consul.hcl",
      "sudo sed -i \"s|consulacltoken|\"$CONSULACLTOKEN\"|g\" /etc/consul.d/consul.hcl",
      "sudo sed -i 's/#}/}/g' /etc/consul.d/consul.hcl",
      "sudo sed -i 's/#token/token/g' /etc/vault.d/vault.hcl",
      "sudo sed -i \"s|vaulttoken|\"$VAULTTOKEN\"|g\" /etc/vault.d/vault.hcl",
      "sudo sed -i 's|primaryelbname|${var.vaultprimary_elbname}|g' /etc/vault.d/vault.hcl",
      "sudo systemctl start consul",
      "echo 'export VAULT_ADDR=http://127.0.0.1:8200' >> $HOME/.bashrc",
      "sudo systemctl start vault",
		]
    }  
}

resource "null_resource" "vault_unseal" {
  depends_on = [null_resource.vault_configureacls]
	connection {
			type = "ssh"
      bastion_host = var.bastion_host
      bastion_host_key = "${file(var.public_key)}"
      bastion_port = 22
      bastion_user = "ec2-user"
			host = "${aws_instance.vault_primarycluster[0].private_ip}"
			user = "ec2-user"
			bastion_private_key = "${file(var.private_key)}"
      private_key = "${file(var.private_key)}"
		}


provisioner "remote-exec" {
		inline = [
      "sleep 2m",
      "vault operator init -recovery-shares=1 -recovery-threshold=1 > /tmp/vaultkeys"
		 ]
    }  
}
