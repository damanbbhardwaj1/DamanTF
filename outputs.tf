output "instance_id" {
  value = aws_instance.windows2016.id
}

output "public_ip" {
  value = aws_instance.windows2016.public_ip
}

output "key_ssm_parameter_arn" {
  value = aws_ssm_parameter.windows_private_key.arn
}
