variable "master_user_password" {}

resource "aws_elasticsearch_domain" "poc" {
  domain_name           = "poc"
  elasticsearch_version = "7.10"
  encrypt_at_rest {
    enabled = true
  }

  ebs_options {
    ebs_enabled = true
    volume_size = "10"
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  cluster_config {
    instance_type  = "t3.small.elasticsearch"
    instance_count = 1
  }

  node_to_node_encryption {
    enabled = true
  }

  vpc_options {
    security_group_ids = [aws_security_group.elastic-search.id]
    subnet_ids         = [element(module.vpc.private_subnets, 0)]
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true

    # TODO switch to terraform sops to read in an encrypted file and set master_user_password with that value.
    master_user_options {
      master_user_name     = "the-one-and-only"
      master_user_password = var.master_user_password
    }
  }
}

resource "aws_security_group" "elastic-search" {
  name   = "elastic-search"
  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group_rule" "elastic-search-ingress" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["10.0.0.0/16"]

  security_group_id = aws_security_group.elastic-search.id
}

resource "aws_security_group_rule" "elastic-search-egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/16"]
  security_group_id = aws_security_group.elastic-search.id
}
