variable "name" {
  description = "Name prefix used for all resources created by this module"
  type        = string
}

variable "region" {
  description = "AWS region to deploy resources in"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID the cluster runs in"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the load balancer"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the ECS tasks"
  type        = list(string)
}

variable "alb_security_group_id" {
  type = string
}

variable "ecs_tasks_security_group_id" {
  type = string
}

variable "nlb_security_group_id" {
  description = "ID of the security group attached to the Temporal frontend NLB"
  type        = string
}

variable "alb_port" {
  description = "Port the load balancer listens on for the Temporal Web UI"
  type        = number
  default     = 8080
}

# --- Temporal server (temporalio/auto-setup) ---

variable "temporal_version" {
  description = "Tag of the temporalio/auto-setup image to run"
  type        = string
  default     = "1.24.2"
}

variable "temporal_server_cpu" {
  type    = number
  default = 1024
}

variable "temporal_server_memory" {
  type    = number
  default = 2048
}

variable "temporal_server_desired_count" {
  type    = number
  default = 1
}

variable "frontend_grpc_port" {
  description = "Port the Temporal frontend gRPC service listens on"
  type        = number
  default     = 7233
}

# --- Temporal Web UI ---

variable "temporal_ui_version" {
  description = "Tag of the temporalio/ui image to run"
  type        = string
  default     = "2.31.2"
}

variable "temporal_ui_cpu" {
  type    = number
  default = 256
}

variable "temporal_ui_memory" {
  type    = number
  default = 512
}

variable "temporal_ui_desired_count" {
  type    = number
  default = 1
}

variable "ui_container_port" {
  description = "Port the Temporal UI container listens on"
  type        = number
  default     = 8080
}

# --- Database connection ---

variable "db_host" {
  description = "Hostname of the Postgres database"
  type        = string
}

variable "db_port" {
  type    = number
  default = 5432
}

variable "db_name" {
  description = "Name of the default Temporal database (a `<db_name>_visibility` database is also created by auto-setup)"
  type        = string
}

variable "db_secret_arn" {
  description = "ARN of the Secrets Manager secret holding `username`/`password` for the database"
  type        = string
}

variable "log_retention_in_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
