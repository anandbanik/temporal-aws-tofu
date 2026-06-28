vpc_cidr                   = "10.0.0.0/16"
name                       = "temporal"
aws_region                 = "us-east-2"
public_subnet_cidrs        = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs       = ["10.0.3.0/24", "10.0.4.0/24"]
single_nat_gateway         = true
db_instance_class          = "db.t4g.medium"
temporal_version           = "1.29.7"
temporal_ui_version        = "2.49.1"
alb_ingress_cidrs          = ["0.0.0.0/0"]
frontend_nlb_ingress_cidrs = ["0.0.0.0/0"]
db_engine_version          = "16.14"
tags = {
  Environment = "dev"
  Project     = "temporal"
}