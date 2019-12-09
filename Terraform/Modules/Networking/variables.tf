
variable "default_vpcid" {
  type        = string
  description = "VPC Id to deploy the Cluster"
}

variable "bastion_instancetags" {
  type        = map(string)
  description = "Additional tags to attach to the Bastion Host EC2 instance"
  default     = {}
}


variable "vault_primary" {
  type        = list(string)
  description = "Additional tags to attach to the Bastion Host EC2 instance"
}

/*
variable "vault_secondary" {
  type        = list(string)
  description = "Additional tags to attach to the Bastion Host EC2 instance"
}
*/