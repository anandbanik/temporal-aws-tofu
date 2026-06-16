variable "name" {
  description = "Name prefix used for all resources created by this module"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs to attach to the database instance"
  type        = list(string)
}

variable "engine_version" {
  description = "Postgres engine version"
  type        = string
  default     = "16.14"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.medium"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 50
}

variable "max_allocated_storage" {
  description = "Upper limit for RDS storage autoscaling, in GB"
  type        = number
  default     = 200
}

variable "database_name" {
  description = "Name of the default database created on the instance (Temporal will also create a `<database_name>_visibility` database)"
  type        = string
  default     = "temporal"
}

variable "master_username" {
  description = "Master username for the database"
  type        = string
  default     = "temporal"
}

variable "multi_az" {
  description = "Whether to deploy a standby instance in another availability zone"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection on the instance"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final snapshot when the instance is destroyed"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
