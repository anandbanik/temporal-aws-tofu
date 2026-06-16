variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix applied to all resources"
  type        = string
  default     = "temporal"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to spread resources across"
  type        = number
  default     = 2
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ"
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ"
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24"]
}

variable "single_nat_gateway" {
  description = "Use a single shared NAT gateway instead of one per AZ (cheaper, less resilient)"
  type        = bool
  default     = true
}

variable "alb_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the Temporal Web UI. Restrict this in production (e.g. to your office/VPN CIDR)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "db_instance_class" {
  description = "RDS instance class for the Postgres database"
  type        = string
  default     = "db.t4g.medium"
}

variable "db_allocated_storage" {
  description = "Allocated storage for the Postgres database, in GB"
  type        = number
  default     = 50
}

variable "db_engine_version" {
  description = "Postgres engine version"
  type        = string
  default     = "15.7"
}

variable "db_multi_az" {
  description = "Whether to deploy the database across multiple availability zones"
  type        = bool
  default     = false
}

variable "temporal_version" {
  description = "Tag of the temporalio/auto-setup image to run for the Temporal server"
  type        = string
  default     = "1.24.2"
}

variable "temporal_ui_version" {
  description = "Tag of the temporalio/ui image to run"
  type        = string
  default     = "2.31.2"
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    Project   = "temporal"
    ManagedBy = "terraform"
  }
}
