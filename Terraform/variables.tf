variable "aws_region" {
  type        = "string"  
  description = "Name of the AWS region to provision resources in."
}

variable "vpc_id" {
  type        = "string"  
  description = "VPC to deploy the Cluster."
}

variable "aws_profile" {
  type        = "string"
  description = "Name of the AWS Credential profile to use."
}

variable "private_key" {
  type        = "string"
  description = "Name of the AWS Credential profile to use."
}

variable "public_key" {
  type        = "string"
  description = "Name of the AWS Credential profile to use."
}


variable "consulcluster_instancetype" {
  type        = "string"
  description = "The EC2 instance type to use for Consul cluster nodes."
}

/*
variable "tls_common_name" {
  type        = string
  description = "Value for Command Name field in certificate."
  default     = ""
}

variable "tls_organization_name" {
  type        = string
  description = "Value for Organization Name field in certificate."
  default     = ""
}

variable "tls_download_certs" {
  type        = string
  description = "Flag to enable saving certificate resources locally."
  default     = true
}
*/

variable "name" {
  type        = string
  description = "Name prefix for generated resources."
  default     = ""
}
