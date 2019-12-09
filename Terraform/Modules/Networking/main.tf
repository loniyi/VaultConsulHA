#----------------Cloud Environment

#-----Default VPC
data "aws_vpc" "default" { 
  id = "${var.default_vpcid}"
}

#----Private Subnets
data "aws_subnet_ids" "private_subnets" {
  vpc_id = "${data.aws_vpc.default.id}"
}

data "aws_subnet" "private_subnets" {
  count = length(data.aws_subnet_ids.private_subnets.ids)
  id    = tolist(data.aws_subnet_ids.private_subnets.ids)[count.index]
}

#----Public Subnets
data "aws_subnet_ids" "public_subnets" {
  vpc_id = "${data.aws_vpc.default.id}"
}

data "aws_subnet" "public_subnets" {
  count = length(data.aws_subnet_ids.public_subnets.ids)
  id    = tolist(data.aws_subnet_ids.public_subnets.ids)[count.index]
}

#----KMS
data "aws_kms_alias" "vaultprimary_autounseal" {
  name = "alias/vaultprimary"
}

data "aws_kms_alias" "vaultsecondary_autounseal" {
  name = "alias/vaultsecondary"
}

#----Security Group
resource "aws_security_group" "cluster" {
  name        = "VaultConsultCluster"
  description = "Rules for Vault and Consul cluster"
  vpc_id      = "${data.aws_vpc.default.id}"

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  ingress {
    from_port = 8200
    to_port   = 8200
    protocol  = "tcp"

    security_groups = [
      aws_security_group.vault_elb.id,   
    ]
  }
  
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

   tags = {
    name = "VaultConsulCluster-SG"
  }
}

resource "aws_security_group" "bastion" {
  name        = "bastion_host_sg"
  description = "Rules for bastion host"
  vpc_id      = "${data.aws_vpc.default.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["12.181.68.186/32", "50.251.142.248/29", "172.31.0.0/16", "73.106.129.36/32", "13.68.223.227/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["12.181.68.186/32", "50.251.142.248/29", "172.31.0.0/16", "73.106.129.36/32", "13.68.223.227/32"]
  }
}

resource "aws_security_group" "private_ssh_ingress" {
  name        = "bastionhost_private-ssh"
  description = "Rules to allow SSH access to instances on private subnets"
  vpc_id      = "${data.aws_vpc.default.id}"

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
}





resource "aws_security_group" "vault_elb" {
  name        = "vault-elb"
  description = "Rules for primary and secondary vault cluster load balancer"
  vpc_id      = "${data.aws_vpc.default.id}"

  ingress {
    description = "Ingress 8200 from load balancer"
    protocol    = "tcp"
    from_port   = 8200
    to_port     = 8200

    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Egress 8200 to VPC"
    protocol    = "tcp"
    from_port   = 8200
    to_port     = 8200

    cidr_blocks = "${data.aws_vpc.default.*.cidr_block}"
  }
}

resource "aws_elb" "vault_primary" {
  name = "primary-vault"

  internal            = false
  connection_draining = false

  security_groups = [aws_security_group.vault_elb.id]
  subnets         = "${data.aws_subnet.public_subnets.*.id}"
  instances       = var.vault_primary

  # Run the ELB in TCP passthrough mode
  listener {
    lb_port           = 8200
    lb_protocol       = "TCP"
    instance_port     = 8200
    instance_protocol = "TCP"
  }

  health_check {
    target              = "HTTP:8200/v1/sys/health"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }
}

/*

resource "aws_elb" "vault_secondary" {
  name = "secondary-vault"

  internal            = false
  connection_draining = false

  security_groups = [aws_security_group.vault_elb.id]
  subnets         = "${data.aws_subnet.public_subnets.*.id}"
  instances       = var.vault_secondary

  # Run the ELB in TCP passthrough mode
  listener {
    lb_port           = 8200
    lb_protocol       = "TCP"
    instance_port     = 8200
    instance_protocol = "TCP"
  }

  health_check {
    target              = "HTTP:8200/v1/sys/health"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }
}


*/

#----Creating Random String
resource "random_string" "cluster" {
  length  = 8
  special = false
  upper   = false
  number  = false
}

resource "random_string" "base64" {
  length  = 16
  special = true
  upper   = true
  number  = true
}

#----SSH Keys
resource "tls_private_key" "key_pair" {
  rsa_bits  = 4096
  algorithm = "RSA"
}

#----AWS Key Pair
resource "aws_key_pair" "generated_key" {
  key_name   = random_string.cluster.result
  public_key = tls_private_key.key_pair.public_key_openssh
}

#---Saving Public Key to File
resource "local_file" "cluster_publicsshkey" {
  content  = tls_private_key.key_pair.public_key_openssh
  filename = "./ssh/id_rsa.pub"

  provisioner "local-exec" {
    command = "chmod 0600 ./ssh/id_rsa.pub"
  }
}

#---Saving Private Key to File
resource "local_file" "cluster_privatesshkey" {
  content  = tls_private_key.key_pair.private_key_pem
  filename = "./ssh/id_rsa"

  provisioner "local-exec" {
    command = "chmod 0600 ./ssh/id_rsa"
  }
}

#----lfcs Linux Servers Instance AMI ID
data "aws_ami" "cluster" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
 
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.cluster.image_id
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = aws_key_pair.generated_key.key_name
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  subnet_id                   = element(data.aws_subnet.public_subnets.*.id, 0)

 tags = merge(
    {
      "Name" = format("vaultclusterbastion", )
    },
    var.bastion_instancetags,
  )
}

data "aws_iam_instance_profile" "describe_instance" {
  name = "CAJ"
}

