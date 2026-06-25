data "aws_region" "current" {}

locals {
  cluster_name          = "${var.name}-cluster"
  namespace_name        = "${var.name}.local"
  frontend_service_name = "temporal-frontend"
  frontend_address      = "${local.frontend_service_name}.${local.namespace_name}:${var.frontend_grpc_port}"
}

# ---------------------------------------------------------------------------
# Cluster
# ---------------------------------------------------------------------------

resource "aws_ecs_cluster" "this" {
  name = local.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.tags, { Name = local.cluster_name })
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

# ---------------------------------------------------------------------------
# Service discovery: lets the UI (and external workers running inside the VPC)
# resolve the Temporal frontend's gRPC endpoint via internal DNS rather than
# routing it through the load balancer.
# ---------------------------------------------------------------------------

resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = local.namespace_name
  description = "Service discovery namespace for Temporal services"
  vpc         = var.vpc_id
}

resource "aws_service_discovery_service" "frontend" {
  name = local.frontend_service_name

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "server" {
  name              = "/ecs/${var.name}/temporal-server"
  retention_in_days = var.log_retention_in_days

  tags = var.tags
}
/*
resource "aws_cloudwatch_log_group" "ui" {
  name              = "/ecs/${var.name}/temporal-ui"
  retention_in_days = var.log_retention_in_days

  tags = var.tags
}
*/
# ---------------------------------------------------------------------------
# IAM
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name_prefix        = "${var.name}-exec-"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.db_secret_arn]
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  name_prefix = "secrets-access-"
  role        = aws_iam_role.execution.id
  policy      = data.aws_iam_policy_document.execution_secrets.json
}

resource "aws_iam_role" "task" {
  name_prefix        = "${var.name}-task-"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Temporal Admin Topls (one-shot task to create the schema and visibility database)
# ---------------------------------------------------------------------------

resource "aws_ecs_task_definition" "temporal_dbsetup" {
  family                   = "${var.name}-temporal-dbsetup"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.temporal_server_cpu
  memory                   = var.temporal_server_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "temporal-dbsetup"
      image     = "ghcr.io/anandbanik/temporal-aws-tofu/admin-tools:v1.0.2"
      essential = true

      portMappings = [
        {
          containerPort = var.frontend_grpc_port
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "DB", value = "postgres12" },
        { name = "DB_PORT", value = tostring(var.db_port) },
        { name = "POSTGRES_SEEDS", value = var.db_host },
      ]

      secrets = [
        {
          name      = "POSTGRES_USER"
          valueFrom = "${var.db_secret_arn}:username::"
        },
        {
          name      = "POSTGRES_PWD"
          valueFrom = "${var.db_secret_arn}:password::"
        },
        {
          name      = "SQL_PASSWORD"
          valueFrom = "${var.db_secret_arn}:password::"
        },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.server.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "temporal-server"
        }
      }
    }
  ])

  tags = var.tags
}

#####################
# Trigger the One-Shot Setup Task
#####################
resource "null_resource" "run_temporal_admin" {
  depends_on = [
    aws_ecs_task_definition.temporal_dbsetup,
    //aws_rds_cluster.temporal  # or your RDS resource
  ]

  provisioner "local-exec" {
    command = <<EOT
      TASK_ARN=$(aws ecs run-task \
        --cluster ${aws_ecs_cluster.this.name} \
        --launch-type FARGATE \
        --task-definition ${aws_ecs_task_definition.temporal_dbsetup.family} \
        --network-configuration "awsvpcConfiguration={subnets=[${var.private_subnet_ids.0}],securityGroups=[${var.ecs_tasks_security_group_id}],assignPublicIp=DISABLED}" \
        --region ${var.region} \
        --query 'tasks[0].taskArn' \
        --output text)

      echo "Waiting for task $TASK_ARN to complete..."

      aws ecs wait tasks-stopped \
        --cluster ${aws_ecs_cluster.this.name} \
        --tasks $TASK_ARN \
        --region ${var.region}

      EXIT_CODE=$(aws ecs describe-tasks \
        --cluster ${aws_ecs_cluster.this.name} \
        --tasks $TASK_ARN \
        --region ${var.region} \
        --query 'tasks[0].containers[0].exitCode' \
        --output text)

      echo "Task exited with code: $EXIT_CODE"
      if [ "$EXIT_CODE" != "0" ]; then
        echo "Temporal schema setup FAILED"
        exit 1
      fi
    EOT
  }
}


# ---------------------------------------------------------------------------
# Temporal server (runs frontend/history/matching/worker via auto-setup image,
# which also creates the schema and visibility database on first boot)
# ---------------------------------------------------------------------------

resource "aws_ecs_task_definition" "temporal_server" {
  family                   = "${var.name}-temporal-server"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.temporal_server_cpu
  memory                   = var.temporal_server_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "temporal-dbsetup"
      //image     = "temporalio/auto-setup:${var.temporal_version}"
      image     = "ghcr.io/anandbanik/temporal-aws-tofu/admin-tools:v1.0.2"
      essential = true

      portMappings = [
        {
          containerPort = var.frontend_grpc_port
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "DB", value = "postgres12" },
        { name = "DB_PORT", value = tostring(var.db_port) },
        { name = "POSTGRES_SEEDS", value = var.db_host },
        /*
        { name = "DBNAME", value = var.db_name },
        { name = "VISIBILITY_DBNAME", value = "${var.db_name}_visibility" },
        { name = "ENABLE_ES", value = "false" },
        { name = "SQL_TLS_ENABLED", value = "true" },
        { name = "SQL_HOST_VERIFICATION", value = "false" },
        */
      ]

      secrets = [
        {
          name      = "POSTGRES_USER"
          valueFrom = "${var.db_secret_arn}:username::"
        },
        {
          name      = "POSTGRES_PWD"
          valueFrom = "${var.db_secret_arn}:password::"
        },
        {
          name      = "SQL_PASSWORD"
          valueFrom = "${var.db_secret_arn}:password::"
        },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.server.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "temporal-server"
        }
      }
    }
  ])

  tags = var.tags
}


resource "aws_ecs_service" "server" {
  name            = "temporal-server"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.server.arn
  desired_count   = var.temporal_server_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_tasks_security_group_id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.frontend.arn
  }

  tags = var.tags
}


/*
# ---------------------------------------------------------------------------
# Load balancer for the Temporal Web UI
# ---------------------------------------------------------------------------

resource "aws_lb" "this" {
  name_prefix        = substr(var.name, 0, 6)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  tags = merge(var.tags, { Name = "${var.name}-alb" })
}

resource "aws_lb_target_group" "ui" {
  name_prefix = "tui-"
  port        = var.ui_container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.alb_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ui.arn
  }
}

# ---------------------------------------------------------------------------
# Temporal Web UI
# ---------------------------------------------------------------------------

resource "aws_ecs_task_definition" "ui" {
  family                   = "${var.name}-temporal-ui"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.temporal_ui_cpu
  memory                   = var.temporal_ui_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "temporal-ui"
      image     = "temporalio/ui:${var.temporal_ui_version}"
      essential = true

      portMappings = [
        {
          containerPort = var.ui_container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "TEMPORAL_ADDRESS", value = local.frontend_address },
        { name = "TEMPORAL_UI_PORT", value = tostring(var.ui_container_port) },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ui.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "temporal-ui"
        }
      }
    }
  ])

  tags = var.tags
}

resource "aws_ecs_service" "ui" {
  name            = "temporal-ui"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.ui.arn
  desired_count   = var.temporal_ui_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_tasks_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ui.arn
    container_name   = "temporal-ui"
    container_port   = var.ui_container_port
  }

  depends_on = [aws_lb_listener.http, aws_ecs_service.server]

  tags = var.tags
}
*/
