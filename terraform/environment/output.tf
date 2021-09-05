output "lb_url" {
  value = aws_lb.nginx.dns_name
}

output "ec2_id" {
  value = aws_instance.ec2-bastion.id
}

output "ec2_private_ip" {
  value = aws_instance.ec2-bastion.private_ip
}
