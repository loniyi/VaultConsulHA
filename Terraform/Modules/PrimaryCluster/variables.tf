variable "aws_ami" {
  type        = string
  description = "AMI ID to use for Consul EC2 instances"
}

variable "aws_region" {
  type        = string
  description = "AMI ID to use for Consul EC2 instances"
}

variable "aws_keypair" {
  type        = string
  description = "Keypair name for authenticating to Consul EC2 instances"
}

variable "private_key" {
  type        = string
  description = "Private Key to log into Consul EC2 instances"
}

variable "bastion_host" {
  type        = string
  description = "Keypair name for authenticating to Consul EC2 instances"
}

variable "public_key" {
  type        = string
  description = "Public Key to log into Consul EC2 instances"
}

variable "privatesubnet_id" {
  type        = list(string)
  description = "Private IPs to connect Consul EC2 instances"
}


variable "consulcluster_securitygroups" {
  type        = string
  description = "Security group ID's associated with the Consul Cluster nodes."
}

variable "bastionhost_securitygroups" {
  type        = string
  description = "Security group ID's associated with the Consul Cluster nodes."
}

variable "consulcluster_instancetype" {
  type        = string
  description = "The EC2 instance type to use for Consul cluster nodes."
}

variable "encrypt_key" {
  type        = string
  description = "The EC2 instance type to use for Consul cluster nodes."
}

variable "vaultprimary_elbname" {
  type        = string
  description = "The EC2 instance type to use for Consul cluster nodes."
}

variable "vaultprimary_kmskey" {
  type        = string
  description = "The EC2 instance type to use for Consul cluster nodes."
}


/*
variable "common_tags" {
  type        = map(string)
  description = "Additional tags to attach to Consul EC2 instances"
  default     = {}
}
*/

variable "instance_profile" {
  type        = string
  description = "The EC2 instance type to use for Consul cluster nodes."
}


