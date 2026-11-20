output "instance_public_ip" {
  value = aws_instance.app.public_ip
}

output "app_url" {
  value = "http://${aws_instance.app.public_ip}:8000"
}

output "db_endpoint" {
  value = aws_db_instance.db.address
}

output "secret_name" {
  value = aws_secretsmanager_secret.db.name
}
