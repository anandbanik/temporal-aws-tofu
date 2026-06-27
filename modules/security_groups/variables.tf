variable "name" {
  description = "Name prefix used for all security groups created by this module"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC the security groups belong to"
  type        = string
}

variable "alb_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the load balancer"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "alb_port" {
  description = "Port the load balancer listens on for the Temporal Web UI"
  type        = number
  default     = 8080
}

variable "ui_container_port" {
  description = "Port the Temporal UI container listens on"
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Port Postgres listens on"
  type        = number
  default     = 5432
}

variable "frontend_grpc_port" {
  description = "Port the Temporal frontend gRPC service listens on"
  type        = number
  default     = 7233
}

variable "nlb_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the internet-facing Temporal frontend NLB"
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
