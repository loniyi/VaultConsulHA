#-----Cloud Provider
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
  version = ">= 0.12"
}


locals {
  common_tags = {
    owner        = "Shadow-Soft TOCTeam"
    purpose      = "Internal Workload"
    expiration   = "indefinite"
    environment  = "techops"
    availability = "on_demand"
  }
}
 

module "networking" {
  source                    = "./Modules/Networking"
  default_vpcid             = var.vpc_id
  vault_primary = module.primarycluster.vaultprimary_servers
  #bastion_instancetags      = "[local.common_tags]"
}

module "primarycluster" {
  source                       = "./Modules/PrimaryCluster"
  aws_ami                      = module.networking.aws_ami
  aws_region                   = var.aws_region
  aws_keypair                  = module.networking.aws_keypair
  private_key                  = var.private_key
  bastion_host                 = module.networking.bastionhost_publicip
  public_key                   = var.public_key
  encrypt_key                  = module.networking.random_stringbase64
  privatesubnet_id             = module.networking.private_subnets
  instance_profile             = module.networking.instance_profile
  consulcluster_securitygroups = module.networking.cluster_securitygroups
  bastionhost_securitygroups   = module.networking.privatesubnet_sshingress
  consulcluster_instancetype   = var.consulcluster_instancetype
  vaultprimary_elbname         = module.networking.vaultprimary_elbdnsname
  vaultprimary_kmskey          = module.networking.vaultprimary_kmskey
  #consulcluster_instancetags  = "local.common_tags" 
}

data "template_file" "ssh_config" {
  template = <<-EOT
  # Primary Nodes
  Host consul-p1
    HostName ${element(module.primarycluster.consulprimary_privateips, 0)}
  Host consul-p2
    HostName ${element(module.primarycluster.consulprimary_privateips, 1)}
  Host consul-p3
    HostName ${element(module.primarycluster.consulprimary_privateips, 2)}
  Host vault-p1
    HostName ${element(module.primarycluster.vaultprimary_privateips, 0)}
  Host vault-p2
    HostName ${element(module.primarycluster.vaultprimary_privateips, 1)}
  Host vault-p3
    HostName ${element(module.primarycluster.vaultprimary_privateips, 2)} 
  
  Host consul* vault*
    ProxyJump ec2-user@${module.networking.bastionhost_publicip}
    IdentityFile ./ssh/id_rsa
    ForwardAgent yes
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    User ec2-user
EOT

}

resource "local_file" "ssh_config" {
  content  = data.template_file.ssh_config.rendered
  filename = "ssh_config"
}

data "template_file" "instructions" {
  template = <<-EOT

  
    Primary Cluster Details
    Consul Nodes:
      consul-p1: ${element(module.primarycluster.consulprimary_privateips, 0)}
      consul-p2: ${element(module.primarycluster.consulprimary_privateips, 1)}
      consul-p3: ${element(module.primarycluster.consulprimary_privateips, 2)}
    
    Vault Nodes:
      vault-p1: ${element(module.primarycluster.vaultprimary_privateips, 0)}
      vault-p2: ${element(module.primarycluster.vaultprimary_privateips, 1)}
      vault-p3: ${element(module.primarycluster.vaultprimary_privateips, 2)}

    Load Balancer: http://${module.networking.vaultprimary_elbdnsname}:8200
  

  Add the private key to your SSH agent:
    ssh-add -K ./ssh/id_rsa

  Connect to a host using one of the node names above, e.g.:
    ssh -F ssh_config consul-p1

EOT

}



/*
module "root_tls_self_signed_ca" {
  source = "github.com/krarey/tls-self-signed-cert?ref=tf12"

  name              = "${var.name}-root"
  ca_common_name    = var.tls_common_name
  organization_name = var.tls_organization_name
  common_name       = var.tls_common_name
  download_certs    = var.tls_download_certs

  validity_period_hours = "8760"

  ca_allowed_uses = [
    "cert_signing",
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

module "leaf_tls_self_signed_cert" {
  source = "github.com/krarey/tls-self-signed-cert?ref=tf12"

  name              = "${var.name}-leaf"
  organization_name = var.tls_organization_name
  common_name       = var.tls_common_name
  ca_override       = true
  ca_key_override   = module.root_tls_self_signed_ca.ca_private_key_pem
  ca_cert_override  = module.root_tls_self_signed_ca.ca_cert_pem
  download_certs    = var.tls_download_certs

  validity_period_hours = "8760"

  dns_names = [
    "localhost",
    "*.node.consul",
    "*.service.consul",
    "server.dc1.consul",
    "*.dc1.consul",
    "server.${var.name}.consul",
    "*.${var.name}.consul",
  ]

  ip_addresses = [
    "0.0.0.0",
    "127.0.0.1",
  ]

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}
*/
