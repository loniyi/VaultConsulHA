output "aws_vpc" {
  value = "${data.aws_vpc.default.id}"
}
output "private_subnets" {
  value = "${data.aws_subnet.private_subnets.*.id}"
}

output "public_subnets" {
  value = "${data.aws_subnet.public_subnets.*.id}"
}

output "cluster_securitygroups" {
  value = "${aws_security_group.cluster.id}"
}

output "bastion_securitygroups" {
  value = "${aws_security_group.bastion.id}"
}

output "aws_keypair" {
  value = "${aws_key_pair.generated_key.key_name}"
}

output "aws_ami" {
  value = "${data.aws_ami.cluster.image_id}"
}

output "bastionhost_publicip" {
  value = "${aws_instance.bastion.public_ip}"
}


output "privatesubnet_sshingress" {
  value = "${aws_security_group.private_ssh_ingress.id}"
}


output "private_keypem" {
  value = "${tls_private_key.key_pair.private_key_pem}"
}

output "instance_profile" {
  value = "${data.aws_iam_instance_profile.describe_instance.name}"
}

output "random_stringbase64" {
  value = "${base64encode(random_string.base64.result)}"
}

output "vaultprimary_elbdnsname" {
  value = "${aws_elb.vault_primary.dns_name}"
}


output "vaultprimary_kmskey" {
  value = "${data.aws_kms_alias.vaultprimary_autounseal.target_key_id}"
}

output "vaultsecondary_kmskey" {
  value = "${data.aws_kms_alias.vaultsecondary_autounseal.target_key_id}"
}

/*
output "vaultsecondary_elbdnsname" {
  value = "${aws_elb.vault_secondary.dns_name}"
}
*/