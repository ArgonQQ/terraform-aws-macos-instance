# Outputs

output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.macos_template.id
}

output "launch_template_arn" {
  description = "ARN of the launch template"
  value       = aws_launch_template.macos_template.arn
}

output "instance_id" {
  description = "ID of the Mac EC2 instance"
  value       = aws_instance.macos_instance.id
}

output "instance_public_ip" {
  description = "Public IP address of the Mac instance"
  value       = aws_instance.macos_instance.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the Mac instance"
  value       = aws_instance.macos_instance.private_ip
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.macos_sg.id
}
