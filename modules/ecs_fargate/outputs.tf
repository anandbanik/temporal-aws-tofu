output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.this.name
}

/*
output "alb_dns_name" {
  description = "DNS name of the load balancer fronting the Temporal UI"
  value       = aws_lb.this.dns_name
}

output "ui_url" {
  description = "URL of the Temporal Web UI"
  value       = "http://${aws_lb.this.dns_name}:${var.alb_port}"
}
*/

output "frontend_address" {
  description = "Internal DNS address of the Temporal frontend gRPC endpoint, reachable from within the VPC (e.g. by workers)"
  value       = local.frontend_address
}
