terraform {
  required_version = ">= 0.14.10"
  backend "s3" {
    bucket = "numberfiveisalive-tf-state"
    key    = "environment.tfstate"
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
