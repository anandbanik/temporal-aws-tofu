output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}


output "temporal_ui_url" {
  description = "URL of the Temporal Web UI"
  value       = module.temporal.ui_url
}


output "temporal_frontend_address" {
  description = "Internal address of the Temporal frontend gRPC endpoint (reachable from within the VPC, e.g. by SDK workers)"
  value       = module.temporal.frontend_address
}

output "temporal_frontend_nlb_address" {
  description = "Address of the Temporal frontend NLB (host:port), for clients that can't resolve the Cloud Map private DNS namespace"
  value       = module.temporal.frontend_nlb_address
}

output "database_endpoint" {
  description = "Endpoint (hostname) of the Postgres database"
  value       = module.postgres.address
}

output "database_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the database master credentials"
  value       = module.postgres.secret_arn
}
