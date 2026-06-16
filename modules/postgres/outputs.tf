output "db_instance_id" {
  description = "ID of the RDS instance"
  value       = aws_db_instance.this.id
}

output "address" {
  description = "Hostname of the RDS instance"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Port the RDS instance listens on"
  value       = aws_db_instance.this.port
}

output "database_name" {
  description = "Name of the default database"
  value       = aws_db_instance.this.db_name
}

output "master_username" {
  description = "Master username"
  value       = aws_db_instance.this.username
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret holding the database credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}
