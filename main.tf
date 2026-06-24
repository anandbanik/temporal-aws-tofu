data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

module "vpc" {
  source = "./modules/vpc"

  name                 = var.name
  cidr_block           = var.vpc_cidr
  azs                  = local.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway
  tags                 = var.tags
}

module "security_groups" {
  source = "./modules/security_groups"

  name              = var.name
  vpc_id            = module.vpc.vpc_id
  alb_ingress_cidrs = var.alb_ingress_cidrs
  tags              = var.tags
}

module "postgres" {
  source = "./modules/postgres"

  name               = var.name
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.rds_security_group_id]
  engine_version     = var.db_engine_version
  instance_class     = var.db_instance_class
  allocated_storage  = var.db_allocated_storage
  multi_az           = var.db_multi_az
  tags               = var.tags
}

module "temporal" {
  source = "./modules/ecs_fargate"
  name                        = var.name
  region                      = var.aws_region
  vpc_id                      = module.vpc.vpc_id
  public_subnet_ids           = module.vpc.public_subnet_ids
  private_subnet_ids          = module.vpc.private_subnet_ids
  alb_security_group_id       = module.security_groups.alb_security_group_id
  ecs_tasks_security_group_id = module.security_groups.ecs_tasks_security_group_id

  temporal_version    = var.temporal_version
  temporal_ui_version = var.temporal_ui_version

  db_host       = module.postgres.address
  db_port       = module.postgres.port
  db_name       = module.postgres.database_name
  db_secret_arn = module.postgres.secret_arn

  tags = var.tags
}
