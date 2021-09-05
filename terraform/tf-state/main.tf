terraform {
  required_version = ">= 0.14.10"

  # First terraform apply this will be commented. Once the terraform
  # apply has deploy these resources un-comment the s3 backend block
  # and upload the state to s3.
  backend "s3" {
    bucket = "numberfiveisalive-tf-state"
    key    = "tf-state.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  default_tags {
    tags = {
      Environment = "poc"
      Owner       = "johnny5"
      Project     = "tf-state"
    }
  }
}

# https://www.terraform.io/docs/language/settings/backends/s3.html

# TODO: create iam policies for s3/dynamodb to limit access.

resource "aws_s3_bucket" "tf-state" {
  bucket = "numberfiveisalive-tf-state"
  acl    = "private"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "aws:kms"
      }
    }
  }
}

resource "aws_dynamodb_table" "tf-state-lock" {
  name           = "numberfiveisalive-tf-state-lock"
  read_capacity  = 2
  write_capacity = 2
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
