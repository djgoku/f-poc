data "aws_caller_identity" "current" {}

resource "aws_ecs_cluster" "main" {
  name = "main"

  capacity_providers = ["FARGATE_SPOT"]
}

resource "aws_ecs_task_definition" "nginx" {
  family                   = "service"
  container_definitions    = file("files/nginx.json")
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.nginx.arn
}

resource "aws_ecs_service" "nginx" {
  name            = "nginx"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.nginx.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.nginx.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.nginx.arn
    container_name   = "nginx"
    container_port   = 80
  }
}

resource "aws_lb" "nginx" {
  name               = "nginx-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.nginx-lb.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_listener" "nginx" {
  load_balancer_arn = aws_lb.nginx.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx.arn
  }
}

resource "aws_lb_target_group" "nginx" {
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id

  # https://github.com/hashicorp/terraform-provider-aws/issues/636
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "nginx-tg"
  }
}

resource "aws_security_group" "nginx-lb" {
  name   = "nginx-lb"
  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group_rule" "nginx-lb-ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nginx-lb.id
}

resource "aws_security_group_rule" "nginx-lb-egress" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.nginx-lb.id
  source_security_group_id = aws_security_group.nginx.id
}

resource "aws_security_group" "nginx" {
  name   = "nginx"
  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group_rule" "nginx-ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/16"]
  security_group_id = aws_security_group.nginx.id
}

resource "aws_security_group_rule" "nginx-egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nginx.id
}

resource "aws_iam_role" "nginx" {
  name = "nginx-role"

  assume_role_policy = data.aws_iam_policy_document.nginx-assume-role.json
}

resource "aws_iam_policy" "nginx" {
  name = "nginx-policy"

  policy = data.aws_iam_policy_document.nginx.json
}

data "aws_iam_policy_document" "nginx-assume-role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_cloudwatch_log_group" "nginx" {
  name = "/aws/ecs/nginx-log-group"
}

data "aws_iam_policy_document" "nginx" {
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogStream",
    ]
    resources = ["arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/ecs/nginx-log-group:*"]
  }

  statement {
    sid       = "GetAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "nginx-attach" {
  role       = aws_iam_role.nginx.name
  policy_arn = aws_iam_policy.nginx.arn
}

# terraform doesn't support this so it was deployed through aws
# console. We would need to deploy all the pieces ourselves if we
# didn't want to use this terraform resource.
#
# https://github.com/hashicorp/terraform-provider-aws/issues/17090
#
# resource "aws_cloudwatch_log_subscription_filter" "nginx" {
#   name = "ecs-nginx-cloudwatch-logs-to-elastic-search"

#   role_arn        = aws_iam_role.ecs-cloudwatch-elastic-search-subscription.arn
#   log_group_name  = aws_cloudwatch_log_group.nginx.name
#   filter_pattern  = "- \"ELB-HealthChecker\""
#   destination_arn = aws_elasticsearch_domain.poc.arn
# }

resource "aws_iam_role" "ecs-cloudwatch-elastic-search-subscription" {
  name = "ecs-cloudwatch-elastic-search-subscription"

  assume_role_policy = data.aws_iam_policy_document.ecs-cloudwatch-elastic-search-subscription-assume-role.json
}

data "aws_iam_policy_document" "ecs-cloudwatch-elastic-search-subscription-assume-role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "ecs-cloudwatch-elastic-search-subscription" {
  name = "ecs-cloudwatch-elastic-search-subscription-policy"

  policy = data.aws_iam_policy_document.ecs-cloudwatch-elastic-search-subscription.json
}

# TODO investigate what the least privileged access could be here.
data "aws_iam_policy_document" "ecs-cloudwatch-elastic-search-subscription" {
  statement {
    sid    = "ElasticSearchAccess"
    effect = "Allow"
    actions = [
      "es:*"
    ]
    resources = ["arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:domain:/poc/*"]
  }

  statement {
    sid    = "LambdaAccess"
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "logs:PutLogEvents",
      "logs:CreateLogGroup",
      "logs:CreateLogStream"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "ecs-cloudwatch-elastic-search-subscription-attach" {
  role       = aws_iam_role.ecs-cloudwatch-elastic-search-subscription.name
  policy_arn = aws_iam_policy.ecs-cloudwatch-elastic-search-subscription.arn
}
