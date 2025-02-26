output "ec2_public_ip" {
  description = "EC2 Public IP"
  value       = aws_instance.k3s_master.public_ip
}

output "ecr_repository_url" {
  description = "ECR Repo URL"
  value       = aws_ecr_repository.weather_app.repository_url
}

output "ssh_command" {
  description = "EC2'ye SSH ile bağlanma komutu"
  value       = "ssh -i ~/.ssh/weather-app-key ubuntu@${aws_instance.k3s_master.public_ip}"
}