output "lb_url" {
  value = aws_lb.nginx.dns_name
}

output "ec2_id" {
  value = aws_instance.ec2-bastion.id
}

output "ec2_private_ip" {
  value = aws_instance.ec2-bastion.private_ip
}

output "es_endpoint" {
  value = aws_elasticsearch_domain.poc.endpoint
}

output "es_kibana_endpoint" {
  value = aws_elasticsearch_domain.poc.kibana_endpoint
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/id_rsa ec2-user@${aws_instance.ec2-bastion.id} -L 8080:${aws_instance.ec2-bastion.private_ip}:22 -L 9090:${aws_elasticsearch_domain.poc.endpoint}:443"
}
