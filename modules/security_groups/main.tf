# Load balancer: only the UI port is reachable from the configured CIDRs.
resource "aws_security_group" "alb" {
  name_prefix = "${var.name}-alb-"
  description = "Controls access to the Temporal UI load balancer"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_internet" {
  count             = length(var.alb_ingress_cidrs)
  security_group_id = aws_security_group.alb.id
  description       = "Allow inbound traffic to the Temporal UI"
  cidr_ipv4         = var.alb_ingress_cidrs[count.index]
  from_port         = var.alb_port
  to_port           = var.alb_port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_all_outbound" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Frontend NLB: only the gRPC port is reachable, from the configured CIDRs (internet-facing).
resource "aws_security_group" "nlb" {
  name_prefix = "${var.name}-frontend-nlb-"
  description = "Controls access to the Temporal frontend NLB"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name}-frontend-nlb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "nlb_frontend" {
  count             = length(var.nlb_ingress_cidrs)
  security_group_id = aws_security_group.nlb.id
  description       = "Allow inbound traffic to the Temporal frontend gRPC endpoint"
  cidr_ipv4         = var.nlb_ingress_cidrs[count.index]
  from_port         = var.frontend_grpc_port
  to_port           = var.frontend_grpc_port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "nlb_all_outbound" {
  security_group_id = aws_security_group.nlb.id
  description       = "Allow all outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ECS tasks: reachable from the ALB (UI) and from each other (frontend gRPC, internal membership ports).
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${var.name}-ecs-tasks-"
  description = "Controls access to the Temporal ECS tasks"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name}-ecs-tasks-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs_tasks.id
  description                  = "Allow the load balancer to reach the Temporal UI"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.ui_container_port
  to_port                      = var.ui_container_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_nlb" {
  security_group_id            = aws_security_group.ecs_tasks.id
  description                  = "Allow the frontend NLB to reach the Temporal frontend gRPC endpoint"
  referenced_security_group_id = aws_security_group.nlb.id
  from_port                    = var.frontend_grpc_port
  to_port                      = var.frontend_grpc_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ecs_self" {
  security_group_id            = aws_security_group.ecs_tasks.id
  description                  = "Allow Temporal services to reach each other (frontend gRPC, membership, etc.)"
  referenced_security_group_id = aws_security_group.ecs_tasks.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_egress_rule" "ecs_all_outbound" {
  security_group_id = aws_security_group.ecs_tasks.id
  description       = "Allow all outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# RDS: reachable only from the ECS tasks security group.
resource "aws_security_group" "rds" {
  name_prefix = "${var.name}-rds-"
  description = "Controls access to the Temporal Postgres database"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name}-rds-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs_tasks" {
  security_group_id            = aws_security_group.rds.id
  description                  = "Allow Temporal ECS tasks to reach Postgres"
  referenced_security_group_id = aws_security_group.ecs_tasks.id
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "rds_all_outbound" {
  security_group_id = aws_security_group.rds.id
  description       = "Allow all outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
