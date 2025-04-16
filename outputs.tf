
output "instance_id" {
  value = aws_instance.windows_ec2.id
}

output "public_ip" {
  value = aws_instance.windows_ec2.public_ip
}

output "key_secret_arn" {
  value = aws_secretsmanager_secret.key_secret.arn
}
