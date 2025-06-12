output "instance_id" {
  value = aws_instance.windows2016.id
}

output "public_ip" {
  value = aws_instance.windows2016.public_ip
}

output "key_secret_arn" {
  value = aws_secretsmanager_secret.windows_key_secret.arn
}
