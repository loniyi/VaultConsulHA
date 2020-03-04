output "consulprimary_privateips" {
  value = aws_instance.consul_primarycluster.*.private_ip
}

output "vaultprimary_privateips" {
  value = aws_instance.vault_primarycluster.*.private_ip
}

output "vaultprimary_servers" {
  value = aws_instance.vault_primarycluster.*.id
}




