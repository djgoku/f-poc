variable "ec2_public_key" {
  description = "AWS EC2 EC2 public key"
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDZrXt2H2I2qeCLvWVvsJ2Ss9KcbbiQbKGTsG2W9a73hreFfRHBlxYgaTGn4MmC9dqT60fUZ4v8gRNxgO6V9S89v2F06bGaCo6jlYOFWyANUTdwGU9GMXRrT2jGlKhSxrK6RFdXzlk6wPAvgjc5X9t9kklOhavd0xwJsgopDIBUPq+qCsW3e8v/aX6lz/AGHkhGY67Ghh6TGqVhe1zpFfcXYIm6tr/i9Z2UtV5VkTOp2RzDxUeG7N4aa0DNPCnzyfmiUNWa0e8G6LeTEIX7rOwgrRZmHr8tMQFl1k1m5i/ilVnY/8UNzHCkHvLUE1puwMu4D/CQ83msypiheuYvWMqV"
}

resource "aws_key_pair" "ec2-bastion" {
  key_name   = "johnny5"
  public_key = var.ec2_public_key
}

data "aws_ami" "amzn2" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.*-x86_64-gp2"]
  }
  owners = ["137112412989"]
}

resource "aws_instance" "ec2-bastion" {
  ami                  = data.aws_ami.amzn2.id
  instance_type        = "t3.micro"
  key_name             = aws_key_pair.ec2-bastion.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2-bastion.id

  subnet_id              = element(module.vpc.private_subnets, 0)
  vpc_security_group_ids = [aws_security_group.ec2-bastion.id]
}

resource "aws_security_group" "ec2-bastion" {
  name   = "ec2-bastion"
  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group_rule" "egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["10.0.0.0/16", "0.0.0.0/0"]

  security_group_id = aws_security_group.ec2-bastion.id
}

resource "aws_iam_instance_profile" "ec2-bastion" {
  name = "ec2-bastion"

  role = aws_iam_role.ec2-bastion.name
}

resource "aws_iam_role" "ec2-bastion" {
  name = "ec2-bastion"

  assume_role_policy = data.aws_iam_policy_document.ec2-bastion-assume-role.json
}

data "aws_iam_policy_document" "ec2-bastion-assume-role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ssm-managed-role" {
  role       = aws_iam_role.ec2-bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
